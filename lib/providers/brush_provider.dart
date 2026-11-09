import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brush_model.dart';

/// Current active brush notifier
final activeBrushProvider =
    StateNotifierProvider<ActiveBrushNotifier, BrushModel>(
  (ref) => ActiveBrushNotifier(),
);

class ActiveBrushNotifier extends StateNotifier<BrushModel> {
  late BrushModel _lastDrawingBrush;

  ActiveBrushNotifier()
      : super(BrushModel.defaults.firstWhere((b) => b.id == 'pen_1')) {
    _lastDrawingBrush = state;
  }

  BrushModel get lastDrawingBrush => _lastDrawingBrush;
  bool get isEraser => state.type == BrushType.eraser;

  void setBrush(BrushModel brush) {
    if (brush.type != BrushType.eraser) {
      _lastDrawingBrush = brush;
    }
    state = brush;
  }

  void setSize(double size) {
    state = state.copyWith(size: size.clamp(1.0, 500.0));
    if (state.type != BrushType.eraser) {
      _lastDrawingBrush = _lastDrawingBrush.copyWith(size: state.size);
    }
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.01, 1.0));
    if (state.type != BrushType.eraser) {
      _lastDrawingBrush = _lastDrawingBrush.copyWith(opacity: state.opacity);
    }
  }

  void setHardness(double hardness) {
    state = state.copyWith(hardness: hardness.clamp(0.0, 1.0));
  }

  void setSpacing(double spacing) {
    state = state.copyWith(spacing: spacing.clamp(0.01, 1.0));
  }

  void setStreamline(double streamline) {
    state = state.copyWith(streamline: streamline.clamp(0.0, 1.0));
    if (state.type != BrushType.eraser) {
      _lastDrawingBrush =
          _lastDrawingBrush.copyWith(streamline: state.streamline);
    }
  }

  void setPressureSensitive(bool v) {
    state = state.copyWith(pressureSensitive: v);
  }

  /// Switch to Eraser tool while preserving the current drawing brush
  void selectEraser({bool soft = false}) {
    if (state.type != BrushType.eraser) {
      _lastDrawingBrush = state;
    }
    final eraserBrush = BrushModel.defaults.firstWhere(
      (b) => b.id == (soft ? 'eraser_soft' : 'eraser_1'),
      orElse: () => BrushModel(
        id: 'eraser_1',
        name: 'Eraser',
        type: BrushType.eraser,
        size: state.size,
        opacity: 1.0,
      ),
    );
    state = eraserBrush.copyWith(size: state.size);
  }

  /// Restore the active drawing brush after using eraser
  void restoreDrawingBrush() {
    state = _lastDrawingBrush;
  }

  /// Toggle between drawing brush and eraser
  void toggleEraser() {
    if (state.type == BrushType.eraser) {
      restoreDrawingBrush();
    } else {
      selectEraser();
    }
  }
}

/// All available brushes
final brushListProvider =
    StateNotifierProvider<BrushListNotifier, List<BrushModel>>(
  (ref) => BrushListNotifier(),
);

class BrushListNotifier extends StateNotifier<List<BrushModel>> {
  BrushListNotifier() : super(BrushModel.defaults);

  void addBrush(BrushModel brush) => state = [...state, brush];

  void removeBrush(String id) =>
      state = state.where((b) => b.id != id).toList();

  void updateBrush(BrushModel updated) => state = [
        for (final b in state)
          if (b.id == updated.id) updated else b
      ];
}

/// Foreground drawing color & history
final drawingColorProvider =
    StateNotifierProvider<DrawingColorNotifier, Color>(
  (ref) => DrawingColorNotifier(),
);

class DrawingColorNotifier extends StateNotifier<Color> {
  DrawingColorNotifier() : super(const Color(0xFF1E88E5));

  final List<Color> _colorHistory = [
    Colors.black,
    Colors.white,
    const Color(0xFF1E88E5),
    const Color(0xFFE53935),
    const Color(0xFF43A047),
    const Color(0xFFFB8C00),
    const Color(0xFF8E24AA),
  ];
  List<Color> get colorHistory => List.unmodifiable(_colorHistory);

  Color _secondaryColor = Colors.white;
  Color get secondaryColor => _secondaryColor;

  void setColor(Color color) {
    _colorHistory.remove(color);
    _colorHistory.insert(0, color);
    if (_colorHistory.length > 30) {
      _colorHistory.removeLast();
    }
    state = color;
  }

  void setSecondaryColor(Color color) {
    _secondaryColor = color;
  }

  void swapColors() {
    final tmp = state;
    state = _secondaryColor;
    _secondaryColor = tmp;
  }
}
