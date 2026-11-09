import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();
    final colorNotifier = ref.read(drawingColorProvider.notifier);
    final history = colorNotifier.colorHistory;
    final secondaryColor = colorNotifier.secondaryColor;

    return Container(
      constraints: const BoxConstraints(maxHeight: 560),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF222222),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with foreground/secondary swap
            Row(
              children: [
                // Foreground/Background swatches
                GestureDetector(
                  onTap: () {
                    colorNotifier.swapColors();
                    setState(() {
                      _hsvColor = HSVColor.fromColor(ref.read(drawingColorProvider));
                    });
                  },
                  child: SizedBox(
                    width: 50,
                    height: 40,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              border: Border.all(color: Colors.white30, width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: currentColor,
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Text(
                      'Tap swatches to swap FG/BG',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),
            // Circular Wheel + Saturation/Value Box
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: _HueRingPicker(
                  hue: _hsvColor.hue,
                  onHueChanged: (hue) {
                    _updateColor(_hsvColor.withHue(hue));
                  },
                  child: Center(
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: _SatValPicker(
                        hsv: _hsvColor,
                        onChanged: (sat, val) {
                          _updateColor(
                            _hsvColor.withSaturation(sat).withValue(val),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Opacity / Alpha slider
            Row(
              children: [
                const Icon(Icons.opacity, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('Alpha', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _hsvColor.alpha,
                    min: 0.05,
                    max: 1.0,
                    onChanged: (a) => _updateColor(_hsvColor.withAlpha(a)),
                  ),
                ),
                Text(
                  '${(_hsvColor.alpha * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            // Swatches
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _swatches.map((col) {
                final isSelected = currentColor.value == col.value;
                return GestureDetector(
                  onTap: () {
                    _updateColor(HSVColor.fromColor(col));
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final col = history[i];
                    return GestureDetector(
                      onTap: () => _updateColor(HSVColor.fromColor(col)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
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

class _HueRingPicker extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onHueChanged;
  final Widget child;

  const _HueRingPicker({
    required this.hue,
    required this.onHueChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _handleTouch(d.localPosition, context),
      onPanUpdate: (d) => _handleTouch(d.localPosition, context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _HueRingPainter(currentHue: hue),
          ),
          child,
        ],
      ),
    );
  }

  void _handleTouch(Offset pos, BuildContext context) {
    final center = const Offset(110, 110);
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final angle = math.atan2(dy, dx);
    double deg = (angle * 180 / math.pi) % 360;
    if (deg < 0) deg += 360;
    onHueChanged(deg);
  }
}

class _HueRingPainter extends CustomPainter {
  final double currentHue;

  _HueRingPainter({required this.currentHue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final sweepGradient = SweepGradient(
      colors: List.generate(
        360,
        (i) => HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor(),
      ),
    );

    final ringPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius, ringPaint);

    // Indicator thumb
    final thumbAngle = currentHue * math.pi / 180;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);

    canvas.drawCircle(
      Offset(thumbX, thumbY),
      10,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(thumbX, thumbY),
      10,
      Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter old) => old.currentHue != currentHue;
}

class _SatValPicker extends StatelessWidget {
  final HSVColor hsv;
  final void Function(double sat, double val) onChanged;

  const _SatValPicker({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _handleTouch(d.localPosition),
      onPanUpdate: (d) => _handleTouch(d.localPosition),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          size: const Size(110, 110),
          painter: _SatValPainter(hsv: hsv),
        ),
      ),
    );
  }

  void _handleTouch(Offset pos) {
    final sat = (pos.dx / 110.0).clamp(0.0, 1.0);
    final val = (1.0 - (pos.dy / 110.0)).clamp(0.0, 1.0);
    onChanged(sat, val);
  }
}

class _SatValPainter extends CustomPainter {
  final HSVColor hsv;

  _SatValPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final pureHue = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();

    // White to pure hue horizontal
    final horiz = LinearGradient(
      colors: [Colors.white, pureHue],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = horiz);

    // Transparent to black vertical
    final vert = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = vert);

    // Thumb position
    final tx = hsv.saturation * size.width;
    final ty = (1.0 - hsv.value) * size.height;

    canvas.drawCircle(
      Offset(tx, ty),
      6,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(tx, ty),
      6,
      Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SatValPainter old) =>
      old.hsv.hue != hsv.hue ||
      old.hsv.saturation != hsv.saturation ||
      old.hsv.value != hsv.value;
}
