import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/brush_model.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/brush_provider.dart';
import '../color/color_wheel.dart';

/// Professional mobile bottom toolbar inspired by Autodesk SketchBook.
/// Compact, responsive, and customizable.
class BottomToolbar extends ConsumerWidget {
  final VoidCallback onOpenBrushStudio;

  const BottomToolbar({
    super.key,
    required this.onOpenBrushStudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final activeTool = canvasState.activeTool;
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final brushNotifier = ref.read(activeBrushProvider.notifier);
    final activeBrush = ref.watch(activeBrushProvider);
    final currentColor = ref.watch(drawingColorProvider);

    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xF01E1E1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Brush Tool
              _ToolIcon(
                icon: Icons.brush,
                label: 'Brush',
                isActive: activeTool == DrawingTool.brush,
                onTap: () {
                  if (activeTool == DrawingTool.brush) {
                    onOpenBrushStudio();
                  } else {
                    canvasNotifier.setTool(DrawingTool.brush);
                    brushNotifier.restoreDrawingBrush();
                  }
                },
                onLongPress: onOpenBrushStudio,
              ),

              // 2. Pencil Tool
              _ToolIcon(
                icon: Icons.edit_outlined,
                label: 'Pencil',
                isActive: activeTool == DrawingTool.pencil,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.pencil);
                  brushNotifier.restoreDrawingBrush();
                  final pencil = ref.read(brushListProvider).firstWhere(
                        (b) => b.type == BrushType.pencil,
                        orElse: () => activeBrush,
                      );
                  brushNotifier.setBrush(pencil);
                },
              ),

              // 3. Eraser Tool
              _ToolIcon(
                icon: Icons.auto_fix_normal_outlined,
                label: 'Eraser',
                isActive: activeTool == DrawingTool.eraser,
                onTap: () {
                  if (activeTool == DrawingTool.eraser) {
                    // Toggle back to brush
                    canvasNotifier.setTool(DrawingTool.brush);
                    brushNotifier.restoreDrawingBrush();
                  } else {
                    canvasNotifier.setTool(DrawingTool.eraser);
                    brushNotifier.selectEraser();
                  }
                },
              ),

              // 4. Smudge Tool
              _ToolIcon(
                icon: Icons.blur_on,
                label: 'Smudge',
                isActive: activeTool == DrawingTool.smudge,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.smudge);
                  brushNotifier.restoreDrawingBrush();
                },
              ),

              const VerticalDivider(
                width: 14,
                color: Colors.white12,
                indent: 10,
                endIndent: 10,
              ),

              // 5. Color Puck (Current Color preview & picker trigger)
              GestureDetector(
                onTap: () => _openColorWheel(context),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Eyedropper Tool
              _ToolIcon(
                icon: Icons.colorize,
                label: 'Sample',
                isActive: activeTool == DrawingTool.eyedropper,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.eyedropper);
                },
              ),

              const VerticalDivider(
                width: 14,
                color: Colors.white12,
                indent: 10,
                endIndent: 10,
              ),

              // 7. Shapes Tool with Popup Menu
              PopupMenuButton<ShapeType>(
                tooltip: 'Shapes',
                color: const Color(0xFF2C2C2C),
                icon: Icon(
                  Icons.category_outlined,
                  color: activeTool == DrawingTool.shapes
                      ? const Color(0xFF6C63FF)
                      : Colors.white70,
                  size: 22,
                ),
                onSelected: (shape) {
                  canvasNotifier.setShapeType(shape);
                  canvasNotifier.setTool(DrawingTool.shapes);
                },
                itemBuilder: (ctx) => [
                  _shapeItem(ShapeType.rectangle, 'Rectangle', Icons.crop_square),
                  _shapeItem(ShapeType.roundedRectangle, 'Rounded Rectangle', Icons.crop_free),
                  _shapeItem(ShapeType.circle, 'Circle', Icons.circle_outlined),
                  _shapeItem(ShapeType.ellipse, 'Ellipse', Icons.brightness_1_outlined),
                  _shapeItem(ShapeType.line, 'Line', Icons.show_chart),
                  _shapeItem(ShapeType.triangle, 'Triangle', Icons.change_history),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    checked: canvasState.isShapeFilled,
                    value: canvasState.activeShapeType,
                    child: const Text('Fill Shape', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      canvasNotifier.setShapeFilled(!canvasState.isShapeFilled);
                    },
                  ),
                ],
              ),

              // 8. Text Tool
              _ToolIcon(
                icon: Icons.title,
                label: 'Text',
                isActive: activeTool == DrawingTool.text,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.text);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap anywhere on canvas to place or edit text'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                onLongPress: () => _showTextInputDialog(context, ref),
              ),

              // 9. Gradient Tool
              PopupMenuButton<bool>(
                tooltip: 'Gradient Tool',
                color: const Color(0xFF2C2C2C),
                icon: Icon(
                  Icons.gradient,
                  color: activeTool == DrawingTool.gradient
                      ? const Color(0xFF6C63FF)
                      : Colors.white70,
                  size: 22,
                ),
                onSelected: (isRadial) {
                  canvasNotifier.setRadialGradient(isRadial);
                  canvasNotifier.setTool(DrawingTool.gradient);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: false,
                    child: Row(
                      children: [
                        Icon(Icons.linear_scale, color: Colors.white70, size: 20),
                        SizedBox(width: 8),
                        Text('Linear Gradient', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: true,
                    child: Row(
                      children: [
                        Icon(Icons.blur_circular, color: Colors.white70, size: 20),
                        SizedBox(width: 8),
                        Text('Radial Gradient', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),

              // 10. Fill Tool (Paint Bucket)
              _ToolIcon(
                icon: Icons.format_color_fill,
                label: 'Fill',
                isActive: activeTool == DrawingTool.fill,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.fill);
                },
              ),

              // 11. Transform / Move Tool
              _ToolIcon(
                icon: Icons.open_with,
                label: 'Transform',
                isActive: activeTool == DrawingTool.transform,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.transform);
                },
              ),

              // 12. Selection Tool
              _ToolIcon(
                icon: Icons.crop_free,
                label: 'Select',
                isActive: activeTool == DrawingTool.selection,
                onTap: () {
                  canvasNotifier.setTool(DrawingTool.selection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ShapeType> _shapeItem(
      ShapeType type, String label, IconData icon) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _openColorWheel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ColorWheelSheet(),
    );
  }

  void _showTextInputDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    double fontSize = 32.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Add Text', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter text here...',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Size: ', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12.0,
                      max: 120.0,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                  ),
                  Text('${fontSize.round()} pt',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('Place Text', style: TextStyle(color: Colors.white)),
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  final color = ref.read(drawingColorProvider);
                  // Place text in canvas center
                  final canvas = ref.read(canvasProvider).canvas;
                  final center = Offset(
                    canvas.width / 2.0,
                    canvas.height / 2.0,
                  );
                  ref.read(canvasProvider.notifier).commitText(
                        txt,
                        center,
                        fontSize,
                        color,
                      );
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: const Color(0xFF6C63FF), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? const Color(0xFF6C63FF) : Colors.white70,
        ),
      ),
    );
  }
}
