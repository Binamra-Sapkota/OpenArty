import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import '../../providers/canvas_provider.dart';
import '../../providers/layer_provider.dart';
import '../../providers/brush_provider.dart';
import '../../widgets/canvas/canvas_painter.dart';
import '../../utils/image_utils.dart';

/// Clean, responsive top toolbar.
/// Eliminates the 147px overflow by grouping secondary tools into a sleek overflow menu.
class TopToolbar extends ConsumerWidget {
  final VoidCallback onToggleBrushPanel;
  final VoidCallback onToggleLayerPanel;
  final VoidCallback? onManualSave;
  final bool isBrushPanelOpen;
  final bool isLayerPanelOpen;

  const TopToolbar({
    super.key,
    required this.onToggleBrushPanel,
    required this.onToggleLayerPanel,
    this.onManualSave,
    required this.isBrushPanelOpen,
    required this.isLayerPanelOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);

    final canUndo = canvasState.canUndo;
    final canRedo = canvasState.canRedo;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showTitle = constraints.maxWidth >= 480;

          return Row(
            children: [
              // Back to Gallery
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                tooltip: 'Gallery',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: () => Navigator.of(context).maybePop(),
              ),

              // Title shown only on wider screens/tablets
              if (showTitle) ...[
                const SizedBox(width: 4),
                const Text(
                  'OpenArty',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],

              const Spacer(),

              // Undo
              IconButton(
                icon: const Icon(Icons.undo, size: 20),
                color: canUndo ? Colors.white : Colors.white24,
                tooltip: 'Undo',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: canUndo ? () => canvasNotifier.undo() : null,
              ),

              // Redo
              IconButton(
                icon: const Icon(Icons.redo, size: 20),
                color: canRedo ? Colors.white : Colors.white24,
                tooltip: 'Redo',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: canRedo ? () => canvasNotifier.redo() : null,
              ),

              // Fit to Screen
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined, size: 20),
                color: Colors.white70,
                tooltip: 'Fit Canvas to Screen',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: () {
                  final media = MediaQuery.of(context).size;
                  canvasNotifier.fitToScreen(Size(media.width, media.height - 110));
                },
              ),

              // Brush Studio toggle
              IconButton(
                icon: Icon(
                  Icons.brush,
                  size: 20,
                  color: isBrushPanelOpen
                      ? const Color(0xFF6C63FF)
                      : Colors.white70,
                ),
                tooltip: 'Brush Studio',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: onToggleBrushPanel,
              ),

              // Layer Panel toggle
              IconButton(
                icon: Icon(
                  Icons.layers,
                  size: 20,
                  color: isLayerPanelOpen
                      ? const Color(0xFF6C63FF)
                      : Colors.white70,
                ),
                tooltip: 'Layers',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: onToggleLayerPanel,
              ),

              // Overflow Menu for All Secondary Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                tooltip: 'Options & Canvas Settings',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                color: const Color(0xFF2C2C2C),
                onSelected: (value) => _handleMenuSelection(value, context, ref),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Color(0xFF6C63FF), size: 18),
                        SizedBox(width: 10),
                        Text('Export & Share', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import_layer',
                    child: Row(
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.amber, size: 18),
                        SizedBox(width: 10),
                        Text('Import Image to Layer', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reference_image',
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, color: Colors.lightBlueAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Reference Image', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: 'grid',
                    checked: canvasState.showGrid,
                    child: const Text('Show Grid', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'symmetry',
                    child: Row(
                      children: [
                        Icon(Icons.call_split, color: Colors.white70, size: 18),
                        SizedBox(width: 10),
                        Text('Symmetry Guide...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: 'palm_rejection',
                    checked: canvasState.palmRejectionEnabled,
                    child: const Text('Palm Rejection', style: TextStyle(color: Colors.white)),
                  ),
                  CheckedPopupMenuItem(
                    value: 'stylus_only',
                    checked: canvasState.stylusOnlyMode,
                    child: const Text('Stylus Only Mode', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'save_artwork',
                    child: Row(
                      children: [
                        Icon(Icons.save_outlined,
                            color: Color(0xFF6C63FF), size: 18),
                        SizedBox(width: 10),
                        Text('Save Artwork',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_layer',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Clear Active Layer', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleMenuSelection(String value, BuildContext context, WidgetRef ref) {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final layerState = ref.read(layerProvider);

    switch (value) {
      case 'export':
        _exportCanvas(context, ref);
        break;
      case 'import_layer':
        _importImageAsLayer(context, ref);
        break;
      case 'reference_image':
        _importReferenceImage(context, ref);
        break;
      case 'grid':
        canvasNotifier.toggleGrid();
        break;
      case 'symmetry':
        _showSymmetryDialog(context, ref);
        break;
      case 'palm_rejection':
        canvasNotifier.togglePalmRejection();
        break;
      case 'stylus_only':
        canvasNotifier.toggleStylusOnlyMode();
        break;
      case 'save_artwork':
        onManualSave?.call();
        break;
      case 'clear_layer':
        _confirmClear(context, canvasNotifier, layerState.activeLayerId);
        break;
    }
  }

  Future<void> _importImageAsLayer(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (context.mounted) {
          await _showImageCropDialog(context, bytes, file.name, ref);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import image: $e')),
        );
      }
    }
  }

  Future<void> _showImageCropDialog(
    BuildContext context,
    Uint8List bytes,
    String fileName,
    WidgetRef ref,
  ) async {
    String selectedCrop = 'Original';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Image Layer',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    color: Colors.black26,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Crop Mode (Preserves quality & ratio):',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _cropChip('Original', selectedCrop,
                        (val) => setDialogState(() => selectedCrop = val)),
                    _cropChip('1:1 Square', selectedCrop,
                        (val) => setDialogState(() => selectedCrop = val)),
                    _cropChip('16:9 Landscape', selectedCrop,
                        (val) => setDialogState(() => selectedCrop = val)),
                    _cropChip('9:16 Portrait', selectedCrop,
                        (val) => setDialogState(() => selectedCrop = val)),
                    _cropChip('4:3 Classic', selectedCrop,
                        (val) => setDialogState(() => selectedCrop = val)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child:
                  const Text('Add Layer', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                Uint8List finalBytes = bytes;
                if (selectedCrop != 'Original') {
                  final decoded = img.decodeImage(bytes);
                  if (decoded != null) {
                    int cropW = decoded.width;
                    int cropH = decoded.height;
                    int cropX = 0;
                    int cropY = 0;

                    if (selectedCrop == '1:1 Square') {
                      final side = math.min(decoded.width, decoded.height);
                      cropW = side;
                      cropH = side;
                      cropX = (decoded.width - side) ~/ 2;
                      cropY = (decoded.height - side) ~/ 2;
                    } else if (selectedCrop == '16:9 Landscape') {
                      if (decoded.width / decoded.height > 16 / 9) {
                        cropH = decoded.height;
                        cropW = (cropH * 16) ~/ 9;
                        cropX = (decoded.width - cropW) ~/ 2;
                      } else {
                        cropW = decoded.width;
                        cropH = (cropW * 9) ~/ 16;
                        cropY = (decoded.height - cropH) ~/ 2;
                      }
                    } else if (selectedCrop == '9:16 Portrait') {
                      if (decoded.width / decoded.height > 9 / 16) {
                        cropH = decoded.height;
                        cropW = (cropH * 9) ~/ 16;
                        cropX = (decoded.width - cropW) ~/ 2;
                      } else {
                        cropW = decoded.width;
                        cropH = (cropW * 16) ~/ 9;
                        cropY = (decoded.height - cropH) ~/ 2;
                      }
                    } else if (selectedCrop == '4:3 Classic') {
                      if (decoded.width / decoded.height > 4 / 3) {
                        cropH = decoded.height;
                        cropW = (cropH * 4) ~/ 3;
                        cropX = (decoded.width - cropW) ~/ 2;
                      } else {
                        cropW = decoded.width;
                        cropH = (cropW * 3) ~/ 4;
                        cropY = (decoded.height - cropH) ~/ 2;
                      }
                    }

                    final cropped = img.copyCrop(
                      decoded,
                      x: cropX,
                      y: cropY,
                      width: cropW,
                      height: cropH,
                    );
                    finalBytes = Uint8List.fromList(img.encodePng(cropped));
                  }
                }

                ref
                    .read(layerProvider.notifier)
                    .addImageLayer(finalBytes, name: fileName);
                ref
                    .read(canvasProvider.notifier)
                    .setTool(DrawingTool.transform);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Added layer! Drag to move, pinch or use slider to resize.'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cropChip(
      String label, String currentSelected, ValueChanged<String> onSelected) {
    final isSelected = label == currentSelected;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF383838),
      onSelected: (_) => onSelected(label),
    );
  }

  Future<void> _importReferenceImage(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        ref.read(canvasProvider.notifier).setReferenceImage(
              ReferenceImageData(path: file.path),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reference image added to canvas')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick reference image: $e')),
        );
      }
    }
  }

  void _showSymmetryDialog(BuildContext context, WidgetRef ref) {
    final canvasState = ref.read(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Symmetry Guide', style: TextStyle(color: Colors.white)),
        children: [
          RadioListTile<SymmetryMode>(
            title: const Text('No Symmetry', style: TextStyle(color: Colors.white)),
            value: SymmetryMode.none,
            groupValue: canvasState.symmetryMode,
            onChanged: (mode) {
              if (mode != null) canvasNotifier.setSymmetry(mode);
              Navigator.of(ctx).pop();
            },
          ),
          RadioListTile<SymmetryMode>(
            title: const Text('Vertical Mirror', style: TextStyle(color: Colors.white)),
            value: SymmetryMode.vertical,
            groupValue: canvasState.symmetryMode,
            onChanged: (mode) {
              if (mode != null) canvasNotifier.setSymmetry(mode);
              Navigator.of(ctx).pop();
            },
          ),
          RadioListTile<SymmetryMode>(
            title: const Text('Horizontal Mirror', style: TextStyle(color: Colors.white)),
            value: SymmetryMode.horizontal,
            groupValue: canvasState.symmetryMode,
            onChanged: (mode) {
              if (mode != null) canvasNotifier.setSymmetry(mode);
              Navigator.of(ctx).pop();
            },
          ),
          RadioListTile<SymmetryMode>(
            title: const Text('Radial Symmetry (8-way)', style: TextStyle(color: Colors.white)),
            value: SymmetryMode.radial,
            groupValue: canvasState.symmetryMode,
            onChanged: (mode) {
              if (mode != null) canvasNotifier.setSymmetry(mode);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }



  void _confirmClear(
      BuildContext context, CanvasNotifier notifier, String layerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Clear Layer?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear all strokes on the current layer. You can still undo this.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              notifier.clearLayer(layerId);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportCanvas(BuildContext context, WidgetRef ref) async {
    final canvasState = ref.read(canvasProvider);
    final layerState = ref.read(layerProvider);
    final brushList = ref.read(brushListProvider);
    final brushMap = {for (final b in brushList) b.id: b};

    final width = canvasState.canvas.width;
    final height = canvasState.canvas.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painter = CanvasPainter(
      layers: layerState.layers,
      committedStrokes: canvasState.committedStrokes,
      currentStrokes: const [],
      activeLayerId: canvasState.activeLayerId,
      brushMap: brushMap,
      showGrid: false,
      gridSize: canvasState.gridSize,
      symmetryMode: SymmetryMode.none,
      radialSymmetryCount: canvasState.radialSymmetryCount,
      showSymmetryGuide: false,
      canvasState: canvasState,
    );

    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Export Artwork',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. PNG Export
              _exportFormatTile(
                context: ctx,
                title: 'PNG Image (.png)',
                subtitle: 'Lossless raster with transparent background',
                icon: Icons.image,
                iconColor: const Color(0xFF6C63FF),
                onChooseLocation: () {
                  Navigator.of(ctx).pop();
                  _showDestinationPicker(
                    context: context,
                    formatName: 'PNG',
                    onSaveToFolder: (folder) =>
                        ImageUtils.exportAsPng(image, 'Artwork', customDir: '/storage/emulated/0/$folder/OpenArty'),
                    onShare: () async {
                      final path = await ImageUtils.exportAsPng(image, 'Artwork');
                      await Share.shareXFiles([XFile(path)], text: 'Artwork from OpenArty');
                      return path;
                    },
                  );
                },
                onSave: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPng(image, 'Artwork');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved PNG to:\n$path')),
                    );
                  }
                },
                onShare: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPng(image, 'Artwork');
                  await Share.shareXFiles([XFile(path)], text: 'Artwork from OpenArty');
                },
              ),

              const Divider(color: Colors.white12, height: 16),

              // 2. JPEG / JPG Export
              _exportFormatTile(
                context: ctx,
                title: 'JPEG Image (.jpg)',
                subtitle: 'Compressed photographic format (high quality 92%)',
                icon: Icons.photo,
                iconColor: Colors.amber,
                onChooseLocation: () {
                  Navigator.of(ctx).pop();
                  _showDestinationPicker(
                    context: context,
                    formatName: 'JPEG',
                    onSaveToFolder: (folder) =>
                        ImageUtils.exportAsJpeg(image, 'Artwork', customDir: '/storage/emulated/0/$folder/OpenArty'),
                    onShare: () async {
                      final path = await ImageUtils.exportAsJpeg(image, 'Artwork');
                      await Share.shareXFiles([XFile(path)], text: 'Artwork from OpenArty');
                      return path;
                    },
                  );
                },
                onSave: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsJpeg(image, 'Artwork');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved JPEG to:\n$path')),
                    );
                  }
                },
                onShare: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsJpeg(image, 'Artwork');
                  await Share.shareXFiles([XFile(path)], text: 'Artwork from OpenArty');
                },
              ),

              const Divider(color: Colors.white12, height: 16),

              // 3. SVG Vector Export
              _exportFormatTile(
                context: ctx,
                title: 'SVG Vector (.svg)',
                subtitle: 'Scalable vector strokes for Illustrator & Inkscape',
                icon: Icons.polyline,
                iconColor: const Color(0xFF00E5FF),
                onChooseLocation: () {
                  Navigator.of(ctx).pop();
                  _showDestinationPicker(
                    context: context,
                    formatName: 'SVG',
                    onSaveToFolder: (folder) => ImageUtils.exportAsSvg(
                      width: width,
                      height: height,
                      layers: layerState.layers,
                      committedStrokes: canvasState.committedStrokes,
                      projectName: 'Artwork',
                      backgroundColor: canvasState.canvas.backgroundColor,
                      customDir: '/storage/emulated/0/$folder/OpenArty',
                    ),
                    onShare: () async {
                      final path = await ImageUtils.exportAsSvg(
                        width: width,
                        height: height,
                        layers: layerState.layers,
                        committedStrokes: canvasState.committedStrokes,
                        projectName: 'Artwork',
                        backgroundColor: canvasState.canvas.backgroundColor,
                      );
                      await Share.shareXFiles([XFile(path)], text: 'Vector artwork from OpenArty');
                      return path;
                    },
                  );
                },
                onSave: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsSvg(
                    width: width,
                    height: height,
                    layers: layerState.layers,
                    committedStrokes: canvasState.committedStrokes,
                    projectName: 'Artwork',
                    backgroundColor: canvasState.canvas.backgroundColor,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved SVG to:\n$path')),
                    );
                  }
                },
                onShare: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsSvg(
                    width: width,
                    height: height,
                    layers: layerState.layers,
                    committedStrokes: canvasState.committedStrokes,
                    projectName: 'Artwork',
                    backgroundColor: canvasState.canvas.backgroundColor,
                  );
                  await Share.shareXFiles([XFile(path)], text: 'Vector artwork from OpenArty');
                },
              ),

              const Divider(color: Colors.white12, height: 16),

              // 4. PDF Document Export
              _exportFormatTile(
                context: ctx,
                title: 'PDF Document (.pdf)',
                subtitle: 'Print-ready portable document at full canvas resolution',
                icon: Icons.picture_as_pdf,
                iconColor: Colors.redAccent,
                onChooseLocation: () {
                  Navigator.of(ctx).pop();
                  _showDestinationPicker(
                    context: context,
                    formatName: 'PDF',
                    onSaveToFolder: (folder) => ImageUtils.exportAsPdf(
                      image,
                      'Artwork',
                      width: width,
                      height: height,
                      customDir: '/storage/emulated/0/$folder/OpenArty',
                    ),
                    onShare: () async {
                      final path = await ImageUtils.exportAsPdf(
                        image,
                        'Artwork',
                        width: width,
                        height: height,
                      );
                      await Share.shareXFiles([XFile(path)], text: 'PDF artwork from OpenArty');
                      return path;
                    },
                  );
                },
                onSave: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPdf(
                    image,
                    'Artwork',
                    width: width,
                    height: height,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved PDF to:\n$path')),
                    );
                  }
                },
                onShare: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPdf(
                    image,
                    'Artwork',
                    width: width,
                    height: height,
                  );
                  await Share.shareXFiles([XFile(path)], text: 'PDF artwork from OpenArty');
                },
              ),

              const Divider(color: Colors.white12, height: 16),

              // 5. PSD Document Export
              _exportFormatTile(
                context: ctx,
                title: 'Photoshop Document (.psd)',
                subtitle: 'Adobe Photoshop standard format with RGBA channels',
                icon: Icons.layers,
                iconColor: const Color(0xFF31A8FF),
                onChooseLocation: () {
                  Navigator.of(ctx).pop();
                  _showDestinationPicker(
                    context: context,
                    formatName: 'PSD',
                    onSaveToFolder: (folder) => ImageUtils.exportAsPsd(
                      image,
                      'Artwork',
                      width: width,
                      height: height,
                      customDir: '/storage/emulated/0/$folder/OpenArty',
                    ),
                    onShare: () async {
                      final path = await ImageUtils.exportAsPsd(
                        image,
                        'Artwork',
                        width: width,
                        height: height,
                      );
                      await Share.shareXFiles([XFile(path)], text: 'PSD artwork from OpenArty');
                      return path;
                    },
                  );
                },
                onSave: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPsd(
                    image,
                    'Artwork',
                    width: width,
                    height: height,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved PSD to:\n$path')),
                    );
                  }
                },
                onShare: () async {
                  Navigator.of(ctx).pop();
                  final path = await ImageUtils.exportAsPsd(
                    image,
                    'Artwork',
                    width: width,
                    height: height,
                  );
                  await Share.shareXFiles([XFile(path)], text: 'PSD artwork from OpenArty');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportFormatTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onChooseLocation,
    required VoidCallback onSave,
    required VoidCallback onShare,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Choose Location folder button
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.tealAccent, size: 20),
            tooltip: 'Choose Folder to Save',
            onPressed: onChooseLocation,
          ),
          // Save button
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white70, size: 20),
            tooltip: 'Save',
            onPressed: onSave,
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70, size: 20),
            tooltip: 'Share',
            onPressed: onShare,
          ),
        ],
      ),
    );
  }

  void _showDestinationPicker({
    required BuildContext context,
    required String formatName,
    required Future<String> Function(String folderName) onSaveToFolder,
    required Future<String> Function() onShare,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Save $formatName To...',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF6C63FF)),
                title: const Text('Pictures Folder', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Directly accessible in your phone gallery',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await onSaveToFolder('Pictures');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to Pictures:\n$path')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.tealAccent),
                title: const Text('Downloads Folder', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Save to your phone Download directory',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await onSaveToFolder('Download');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to Downloads:\n$path')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_shared, color: Colors.amber),
                title: const Text('Documents Folder', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Save to your phone Documents directory',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await onSaveToFolder('Documents');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to Documents:\n$path')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.purpleAccent),
                title: const Text('Share / Save to Other Apps', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Open Android share sheet to save anywhere or send to apps',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onShare();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
