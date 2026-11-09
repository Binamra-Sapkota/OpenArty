import 'package:hive/hive.dart';

part 'brush_model.g.dart';

@HiveType(typeId: 1)
enum BrushType {
  @HiveField(0)
  pencil,
  @HiveField(1)
  pen,
  @HiveField(2)
  airbrush,
  @HiveField(3)
  marker,
  @HiveField(4)
  watercolor,
  @HiveField(5)
  ink,
  @HiveField(6)
  gouache,
  @HiveField(7)
  charcoal,
  @HiveField(8)
  pastel,
  @HiveField(9)
  smudge,
  @HiveField(10)
  eraser,
}

enum BrushCategory {
  sketching,
  inking,
  painting,
  airbrushing,
  artistic,
  utilities,
}

@HiveType(typeId: 2)
class BrushModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  BrushType type;

  @HiveField(3)
  double size;

  @HiveField(4)
  double opacity;

  @HiveField(5)
  double hardness;

  @HiveField(6)
  double spacing;

  @HiveField(7)
  double streamline;

  @HiveField(8)
  bool pressureSensitive;

  @HiveField(9)
  bool tiltSensitive;

  @HiveField(10)
  double taper;

  @HiveField(11)
  double jitter;

  BrushModel({
    required this.id,
    required this.name,
    required this.type,
    this.size = 20.0,
    this.opacity = 1.0,
    this.hardness = 0.8,
    this.spacing = 0.1,
    this.streamline = 0.5,
    this.pressureSensitive = true,
    this.tiltSensitive = false,
    this.taper = 0.0,
    this.jitter = 0.0,
  });

  BrushModel copyWith({
    String? id,
    String? name,
    BrushType? type,
    double? size,
    double? opacity,
    double? hardness,
    double? spacing,
    double? streamline,
    bool? pressureSensitive,
    bool? tiltSensitive,
    double? taper,
    double? jitter,
  }) {
    return BrushModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      hardness: hardness ?? this.hardness,
      spacing: spacing ?? this.spacing,
      streamline: streamline ?? this.streamline,
      pressureSensitive: pressureSensitive ?? this.pressureSensitive,
      tiltSensitive: tiltSensitive ?? this.tiltSensitive,
      taper: taper ?? this.taper,
      jitter: jitter ?? this.jitter,
    );
  }

  String get typeName {
    switch (type) {
      case BrushType.pencil:
        return 'Pencil';
      case BrushType.pen:
        return 'Pen';
      case BrushType.airbrush:
        return 'Airbrush';
      case BrushType.marker:
        return 'Marker';
      case BrushType.watercolor:
        return 'Watercolor';
      case BrushType.ink:
        return 'Ink';
      case BrushType.gouache:
        return 'Gouache';
      case BrushType.charcoal:
        return 'Charcoal';
      case BrushType.pastel:
        return 'Pastel';
      case BrushType.smudge:
        return 'Smudge';
      case BrushType.eraser:
        return 'Eraser';
    }
  }

  BrushCategory get category {
    switch (type) {
      case BrushType.pencil:
        return BrushCategory.sketching;
      case BrushType.pen:
      case BrushType.ink:
      case BrushType.marker:
        return BrushCategory.inking;
      case BrushType.watercolor:
      case BrushType.gouache:
        return BrushCategory.painting;
      case BrushType.airbrush:
        return BrushCategory.airbrushing;
      case BrushType.charcoal:
      case BrushType.pastel:
        return BrushCategory.artistic;
      case BrushType.smudge:
      case BrushType.eraser:
        return BrushCategory.utilities;
    }
  }

  static List<BrushModel> get defaults => [
        BrushModel(
          id: 'pencil_1',
          name: 'HB Pencil',
          type: BrushType.pencil,
          size: 6,
          opacity: 0.85,
          hardness: 0.7,
          spacing: 0.05,
          streamline: 0.4,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'pencil_2',
          name: 'Technical Pencil',
          type: BrushType.pencil,
          size: 3,
          opacity: 0.95,
          hardness: 0.9,
          spacing: 0.02,
          streamline: 0.5,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'pen_1',
          name: 'Technical Pen',
          type: BrushType.pen,
          size: 5,
          opacity: 1.0,
          hardness: 1.0,
          spacing: 0.02,
          streamline: 0.6,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'pen_hard',
          name: 'Hard Round Brush',
          type: BrushType.pen,
          size: 16,
          opacity: 1.0,
          hardness: 1.0,
          spacing: 0.01,
          streamline: 0.5,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'airbrush_soft',
          name: 'Soft Round Brush',
          type: BrushType.airbrush,
          size: 32,
          opacity: 0.7,
          hardness: 0.0,
          spacing: 0.02,
          streamline: 0.4,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'airbrush_1',
          name: 'Airbrush',
          type: BrushType.airbrush,
          size: 60,
          opacity: 0.45,
          hardness: 0.0,
          spacing: 0.03,
          streamline: 0.3,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'marker_1',
          name: 'Chisel Marker',
          type: BrushType.marker,
          size: 22,
          opacity: 0.85,
          hardness: 0.9,
          spacing: 0.02,
          streamline: 0.5,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'ink_1',
          name: 'Calligraphy Ink',
          type: BrushType.ink,
          size: 8,
          opacity: 1.0,
          hardness: 0.95,
          spacing: 0.02,
          streamline: 0.75,
          taper: 0.4,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'watercolor_1',
          name: 'Watercolor Wash',
          type: BrushType.watercolor,
          size: 40,
          opacity: 0.4,
          hardness: 0.1,
          spacing: 0.08,
          streamline: 0.25,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'charcoal_1',
          name: 'Vine Charcoal',
          type: BrushType.charcoal,
          size: 28,
          opacity: 0.7,
          hardness: 0.3,
          spacing: 0.1,
          streamline: 0.2,
          jitter: 0.3,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'pastel_1',
          name: 'Soft Pastel',
          type: BrushType.pastel,
          size: 25,
          opacity: 0.6,
          hardness: 0.2,
          spacing: 0.06,
          streamline: 0.2,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'smudge_1',
          name: 'Smudge Blender',
          type: BrushType.smudge,
          size: 30,
          opacity: 0.6,
          hardness: 0.5,
          spacing: 0.05,
          streamline: 0.4,
          pressureSensitive: true,
        ),
        BrushModel(
          id: 'eraser_1',
          name: 'Precision Eraser',
          type: BrushType.eraser,
          size: 15,
          opacity: 1.0,
          hardness: 1.0,
          spacing: 0.02,
          streamline: 0.5,
          pressureSensitive: false,
        ),
        BrushModel(
          id: 'eraser_soft',
          name: 'Soft Eraser',
          type: BrushType.eraser,
          size: 40,
          opacity: 0.6,
          hardness: 0.0,
          spacing: 0.02,
          streamline: 0.4,
          pressureSensitive: false,
        ),
      ];
}
