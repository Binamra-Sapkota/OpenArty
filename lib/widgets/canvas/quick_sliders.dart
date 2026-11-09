import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

/// Floating movable quick sliders for brush size and brush opacity
/// Inspired by Autodesk SketchBook and Procreate.
/// Can be dragged anywhere on the screen by grabbing the top grip handle.
class QuickSliders extends ConsumerStatefulWidget {
  const QuickSliders({super.key});

  @override
  ConsumerState<QuickSliders> createState() => _QuickSlidersState();
}

class _QuickSlidersState extends ConsumerState<QuickSliders> {
  Offset _position = const Offset(8, 160);
  bool _isDraggingSize = false;
  bool _isDraggingOpacity = false;

  @override
  Widget build(BuildContext context) {
    final activeBrush = ref.watch(activeBrushProvider);
    final brushNotifier = ref.read(activeBrushProvider.notifier);
    final currentColor = ref.watch(drawingColorProvider);
    final media = MediaQuery.of(context).size;

    final clampedX =
        _position.dx.clamp(4.0, math.max(4.0, media.width - 50.0)).toDouble();
    final clampedY =
        _position.dy.clamp(10.0, math.max(10.0, media.height - 310.0)).toDouble();

    final isNearRight = clampedX > media.width / 2;

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preview pill on left if docked near right
          if (isNearRight && (_isDraggingSize || _isDraggingOpacity)) ...[
            _buildPreviewPill(activeBrush, currentColor),
            const SizedBox(width: 10),
          ],

          // Movable vertical slider pill container
          Container(
            width: 38,
            height: 270,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xEE1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Move Grip Handle (drag to reposition anywhere)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                    });
                  },
                  child: Container(
                    height: 24,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 6),

                // 2. Size Slider
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      setState(() => _isDraggingSize = true);
                    },
                    onVerticalDragUpdate: (details) {
                      final delta = -details.primaryDelta!;
                      final newSize =
                          (activeBrush.size + delta * 1.5).clamp(1.0, 500.0);
                      brushNotifier.setSize(newSize);
                    },
                    onVerticalDragEnd: (_) {
                      setState(() => _isDraggingSize = false);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.white70),
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final ratio =
                                  (activeBrush.size / 500.0).clamp(0.0, 1.0);
                              return Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: constraints.maxHeight * ratio,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SIZE',
                          style: TextStyle(
                            fontSize: 7.5,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white24, height: 12),

                // 3. Opacity Slider
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) {
                      setState(() => _isDraggingOpacity = true);
                    },
                    onVerticalDragUpdate: (details) {
                      final delta = -details.primaryDelta!;
                      final newOpacity =
                          (activeBrush.opacity + delta * 0.008).clamp(0.01, 1.0);
                      brushNotifier.setOpacity(newOpacity);
                    },
                    onVerticalDragEnd: (_) {
                      setState(() => _isDraggingOpacity = false);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.opacity, size: 10, color: Colors.white70),
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final ratio = activeBrush.opacity.clamp(0.0, 1.0);
                              return Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: constraints.maxHeight * ratio,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'OPAC',
                          style: TextStyle(
                            fontSize: 7.5,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 6),

                // 4. Bottom Move Grip Handle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                    });
                  },
                  child: Container(
                    height: 22,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Preview pill on right if docked near left
          if (!isNearRight && (_isDraggingSize || _isDraggingOpacity)) ...[
            const SizedBox(width: 10),
            _buildPreviewPill(activeBrush, currentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPill(dynamic activeBrush, Color currentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDraggingSize) ...[
            Text(
              '${activeBrush.size.round()} px',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: math.min(activeBrush.size.toDouble(), 48.0),
              height: math.min(activeBrush.size.toDouble(), 48.0),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: activeBrush.opacity.toDouble()),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
            ),
          ],
          if (_isDraggingOpacity) ...[
            Text(
              '${(activeBrush.opacity * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: activeBrush.opacity.toDouble()),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white38),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
