import 'package:hive/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 0)
class ProjectModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? thumbnailPath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime modifiedAt;

  @HiveField(5)
  int canvasWidth;

  @HiveField(6)
  int canvasHeight;

  @HiveField(7)
  int dpi;

  @HiveField(8)
  String? projectFilePath;

  @HiveField(9)
  int layerCount;

  ProjectModel({
    required this.id,
    required this.name,
    this.thumbnailPath,
    required this.createdAt,
    required this.modifiedAt,
    this.canvasWidth = 1080,
    this.canvasHeight = 1080,
    this.dpi = 150,
    this.projectFilePath,
    this.layerCount = 1,
  });

  String get dimensionLabel => '${canvasWidth}×$canvasHeight';
}
