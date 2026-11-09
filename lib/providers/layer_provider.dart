import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/layer_model.dart';

const _uuid = Uuid();

class LayerState {
  final List<LayerModel> layers;
  final String activeLayerId;
  final Map<String, ui.Image?> layerImages; // Rendered image cache

  const LayerState({
    required this.layers,
    required this.activeLayerId,
    this.layerImages = const {},
  });

  LayerModel? get activeLayer {
    try {
      return layers.firstWhere((l) => l.id == activeLayerId);
    } catch (_) {
      return layers.isNotEmpty ? layers.first : null;
    }
  }

  int get activeLayerIndex {
    return layers.indexWhere((l) => l.id == activeLayerId);
  }

  LayerState copyWith({
    List<LayerModel>? layers,
    String? activeLayerId,
    Map<String, ui.Image?>? layerImages,
  }) {
    return LayerState(
      layers: layers ?? this.layers,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      layerImages: layerImages ?? this.layerImages,
    );
  }
}

final layerProvider =
    StateNotifierProvider<LayerNotifier, LayerState>((ref) {
  final initialLayerId = _uuid.v4();
  return LayerNotifier(
    LayerState(
      layers: [
        LayerModel(
          id: initialLayerId,
          name: 'Layer 1',
          isVisible: true,
        ),
      ],
      activeLayerId: initialLayerId,
    ),
  );
});

class LayerNotifier extends StateNotifier<LayerState> {
  LayerNotifier(super.state);

  void setActiveLayer(String id) {
    state = state.copyWith(activeLayerId: id);
  }

  void addLayer({String? name, bool above = true}) {
    final id = _uuid.v4();
    final newLayer = LayerModel(
      id: id,
      name: name ?? 'Layer ${state.layers.length + 1}',
    );

    final idx = state.activeLayerIndex;
    final newLayers = [...state.layers];
    final insertAt = above ? idx : idx + 1;
    newLayers.insert(insertAt.clamp(0, newLayers.length), newLayer);

    state = state.copyWith(
      layers: newLayers,
      activeLayerId: id,
    );
  }

  void addImageLayer(Uint8List bytes, {String? name}) {
    final id = _uuid.v4();
    final newLayer = LayerModel(
      id: id,
      name: name ?? 'Image ${state.layers.length + 1}',
      pixelData: bytes,
    );
    final idx = state.activeLayerIndex;
    final newLayers = [...state.layers];
    newLayers.insert(idx.clamp(0, newLayers.length), newLayer);
    state = state.copyWith(layers: newLayers, activeLayerId: id);
  }

  void addGroupLayer() {
    final id = _uuid.v4();
    final group = LayerModel(
      id: id,
      name: 'Group ${state.layers.length + 1}',
      isGroup: true,
    );
    final idx = state.activeLayerIndex;
    final newLayers = [...state.layers];
    newLayers.insert(idx, group);
    state = state.copyWith(layers: newLayers, activeLayerId: id);
  }

  void removeLayer(String id) {
    if (state.layers.length <= 1) return; // Keep at least 1 layer
    final newLayers = state.layers.where((l) => l.id != id).toList();
    final newActiveId = state.activeLayerId == id
        ? newLayers.first.id
        : state.activeLayerId;
    state = state.copyWith(layers: newLayers, activeLayerId: newActiveId);
  }

  void duplicateLayer(String id) {
    final src = state.layers.firstWhere((l) => l.id == id);
    final newId = _uuid.v4();
    final dup = src.copyWith(
      id: newId,
      name: '${src.name} Copy',
      pixelData: src.pixelData != null ? Uint8List.fromList(src.pixelData!) : null,
    );
    final idx = state.layers.indexWhere((l) => l.id == id);
    final newLayers = [...state.layers];
    newLayers.insert(idx, dup);
    state = state.copyWith(layers: newLayers, activeLayerId: newId);
  }

  void reorderLayer(int oldIdx, int newIdx) {
    final newLayers = [...state.layers];
    final item = newLayers.removeAt(oldIdx);
    newLayers.insert(newIdx, item);
    state = state.copyWith(layers: newLayers);
  }

  void toggleVisibility(String id) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(isVisible: !l.isVisible) else l
      ],
    );
  }

  void toggleLock(String id) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(isLocked: !l.isLocked) else l
      ],
    );
  }

  void toggleAlphaLock(String id) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(isAlphaLocked: !l.isAlphaLocked) else l
      ],
    );
  }

  void setOpacity(String id, double opacity) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(opacity: opacity.clamp(0.0, 1.0)) else l
      ],
    );
  }

  void setBlendMode(String id, LayerBlendMode mode) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(blendMode: mode) else l
      ],
    );
  }

  void renameLayer(String id, String name) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(name: name) else l
      ],
    );
  }

  void updateLayerTransform(
    String id, {
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotation,
  }) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id)
            l.copyWith(
              offsetX: offsetX ?? l.offsetX,
              offsetY: offsetY ?? l.offsetY,
              scale: scale ?? l.scale,
              rotation: rotation ?? l.rotation,
            )
          else
            l
      ],
    );
  }

  void resetLayerTransform(String id) {
    updateLayerTransform(id, offsetX: 0.0, offsetY: 0.0, scale: 1.0, rotation: 0.0);
  }

  void setLayerPixelData(String id, Uint8List data) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id) l.copyWith(pixelData: data) else l
      ],
    );
  }

  /// Merge two adjacent layers
  void mergeLayers(String topId, String bottomId) {
    // This is handled by canvas provider for actual pixel merging
    // Here we just remove the top layer after merge
    removeLayer(topId);
  }

  /// Merge all visible layers into the bottom-most visible
  void mergeVisible() {
    final visible = state.layers.where((l) => l.isVisible).toList();
    if (visible.length < 2) return;
    // The actual pixel merging is done in canvas provider
    // Here remove all but the last visible layer
    final keepId = visible.last.id;
    final newLayers = state.layers
        .where((l) => !l.isVisible || l.id == keepId)
        .toList();
    state = state.copyWith(layers: newLayers, activeLayerId: keepId);
  }

  void updateLayerImage(String id, ui.Image? image) {
    final newImages = Map<String, ui.Image?>.from(state.layerImages);
    newImages[id] = image;
    state = state.copyWith(layerImages: newImages);
  }
}
