import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

/// Professional Rectangular Color Selector Sheet (SketchBook style)
/// Features:
/// - Large rectangular Saturation-Brightness / Value matrix
/// - Horizontal rainbow Hue spectrum slider
/// - Alpha / Opacity transparency slider with checkerboard
/// - Swatches & recent color history
/// - Direct Hexadecimal / RGB value display with keyboard edit
class ColorWheelSheet extends ConsumerStatefulWidget {
  const ColorWheelSheet({super.key});

  @override
  ConsumerState<ColorWheelSheet> createState() => _ColorWheelSheetState();
}

class _ColorWheelSheetState extends ConsumerState<ColorWheelSheet> {
  late HSVColor _hsvColor;
  late Color _initialColor;

  static const List<Color> _swatches = [
    Colors.black,
    Colors.white,
    Color(0xFF9E9E9E),
    Color(0xFFD32F2F),
    Color(0xFFF57C00),
    Color(0xFFFFD600),
    Color(0xFF388E3C),
    Color(0xFF0097A7),
    Color(0xFF1976D2),
    Color(0xFF7B1FA2),
    Color(0xFFC2185B),
    Color(0xFF5D4037),
  ];

  @override
  void initState() {
    super.initState();
    _initialColor = ref.read(drawingColorProvider);
    _hsvColor = HSVColor.fromColor(_initialColor);
  }

  void _updateColor(HSVColor newHsv) {
    setState(() => _hsvColor = newHsv);
    ref.read(drawingColorProvider.notifier).setColor(newHsv.toColor());
  }

  void _openHexInputDialog(Color currentColor) {
    final hexString = currentColor.value
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    final controller = TextEditingController(text: hexString);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Enter Hex Color',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2),
          decoration: const InputDecoration(
            prefixText: '# ',
            prefixStyle:
                TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
            hintText: 'RRGGBB',
            hintStyle: TextStyle(color: Colors.white38),
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
              final hex = controller.text.trim();
              if (hex.length == 6) {
                final intVal = int.tryParse('FF$hex', radix: 16);
                if (intVal != null) {
                  _updateColor(
                      HSVColor.fromColor(Color(intVal).withValues(alpha: _hsvColor.alpha)));
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Set Color', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();
    final colorNotifier = ref.read(drawingColorProvider.notifier);
    final history = colorNotifier.colorHistory;
    final secondaryColor = colorNotifier.secondaryColor;

    return Container(
      constraints: const BoxConstraints(maxHeight: 620),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with Foreground/Secondary Swatch & Hex display
            Row(
              children: [
                // FG / BG overlapping boxes
                GestureDetector(
                  onTap: () {
                    colorNotifier.swapColors();
                    setState(() {
                      _hsvColor =
                          HSVColor.fromColor(ref.read(drawingColorProvider));
                    });
                  },
                  child: SizedBox(
                    width: 52,
                    height: 42,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              border: Border.all(color: Colors.white38, width: 1.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: currentColor,
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Color Info (Tap to edit Hex with keyboard)
                GestureDetector(
                  onTap: () => _openHexInputDialog(currentColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit, size: 14, color: Colors.white54),
                        ],
                      ),
                      Text(
                        'R: ${(currentColor.r * 255).round()}  G: ${(currentColor.g * 255).round()}  B: ${(currentColor.b * 255).round()}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 18),

            // 1. Large Rectangular Saturation-Value Matrix
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: _RectangularSatValBox(
                  hsv: _hsvColor,
                  onChanged: (sat, val) {
                    _updateColor(
                      _hsvColor.withSaturation(sat).withValue(val),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Horizontal Hue Spectrum Slider Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('HUE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white60,
                            letterSpacing: 0.8)),
                    Text('${_hsvColor.hue.round()}°',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 4),
                _RectangularHueSlider(
                  hue: _hsvColor.hue,
                  onChanged: (hue) {
                    _updateColor(_hsvColor.withHue(hue));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Horizontal Alpha / Opacity Slider Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('OPACITY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white60,
                            letterSpacing: 0.8)),
                    Text('${(_hsvColor.alpha * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 4),
                _RectangularAlphaSlider(
                  hsv: _hsvColor,
                  onChanged: (alpha) {
                    _updateColor(_hsvColor.withAlpha(alpha));
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Curated Swatches Row
            const Text(
              'PALETTE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _swatches.map((col) {
                final isSelected = currentColor.value == col.value;
                return GestureDetector(
                  onTap: () {
                    _updateColor(HSVColor.fromColor(col).withAlpha(_hsvColor.alpha));
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(color: Colors.black54, blurRadius: 4)
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            // 5. Recent History Row
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'RECENT COLORS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final col = history[i];
                    return GestureDetector(
                      onTap: () => _updateColor(
                          HSVColor.fromColor(col).withAlpha(_hsvColor.alpha)),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: col,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Rectangular Saturation & Brightness (Value) Box
class _RectangularSatValBox extends StatelessWidget {
  final HSVColor hsv;
  final void Function(double sat, double val) onChanged;

  const _RectangularSatValBox({
    required this.hsv,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, Size size) {
    final sat = (localPos.dx / size.width).clamp(0.0, 1.0);
    final val = (1.0 - (localPos.dy / size.height)).clamp(0.0, 1.0);
    onChanged(sat, val);
  }

  @override
  Widget build(BuildContext context) {
    final pureHueColor = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final thumbX = (hsv.saturation * width).clamp(0.0, width);
        final thumbY = ((1.0 - hsv.value) * height).clamp(0.0, height);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleTouch(d.localPosition, Size(width, height)),
          onPanUpdate: (d) => _handleTouch(d.localPosition, Size(width, height)),
          child: Stack(
            children: [
              // 1. Pure hue base
              Container(color: pureHueColor),
              // 2. Horizontal white gradient (Saturation: 0 -> 1)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.transparent],
                  ),
                ),
              ),
              // 3. Vertical black gradient (Value: 1 -> 0)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              // 4. Draggable circular crosshair indicator
              Positioned(
                left: thumbX - 11,
                top: thumbY - 11,
                child: IgnorePointer(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hsv.toColor(),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal Rainbow Hue Slider Bar
class _RectangularHueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _RectangularHueSlider({
    required this.hue,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, double width) {
    final h = ((localPos.dx / width) * 360.0).clamp(0.0, 360.0);
    onChanged(h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = ((hue / 360.0) * width).clamp(0.0, width);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleTouch(d.localPosition, width),
          onPanUpdate: (d) => _handleTouch(d.localPosition, width),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000), // 0°
                      Color(0xFFFFFF00), // 60°
                      Color(0xFF00FF00), // 120°
                      Color(0xFF00FFFF), // 180°
                      Color(0xFF0000FF), // 240°
                      Color(0xFFFF00FF), // 300°
                      Color(0xFFFF0000), // 360°
                    ],
                  ),
                ),
              ),
              Positioned(
                left: thumbX - 10,
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    height: 28,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal Opacity / Alpha Transparency Slider
class _RectangularAlphaSlider extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  const _RectangularAlphaSlider({
    required this.hsv,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, double width) {
    final a = (localPos.dx / width).clamp(0.01, 1.0);
    onChanged(a);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = hsv.toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = (hsv.alpha * width).clamp(0.0, width);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleTouch(d.localPosition, width),
          onPanUpdate: (d) => _handleTouch(d.localPosition, width),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Checkerboard background
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    size: Size(width, 24),
                    painter: _CheckerboardPainter(),
                    foregroundPainter: _GradientPainter(
                      colors: [
                        baseColor.withValues(alpha: 0.0),
                        baseColor.withValues(alpha: 1.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbX - 10,
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    height: 28,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 6.0;
    final paintLight = Paint()..color = const Color(0xFFCCCCCC);
    final paintDark = Paint()..color = const Color(0xFF888888);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paintLight : paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientPainter extends CustomPainter {
  final List<Color> colors;

  _GradientPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) => true;
}
