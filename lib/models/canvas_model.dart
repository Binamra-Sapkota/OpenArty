import 'package:flutter/material.dart';

/// Represents the canvas configuration
class CanvasModel {
  final int width;
  final int height;
  final int dpi;
  final String colorProfile;
  final Color backgroundColor;
  final double zoomLevel;
  final Offset panOffset;

  const CanvasModel({
    this.width = 1080,
    this.height = 1080,
    this.dpi = 150,
    this.colorProfile = 'sRGB',
    this.backgroundColor = Colors.white,
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
  });

  String get dimensionString => '${width}x$height px';
  String get displaySize =>
      '${(width / dpi).toStringAsFixed(1)}" × ${(height / dpi).toStringAsFixed(1)}" @ ${dpi}dpi';

  CanvasModel copyWith({
    int? width,
    int? height,
    int? dpi,
    String? colorProfile,
    Color? backgroundColor,
    double? zoomLevel,
    Offset? panOffset,
  }) {
    return CanvasModel(
      width: width ?? this.width,
      height: height ?? this.height,
      dpi: dpi ?? this.dpi,
      colorProfile: colorProfile ?? this.colorProfile,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panOffset: panOffset ?? this.panOffset,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'dpi': dpi,
        'colorProfile': colorProfile,
        'backgroundColor': backgroundColor.value,
        'zoomLevel': zoomLevel,
        'panOffsetX': panOffset.dx,
        'panOffsetY': panOffset.dy,
      };

  factory CanvasModel.fromJson(Map<String, dynamic> json) => CanvasModel(
        width: json['width'] as int? ?? 1080,
        height: json['height'] as int? ?? 1080,
        dpi: json['dpi'] as int? ?? 150,
        colorProfile: json['colorProfile'] as String? ?? 'sRGB',
        backgroundColor:
            Color(json['backgroundColor'] as int? ?? 0xFFFFFFFF),
        zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
        panOffset: Offset(
          (json['panOffsetX'] as num?)?.toDouble() ?? 0.0,
          (json['panOffsetY'] as num?)?.toDouble() ?? 0.0,
        ),
      );

  /// Predefined canvas sizes
  static const List<CanvasSizePreset> presets = [
    CanvasSizePreset(name: 'Square (1080x1080)', width: 1080, height: 1080, dpi: 150),
    CanvasSizePreset(name: 'Portrait A4', width: 2480, height: 3508, dpi: 300),
    CanvasSizePreset(name: 'Landscape A4', width: 3508, height: 2480, dpi: 300),
    CanvasSizePreset(name: 'HD (1920x1080)', width: 1920, height: 1080, dpi: 72),
    CanvasSizePreset(name: '4K (3840x2160)', width: 3840, height: 2160, dpi: 72),
    CanvasSizePreset(name: 'Screen (1080x1920)', width: 1080, height: 1920, dpi: 72),
    CanvasSizePreset(name: 'Square Small (512x512)', width: 512, height: 512, dpi: 72),
    CanvasSizePreset(name: 'Square Large (4096x4096)', width: 4096, height: 4096, dpi: 300),
    CanvasSizePreset(name: 'Custom', width: 1080, height: 1080, dpi: 150),
  ];
}

class CanvasSizePreset {
  final String name;
  final int width;
  final int height;
  final int dpi;

  const CanvasSizePreset({
    required this.name,
    required this.width,
    required this.height,
    required this.dpi,
  });
}
