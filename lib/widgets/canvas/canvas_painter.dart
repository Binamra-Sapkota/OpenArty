import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/brush_model.dart';
import '../../models/layer_model.dart';
import '../../providers/canvas_provider.dart';
import '../../utils/blend_modes.dart';

class CanvasPainter extends CustomPainter {
  final List<LayerModel> layers;
  final Map<String, List<DrawStroke>> committedStrokes;
  final List<DrawStroke> currentStrokes;
  final String activeLayerId;
  final Map<String, BrushModel> brushMap;
  final bool showGrid;
  final double gridSize;
  final SymmetryMode symmetryMode;
  final int radialSymmetryCount;
  final bool showSymmetryGuide;
  final CanvasState canvasState;
  final Map<String, ui.Image?> layerImages;

  CanvasPainter({
    required this.layers,
    required this.committedStrokes,
    required this.currentStrokes,
    required this.activeLayerId,
    required this.brushMap,
    required this.showGrid,
    required this.gridSize,
    required this.symmetryMode,
    required this.radialSymmetryCount,
    required this.showSymmetryGuide,
    required this.canvasState,
    this.layerImages = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasWidth = canvasState.canvas.width.toDouble();
    final canvasHeight = canvasState.canvas.height.toDouble();

    // Clip to canvas bounds
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    // Draw checkerboard for transparency
    _drawCheckerboard(canvas, canvasWidth, canvasHeight);

    // Draw background color if not transparent
    if (canvasState.canvas.backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        Paint()..color = canvasState.canvas.backgroundColor,
      );
    }

    // Draw layers from bottom to top
    for (final layer in layers.reversed) {
      if (!layer.isVisible) continue;

      final layerPaint = Paint()
        ..blendMode = layer.blendMode.flutterBlendMode
        ..color = Colors.white.withValues(alpha: layer.opacity);

      canvas.saveLayer(
        Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        layerPaint,
      );

      // Apply layer transformation (move, scale, rotate)
      canvas.save();
      if (layer.offsetX != 0.0 ||
          layer.offsetY != 0.0 ||
          layer.scale != 1.0 ||
          layer.rotation != 0.0) {
        canvas.translate(
            canvasWidth / 2 + layer.offsetX, canvasHeight / 2 + layer.offsetY);
        if (layer.rotation != 0.0) canvas.rotate(layer.rotation);
        if (layer.scale != 1.0) canvas.scale(layer.scale);
        canvas.translate(-canvasWidth / 2, -canvasHeight / 2);
      }

      // Draw imported image if this is an image layer
      final layerImg = layerImages[layer.id];
      if (layerImg != null) {
        final src = Rect.fromLTWH(
          0,
          0,
          layerImg.width.toDouble(),
          layerImg.height.toDouble(),
        );
        final dst = Rect.fromLTWH(0, 0, canvasWidth, canvasHeight);
        canvas.drawImageRect(layerImg, src, dst, Paint());
      }

      // Draw committed strokes for this layer
      final strokes = committedStrokes[layer.id] ?? [];
      for (final stroke in strokes) {
        _renderStroke(canvas, stroke, size);
      }

      // Draw currently active strokes for the active layer
      if (layer.id == activeLayerId) {
        for (final stroke in currentStrokes) {
          _renderStroke(canvas, stroke, size);
        }
      }

      canvas.restore(); // restore layer transform
      canvas.restore(); // restore saveLayer
    }

    // Grid overlay
    if (showGrid) {
      _drawGrid(canvas, canvasWidth, canvasHeight);
    }

    // Symmetry guides
    if (showSymmetryGuide && symmetryMode != SymmetryMode.none) {
      _drawSymmetryGuide(canvas, canvasWidth, canvasHeight);
    }
  }

  void _drawCheckerboard(Canvas canvas, double width, double height) {
    const squareSize = 20.0;
    final paint1 = Paint()..color = const Color(0xFF282828);
    final paint2 = Paint()..color = const Color(0xFF323232);

    final cols = (width / squareSize).ceil();
    final rows = (height / squareSize).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final isEven = (row + col) % 2 == 0;
        final rect = Rect.fromLTWH(
          col * squareSize,
          row * squareSize,
          squareSize,
          squareSize,
        );
        canvas.drawRect(rect, isEven ? paint1 : paint2);
      }
    }
  }

  void _renderStroke(Canvas canvas, DrawStroke stroke, Size size) {
    switch (stroke.kind) {
      case StrokeKind.freehand:
        _drawFreehandStroke(canvas, stroke, size);
        break;
      case StrokeKind.fill:
        _drawFill(canvas, stroke);
        break;
      case StrokeKind.line:
      case StrokeKind.rectangle:
      case StrokeKind.roundedRectangle:
      case StrokeKind.circle:
      case StrokeKind.ellipse:
      case StrokeKind.triangle:
        _drawShape(canvas, stroke, size);
        break;
      case StrokeKind.text:
        _drawText(canvas, stroke);
        break;
      case StrokeKind.gradientLinear:
      case StrokeKind.gradientRadial:
        _drawGradient(canvas, stroke);
        break;
    }
  }

  void _drawFill(Canvas canvas, DrawStroke stroke) {
    final canvasWidth = canvasState.canvas.width.toDouble();
    final canvasHeight = canvasState.canvas.height.toDouble();
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.brushOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), paint);
  }

  void _drawGradient(Canvas canvas, DrawStroke stroke) {
    final start = stroke.shapeStart ?? Offset.zero;
    final end = stroke.shapeEnd ?? const Offset(200, 200);
    final color1 = stroke.color;
    final color2 = stroke.secondaryColor ?? Colors.transparent;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    if (stroke.kind == StrokeKind.gradientRadial) {
      final radius = math.max(10.0, (end - start).distance);
      paint.shader = ui.Gradient.radial(
        start,
        radius,
        [color1, color2],
      );
    } else {
      // Linear gradient along exact user stroke line from start to end
      paint.shader = ui.Gradient.linear(
        start,
        end,
        [color1, color2],
      );
    }

    final canvasWidth = canvasState.canvas.width.toDouble();
    final canvasHeight = canvasState.canvas.height.toDouble();
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), paint);
  }

  void _drawText(Canvas canvas, DrawStroke stroke) {
    final text = stroke.text ?? '';
    if (text.isEmpty) return;
    final pos = stroke.shapeStart ?? Offset.zero;
    final fontSize = stroke.fontSize ?? 28.0;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: stroke.color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      pos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawShape(Canvas canvas, DrawStroke stroke, Size size) {
    final start = stroke.shapeStart ?? Offset.zero;
    final end = stroke.shapeEnd ?? start;

    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.brushOpacity)
      ..style = stroke.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke.brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromPoints(start, end);
    final path = Path();

    switch (stroke.kind) {
      case StrokeKind.line:
        canvas.drawLine(start, end, paint);
        return;
      case StrokeKind.rectangle:
        path.addRect(rect);
        break;
      case StrokeKind.roundedRectangle:
        path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
        break;
      case StrokeKind.circle:
        final radius = (end - start).distance / 2;
        final center = (start + end) / 2;
        path.addOval(Rect.fromCircle(center: center, radius: radius));
        break;
      case StrokeKind.ellipse:
        path.addOval(rect);
        break;
      case StrokeKind.triangle:
        path.moveTo((start.dx + end.dx) / 2, start.dy);
        path.lineTo(end.dx, end.dy);
        path.lineTo(start.dx, end.dy);
        path.close();
        break;
      default:
        break;
    }

    canvas.drawPath(path, paint);

    if (symmetryMode != SymmetryMode.none) {
      _drawSymmetricPath(canvas, path, paint);
    }
  }

  void _drawFreehandStroke(Canvas canvas, DrawStroke stroke, Size size) {
    if (stroke.points.isEmpty) return;

    final isEraser = stroke.brushId == 'eraser_1' ||
        stroke.brushId == 'eraser_soft' ||
        stroke.brushId.startsWith('eraser');

    final brushType = _getBrushType(stroke.brushId);
    final paint = Paint()
      ..color = isEraser
          ? Colors.transparent
          : stroke.color.withValues(alpha: stroke.brushOpacity)
      ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.brushSize;

    if (!isEraser) {
      _applyBrushEffects(paint, brushType, stroke);
    }

    final points = stroke.points;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first.position,
        stroke.brushSize / 2,
        Paint()
          ..color = isEraser
              ? Colors.transparent
              : stroke.color.withValues(alpha: stroke.brushOpacity)
          ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver
          ..style = PaintingStyle.fill,
      );
      return;
    }

    // Build smooth path using quadratic bezier curves
    final path = Path();
    path.moveTo(points.first.position.dx, points.first.position.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i].position;
      final p1 = points[i + 1].position;
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }

    path.lineTo(points.last.position.dx, points.last.position.dy);
    canvas.drawPath(path, paint);

    if (symmetryMode != SymmetryMode.none) {
      _drawSymmetricPath(canvas, path, paint);
    }
  }

  void _applyBrushEffects(Paint paint, BrushType type, DrawStroke stroke) {
    switch (type) {
      case BrushType.airbrush:
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.0, stroke.brushSize * 0.35),
        );
        break;
      case BrushType.watercolor:
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.5, stroke.brushSize * 0.15),
        );
        break;
      case BrushType.charcoal:
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
        break;
      case BrushType.pencil:
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);
        break;
      case BrushType.smudge:
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.0, stroke.brushSize * 0.25),
        );
        paint.blendMode = BlendMode.dstOut;
        break;
      default:
        break;
    }
  }

  void _drawSymmetricPath(Canvas canvas, Path path, Paint paint) {
    final canvasWidth = canvasState.canvas.width.toDouble();
    final canvasHeight = canvasState.canvas.height.toDouble();
    final cx = canvasWidth / 2;
    final cy = canvasHeight / 2;

    if (symmetryMode == SymmetryMode.vertical) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-cx, 0);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else if (symmetryMode == SymmetryMode.horizontal) {
      canvas.save();
      canvas.translate(0, cy);
      canvas.scale(1, -1);
      canvas.translate(0, -cy);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else if (symmetryMode == SymmetryMode.radial) {
      final angleStep = (math.pi * 2) / radialSymmetryCount;
      for (int i = 1; i < radialSymmetryCount; i++) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(angleStep * i);
        canvas.translate(-cx, -cy);
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }
  }

  void _drawGrid(Canvas canvas, double width, double height) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.18)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), paint);
    }
    for (double y = 0; y <= height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  void _drawSymmetryGuide(Canvas canvas, double width, double height) {
    final paint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (symmetryMode == SymmetryMode.vertical) {
      canvas.drawLine(
        Offset(width / 2, 0),
        Offset(width / 2, height),
        paint,
      );
    } else if (symmetryMode == SymmetryMode.horizontal) {
      canvas.drawLine(
        Offset(0, height / 2),
        Offset(width, height / 2),
        paint,
      );
    } else if (symmetryMode == SymmetryMode.radial) {
      final cx = width / 2;
      final cy = height / 2;
      final r = math.sqrt(cx * cx + cy * cy);
      final angleStep = (math.pi * 2) / radialSymmetryCount;
      for (int i = 0; i < radialSymmetryCount; i++) {
        final angle = angleStep * i;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
          paint,
        );
      }
    }
  }

  BrushType _getBrushType(String brushId) {
    if (brushId.startsWith('pencil')) return BrushType.pencil;
    if (brushId.startsWith('pen')) return BrushType.pen;
    if (brushId.startsWith('airbrush')) return BrushType.airbrush;
    if (brushId.startsWith('marker')) return BrushType.marker;
    if (brushId.startsWith('watercolor')) return BrushType.watercolor;
    if (brushId.startsWith('ink')) return BrushType.ink;
    if (brushId.startsWith('charcoal')) return BrushType.charcoal;
    if (brushId.startsWith('pastel')) return BrushType.pastel;
    if (brushId.startsWith('smudge')) return BrushType.smudge;
    if (brushId.startsWith('eraser')) return BrushType.eraser;
    return BrushType.pen;
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
