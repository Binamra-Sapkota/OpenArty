import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/layer_model.dart';
import '../../providers/layer_provider.dart';
import '../../providers/canvas_provider.dart';
import 'layer_item.dart';

class LayerPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  final Function(String layerId)? onEditText;

  const LayerPanel({super.key, this.onClose, this.onEditText});

  void _showEditTextDialog(BuildContext context, WidgetRef ref, LayerModel layer) {
    final textController = TextEditingController(text: layer.textContent ?? '');
    double fontSize = layer.fontSize ?? 42.0;
    Color textColor = layer.textColor ?? Colors.white;
    bool isBold = layer.isBold;
    bool isItalic = layer.isItalic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.title, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 8),
              Text('Edit Text Layer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Edit text...',
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
                    IconButton(
                      icon: Icon(Icons.format_bold,
                          color: isBold ? const Color(0xFF6C63FF) : Colors.white38),
                      tooltip: 'Bold',
                      onPressed: () => setDialogState(() => isBold = !isBold),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic,
                          color: isItalic ? const Color(0xFF6C63FF) : Colors.white38),
                      tooltip: 'Italic',
                      onPressed: () => setDialogState(() => isItalic = !isItalic),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Size: ', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 14.0,
                        max: 180.0,
                        onChanged: (v) => setDialogState(() => fontSize = v),
                      ),
                    ),
                    Text('${fontSize.round()} pt',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
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
              child: const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  ref.read(layerProvider.notifier).updateTextLayer(
                    layer.id,
                    text: txt,
                    fontSize: fontSize,
                    color: textColor,
                    isBold: isBold,
                    isItalic: isItalic,
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
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: true,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                layerNotifier.reorderLayer(oldIndex, newIndex);
              },
              itemCount: layerState.layers.length,
              itemBuilder: (context, index) {
                final layer = layerState.layers[index];
                final isActive = layer.id == layerState.activeLayerId;
                return Container(
                  key: ValueKey(layer.id),
                  child: LayerItem(
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
                    onEditText: () => _showEditTextDialog(context, ref, layer),
                    onRename: (newName) =>
                        layerNotifier.renameLayer(layer.id, newName),
                    onMoveUp: () => layerNotifier.moveLayerUp(layer.id),
                    onMoveDown: () => layerNotifier.moveLayerDown(layer.id),
                    onOpacityChanged: (v) => layerNotifier.setOpacity(layer.id, v),
                    onBlendModeChanged: (mode) =>
                        layerNotifier.setBlendMode(layer.id, mode),
                  ),
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
