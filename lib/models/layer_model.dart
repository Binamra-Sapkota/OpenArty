import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Blend mode enum matching common painting app blend modes
enum LayerBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  hue,
  saturation,
  color,
  luminosity,
}

/// Type of content represented by a layer
enum LayerType {
  drawing,
  image,
  text,
  gradient,
}

extension LayerBlendModeExt on LayerBlendMode {
  String get displayName {
    switch (this) {
      case LayerBlendMode.normal:
        return 'Normal';
      case LayerBlendMode.multiply:
        return 'Multiply';
      case LayerBlendMode.screen:
        return 'Screen';
      case LayerBlendMode.overlay:
        return 'Overlay';
      case LayerBlendMode.darken:
        return 'Darken';
      case LayerBlendMode.lighten:
        return 'Lighten';
      case LayerBlendMode.colorDodge:
        return 'Color Dodge';
      case LayerBlendMode.colorBurn:
        return 'Color Burn';
      case LayerBlendMode.hardLight:
        return 'Hard Light';
      case LayerBlendMode.softLight:
        return 'Soft Light';
      case LayerBlendMode.difference:
        return 'Difference';
      case LayerBlendMode.exclusion:
        return 'Exclusion';
      case LayerBlendMode.hue:
        return 'Hue';
      case LayerBlendMode.saturation:
        return 'Saturation';
      case LayerBlendMode.color:
        return 'Color';
      case LayerBlendMode.luminosity:
        return 'Luminosity';
    }
  }

  BlendMode get flutterBlendMode {
    switch (this) {
      case LayerBlendMode.normal:
        return BlendMode.srcOver;
      case LayerBlendMode.multiply:
        return BlendMode.multiply;
      case LayerBlendMode.screen:
        return BlendMode.screen;
      case LayerBlendMode.overlay:
        return BlendMode.overlay;
      case LayerBlendMode.darken:
        return BlendMode.darken;
      case LayerBlendMode.lighten:
        return BlendMode.lighten;
      case LayerBlendMode.colorDodge:
        return BlendMode.colorDodge;
      case LayerBlendMode.colorBurn:
        return BlendMode.colorBurn;
      case LayerBlendMode.hardLight:
        return BlendMode.hardLight;
      case LayerBlendMode.softLight:
        return BlendMode.softLight;
      case LayerBlendMode.difference:
        return BlendMode.difference;
      case LayerBlendMode.exclusion:
        return BlendMode.exclusion;
      case LayerBlendMode.hue:
        return BlendMode.hue;
      case LayerBlendMode.saturation:
        return BlendMode.saturation;
      case LayerBlendMode.color:
        return BlendMode.color;
      case LayerBlendMode.luminosity:
        return BlendMode.luminosity;
    }
  }
}

/// Represents a single drawing layer
class LayerModel {
  final String id;
  String name;
  LayerType layerType;
  Uint8List? pixelData; // Encoded PNG bytes
  bool isVisible;
  bool isLocked;
  bool isAlphaLocked;
  double opacity;
  LayerBlendMode blendMode;
  bool isGroup;
  List<LayerModel> children; // For group layers
  int width;
  int height;
  double offsetX;
  double offsetY;
  double scale;
  double rotation;

  // Text layer specific properties
  String? textContent;
  double? fontSize;
  Color? textColor;
  bool isBold;
  bool isItalic;

  LayerModel({
    required this.id,
    required this.name,
    this.layerType = LayerType.drawing,
    this.pixelData,
    this.isVisible = true,
    this.isLocked = false,
    this.isAlphaLocked = false,
    this.opacity = 1.0,
    this.blendMode = LayerBlendMode.normal,
    this.isGroup = false,
    List<LayerModel>? children,
    this.width = 1080,
    this.height = 1080,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.textContent,
    this.fontSize,
    this.textColor,
    this.isBold = false,
    this.isItalic = false,
  }) : children = children ?? [];

  bool get isTextLayer =>
      layerType == LayerType.text || (textContent != null && textContent!.isNotEmpty);

  LayerModel copyWith({
    String? id,
    String? name,
    LayerType? layerType,
    Uint8List? pixelData,
    bool? isVisible,
    bool? isLocked,
    bool? isAlphaLocked,
    double? opacity,
    LayerBlendMode? blendMode,
    bool? isGroup,
    List<LayerModel>? children,
    int? width,
    int? height,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotation,
    String? textContent,
    double? fontSize,
    Color? textColor,
    bool? isBold,
    bool? isItalic,
  }) {
    return LayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      layerType: layerType ?? this.layerType,
      pixelData: pixelData ?? this.pixelData,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      isAlphaLocked: isAlphaLocked ?? this.isAlphaLocked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      isGroup: isGroup ?? this.isGroup,
      children: children ?? this.children,
      width: width ?? this.width,
      height: height ?? this.height,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      textContent: textContent ?? this.textContent,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
    );
  }

  Map<String, dynamic> toJson({bool includePixelData = true}) => {
        'id': id,
        'name': name,
        'layerType': layerType.index,
        'isVisible': isVisible,
        'isLocked': isLocked,
        'isAlphaLocked': isAlphaLocked,
        'opacity': opacity,
        'blendMode': blendMode.index,
        'isGroup': isGroup,
        'width': width,
        'height': height,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
        'rotation': rotation,
        'pixelData': (includePixelData && pixelData != null) ? base64Encode(pixelData!) : null,
        'textContent': textContent,
        'fontSize': fontSize,
        'textColor': textColor?.toARGB32(),
        'isBold': isBold,
        'isItalic': isItalic,
      };

  factory LayerModel.fromJson(Map<String, dynamic> json) => LayerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        layerType: json['layerType'] != null
            ? LayerType.values[json['layerType'] as int]
            : (json['textContent'] != null ? LayerType.text : LayerType.drawing),
        isVisible: json['isVisible'] as bool? ?? true,
        isLocked: json['isLocked'] as bool? ?? false,
        isAlphaLocked: json['isAlphaLocked'] as bool? ?? false,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        blendMode: LayerBlendMode.values[json['blendMode'] as int? ?? 0],
        isGroup: json['isGroup'] as bool? ?? false,
        width: json['width'] as int? ?? 1080,
        height: json['height'] as int? ?? 1080,
        offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
        offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        pixelData: json['pixelData'] != null
            ? base64Decode(json['pixelData'] as String)
            : null,
        textContent: json['textContent'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble(),
        textColor: json['textColor'] != null ? Color(json['textColor'] as int) : null,
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
      );
}
