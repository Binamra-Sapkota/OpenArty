import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/canvas_model.dart';
import '../models/brush_model.dart';
import '../models/history_model.dart';
import '../utils/blend_modes.dart';
import 'layer_provider.dart';

enum DrawingTool {
  brush,
  pencil,
  eraser,
  smudge,
  eyedropper,
  fill,
  gradient,
  shapes,
  text,
  selection,
  transform,
}

enum ShapeType {
  line,
  rectangle,
  roundedRectangle,
  circle,
  ellipse,
  triangle,
  star,
  polygon,
  diamond,
  heart,
  arrow,
  speechBubble,
  cloud,
}

enum SelectionShape { rectangle, ellipse, lasso, automatic }

enum SymmetryMode { none, vertical, horizontal, radial }

class SelectionData {
  final Rect? rect;
  final Path? path;
  final SelectionShape shape;
  final bool isActive;

  const SelectionData({
    this.rect,
    this.path,
    this.shape = SelectionShape.rectangle,
    this.isActive = false,
  });

  SelectionData copyWith({
    Rect? rect,
    Path? path,
    SelectionShape? shape,
    bool? isActive,
  }) {
    return SelectionData(
      rect: rect ?? this.rect,
      path: path ?? this.path,
      shape: shape ?? this.shape,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ReferenceImageData {
  final String path;
  final Offset offset;
  final double scale;
  final double opacity;
  final bool isVisible;

  const ReferenceImageData({
    required this.path,
    this.offset = const Offset(50, 80),
    this.scale = 1.0,
    this.opacity = 0.9,
    this.isVisible = true,
  });

  ReferenceImageData copyWith({
    String? path,
    Offset? offset,
    double? scale,
    double? opacity,
    bool? isVisible,
  }) {
    return ReferenceImageData(
      path: path ?? this.path,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class CanvasState {
  final CanvasModel canvas;
  final DrawingTool activeTool;
  final SelectionData selection;
  final SymmetryMode symmetryMode;
  final bool showGrid;
  final bool showGuides;
  final double gridSize;
  final bool quickShapeEnabled;
  final List<DrawStroke> currentStrokes;
  final Map<String, List<DrawStroke>> committedStrokes;
  final List<List<DrawStroke>> undoStack;
  final List<List<DrawStroke>> redoStack;
  final List<CanvasHistoryEntry> historyUndoStack;
  final List<CanvasHistoryEntry> historyRedoStack;
  final bool isDrawing;
  final double zoomLevel;
  final Offset panOffset;
  final double rotation;
  final String activeLayerId;
  final bool showSymmetryGuide;
  final int radialSymmetryCount;
  final ShapeType activeShapeType;
  final bool isShapeFilled;
  final double shapeStrokeWidth;
  final bool isRadialGradient;
  final ReferenceImageData? referenceImage;
  final bool palmRejectionEnabled;
  final bool stylusOnlyMode;

  const CanvasState({
    this.canvas = const CanvasModel(),
    this.activeTool = DrawingTool.brush,
    this.selection = const SelectionData(),
    this.symmetryMode = SymmetryMode.none,
    this.showGrid = false,
    this.showGuides = false,
    this.gridSize = 50,
    this.quickShapeEnabled = false,
    this.currentStrokes = const [],
    this.committedStrokes = const {},
    this.undoStack = const [],
    this.redoStack = const [],
    this.historyUndoStack = const [],
    this.historyRedoStack = const [],
    this.isDrawing = false,
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
    this.rotation = 0.0,
    this.activeLayerId = '',
    this.showSymmetryGuide = true,
    this.radialSymmetryCount = 8,
    this.activeShapeType = ShapeType.rectangle,
    this.isShapeFilled = false,
    this.shapeStrokeWidth = 4.0,
    this.isRadialGradient = false,
    this.referenceImage,
    this.palmRejectionEnabled = true,
    this.stylusOnlyMode = false,
  });

  bool get canUndo => historyUndoStack.isNotEmpty || undoStack.isNotEmpty;
  bool get canRedo => historyRedoStack.isNotEmpty || redoStack.isNotEmpty;

  CanvasState copyWith({
    CanvasModel? canvas,
    DrawingTool? activeTool,
    SelectionData? selection,
    SymmetryMode? symmetryMode,
    bool? showGrid,
    bool? showGuides,
    double? gridSize,
    bool? quickShapeEnabled,
    List<DrawStroke>? currentStrokes,
    Map<String, List<DrawStroke>>? committedStrokes,
    List<List<DrawStroke>>? undoStack,
    List<List<DrawStroke>>? redoStack,
    List<CanvasHistoryEntry>? historyUndoStack,
    List<CanvasHistoryEntry>? historyRedoStack,
    bool? isDrawing,
    double? zoomLevel,
    Offset? panOffset,
    double? rotation,
    String? activeLayerId,
    bool? showSymmetryGuide,
    int? radialSymmetryCount,
    ShapeType? activeShapeType,
    bool? isShapeFilled,
    double? shapeStrokeWidth,
    bool? isRadialGradient,
    ReferenceImageData? referenceImage,
    bool clearReferenceImage = false,
    bool? palmRejectionEnabled,
    bool? stylusOnlyMode,
  }) {
    return CanvasState(
      canvas: canvas ?? this.canvas,
      activeTool: activeTool ?? this.activeTool,
      selection: selection ?? this.selection,
      symmetryMode: symmetryMode ?? this.symmetryMode,
      showGrid: showGrid ?? this.showGrid,
      showGuides: showGuides ?? this.showGuides,
      gridSize: gridSize ?? this.gridSize,
      quickShapeEnabled: quickShapeEnabled ?? this.quickShapeEnabled,
      currentStrokes: currentStrokes ?? this.currentStrokes,
      committedStrokes: committedStrokes ?? this.committedStrokes,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      historyUndoStack: historyUndoStack ?? this.historyUndoStack,
      historyRedoStack: historyRedoStack ?? this.historyRedoStack,
      isDrawing: isDrawing ?? this.isDrawing,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panOffset: panOffset ?? this.panOffset,
      rotation: rotation ?? this.rotation,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      showSymmetryGuide: showSymmetryGuide ?? this.showSymmetryGuide,
      radialSymmetryCount: radialSymmetryCount ?? this.radialSymmetryCount,
      activeShapeType: activeShapeType ?? this.activeShapeType,
      isShapeFilled: isShapeFilled ?? this.isShapeFilled,
      shapeStrokeWidth: shapeStrokeWidth ?? this.shapeStrokeWidth,
      isRadialGradient: isRadialGradient ?? this.isRadialGradient,
      referenceImage: clearReferenceImage ? null : (referenceImage ?? this.referenceImage),
      palmRejectionEnabled: palmRejectionEnabled ?? this.palmRejectionEnabled,
      stylusOnlyMode: stylusOnlyMode ?? this.stylusOnlyMode,
    );
  }
}

final canvasProvider =
    StateNotifierProvider<CanvasNotifier, CanvasState>((ref) {
  return CanvasNotifier(ref);
});

class CanvasNotifier extends StateNotifier<CanvasState> {
  final Ref? _ref;
  CanvasNotifier([this._ref]) : super(const CanvasState());

  DrawStroke? _currentStroke;
  List<DrawPoint> _currentPoints = [];
  Offset? _shapeStart;

  CanvasHistoryEntry _createCurrentSnapshot() {
    final currentLayers = _ref?.read(layerProvider).layers ?? [];
    final currentActiveId =
        _ref?.read(layerProvider).activeLayerId ?? state.activeLayerId;
    return CanvasHistoryEntry(
      committedStrokes: state.committedStrokes.map(
        (k, v) => MapEntry(k, List<DrawStroke>.from(v)),
      ),
      layers: currentLayers.map((l) => l.copyWith()).toList(),
      activeLayerId: currentActiveId,
    );
  }

  /// Maximum number of undo history states kept in memory to guarantee 2GB-3GB RAM compatibility
  static const int maxHistoryStates = 20;

  /// Records a full document history snapshot before modifying strokes, layers, text, or gradients
  void recordSnapshot() {
    final snapshot = _createCurrentSnapshot();
    final newUndo = [...state.historyUndoStack, snapshot];
    if (newUndo.length > maxHistoryStates) {
      newUndo.removeAt(0);
    }
    state = state.copyWith(
      historyUndoStack: newUndo,
      historyRedoStack: [],
    );
  }

  void setHistory({
    List<CanvasHistoryEntry>? undoStack,
    List<CanvasHistoryEntry>? redoStack,
  }) {
    state = state.copyWith(
      historyUndoStack: undoStack ?? state.historyUndoStack,
      historyRedoStack: redoStack ?? state.historyRedoStack,
    );
  }

  String _resolveActiveLayerId([String? layerId]) {
    if (layerId != null && layerId.isNotEmpty) return layerId;
    final fromLayer = _ref?.read(layerProvider).activeLayerId;
    if (fromLayer != null && fromLayer.isNotEmpty) return fromLayer;
    return state.activeLayerId;
  }

  void initCanvas(CanvasModel canvas, String layerId) {
    state = state.copyWith(
      canvas: canvas,
      activeLayerId: layerId,
      committedStrokes: {layerId: []},
      undoStack: [],
      redoStack: [],
      historyUndoStack: [],
      historyRedoStack: [],
    );
  }

  void setCanvas(CanvasModel canvas) {
    state = state.copyWith(canvas: canvas);
  }

  void setCommittedStrokes(Map<String, List<DrawStroke>> strokes) {
    state = state.copyWith(
      committedStrokes: strokes,
      undoStack: [],
      redoStack: [],
      historyUndoStack: [],
      historyRedoStack: [],
    );
  }

  void setActiveLayer(String layerId) {
    state = state.copyWith(activeLayerId: layerId);
  }

  void setTool(DrawingTool tool) {
    if (state.activeTool == DrawingTool.transform && tool != DrawingTool.transform) {
      final r = _ref;
      if (r != null) {
        final layerState = r.read(layerProvider);
        if (layerState.previousLayerIdBeforeTransform != null ||
            layerState.activeLayer?.isTextLayer == true) {
          r.read(layerProvider.notifier).restorePreviousLayerIfText();
          final newActive = r.read(layerProvider).activeLayerId;
          setActiveLayer(newActive);
        }
      }
    }
    state = state.copyWith(activeTool: tool);
  }

  void setShapeType(ShapeType shapeType) {
    state = state.copyWith(activeShapeType: shapeType);
  }

  void setShapeFilled(bool isFilled) {
    state = state.copyWith(isShapeFilled: isFilled);
  }

  void setShapeStrokeWidth(double width) {
    state = state.copyWith(shapeStrokeWidth: width.clamp(1.0, 100.0));
  }

  void setRadialGradient(bool isRadial) {
    state = state.copyWith(isRadialGradient: isRadial);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoomLevel: zoom.clamp(0.05, 50.0));
  }

  void setPan(Offset offset) {
    state = state.copyWith(panOffset: offset);
  }

  void setRotation(double radians) {
    state = state.copyWith(rotation: radians);
  }

  void resetViewport() {
    state = state.copyWith(
      zoomLevel: 1.0,
      panOffset: Offset.zero,
      rotation: 0.0,
    );
  }

  void fitToScreen(Size screenSize) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return;
    final canvasW = state.canvas.width.toDouble();
    final canvasH = state.canvas.height.toDouble();
    // Allow padding for toolbars
    final availableW = screenSize.width * 0.9;
    final availableH = (screenSize.height - 120) * 0.9;

    final scaleX = availableW / canvasW;
    final scaleY = availableH / canvasH;
    final bestZoom = math.min(scaleX, scaleY).clamp(0.1, 5.0);

    state = state.copyWith(
      zoomLevel: bestZoom,
      panOffset: Offset.zero,
      rotation: 0.0,
    );
  }

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void setGridSize(double size) {
    state = state.copyWith(gridSize: size.clamp(5, 500));
  }

  void setSymmetry(SymmetryMode mode) {
    state = state.copyWith(symmetryMode: mode);
  }

  void setRadialSymmetryCount(int count) {
    state = state.copyWith(radialSymmetryCount: count.clamp(2, 32));
  }

  void togglePalmRejection() {
    state = state.copyWith(palmRejectionEnabled: !state.palmRejectionEnabled);
  }

  void toggleStylusOnlyMode() {
    state = state.copyWith(stylusOnlyMode: !state.stylusOnlyMode);
  }

  void setReferenceImage(ReferenceImageData data) {
    state = state.copyWith(referenceImage: data);
  }

  void updateReferenceImage({
    Offset? offset,
    double? scale,
    double? opacity,
    bool? isVisible,
  }) {
    if (state.referenceImage == null) return;
    state = state.copyWith(
      referenceImage: state.referenceImage!.copyWith(
        offset: offset,
        scale: scale,
        opacity: opacity,
        isVisible: isVisible,
      ),
    );
  }

  void toggleReferenceImageVisibility() {
    if (state.referenceImage == null) return;
    updateReferenceImage(isVisible: !state.referenceImage!.isVisible);
  }

  void clearReferenceImage() {
    state = state.copyWith(clearReferenceImage: true);
  }

  // --- Drawing Strokes ---

  void beginStroke(
      Offset position, BrushModel brush, Color color, double pressure,
      {String? layerId}) {
    final activeId = _resolveActiveLayerId(layerId);
    final effectivePressure = brush.pressureSensitive ? pressure : 1.0;
    final pointSize = brush.size *
        (brush.pressureSensitive ? (0.25 + 0.75 * effectivePressure) : 1.0);
    final pointOpacity = (brush.opacity *
            (brush.pressureSensitive ? (0.4 + 0.6 * effectivePressure) : 1.0))
        .clamp(0.05, 1.0);

    final point = DrawPoint(
      position: position,
      pressure: effectivePressure,
      size: pointSize,
      opacity: pointOpacity,
    );

    _currentPoints = [point];
    _currentStroke = DrawStroke(
      points: _currentPoints,
      color: color,
      brushId: brush.id,
      brushSize: brush.size,
      brushOpacity: brush.opacity,
      layerId: activeId,
      kind: StrokeKind.freehand,
    );

    state = state.copyWith(
      isDrawing: true,
      activeLayerId: activeId,
      currentStrokes: [_currentStroke!],
    );
  }

  void continueStroke(Offset position, BrushModel brush, double pressure) {
    if (!state.isDrawing || _currentStroke == null) return;

    // Minimum distance check: prevents lag from thousands of micro sub-pixel events
    if (_currentPoints.isNotEmpty) {
      final lastPos = _currentPoints.last.position;
      final dist = (position - lastPos).distance;
      if (dist < 1.5) return;
    }

    final effectivePressure = brush.pressureSensitive ? pressure : 1.0;
    final pointSize = brush.size *
        (brush.pressureSensitive ? (0.25 + 0.75 * effectivePressure) : 1.0);
    final pointOpacity = (brush.opacity *
            (brush.pressureSensitive ? (0.4 + 0.6 * effectivePressure) : 1.0))
        .clamp(0.05, 1.0);

    final point = DrawPoint(
      position: position,
      pressure: effectivePressure,
      size: pointSize,
      opacity: pointOpacity,
    );

    _currentPoints.add(point);
    _currentStroke = _currentStroke!.copyWith(points: _currentPoints);

    state = state.copyWith(currentStrokes: [_currentStroke!]);
  }

  void endStroke() {
    if (!state.isDrawing || _currentStroke == null) return;

    recordSnapshot();

    final layerId = _currentStroke!.layerId.isNotEmpty
        ? _currentStroke!.layerId
        : _resolveActiveLayerId();
    final existing = state.committedStrokes[layerId] ?? [];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);

    final finalStroke = _currentStroke!.copyWith(
      points: _currentPoints.isNotEmpty
          ? List<DrawPoint>.from(_currentPoints)
          : _currentStroke!.points,
    );
    newCommitted[layerId] = [...existing, finalStroke];

    // Push to undo stack
    final newUndoStack = [...state.undoStack, existing];
    if (newUndoStack.length > 50) newUndoStack.removeAt(0);

    _currentStroke = null;
    _currentPoints = [];
    state = state.copyWith(
      isDrawing: false,
      currentStrokes: const [],
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  void cancelCurrentStroke() {
    _currentStroke = null;
    _currentPoints = [];
    _shapeStart = null;
    state = state.copyWith(
      isDrawing: false,
      currentStrokes: const [],
    );
  }

  bool fillShapeAt(Offset pos, Color color, {String? layerId}) {
    final activeId = _resolveActiveLayerId(layerId);
    final existing = state.committedStrokes[activeId] ?? [];
    for (int i = existing.length - 1; i >= 0; i--) {
      final stroke = existing[i];

      // 1. Shapes (rect, circle, triangle, line)
      if (stroke.shapeStart != null && stroke.shapeEnd != null) {
        final rect = Rect.fromPoints(stroke.shapeStart!, stroke.shapeEnd!);
        if (stroke.kind == StrokeKind.rectangle ||
            stroke.kind == StrokeKind.roundedRectangle) {
          if (rect.contains(pos)) {
            final updated = stroke.copyWith(isFilled: true, color: color);
            final newStrokes = [...existing];
            newStrokes[i] = updated;
            final newCommitted =
                Map<String, List<DrawStroke>>.from(state.committedStrokes);
            newCommitted[activeId] = newStrokes;
            state = state.copyWith(
              committedStrokes: newCommitted,
              undoStack: [...state.undoStack, existing],
              redoStack: [],
            );
            return true;
          }
        } else if (stroke.kind == StrokeKind.circle ||
            stroke.kind == StrokeKind.ellipse) {
          final center = rect.center;
          final rx = rect.width / 2;
          final ry = rect.height / 2;
          if (rx > 0 && ry > 0) {
            final normX = (pos.dx - center.dx) / rx;
            final normY = (pos.dy - center.dy) / ry;
            if (normX * normX + normY * normY <= 1.05) {
              final updated = stroke.copyWith(isFilled: true, color: color);
              final newStrokes = [...existing];
              newStrokes[i] = updated;
              final newCommitted =
                  Map<String, List<DrawStroke>>.from(state.committedStrokes);
              newCommitted[activeId] = newStrokes;
              state = state.copyWith(
                committedStrokes: newCommitted,
                undoStack: [...state.undoStack, existing],
                redoStack: [],
              );
              return true;
            }
          }
        } else if (stroke.kind == StrokeKind.triangle) {
          final top = Offset(rect.center.dx, rect.top);
          final bl = Offset(rect.left, rect.bottom);
          final br = Offset(rect.right, rect.bottom);
          if (_pointInTriangle(pos, top, bl, br)) {
            final updated = stroke.copyWith(isFilled: true, color: color);
            final newStrokes = [...existing];
            newStrokes[i] = updated;
            final newCommitted =
                Map<String, List<DrawStroke>>.from(state.committedStrokes);
            newCommitted[activeId] = newStrokes;
            state = state.copyWith(
              committedStrokes: newCommitted,
              undoStack: [...state.undoStack, existing],
              redoStack: [],
            );
            return true;
          }
        } else if (stroke.kind == StrokeKind.line) {
          final dist = _distToSegment(pos, stroke.shapeStart!, stroke.shapeEnd!);
          if (dist <= 20.0) {
            final updated = stroke.copyWith(color: color);
            final newStrokes = [...existing];
            newStrokes[i] = updated;
            final newCommitted =
                Map<String, List<DrawStroke>>.from(state.committedStrokes);
            newCommitted[activeId] = newStrokes;
            state = state.copyWith(
              committedStrokes: newCommitted,
              undoStack: [...state.undoStack, existing],
              redoStack: [],
            );
            return true;
          }
        }
      }

      // 2. Text items
      if (stroke.kind == StrokeKind.text && stroke.shapeStart != null) {
        final dist = (stroke.shapeStart! - pos).distance;
        if (dist <= (stroke.fontSize ?? 28) + 15) {
          final updated = stroke.copyWith(color: color);
          final newStrokes = [...existing];
          newStrokes[i] = updated;
          final newCommitted =
              Map<String, List<DrawStroke>>.from(state.committedStrokes);
          newCommitted[activeId] = newStrokes;
          state = state.copyWith(
            committedStrokes: newCommitted,
            undoStack: [...state.undoStack, existing],
            redoStack: [],
          );
          return true;
        }
      }

      // 3. Freehand stroke re-coloring
      if (stroke.kind == StrokeKind.freehand) {
        for (final pt in stroke.points) {
          if ((pt.position - pos).distance <= stroke.brushSize + 12.0) {
            final updated = stroke.copyWith(color: color);
            final newStrokes = [...existing];
            newStrokes[i] = updated;
            final newCommitted =
                Map<String, List<DrawStroke>>.from(state.committedStrokes);
            newCommitted[activeId] = newStrokes;
            state = state.copyWith(
              committedStrokes: newCommitted,
              undoStack: [...state.undoStack, existing],
              redoStack: [],
            );
            return true;
          }
        }
      }
    }
    return false;
  }

  static double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
    if (l2 == 0) return (p - v).distance;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2).clamp(0.0, 1.0);
    final proj = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - proj).distance;
  }

  static bool _pointInTriangle(Offset p, Offset p0, Offset p1, Offset p2) {
    final dX = p.dx - p2.dx;
    final dY = p.dy - p2.dy;
    final dX21 = p2.dx - p1.dx;
    final dY12 = p1.dy - p2.dy;
    final d = dY12 * (p0.dx - p2.dx) + dX21 * (p0.dy - p2.dy);
    if (d == 0) return false;
    final s = dY12 * dX + dX21 * dY;
    final t = (p2.dy - p0.dy) * dX + (p0.dx - p2.dx) * dY;
    if (d > 0) return s >= 0 && t >= 0 && (s + t) <= d;
    return s <= 0 && t <= 0 && (s + t) >= d;
  }

  /// Find text stroke near the given position
  int findTextStrokeAt(Offset pos, {String? layerId}) {
    final activeId = _resolveActiveLayerId(layerId);
    final existing = state.committedStrokes[activeId] ?? [];
    for (int i = existing.length - 1; i >= 0; i--) {
      final s = existing[i];
      if (s.kind == StrokeKind.text && s.shapeStart != null) {
        final dist = (s.shapeStart! - pos).distance;
        final approxW = (s.text?.length ?? 1) * (s.fontSize ?? 28) * 0.7;
        final approxH = (s.fontSize ?? 28) * 1.4;
        final bounds = Rect.fromCenter(
          center: s.shapeStart!,
          width: approxW + 30,
          height: approxH + 20,
        );
        if (bounds.contains(pos) || dist < 35) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Update an existing text stroke
  void updateTextStroke(
    int index, {
    String? text,
    double? fontSize,
    Color? color,
    Offset? pos,
    String? layerId,
  }) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    final existing = state.committedStrokes[activeId] ?? [];
    if (index < 0 || index >= existing.length) return;
    final stroke = existing[index];
    final updated = stroke.copyWith(
      text: text ?? stroke.text,
      fontSize: fontSize ?? stroke.fontSize,
      brushSize: fontSize ?? stroke.brushSize,
      color: color ?? stroke.color,
      shapeStart: pos ?? stroke.shapeStart,
      points: pos != null ? [DrawPoint(position: pos)] : stroke.points,
    );
    final newStrokes = [...existing];
    newStrokes[index] = updated;
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = newStrokes;
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: [...state.undoStack, existing],
      redoStack: [],
    );
  }

  /// Delete a stroke by index
  void deleteStroke(int index, {String? layerId}) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    final existing = state.committedStrokes[activeId] ?? [];
    if (index < 0 || index >= existing.length) return;
    final newStrokes = [...existing];
    newStrokes.removeAt(index);
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = newStrokes;
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: [...state.undoStack, existing],
      redoStack: [],
    );
  }

  // --- Shapes, Text, Fill & Gradients ---

  void beginShape(Offset start, Color color, double strokeWidth, bool isFilled) {
    _shapeStart = start;
    StrokeKind kind = StrokeKind.rectangle;
    switch (state.activeShapeType) {
      case ShapeType.line:
        kind = StrokeKind.line;
        break;
      case ShapeType.rectangle:
        kind = StrokeKind.rectangle;
        break;
      case ShapeType.roundedRectangle:
        kind = StrokeKind.roundedRectangle;
        break;
      case ShapeType.circle:
        kind = StrokeKind.circle;
        break;
      case ShapeType.ellipse:
        kind = StrokeKind.ellipse;
        break;
      case ShapeType.triangle:
        kind = StrokeKind.triangle;
        break;
      case ShapeType.star:
        kind = StrokeKind.star;
        break;
      case ShapeType.polygon:
        kind = StrokeKind.polygon;
        break;
      case ShapeType.diamond:
        kind = StrokeKind.diamond;
        break;
      case ShapeType.heart:
        kind = StrokeKind.heart;
        break;
      case ShapeType.arrow:
        kind = StrokeKind.arrow;
        break;
      case ShapeType.speechBubble:
        kind = StrokeKind.speechBubble;
        break;
      case ShapeType.cloud:
        kind = StrokeKind.cloud;
        break;
    }

    _currentStroke = DrawStroke(
      points: [DrawPoint(position: start)],
      color: color,
      brushId: 'shape',
      brushSize: strokeWidth,
      brushOpacity: 1.0,
      layerId: _resolveActiveLayerId(),
      kind: kind,
      isFilled: isFilled,
      shapeStart: start,
      shapeEnd: start,
    );

    state = state.copyWith(
      isDrawing: true,
      currentStrokes: [_currentStroke!],
    );
  }

  void updateShape(Offset current) {
    if (!state.isDrawing || _currentStroke == null || _shapeStart == null) return;
    _currentStroke = DrawStroke(
      points: [DrawPoint(position: _shapeStart!), DrawPoint(position: current)],
      color: _currentStroke!.color,
      brushId: 'shape',
      brushSize: _currentStroke!.brushSize,
      brushOpacity: _currentStroke!.brushOpacity,
      layerId: _currentStroke!.layerId,
      kind: _currentStroke!.kind,
      isFilled: _currentStroke!.isFilled,
      shapeStart: _shapeStart,
      shapeEnd: current,
    );
    state = state.copyWith(currentStrokes: [_currentStroke!]);
  }

  void commitShape() {
    endStroke();
    _shapeStart = null;
  }

  void commitText(String text, Offset pos, double size, Color color,
      {bool bold = false, bool italic = false, String? layerId}) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    final stroke = DrawStroke(
      points: [DrawPoint(position: pos)],
      color: color,
      brushId: 'text',
      brushSize: size,
      brushOpacity: 1.0,
      layerId: activeId,
      kind: StrokeKind.text,
      text: text,
      fontSize: size,
      shapeStart: pos,
    );

    final existing = state.committedStrokes[activeId] ?? [];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = [...existing, stroke];

    final newUndoStack = [...state.undoStack, existing];
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  void commitFill(Color color, {String? layerId}) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    final stroke = DrawStroke(
      points: const [],
      color: color,
      brushId: 'fill',
      brushSize: 1,
      brushOpacity: 1.0,
      layerId: activeId,
      kind: StrokeKind.fill,
    );

    final existing = state.committedStrokes[activeId] ?? [];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = [...existing, stroke];

    final newUndoStack = [...state.undoStack, existing];
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  void commitFloodFill(Uint8List imageBytes, Offset origin, ui.Image? decodedImage,
      {String? layerId, Color? color}) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    final stroke = DrawStroke(
      points: [DrawPoint(position: origin)],
      color: color ?? Colors.black,
      brushId: 'flood_fill',
      brushSize: 1,
      brushOpacity: 1.0,
      layerId: activeId,
      kind: StrokeKind.floodFill,
      shapeStart: origin,
      imageBytes: imageBytes,
      floodFillImage: decodedImage,
    );

    final existing = state.committedStrokes[activeId] ?? [];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = [...existing, stroke];

    final newUndoStack = [...state.undoStack, existing];
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  void commitGradient(Offset start, Offset end, Color color1, Color color2,
      {bool isRadial = false, String? layerId}) {
    recordSnapshot();
    final activeId = _resolveActiveLayerId(layerId);
    var finalEnd = end;
    if ((finalEnd - start).distance < 10.0) {
      finalEnd = start + const Offset(150, 150);
    }
    final stroke = DrawStroke(
      points: [DrawPoint(position: start), DrawPoint(position: finalEnd)],
      color: color1,
      secondaryColor: color2,
      brushId: 'gradient',
      brushSize: 1,
      brushOpacity: 1.0,
      layerId: activeId,
      kind: isRadial
          ? StrokeKind.gradientRadial
          : StrokeKind.gradientLinear,
      shapeStart: start,
      shapeEnd: finalEnd,
    );

    final existing = state.committedStrokes[activeId] ?? [];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[activeId] = [...existing, stroke];

    final newUndoStack = [...state.undoStack, existing];
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  // --- History (Undo/Redo) ---

  void undo() {
    if (state.historyUndoStack.isNotEmpty) {
      final currentSnapshot = _createCurrentSnapshot();
      final newUndo = [...state.historyUndoStack];
      final target = newUndo.removeLast();
      final newRedo = [...state.historyRedoStack, currentSnapshot];
      if (newRedo.length > maxHistoryStates) {
        newRedo.removeAt(0);
      }

      _ref?.read(layerProvider.notifier).setLayers(
            target.layers,
            target.activeLayerId,
          );

      state = state.copyWith(
        committedStrokes: target.committedStrokes,
        activeLayerId: target.activeLayerId,
        historyUndoStack: newUndo,
        historyRedoStack: newRedo,
      );
      return;
    }

    if (state.undoStack.isEmpty) return;
    final layerId = state.activeLayerId;
    final lastState = state.undoStack.last;
    final newUndoStack = [...state.undoStack]..removeLast();

    final currentLayerStrokes = state.committedStrokes[layerId] ?? [];
    final newRedoStack = [...state.redoStack, currentLayerStrokes];

    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[layerId] = lastState;

    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
  }

  void redo() {
    if (state.historyRedoStack.isNotEmpty) {
      final currentSnapshot = _createCurrentSnapshot();
      final newRedo = [...state.historyRedoStack];
      final target = newRedo.removeLast();
      final newUndo = [...state.historyUndoStack, currentSnapshot];
      if (newUndo.length > maxHistoryStates) {
        newUndo.removeAt(0);
      }

      _ref?.read(layerProvider.notifier).setLayers(
            target.layers,
            target.activeLayerId,
          );

      state = state.copyWith(
        committedStrokes: target.committedStrokes,
        activeLayerId: target.activeLayerId,
        historyUndoStack: newUndo,
        historyRedoStack: newRedo,
      );
      return;
    }

    if (state.redoStack.isEmpty) return;
    final layerId = state.activeLayerId;
    final nextState = state.redoStack.last;
    final newRedoStack = [...state.redoStack]..removeLast();

    final currentLayerStrokes = state.committedStrokes[layerId] ?? [];
    final newUndoStack = [...state.undoStack, currentLayerStrokes];

    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[layerId] = nextState;

    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
  }

  void clearLayer(String layerId) {
    recordSnapshot();
    final existing = state.committedStrokes[layerId] ?? [];
    final newUndoStack = [...state.undoStack, existing];
    final newCommitted =
        Map<String, List<DrawStroke>>.from(state.committedStrokes);
    newCommitted[layerId] = [];
    state = state.copyWith(
      committedStrokes: newCommitted,
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  void setSelection(SelectionData selection) {
    state = state.copyWith(selection: selection);
  }

  void clearSelection() {
    state = state.copyWith(selection: const SelectionData());
  }

  List<DrawStroke> getLayerStrokes(String layerId) {
    return state.committedStrokes[layerId] ?? [];
  }
}
