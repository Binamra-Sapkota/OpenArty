import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/layer_provider.dart';
import '../../providers/canvas_provider.dart';
import 'layer_item.dart';

class LayerPanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const LayerPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerState = ref.watch(layerProvider);
    final layerNotifier = ref.read(layerProvider.notifier);
    final screenW = MediaQuery.of(context).size.width;

    return Container(
      width: screenW < 330 ? screenW - 20 : 310,
      constraints: const BoxConstraints(maxHeight: 520),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Layers (${layerState.layers.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF6C63FF)),
                    tooltip: 'Add Layer',
                    onPressed: () => layerNotifier.addLayer(),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                      onPressed: onClose,
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 12, color: Colors.white12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: layerState.layers.length,
              itemBuilder: (context, index) {
                final layer = layerState.layers[index];
                final isActive = layer.id == layerState.activeLayerId;
                return LayerItem(
                  layer: layer,
                  isActive: isActive,
                  onSelect: () {
                    layerNotifier.setActiveLayer(layer.id);
                    ref.read(canvasProvider.notifier).setActiveLayer(layer.id);
                  },
                  onToggleVisibility: () => layerNotifier.toggleVisibility(layer.id),
                  onToggleLock: () => layerNotifier.toggleLock(layer.id),
                  onDuplicate: () => layerNotifier.duplicateLayer(layer.id),
                  onDelete: () {
                    layerNotifier.removeLayer(layer.id);
                    final newActive = ref.read(layerProvider).activeLayerId;
                    ref.read(canvasProvider.notifier).setActiveLayer(newActive);
                  },
                  onTransform: () {
                    layerNotifier.setActiveLayer(layer.id);
                    ref.read(canvasProvider.notifier).setActiveLayer(layer.id);
                    ref.read(canvasProvider.notifier).setTool(DrawingTool.transform);
                    onClose?.call();
                  },
                  onOpacityChanged: (v) => layerNotifier.setOpacity(layer.id, v),
                  onBlendModeChanged: (mode) =>
                      layerNotifier.setBlendMode(layer.id, mode),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => layerNotifier.mergeVisible(),
            icon: const Icon(Icons.merge_type, size: 16),
            label: const Text('Merge Visible Layers', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
