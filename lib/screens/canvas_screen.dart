import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/canvas_model.dart';
import '../models/history_model.dart';
import '../models/project_model.dart';
import '../models/layer_model.dart';
import '../providers/canvas_provider.dart';
import '../providers/layer_provider.dart';
import '../providers/brush_provider.dart';
import '../utils/blend_modes.dart';
import '../utils/image_utils.dart';
import '../widgets/canvas/drawing_canvas.dart';
import '../widgets/canvas/quick_sliders.dart';
import '../widgets/canvas/reference_image_widget.dart';
import '../widgets/canvas/canvas_painter.dart';
import '../widgets/toolbar/top_toolbar.dart';
import '../widgets/toolbar/bottom_toolbar.dart';
import '../widgets/toolbar/brush_panel.dart';
import '../widgets/layers/layer_panel.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final ProjectModel? project;
  final CanvasModel? initialCanvas;

  const CanvasScreen({super.key, this.project, this.initialCanvas});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with WidgetsBindingObserver {
  bool _isBrushPanelOpen = false;
  bool _isLayerPanelOpen = false;
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  late String _effectiveProjectId;
  late String _effectiveProjectName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _effectiveProjectId = widget.project?.id ?? const Uuid().v4();
    _effectiveProjectName = widget.project?.name ?? 'Untitled Artwork';

    // Ensure the project is registered in Hive so it is immediately indexed
    if (Hive.isBoxOpen('projects')) {
      final box = Hive.box<ProjectModel>('projects');
      if (!box.containsKey(_effectiveProjectId)) {
        box.put(
          _effectiveProjectId,
          ProjectModel(
            id: _effectiveProjectId,
            name: _effectiveProjectName,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            canvasWidth: widget.initialCanvas?.width ?? 1080,
            canvasHeight: widget.initialCanvas?.height ?? 1080,
            dpi: widget.initialCanvas?.dpi ?? 150,
            layerCount: 1,
          ),
        );
      }
    }
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('last_opened_project_id', _effectiveProjectId);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAndRestoreProject();
      _startAutoSaveTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _saveArtworkDirectly();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.detached) {
      _saveArtworkDirectly();
    }
  }

  Future<void> _loadAndRestoreProject() async {
    final projectId = _effectiveProjectId;
    final savedData = await ImageUtils.loadProjectData(projectId);

    if (savedData != null && mounted) {
      try {
        final rawLayers = savedData['layers'] as List<dynamic>? ?? [];
        final layers = rawLayers
            .map((l) => LayerModel.fromJson(l as Map<String, dynamic>))
            .toList();
        final activeLayerId = savedData['activeLayerId'] as String? ??
            (layers.isNotEmpty ? layers.first.id : 'layer_1');

        final rawStrokes =
            savedData['committedStrokes'] as Map<String, dynamic>? ?? {};
        final committedStrokes = <String, List<DrawStroke>>{};
        rawStrokes.forEach((k, v) {
          if (v is List) {
            committedStrokes[k] = v
                .map((s) => DrawStroke.fromJson(s as Map<String, dynamic>))
                .toList();
          }
        });

        final w = (savedData['canvasWidth'] as num?)?.toInt() ??
            widget.project?.canvasWidth ??
            1080;
        final h = (savedData['canvasHeight'] as num?)?.toInt() ??
            widget.project?.canvasHeight ??
            1080;

        final bgColorVal = savedData['backgroundColor'] as int?;
        final bgColor = bgColorVal != null
            ? Color(bgColorVal)
            : (widget.initialCanvas?.backgroundColor ?? Colors.white);

        final canvasModel = CanvasModel(
          width: w,
          height: h,
          dpi: widget.project?.dpi ?? 150,
          backgroundColor: bgColor,
        );

        ref.read(layerProvider.notifier).setLayers(layers, activeLayerId);
        ref.read(canvasProvider.notifier).initCanvas(canvasModel, activeLayerId);
        ref.read(canvasProvider.notifier).setCommittedStrokes(committedStrokes);

        // Restore complete history undo/redo stacks
        final rawUndo = savedData['undoStack'] as List<dynamic>? ?? [];
        final undoStack = rawUndo
            .map((e) => CanvasHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        final rawRedo = savedData['redoStack'] as List<dynamic>? ?? [];
        final redoStack = rawRedo
            .map((e) => CanvasHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        ref.read(canvasProvider.notifier).setHistory(
              undoStack: undoStack,
              redoStack: redoStack,
            );

        for (final l in layers) {
          if (l.pixelData != null) {
            ui.decodeImageFromList(l.pixelData!, (img) {
              if (mounted) {
                ref.read(layerProvider.notifier).updateLayerImage(l.id, img);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error restoring saved project: $e');
      }
    } else {
      final activeLayer = ref.read(layerProvider).activeLayerId;
      final canvasModel = widget.initialCanvas ??
          CanvasModel(
            width: widget.project?.canvasWidth ?? 1080,
            height: widget.project?.canvasHeight ?? 1080,
            dpi: widget.project?.dpi ?? 150,
          );
      ref.read(layerProvider.notifier).resetLayers(layerId: activeLayer);
      ref.read(canvasProvider.notifier).initCanvas(canvasModel, activeLayer);

      // Ensure the project file is immediately flushed to disk
      _saveArtworkDirectly();
    }
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    // Non-blocking asynchronous save every 8 seconds when changes occur
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_hasUnsavedChanges && !_isSaving) {
        _saveArtworkNow(updateThumbnail: false);
      }
    });
  }

  Future<void> _showSaveProjectDialog() async {
    final controller = TextEditingController(text: _effectiveProjectName);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    final canvasState = ref.read(canvasProvider);
    final layerState = ref.read(layerProvider);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.bookmark_add, color: Color(0xFF6C63FF), size: 24),
            SizedBox(width: 10),
            Text(
              'Save Project',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save your artwork to the gallery to reopen and continue working later.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                labelStyle: TextStyle(color: Color(0xFF6C63FF)),
                hintText: 'Enter project name',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                ),
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${canvasState.canvas.width} × ${canvasState.canvas.height} px',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '${layerState.layers.length} Layers',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        'Auto-saves 8s',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save, size: 18, color: Colors.white),
            label: const Text('Save to Gallery',
                style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty) {
        _effectiveProjectName = newName;
      }
      await _saveArtworkNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Project "$_effectiveProjectName" saved to gallery!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF2C2C2C),
          ),
        );
      }
    }
  }

  Future<void> _saveArtworkNow({bool updateThumbnail = true}) async {
    if (_isSaving || !mounted) return;
    _isSaving = true;
    try {
      final canvasState = ref.read(canvasProvider);
      final layerState = ref.read(layerProvider);
      if (layerState.layers.isEmpty) return;

      final projectId = _effectiveProjectId;
      final canvasW = canvasState.canvas.width;
      final canvasH = canvasState.canvas.height;

      // Asynchronous non-blocking write to disk
      await ImageUtils.saveProjectData(
        projectId: projectId,
        layers: layerState.layers,
        committedStrokes: canvasState.committedStrokes,
        activeLayerId: layerState.activeLayerId,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        backgroundColor: canvasState.canvas.backgroundColor,
        historyUndoStack: canvasState.historyUndoStack,
        historyRedoStack: canvasState.historyRedoStack,
      );

      _hasUnsavedChanges = false;

      // Register and update Hive project model
      if (Hive.isBoxOpen('projects')) {
        final box = Hive.box<ProjectModel>('projects');
        var p = box.get(projectId);
        if (p == null) {
          p = ProjectModel(
            id: projectId,
            name: _effectiveProjectName,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            dpi: widget.project?.dpi ?? widget.initialCanvas?.dpi ?? 150,
            layerCount: layerState.layers.length,
          );
          await box.put(projectId, p);
        } else {
          p.name = _effectiveProjectName;
          p.modifiedAt = DateTime.now();
          p.canvasWidth = canvasW;
          p.canvasHeight = canvasH;
          p.layerCount = layerState.layers.length;
          await p.save();
        }
      }

      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('last_opened_project_id', projectId);
      }

      // Fast hardware-accelerated thumbnail generation when requested
      if (updateThumbnail) {
        await _saveProjectThumbnail(
            projectId, canvasW, canvasH, layerState, canvasState);
      }
    } catch (e) {
      debugPrint('Auto-save error: $e');
    } finally {
      _isSaving = false;
    }
  }

  void _saveArtworkDirectly() {
    try {
      final canvasState = ref.read(canvasProvider);
      final layerState = ref.read(layerProvider);
      if (layerState.layers.isEmpty) return;

      final projectId = _effectiveProjectId;
      final canvasW = canvasState.canvas.width;
      final canvasH = canvasState.canvas.height;

      ImageUtils.saveProjectDataSync(
        projectId: projectId,
        layers: layerState.layers,
        committedStrokes: canvasState.committedStrokes,
        activeLayerId: layerState.activeLayerId,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        backgroundColor: canvasState.canvas.backgroundColor,
        historyUndoStack: canvasState.historyUndoStack,
        historyRedoStack: canvasState.historyRedoStack,
      );

      if (Hive.isBoxOpen('projects')) {
        final box = Hive.box<ProjectModel>('projects');
        var p = box.get(projectId);
        if (p == null) {
          p = ProjectModel(
            id: projectId,
            name: _effectiveProjectName,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            dpi: widget.project?.dpi ?? widget.initialCanvas?.dpi ?? 150,
            layerCount: layerState.layers.length,
          );
          box.put(projectId, p);
        } else {
          p.name = _effectiveProjectName;
          p.modifiedAt = DateTime.now();
          p.canvasWidth = canvasW;
          p.canvasHeight = canvasH;
          p.layerCount = layerState.layers.length;
          p.save();
        }
      }

      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('last_opened_project_id', projectId);
      }
    } catch (_) {}
  }

  Future<void> _saveProjectThumbnail(
    String projectId,
    int width,
    int height,
    LayerState layerState,
    CanvasState canvasState,
  ) async {
    try {
      final brushList = ref.read(brushListProvider);
      final brushMap = {for (final b in brushList) b.id: b};

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = CanvasPainter(
        layers: layerState.layers,
        committedStrokes: canvasState.committedStrokes,
        currentStrokes: const [],
        activeLayerId: layerState.activeLayerId,
        brushMap: brushMap,
        showGrid: false,
        gridSize: canvasState.gridSize,
        symmetryMode: SymmetryMode.none,
        radialSymmetryCount: canvasState.radialSymmetryCount,
        showSymmetryGuide: false,
        canvasState: canvasState,
        layerImages: layerState.layerImages,
      );
      painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
      final picture = recorder.endRecording();

      final scale = math.min(256.0 / width, 256.0 / height);
      final thumbW = (width * scale).round().clamp(64, 256);
      final thumbH = (height * scale).round().clamp(64, 256);
      final image = await picture.toImage(thumbW, thumbH);
      final thumbPath = await ImageUtils.saveThumbnail(image, projectId);

      if (Hive.isBoxOpen('projects')) {
        final box = Hive.box<ProjectModel>('projects');
        final p = box.get(projectId);
        if (p != null) {
          p.thumbnailPath = thumbPath;
          p.modifiedAt = DateTime.now();
          await p.save();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Keep canvas active layer synchronized with layer state
    ref.listen<String>(
      layerProvider.select((s) => s.activeLayerId),
      (prev, next) {
        if (next != prev) {
          ref.read(canvasProvider.notifier).setActiveLayer(next);
        }
      },
    );

    // Track unsaved changes for non-blocking debounced auto-saving
    ref.listen<Map<String, List<DrawStroke>>>(
      canvasProvider.select((s) => s.committedStrokes),
      (prev, next) {
        if (prev != null && prev != next) {
          _hasUnsavedChanges = true;
        }
      },
    );
    ref.listen<List<LayerModel>>(
      layerProvider.select((s) => s.layers),
      (prev, next) {
        if (prev != null && prev != next) {
          _hasUnsavedChanges = true;
        }
      },
    );

    final canvasState = ref.watch(canvasProvider);
    final layerState = ref.watch(layerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveArtworkNow();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141414),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  TopToolbar(
                    onToggleBrushPanel: () {
                      setState(() {
                        _isBrushPanelOpen = !_isBrushPanelOpen;
                        if (_isBrushPanelOpen) _isLayerPanelOpen = false;
                      });
                    },
                    onToggleLayerPanel: () {
                      setState(() {
                        _isLayerPanelOpen = !_isLayerPanelOpen;
                        if (_isLayerPanelOpen) _isBrushPanelOpen = false;
                      });
                    },
                    onManualSave: _showSaveProjectDialog,
                    isBrushPanelOpen: _isBrushPanelOpen,
                    isLayerPanelOpen: _isLayerPanelOpen,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        const DrawingCanvas(),
                        if (canvasState.activeTool != DrawingTool.transform)
                          const QuickSliders(),
                        const ReferenceImageWidget(),
                      ],
                    ),
                  ),
                  BottomToolbar(
                    onOpenBrushStudio: () {
                      setState(() {
                        _isBrushPanelOpen = !_isBrushPanelOpen;
                        if (_isBrushPanelOpen) _isLayerPanelOpen = false;
                      });
                    },
                  ),
                ],
              ),

              // Floating Transform Controls Bar (when Transform tool is active)
              if (canvasState.activeTool == DrawingTool.transform)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 74,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xEE222222),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF6C63FF), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            layerState.activeLayer?.name ?? 'Layer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Flip Horizontal
                          IconButton(
                            icon: const Icon(Icons.flip,
                                size: 20, color: Colors.white70),
                            tooltip: 'Flip Horizontal',
                            onPressed: () {
                              final l = layerState.activeLayer;
                              if (l != null && l.pixelData != null) {
                                ImageUtils.flipHorizontal(l.pixelData!).then((flipped) {
                                  ref.read(layerProvider.notifier).setLayerPixelData(l.id, flipped);
                                  ui.decodeImageFromList(flipped, (img) {
                                    ref.read(layerProvider.notifier).updateLayerImage(l.id, img);
                                  });
                                });
                              }
                            },
                          ),
                          // Flip Vertical
                          IconButton(
                            icon: const Icon(Icons.swap_vert,
                                size: 20, color: Colors.white70),
                            tooltip: 'Flip Vertical',
                            onPressed: () {
                              final l = layerState.activeLayer;
                              if (l != null && l.pixelData != null) {
                                ImageUtils.flipVertical(l.pixelData!).then((flipped) {
                                  ref.read(layerProvider.notifier).setLayerPixelData(l.id, flipped);
                                  ui.decodeImageFromList(flipped, (img) {
                                    ref.read(layerProvider.notifier).updateLayerImage(l.id, img);
                                  });
                                });
                              }
                            },
                          ),
                          // Rotate 90
                          IconButton(
                            icon: const Icon(Icons.rotate_right,
                                size: 20, color: Colors.white70),
                            tooltip: 'Rotate 90°',
                            onPressed: () {
                              final l = layerState.activeLayer;
                              if (l != null) {
                                ref
                                    .read(layerProvider.notifier)
                                    .updateLayerTransform(
                                      l.id,
                                      rotation: l.rotation + math.pi / 2,
                                    );
                              }
                            },
                          ),
                          // Reset Transform
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 20, color: Colors.white70),
                            tooltip: 'Reset',
                            onPressed: () {
                              final l = layerState.activeLayer;
                              if (l != null) {
                                ref
                                    .read(layerProvider.notifier)
                                    .resetLayerTransform(l.id);
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          // Done / Commit button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: const Size(50, 32),
                            ),
                            child: const Text('Done',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              final layerState = ref.read(layerProvider);
                              final prevId =
                                  layerState.previousLayerIdBeforeTransform;
                              ref
                                  .read(layerProvider.notifier)
                                  .restorePreviousLayerIfText();
                              final newActiveId =
                                  ref.read(layerProvider).activeLayerId;
                              ref
                                  .read(canvasProvider.notifier)
                                  .setActiveLayer(newActiveId);
                              ref
                                  .read(canvasProvider.notifier)
                                  .setTool(DrawingTool.brush);
                              if (prevId != null) {
                                final prevName = layerState.layers
                                    .firstWhereOrNull((l) => l.id == prevId)
                                    ?.name;
                                if (prevName != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Switched back to $prevName'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Floating Brush Studio Panel
              if (_isBrushPanelOpen)
                Positioned(
                  top: 52,
                  right: 10,
                  bottom: 70,
                  child: BrushPanel(
                    onClose: () => setState(() => _isBrushPanelOpen = false),
                  ),
                ),

              // Floating Layers Panel
              if (_isLayerPanelOpen)
                Positioned(
                  top: 52,
                  right: 10,
                  bottom: 70,
                  child: LayerPanel(
                    onClose: () => setState(() => _isLayerPanelOpen = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
