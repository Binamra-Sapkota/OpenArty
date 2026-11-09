import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/brush_provider.dart';

class BrushPanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const BrushPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBrush = ref.watch(activeBrushProvider);
    final brushNotifier = ref.read(activeBrushProvider.notifier);
    final brushList = ref.watch(brushListProvider);

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      width: screenW < 340 ? screenW - 20 : 320,
      constraints: BoxConstraints(maxHeight: screenH - 130),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brush Studio (${activeBrush.name})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Brush presets grid
          SizedBox(
            height: 110,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: brushList.length,
              itemBuilder: (context, i) {
                final brush = brushList[i];
                final isSelected = brush.id == activeBrush.id;
                return InkWell(
                  onTap: () => brushNotifier.setBrush(brush),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.white70 : Colors.white12,
                      ),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      brush.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 20, color: Colors.white12),
          // Size slider
          Row(
            children: [
              const Icon(Icons.line_weight, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Size', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const Spacer(),
              Text(
                '${activeBrush.size.round()} px',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          Slider(
            value: activeBrush.size,
            min: 1.0,
            max: 150.0,
            onChanged: (v) => brushNotifier.setSize(v),
          ),
          // Opacity slider
          Row(
            children: [
              const Icon(Icons.opacity, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Opacity', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const Spacer(),
              Text(
                '${(activeBrush.opacity * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          Slider(
            value: activeBrush.opacity,
            min: 0.05,
            max: 1.0,
            onChanged: (v) => brushNotifier.setOpacity(v),
          ),
          // Streamline / stabilization
          Row(
            children: [
              const Icon(Icons.gesture, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Stabilization', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const Spacer(),
              Text(
                '${(activeBrush.streamline * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          Slider(
            value: activeBrush.streamline,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => brushNotifier.setStreamline(v),
          ),
        ],
      ),
    ),
  );
  }
}
