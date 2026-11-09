// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectModelAdapter extends TypeAdapter<ProjectModel> {
  @override
  final int typeId = 0;

  @override
  ProjectModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectModel(
      id: fields[0] as String,
      name: fields[1] as String,
      thumbnailPath: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      modifiedAt: fields[4] as DateTime,
      canvasWidth: fields[5] as int,
      canvasHeight: fields[6] as int,
      dpi: fields[7] as int,
      projectFilePath: fields[8] as String?,
      layerCount: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.thumbnailPath)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modifiedAt)
      ..writeByte(5)
      ..write(obj.canvasWidth)
      ..writeByte(6)
      ..write(obj.canvasHeight)
      ..writeByte(7)
      ..write(obj.dpi)
      ..writeByte(8)
      ..write(obj.projectFilePath)
      ..writeByte(9)
      ..write(obj.layerCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
