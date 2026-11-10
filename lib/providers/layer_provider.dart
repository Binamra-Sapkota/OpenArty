import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/layer_model.dart';

const _uuid = Uuid();
const Object _sentinel = Object();

class LayerState {
  final List<LayerModel> layers;
  final String activeLayerId;
  final Map<String, ui.Image?> layerImages; // Rendered image cache
  final String? previousLayerIdBeforeTransform;

  const LayerState({
    required this.layers,
    required this.activeLayerId,
    this.layerImages = const {},
    this.previousLayerIdBeforeTransform,
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
    Object? previousLayerIdBeforeTransform = _sentinel,
  }) {
    return LayerState(
      layers: layers ?? this.layers,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      layerImages: layerImages ?? this.layerImages,
      previousLayerIdBeforeTransform: previousLayerIdBeforeTransform == _sentinel
          ? this.previousLayerIdBeforeTransform
          : previousLayerIdBeforeTransform as String?,
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

  void resetLayers({String? layerId}) {
    final id = layerId ?? _uuid.v4();
    state = LayerState(
      layers: [
        LayerModel(
          id: id,
          name: 'Layer 1',
          isVisible: true,
        ),
      ],
      activeLayerId: id,
      layerImages: const {},
    );
  }

  void setLayers(List<LayerModel> layers, String activeLayerId) {
    state = state.copyWith(
      layers: layers,
      activeLayerId: activeLayerId,
      layerImages: const {},
    );
  }

  void addImageLayer(Uint8List bytes, {String? name}) {
    final id = _uuid.v4();
    final newLayer = LayerModel(
      id: id,
      name: name ?? 'Image ${state.layers.length + 1}',
      layerType: LayerType.image,
      pixelData: bytes,
    );
    final idx = state.activeLayerIndex;
    final newLayers = [...state.layers];
    newLayers.insert(idx.clamp(0, newLayers.length), newLayer);
    state = state.copyWith(layers: newLayers, activeLayerId: id);
  }

  void addTextLayer(
    String text, {
    double fontSize = 36.0,
    Color? color,
    bool isBold = false,
    bool isItalic = false,
    Offset? initialPos,
    Size? canvasSize,
  }) {
    final id = _uuid.v4();
    double offX = 0.0;
    double offY = 0.0;
    if (initialPos != null && canvasSize != null) {
      offX = initialPos.dx - canvasSize.width / 2;
      offY = initialPos.dy - canvasSize.height / 2;
    }

    final displayName = text.length > 15
        ? 'T: "${text.substring(0, 15)}..."'
        : 'T: "$text"';

    final newLayer = LayerModel(
      id: id,
      name: displayName,
      layerType: LayerType.text,
      textContent: text,
      fontSize: fontSize,
      textColor: color ?? const Color(0xFFFFFFFF),
      isBold: isBold,
      isItalic: isItalic,
      offsetX: offX,
      offsetY: offY,
    );

    final prevId = state.activeLayerId;
    final idx = state.activeLayerIndex;
    final newLayers = [...state.layers];
    // Insert directly above the active layer (or at index 0)
    final insertIdx = idx >= 0 ? idx : 0;
    newLayers.insert(insertIdx.clamp(0, newLayers.length), newLayer);
    state = state.copyWith(
      layers: newLayers,
      activeLayerId: id,
      previousLayerIdBeforeTransform: prevId,
    );
  }

  void restorePreviousLayerIfText() {
    final prevId = state.previousLayerIdBeforeTransform;
    if (prevId != null && state.layers.any((l) => l.id == prevId)) {
      state = state.copyWith(
        activeLayerId: prevId,
        previousLayerIdBeforeTransform: null,
      );
      return;
    }
    // If active layer is a text layer, switch to the nearest non-text layer
    if (state.activeLayer?.isTextLayer == true) {
      final nonText = state.layers.where((l) => !l.isTextLayer).toList();
      if (nonText.isNotEmpty) {
        state = state.copyWith(
          activeLayerId: nonText.first.id,
          previousLayerIdBeforeTransform: null,
        );
      }
    }
  }

  void updateTextLayer(
    String id, {
    String? text,
    double? fontSize,
    Color? color,
    bool? isBold,
    bool? isItalic,
  }) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == id)
            l.copyWith(
              name: text != null
                  ? (text.length > 15 ? 'T: "${text.substring(0, 15)}..."' : 'T: "$text"')
                  : l.name,
              textContent: text ?? l.textContent,
              fontSize: fontSize ?? l.fontSize,
              textColor: color ?? l.textColor,
              isBold: isBold ?? l.isBold,
              isItalic: isItalic ?? l.isItalic,
            )
          else
            l
      ],
    );
  }

  void moveLayerUp(String id) {
    final idx = state.layers.indexWhere((l) => l.id == id);
    if (idx <= 0) return; // Already at very top
    final newLayers = [...state.layers];
    final item = newLayers.removeAt(idx);
    newLayers.insert(idx - 1, item);
    state = state.copyWith(layers: newLayers);
  }

  void moveLayerDown(String id) {
    final idx = state.layers.indexWhere((l) => l.id == id);
    if (idx < 0 || idx >= state.layers.length - 1) return; // Already at bottom
    final newLayers = [...state.layers];
    final item = newLayers.removeAt(idx);
    newLayers.insert(idx + 1, item);
    state = state.copyWith(layers: newLayers);
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
    final newActiveId = (state.activeLayerId == id ||
            !newLayers.any((l) => l.id == state.activeLayerId))
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
