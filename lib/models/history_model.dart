import '../models/layer_model.dart';
import '../utils/blend_modes.dart';

/// Complete document snapshot for unified undo/redo across strokes, layers, text, and gradients
class CanvasHistoryEntry {
  final Map<String, List<DrawStroke>> committedStrokes;
  final List<LayerModel> layers;
  final String activeLayerId;

  const CanvasHistoryEntry({
    required this.committedStrokes,
    required this.layers,
    required this.activeLayerId,
  });

  Map<String, dynamic> toJson() => {
        'committedStrokes': committedStrokes.map(
          (k, v) => MapEntry(k, v.map((s) => s.toJson()).toList()),
        ),
        'layers': layers.map((l) => l.toJson()).toList(),
        'activeLayerId': activeLayerId,
      };

  factory CanvasHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawStrokes = json['committedStrokes'] as Map<String, dynamic>? ?? {};
    final committed = <String, List<DrawStroke>>{};
    rawStrokes.forEach((k, v) {
      if (v is List) {
        committed[k] = v
            .map((s) => DrawStroke.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    });
    final rawLayers = json['layers'] as List<dynamic>? ?? [];
    final layers = rawLayers
        .map((l) => LayerModel.fromJson(l as Map<String, dynamic>))
        .toList();
    final activeId = json['activeLayerId'] as String? ??
        (layers.isNotEmpty ? layers.first.id : 'layer_1');
    return CanvasHistoryEntry(
      committedStrokes: committed,
      layers: layers,
      activeLayerId: activeId,
    );
  }
}
