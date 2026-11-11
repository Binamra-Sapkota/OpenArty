import 'package:flutter/material.dart';
import '../../models/layer_model.dart';

class LayerItem extends StatelessWidget {
  final LayerModel layer;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onTransform;
  final VoidCallback? onEditText;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<String>? onRename;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<LayerBlendMode> onBlendModeChanged;

  const LayerItem({
    super.key,
    required this.layer,
    required this.isActive,
    required this.onSelect,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onDuplicate,
    required this.onDelete,
    this.onTransform,
    this.onEditText,
    this.onMoveUp,
    this.onMoveDown,
    this.onRename,
    required this.onOpacityChanged,
    required this.onBlendModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF383848) : const Color(0xFF282828),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFF6C63FF) : Colors.white10,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            dense: true,
            onTap: onSelect,
            leading: IconButton(
              icon: Icon(
                layer.isVisible ? Icons.visibility : Icons.visibility_off,
                color: layer.isVisible ? Colors.white : Colors.white30,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
            title: Row(
              children: [
                Icon(
                  layer.isTextLayer
                      ? Icons.title
                      : (layer.layerType == LayerType.image || layer.pixelData != null
                          ? Icons.image
                          : (layer.name.startsWith('Gradient')
                              ? Icons.gradient
                              : Icons.brush)),
                  size: 16,
                  color: layer.isTextLayer
                      ? const Color(0xFF6C63FF)
                      : (layer.layerType == LayerType.image || layer.pixelData != null
                          ? Colors.tealAccent
                          : Colors.white70),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showRenameDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              layer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 13, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${layer.blendMode.displayName} • ${(layer.opacity * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline,
                      size: 18, color: Colors.white54),
                  tooltip: 'Rename Layer',
                  onPressed: () => _showRenameDialog(context),
                ),
                if (layer.isTextLayer)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Color(0xFF6C63FF)),
                    tooltip: 'Edit Text',
                    onPressed: onEditText,
                  ),
                IconButton(
                  icon: Icon(
                    layer.isLocked ? Icons.lock : Icons.lock_open,
                    size: 18,
                    color: layer.isLocked ? Colors.amber : Colors.white38,
                  ),
                  onPressed: onToggleLock,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.white70),
                  color: const Color(0xFF2C2C2C),
                  onSelected: (val) {
                    if (val == 'rename') _showRenameDialog(context);
                    if (val == 'edit_text') onEditText?.call();
                    if (val == 'transform') onTransform?.call();
                    if (val == 'move_up') onMoveUp?.call();
                    if (val == 'move_down') onMoveDown?.call();
                    if (val == 'duplicate') onDuplicate();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_rename_outline,
                              size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Rename Layer',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    if (layer.isTextLayer)
                      const PopupMenuItem(
                        value: 'edit_text',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Color(0xFF6C63FF)),
                            SizedBox(width: 8),
                            Text('Edit Text', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'transform',
                      child: Row(
                        children: [
                          Icon(Icons.open_with, size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Move / Transform', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move_up',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Place in Front (Up)', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move_down',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Place Behind (Down)', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Duplicate Layer', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete Layer', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Blend',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<LayerBlendMode>(
                          value: layer.blendMode,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2E2E2E),
                          underline: const SizedBox(),
                          items: LayerBlendMode.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(
                                mode.displayName,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (mode) {
                            if (mode != null) onBlendModeChanged(mode);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Opacity',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      Expanded(
                        child: Slider(
                          value: layer.opacity,
                          min: 0.0,
                          max: 1.0,
                          onChanged: onOpacityChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: layer.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    String layerTypeName = 'drawing';
    if (layer.isTextLayer) {
      layerTypeName = 'text';
    } else if (layer.layerType == LayerType.image || layer.pixelData != null) {
      layerTypeName = 'image';
    } else if (layer.name.startsWith('Gradient')) {
      layerTypeName = 'gradient';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.drive_file_rename_outline,
                color: Color(0xFF6C63FF), size: 22),
            SizedBox(width: 8),
            Text(
              'Rename Layer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom name for this $layerTypeName layer:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Layer Name',
                labelStyle: TextStyle(color: Color(0xFF6C63FF)),
                hintText: 'e.g. Lineart, Background, Colors',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                ),
              ),
              onSubmitted: (val) {
                final newName = val.trim();
                if (newName.isNotEmpty) {
                  onRename?.call(newName);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check, size: 16, color: Colors.white),
            label: const Text('Rename', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                onRename?.call(newName);
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
