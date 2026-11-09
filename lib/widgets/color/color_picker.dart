import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

class ColorPickerSheet extends ConsumerStatefulWidget {
  const ColorPickerSheet({super.key});

  @override
  ConsumerState<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<ColorPickerSheet> {
  late Color _pickerColor;

  static const List<Color> _defaultPalette = [
    Colors.black,
    Colors.white,
    Color(0xFF808080),
    Color(0xFFFF0055),
    Color(0xFFFF5722),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF673AB7),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF00E676),
    Color(0xFFFF9100),
  ];

  @override
  void initState() {
    super.initState();
    _pickerColor = ref.read(drawingColorProvider);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(drawingColorProvider);
    final colorNotifier = ref.read(drawingColorProvider.notifier);
    final history = colorNotifier.colorHistory;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF222222),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Color Palette & Wheel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ColorPicker(
              pickerColor: _pickerColor,
              onColorChanged: (newColor) {
                setState(() => _pickerColor = newColor);
                colorNotifier.setColor(newColor);
              },
              colorPickerWidth: 280,
              pickerAreaHeightPercent: 0.65,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [],
              pickerAreaBorderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Palette Presets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _defaultPalette.map((col) {
                final isSelected = currentColor.value == col.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _pickerColor = col);
                    colorNotifier.setColor(col);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
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
              const SizedBox(height: 14),
              const Text(
                'Recent Colors',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final col = history[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _pickerColor = col);
                        colorNotifier.setColor(col);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
