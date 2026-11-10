import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

/// Top-Docked, Movable Quick Sliders Bar for Brush Size & Opacity
/// - Shifted to top of canvas by default
/// - Freely movable anywhere on screen via grip handle
/// - Size & Opacity can be adjusted via touch sliders OR by tapping to input exact numeric values via mobile keyboard
class QuickSliders extends ConsumerStatefulWidget {
  const QuickSliders({super.key});

  @override
  ConsumerState<QuickSliders> createState() => _QuickSlidersState();
}

class _QuickSlidersState extends ConsumerState<QuickSliders> {
  // Default position: docked at top of canvas
  Offset _position = const Offset(12, 10);
  bool _isDraggingSize = false;
  bool _isDraggingOpacity = false;

  void _openSizeInputDialog(
      BuildContext context, double currentSize, ActiveBrushNotifier notifier) {
    final controller =
        TextEditingController(text: currentSize.round().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Set Brush Size',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            suffixText: 'px (1 - 500)',
            suffixStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null) {
                notifier.setSize(val.clamp(1.0, 500.0));
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openOpacityInputDialog(BuildContext context, double currentOpacity,
      ActiveBrushNotifier notifier) {
    final controller =
        TextEditingController(text: (currentOpacity * 100).round().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Set Brush Opacity',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            suffixText: '% (1 - 100)',
            suffixStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF)),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null) {
                notifier.setOpacity((val / 100.0).clamp(0.01, 1.0));
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPill(dynamic activeBrush, Color currentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xEE242424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: math.min(24.0, math.max(6.0, (activeBrush.size as double) / 4)),
            height: math.min(24.0, math.max(6.0, (activeBrush.size as double) / 4)),
            decoration: BoxDecoration(
              color: currentColor.withValues(alpha: activeBrush.opacity as double),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${activeBrush.size.round()}px • ${(activeBrush.opacity * 100).round()}%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBrush = ref.watch(activeBrushProvider);
    final brushNotifier = ref.read(activeBrushProvider.notifier);
    final currentColor = ref.watch(drawingColorProvider);
    final media = MediaQuery.of(context).size;

    final barWidth = math.min(310.0, media.width - 24.0);
    final clampedX =
        _position.dx.clamp(4.0, math.max(4.0, media.width - barWidth - 8.0)).toDouble();
    final clampedY =
        _position.dy.clamp(6.0, math.max(6.0, media.height - 120.0)).toDouble();

    final showPreview = _isDraggingSize || _isDraggingOpacity;

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Movable horizontal quick slider bar
          Container(
            width: barWidth,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1E1E1E),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white24, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
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
                    width: 26,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const VerticalDivider(
                  color: Colors.white12,
                  width: 6,
                  indent: 8,
                  endIndent: 8,
                ),

                // 2. Brush Size (Tap chip for keyboard dialog, drag slider for touch)
                GestureDetector(
                  onTap: () => _openSizeInputDialog(
                      context, activeBrush.size, brushNotifier),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle,
                            size: 10, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 3),
                        Text(
                          '${activeBrush.size.round()}px',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard,
                            size: 11, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF6C63FF),
                      thumbColor: const Color(0xFF6C63FF),
                      inactiveTrackColor: Colors.white24,
                    ),
                    child: Slider(
                      value: activeBrush.size,
                      min: 1.0,
                      max: 500.0,
                      onChangeStart: (_) =>
                          setState(() => _isDraggingSize = true),
                      onChanged: (v) => brushNotifier.setSize(v),
                      onChangeEnd: (_) =>
                          setState(() => _isDraggingSize = false),
                    ),
                  ),
                ),

                const VerticalDivider(
                  color: Colors.white12,
                  width: 6,
                  indent: 8,
                  endIndent: 8,
                ),

                // 3. Brush Opacity (Tap chip for keyboard dialog, drag slider for touch)
                GestureDetector(
                  onTap: () => _openOpacityInputDialog(
                      context, activeBrush.opacity, brushNotifier),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.opacity,
                            size: 11, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 3),
                        Text(
                          '${(activeBrush.opacity * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard,
                            size: 11, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF00E5FF),
                      thumbColor: const Color(0xFF00E5FF),
                      inactiveTrackColor: Colors.white24,
                    ),
                    child: Slider(
                      value: activeBrush.opacity,
                      min: 0.01,
                      max: 1.0,
                      onChangeStart: (_) =>
                          setState(() => _isDraggingOpacity = true),
                      onChanged: (v) => brushNotifier.setOpacity(v),
                      onChangeEnd: (_) =>
                          setState(() => _isDraggingOpacity = false),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live visual preview pill while dragging slider
          if (showPreview) _buildPreviewPill(activeBrush, currentColor),
        ],
      ),
    );
  }
}
