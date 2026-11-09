import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/canvas_provider.dart';

/// Floating reference image widget.
/// Users can move, scale, adjust opacity, and dismiss without affecting canvas artwork.
class ReferenceImageWidget extends ConsumerStatefulWidget {
  const ReferenceImageWidget({super.key});

  @override
  ConsumerState<ReferenceImageWidget> createState() =>
      _ReferenceImageWidgetState();
}

class _ReferenceImageWidgetState extends ConsumerState<ReferenceImageWidget> {
  Offset _position = const Offset(40, 100);
  double _scale = 1.0;
  double _opacity = 0.9;
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final refData = ref.watch(canvasProvider.select((s) => s.referenceImage));
    if (refData == null || !refData.isVisible) {
      return const SizedBox.shrink();
    }

    final file = File(refData.path);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    final cardWidth = 220.0 * _scale;
    final cardHeight = 170.0 * _scale;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Opacity(
        opacity: _opacity.clamp(0.1, 1.0),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: const Color(0xEE1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with separate drag handle and click buttons
              Container(
                height: 38,
                padding: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E2E2E),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    // Dedicated Draggable title area
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _position += details.delta;
                          });
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.drag_indicator,
                                size: 18, color: Colors.white54),
                            SizedBox(width: 4),
                            Text(
                              'Reference',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Minimize / Expand button
                    IconButton(
                      icon: Icon(
                        _isMinimized ? Icons.expand_more : Icons.expand_less,
                        size: 20,
                        color: Colors.white70,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      onPressed: () =>
                          setState(() => _isMinimized = !_isMinimized),
                    ),

                    // Guaranteed responsive Close button
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Close Reference',
                      onPressed: () {
                        ref
                            .read(canvasProvider.notifier)
                            .clearReferenceImage();
                      },
                    ),
                  ],
                ),
              ),

              if (!_isMinimized) ...[
                // Image preview with pinch-to-zoom
                ClipRRect(
                  child: Image.file(
                    file,
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.contain,
                  ),
                ),
                // Controls bar: Opacity slider & Scale adjustment
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF242424),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity, size: 14, color: Colors.white54),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            trackHeight: 2,
                          ),
                          child: Slider(
                            value: _opacity,
                            min: 0.2,
                            max: 1.0,
                            onChanged: (val) => setState(() => _opacity = val),
                          ),
                        ),
                      ),
                      // Zoom in / out buttons
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          setState(() {
                            _scale = (_scale - 0.15).clamp(0.6, 3.0);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 18, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          setState(() {
                            _scale = (_scale + 0.15).clamp(0.6, 3.0);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
