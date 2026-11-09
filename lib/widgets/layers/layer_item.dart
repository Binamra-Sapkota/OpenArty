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
            title: Text(
              layer.name,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${layer.blendMode.displayName} • ${(layer.opacity * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    if (val == 'duplicate') onDuplicate();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicate Layer', style: TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Layer', style: TextStyle(color: Colors.redAccent)),
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
}
