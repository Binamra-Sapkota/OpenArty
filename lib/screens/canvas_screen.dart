import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/canvas_model.dart';
import '../models/project_model.dart';
import '../providers/canvas_provider.dart';
import '../providers/layer_provider.dart';
import '../widgets/canvas/drawing_canvas.dart';
import '../widgets/canvas/quick_sliders.dart';
import '../widgets/canvas/reference_image_widget.dart';
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

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  bool _isBrushPanelOpen = false;
  bool _isLayerPanelOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeLayer = ref.read(layerProvider).activeLayerId;
      final canvasModel = widget.initialCanvas ??
          CanvasModel(
            width: widget.project?.canvasWidth ?? 1080,
            height: widget.project?.canvasHeight ?? 1080,
            dpi: widget.project?.dpi ?? 150,
          );
      ref.read(canvasProvider.notifier).initCanvas(canvasModel, activeLayer);
    });
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

    final canvasState = ref.watch(canvasProvider);
    final layerState = ref.watch(layerProvider);

    return Scaffold(
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
                  isBrushPanelOpen: _isBrushPanelOpen,
                  isLayerPanelOpen: _isLayerPanelOpen,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      const DrawingCanvas(),
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
                    border:
                        Border.all(color: const Color(0xFF6C63FF), width: 1.2),
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
                        // Scale Down (-)
                        IconButton(
                          icon: const Icon(Icons.zoom_out,
                              size: 20, color: Colors.white70),
                          tooltip: 'Scale Down',
                          onPressed: () {
                            final l = layerState.activeLayer;
                            if (l != null) {
                              ref
                                  .read(layerProvider.notifier)
                                  .updateLayerTransform(
                                    l.id,
                                    scale: (l.scale - 0.1).clamp(0.1, 10.0),
                                  );
                            }
                          },
                        ),
                        // Scale Up (+)
                        IconButton(
                          icon: const Icon(Icons.zoom_in,
                              size: 20, color: Colors.white70),
                          tooltip: 'Scale Up',
                          onPressed: () {
                            final l = layerState.activeLayer;
                            if (l != null) {
                              ref
                                  .read(layerProvider.notifier)
                                  .updateLayerTransform(
                                    l.id,
                                    scale: (l.scale + 0.1).clamp(0.1, 10.0),
                                  );
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
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                          onPressed: () => ref
                              .read(canvasProvider.notifier)
                              .setTool(DrawingTool.brush),
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
    );
  }
}
