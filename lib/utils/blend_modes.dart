import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Software blend mode implementations for layer compositing
class BlendModes {
  BlendModes._();

  /// Apply blend between source (top) and destination (bottom) color
  static Color blend(Color src, Color dst, BlendMode mode) {
    switch (mode) {
      case BlendMode.multiply:
        return _multiply(src, dst);
      case BlendMode.screen:
        return _screen(src, dst);
      case BlendMode.overlay:
        return _overlay(src, dst);
      case BlendMode.darken:
        return _darken(src, dst);
      case BlendMode.lighten:
        return _lighten(src, dst);
      case BlendMode.colorDodge:
        return _colorDodge(src, dst);
      case BlendMode.colorBurn:
        return _colorBurn(src, dst);
      case BlendMode.hardLight:
        return _hardLight(src, dst);
      case BlendMode.softLight:
        return _softLight(src, dst);
      case BlendMode.difference:
        return _difference(src, dst);
      case BlendMode.exclusion:
        return _exclusion(src, dst);
      default:
        return _srcOver(src, dst);
    }
  }

  static Color _srcOver(Color src, Color dst) {
    final sa = src.opacity;
    final da = dst.opacity;
    final ra = sa + da * (1 - sa);
    if (ra == 0) return Colors.transparent;
    return Color.fromARGB(
      (ra * 255).round(),
      _clamp((src.red * sa + dst.red * da * (1 - sa)) / ra),
      _clamp((src.green * sa + dst.green * da * (1 - sa)) / ra),
      _clamp((src.blue * sa + dst.blue * da * (1 - sa)) / ra),
    );
  }

  static Color _multiply(Color src, Color dst) {
    return Color.fromARGB(
      (src.alpha * dst.alpha / 255).round(),
      (src.red * dst.red / 255).round(),
      (src.green * dst.green / 255).round(),
      (src.blue * dst.blue / 255).round(),
    );
  }

  static Color _screen(Color src, Color dst) {
    return Color.fromARGB(
      _clamp(src.alpha + dst.alpha - (src.alpha * dst.alpha / 255)),
      _clamp(255 - (255 - src.red) * (255 - dst.red) / 255),
      _clamp(255 - (255 - src.green) * (255 - dst.green) / 255),
      _clamp(255 - (255 - src.blue) * (255 - dst.blue) / 255),
    );
  }

  static Color _overlay(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      _overlayChannel(src.red, dst.red),
      _overlayChannel(src.green, dst.green),
      _overlayChannel(src.blue, dst.blue),
    );
  }

  static int _overlayChannel(int src, int dst) {
    if (dst < 128) {
      return _clamp(2 * src * dst / 255);
    } else {
      return _clamp(255 - 2 * (255 - src) * (255 - dst) / 255);
    }
  }

  static Color _darken(Color src, Color dst) {
    return Color.fromARGB(
      math.max(src.alpha, dst.alpha),
      math.min(src.red, dst.red),
      math.min(src.green, dst.green),
      math.min(src.blue, dst.blue),
    );
  }

  static Color _lighten(Color src, Color dst) {
    return Color.fromARGB(
      math.max(src.alpha, dst.alpha),
      math.max(src.red, dst.red),
      math.max(src.green, dst.green),
      math.max(src.blue, dst.blue),
    );
  }

  static Color _colorDodge(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      _colorDodgeChannel(src.red, dst.red),
      _colorDodgeChannel(src.green, dst.green),
      _colorDodgeChannel(src.blue, dst.blue),
    );
  }

  static int _colorDodgeChannel(int src, int dst) {
    if (dst == 0) return 0;
    if (src == 255) return 255;
    return _clamp((dst * 255) / (255 - src));
  }

  static Color _colorBurn(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      _colorBurnChannel(src.red, dst.red),
      _colorBurnChannel(src.green, dst.green),
      _colorBurnChannel(src.blue, dst.blue),
    );
  }

  static int _colorBurnChannel(int src, int dst) {
    if (dst == 255) return 255;
    if (src == 0) return 0;
    return _clamp(255 - ((255 - dst) * 255) / src);
  }

  static Color _hardLight(Color src, Color dst) {
    return _overlay(dst, src);
  }

  static Color _softLight(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      _softLightChannel(src.red, dst.red),
      _softLightChannel(src.green, dst.green),
      _softLightChannel(src.blue, dst.blue),
    );
  }

  static int _softLightChannel(int src, int dst) {
    final s = src / 255.0;
    final d = dst / 255.0;
    double r;
    if (s <= 0.5) {
      r = d - (1.0 - 2.0 * s) * d * (1.0 - d);
    } else {
      final dTerm = (d <= 0.25)
          ? ((16.0 * d - 12.0) * d + 4.0) * d
          : math.sqrt(d);
      r = d + (2.0 * s - 1.0) * (dTerm - d);
    }
    return _clamp(r * 255);
  }

  static Color _difference(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      (src.red - dst.red).abs(),
      (src.green - dst.green).abs(),
      (src.blue - dst.blue).abs(),
    );
  }

  static Color _exclusion(Color src, Color dst) {
    return Color.fromARGB(
      src.alpha,
      _clamp(src.red + dst.red - 2 * src.red * dst.red ~/ 255),
      _clamp(src.green + dst.green - 2 * src.green * dst.green ~/ 255),
      _clamp(src.blue + dst.blue - 2 * src.blue * dst.blue ~/ 255),
    );
  }

  static int _clamp(num value) => value.round().clamp(0, 255);
}

/// Point on the drawing path with pressure info
class DrawPoint {
  final Offset position;
  final double pressure;
  final double size;
  final double opacity;

  const DrawPoint({
    required this.position,
    this.pressure = 1.0,
    this.size = 1.0,
    this.opacity = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'dx': position.dx,
        'dy': position.dy,
        'p': pressure,
        's': size,
        'o': opacity,
      };

  factory DrawPoint.fromJson(Map<String, dynamic> json) => DrawPoint(
        position: Offset(
            (json['dx'] as num).toDouble(), (json['dy'] as num).toDouble()),
        pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
        size: (json['s'] as num?)?.toDouble() ?? 1.0,
        opacity: (json['o'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Stroke types (freehand brush or geometric shapes / text / fill)
enum StrokeKind {
  freehand,
  line,
  rectangle,
  roundedRectangle,
  circle,
  ellipse,
  triangle,
  fill,
  floodFill,
  text,
  gradientLinear,
  gradientRadial,
}

/// A single drawing stroke or shape/text/fill item
class DrawStroke {
  final List<DrawPoint> points;
  final Color color;
  final String brushId;
  final double brushSize;
  final double brushOpacity;
  final String layerId;
  final int blendMode; // BlendMode index
  final StrokeKind kind;
  final bool isFilled;
  final String? text;
  final double? fontSize;
  final Color? secondaryColor; // For gradients
  final Offset? shapeStart;
  final Offset? shapeEnd;
  final Uint8List? imageBytes;
  ui.Image? floodFillImage;

  DrawStroke({
    required this.points,
    required this.color,
    required this.brushId,
    required this.brushSize,
    required this.brushOpacity,
    required this.layerId,
    this.blendMode = 0,
    this.kind = StrokeKind.freehand,
    this.isFilled = false,
    this.text,
    this.fontSize,
    this.secondaryColor,
    this.shapeStart,
    this.shapeEnd,
    this.imageBytes,
    this.floodFillImage,
  });

  DrawStroke copyWith({
    List<DrawPoint>? points,
    Color? color,
    String? brushId,
    double? brushSize,
    double? brushOpacity,
    String? layerId,
    int? blendMode,
    StrokeKind? kind,
    bool? isFilled,
    String? text,
    double? fontSize,
    Color? secondaryColor,
    Offset? shapeStart,
    Offset? shapeEnd,
    Uint8List? imageBytes,
    ui.Image? floodFillImage,
  }) {
    return DrawStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      brushId: brushId ?? this.brushId,
      brushSize: brushSize ?? this.brushSize,
      brushOpacity: brushOpacity ?? this.brushOpacity,
      layerId: layerId ?? this.layerId,
      blendMode: blendMode ?? this.blendMode,
      kind: kind ?? this.kind,
      isFilled: isFilled ?? this.isFilled,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      shapeStart: shapeStart ?? this.shapeStart,
      shapeEnd: shapeEnd ?? this.shapeEnd,
      imageBytes: imageBytes ?? this.imageBytes,
      floodFillImage: floodFillImage ?? this.floodFillImage,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': color.toARGB32(),
        'brushId': brushId,
        'brushSize': brushSize,
        'brushOpacity': brushOpacity,
        'layerId': layerId,
        'blendMode': blendMode,
        'kind': kind.index,
        'isFilled': isFilled,
        'text': text,
        'fontSize': fontSize,
        'secondaryColor': secondaryColor?.toARGB32(),
        'shapeStartX': shapeStart?.dx,
        'shapeStartY': shapeStart?.dy,
        'shapeEndX': shapeEnd?.dx,
        'shapeEndY': shapeEnd?.dy,
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) => DrawStroke(
        points: ((json['points'] as List<dynamic>?) ?? [])
            .map((p) => DrawPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        color: Color(json['color'] as int? ?? 0xFF000000),
        brushId: json['brushId'] as String? ?? 'brush',
        brushSize: (json['brushSize'] as num?)?.toDouble() ?? 8.0,
        brushOpacity: (json['brushOpacity'] as num?)?.toDouble() ?? 1.0,
        layerId: json['layerId'] as String? ?? '',
        blendMode: json['blendMode'] as int? ?? 0,
        kind: StrokeKind.values[(json['kind'] as int? ?? 0)
            .clamp(0, StrokeKind.values.length - 1)],
        isFilled: json['isFilled'] as bool? ?? false,
        text: json['text'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble(),
        secondaryColor: json['secondaryColor'] != null
            ? Color(json['secondaryColor'] as int)
            : null,
        shapeStart: json['shapeStartX'] != null && json['shapeStartY'] != null
            ? Offset((json['shapeStartX'] as num).toDouble(),
                (json['shapeStartY'] as num).toDouble())
            : null,
        shapeEnd: json['shapeEndX'] != null && json['shapeEndY'] != null
            ? Offset((json['shapeEndX'] as num).toDouble(),
                (json['shapeEndY'] as num).toDouble())
            : null,
        imageBytes: json['imageBytes'] != null
            ? base64Decode(json['imageBytes'] as String)
            : null,
      );
}
