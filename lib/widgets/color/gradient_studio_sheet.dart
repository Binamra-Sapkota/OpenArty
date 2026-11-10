import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/gradient_provider.dart';
import '../../providers/brush_provider.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/layer_provider.dart';

class GradientStudioSheet extends ConsumerStatefulWidget {
  const GradientStudioSheet({super.key});

  @override
  ConsumerState<GradientStudioSheet> createState() => _GradientStudioSheetState();
}

class _GradientStudioSheetState extends ConsumerState<GradientStudioSheet> {
  // 0 = Start Color active, 1 = End Color active
  int _activeColorStop = 0;

  static const List<Color> _quickSwatches = [
    Colors.black,
    Colors.white,
    Color(0xFF757575),
    Color(0xFFE53935),
    Color(0xFFFF5722),
    Color(0xFFFFB300),
    Color(0xFF43A047),
    Color(0xFF00ACC1),
    Color(0xFF1E88E5),
    Color(0xFF5E35B1),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
  ];

  @override
  Widget build(BuildContext context) {
    final gradientConfig = ref.watch(gradientConfigProvider);
    final gradientNotifier = ref.read(gradientConfigProvider.notifier);
    final currentDrawingColor = ref.watch(drawingColorProvider);

    final startColor = gradientConfig.startColor;
    final endColor = gradientConfig.endColor;
    final isRadial = gradientConfig.isRadial;

    return Container(
      constraints: const BoxConstraints(maxHeight: 620),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF222222),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Grab Bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.gradient, color: Color(0xFF6C63FF), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Gradient Studio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Gradient Preview Bar with Checkerboard Pattern
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Checkerboard background for transparency
                  CustomPaint(
                    painter: _CheckerboardPainter(cellSize: 8.0),
                  ),
                  // Gradient fill
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: isRadial
                          ? RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [startColor, endColor],
                            )
                          : LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [startColor, endColor],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Linear vs Radial Toggle & Swap
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Linear', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.linear_scale, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Radial', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.blur_circular, size: 16),
                      ),
                    ],
                    selected: {isRadial},
                    onSelectionChanged: (set) {
                      gradientNotifier.setIsRadial(set.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF6C63FF);
                        }
                        return const Color(0xFF2E2E2E);
                      }),
                      foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Swap Colors Button
                Tooltip(
                  message: 'Swap Start & End',
                  child: InkWell(
                    onTap: () => gradientNotifier.swapColors(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2E2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Swap', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Stops Selection (Start / End Tabs)
            Row(
              children: [
                Expanded(
                  child: _ColorStopCard(
                    title: 'Start Color',
                    color: startColor,
                    isActive: _activeColorStop == 0,
                    onTap: () => setState(() => _activeColorStop = 0),
                    onPickDetailed: () => _openColorPicker(
                      context,
                      initialColor: startColor,
                      onColorChanged: (c) {
                        gradientNotifier.setStartColor(c.withValues(alpha: startColor.a));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ColorStopCard(
                    title: 'End Color',
                    color: endColor,
                    isActive: _activeColorStop == 1,
                    onTap: () => setState(() => _activeColorStop = 1),
                    onPickDetailed: () => _openColorPicker(
                      context,
                      initialColor: endColor,
                      onColorChanged: (c) {
                        gradientNotifier.setEndColor(c.withValues(alpha: endColor.a));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Active Stop Opacity / Transparency Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _activeColorStop == 0
                            ? 'Start Transparency / Opacity'
                            : 'End Transparency / Opacity',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${((_activeColorStop == 0 ? gradientConfig.startOpacity : gradientConfig.endOpacity) * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _activeColorStop == 0
                        ? gradientConfig.startOpacity
                        : gradientConfig.endOpacity,
                    min: 0.0,
                    max: 1.0,
                    activeColor: const Color(0xFF6C63FF),
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      if (_activeColorStop == 0) {
                        gradientNotifier.setStartOpacity(v);
                      } else {
                        gradientNotifier.setEndOpacity(v);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Color Palette for active stop
            const Text(
              'Assign Color to Selected Stop:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickSwatches.map((swatch) {
                return GestureDetector(
                  onTap: () {
                    if (_activeColorStop == 0) {
                      gradientNotifier.setStartColor(
                        swatch.withValues(alpha: gradientConfig.startOpacity),
                      );
                    } else {
                      gradientNotifier.setEndColor(
                        swatch.withValues(alpha: gradientConfig.endOpacity),
                      );
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white30,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Presets with Transparency
            const Text(
              'Gradient & Transparency Presets:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: 'Color → Transparent',
                  color1: currentDrawingColor,
                  color2: currentDrawingColor.withValues(alpha: 0.0),
                  onTap: () {
                    gradientNotifier.setPreset(
                      currentDrawingColor.withValues(alpha: 1.0),
                      currentDrawingColor.withValues(alpha: 0.0),
                    );
                  },
                ),
                _PresetChip(
                  label: 'Black → Transparent',
                  color1: Colors.black,
                  color2: Colors.black.withValues(alpha: 0.0),
                  onTap: () {
                    gradientNotifier.setPreset(
                      Colors.black,
                      Colors.black.withValues(alpha: 0.0),
                    );
                  },
                ),
                _PresetChip(
                  label: 'White → Transparent',
                  color1: Colors.white,
                  color2: Colors.white.withValues(alpha: 0.0),
                  onTap: () {
                    gradientNotifier.setPreset(
                      Colors.white,
                      Colors.white.withValues(alpha: 0.0),
                    );
                  },
                ),
                _PresetChip(
                  label: 'Sunset (Orange → Magenta)',
                  color1: const Color(0xFFFF5722),
                  color2: const Color(0xFFE91E63),
                  onTap: () {
                    gradientNotifier.setPreset(
                      const Color(0xFFFF5722),
                      const Color(0xFFE91E63),
                    );
                  },
                ),
                _PresetChip(
                  label: 'Ocean (Cyan → Navy)',
                  color1: const Color(0xFF00E5FF),
                  color2: const Color(0xFF1A237E),
                  onTap: () {
                    gradientNotifier.setPreset(
                      const Color(0xFF00E5FF),
                      const Color(0xFF1A237E),
                    );
                  },
                ),
                _PresetChip(
                  label: 'Neon (Lime → Violet)',
                  color1: const Color(0xFF76FF03),
                  color2: const Color(0xFF7C4DFF),
                  onTap: () {
                    gradientNotifier.setPreset(
                      const Color(0xFF76FF03),
                      const Color(0xFF7C4DFF),
                    );
                  },
                ),
                _PresetChip(
                  label: 'Fire (Gold → Red)',
                  color1: const Color(0xFFFFD600),
                  color2: const Color(0xFFD50000),
                  onTap: () {
                    gradientNotifier.setPreset(
                      const Color(0xFFFFD600),
                      const Color(0xFFD50000),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Create in New Layer toggle
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text(
                  'Create in New Layer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Allows multiple independent gradients with separate blend modes & opacity',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                activeColor: const Color(0xFF6C63FF),
                value: gradientConfig.createInNewLayer,
                onChanged: (val) {
                  gradientNotifier.setCreateInNewLayer(val);
                },
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                    label: const Text(
                      'Add Gradient Layer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final layerState = ref.read(layerProvider);
                      final layerNotifier = ref.read(layerProvider.notifier);
                      final canvasNotifier = ref.read(canvasProvider.notifier);
                      final canvasState = ref.read(canvasProvider);

                      final newName = 'Gradient ${layerState.layers.length + 1}';
                      layerNotifier.addLayer(name: newName);
                      final newLayerId = ref.read(layerProvider).activeLayerId;

                      final canvasW = canvasState.canvas.width.toDouble();
                      final canvasH = canvasState.canvas.height.toDouble();

                      canvasNotifier.commitGradient(
                        Offset.zero,
                        gradientConfig.isRadial
                            ? Offset(canvasW, canvasH)
                            : Offset(0, canvasH),
                        gradientConfig.startColor,
                        gradientConfig.endColor,
                        isRadial: gradientConfig.isRadial,
                        layerId: newLayerId,
                      );

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $newName! Multiple gradients can now be layered.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.gesture, color: Colors.white, size: 18),
                    label: const Text(
                      'Drag on Canvas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      ref.read(canvasProvider.notifier).setTool(DrawingTool.gradient);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Drag across canvas to draw gradient'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openColorPicker(
    BuildContext context, {
    required Color initialColor,
    required ValueChanged<Color> onColorChanged,
  }) {
    Color temp = initialColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pick Color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            pickerAreaBorderRadius: BorderRadius.circular(10),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: const Text('Select', style: TextStyle(color: Colors.white)),
            onPressed: () {
              onColorChanged(temp);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ColorStopCard extends StatelessWidget {
  final String title;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onPickDetailed;

  const _ColorStopCard({
    required this.title,
    required this.color,
    required this.isActive,
    required this.onTap,
    required this.onPickDetailed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF333333) : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF) : Colors.white12,
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white60,
                  ),
                ),
                if (isActive)
                  const Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Swatch with checkerboard background
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _CheckerboardPainter(cellSize: 4.0)),
                      DecoratedBox(decoration: BoxDecoration(color: color)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: onPickDetailed,
                        child: const Text(
                          'Change...',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.color1,
    required this.color2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _CheckerboardPainter(cellSize: 3)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color1, color2]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final double cellSize;
  _CheckerboardPainter({this.cellSize = 8.0});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()..color = const Color(0xFFE0E0E0);
    final darkPaint = Paint()..color = const Color(0xFF9E9E9E);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
