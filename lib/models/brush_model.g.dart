// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brush_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrushModelAdapter extends TypeAdapter<BrushModel> {
  @override
  final int typeId = 2;

  @override
  BrushModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrushModel(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as BrushType,
      size: fields[3] as double,
      opacity: fields[4] as double,
      hardness: fields[5] as double,
      spacing: fields[6] as double,
      streamline: fields[7] as double,
      pressureSensitive: fields[8] as bool,
      tiltSensitive: fields[9] as bool,
      taper: fields[10] as double,
      jitter: fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BrushModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.opacity)
      ..writeByte(5)
      ..write(obj.hardness)
      ..writeByte(6)
      ..write(obj.spacing)
      ..writeByte(7)
      ..write(obj.streamline)
      ..writeByte(8)
      ..write(obj.pressureSensitive)
      ..writeByte(9)
      ..write(obj.tiltSensitive)
      ..writeByte(10)
      ..write(obj.taper)
      ..writeByte(11)
      ..write(obj.jitter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BrushTypeAdapter extends TypeAdapter<BrushType> {
  @override
  final int typeId = 1;

  @override
  BrushType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BrushType.pencil;
      case 1:
        return BrushType.pen;
      case 2:
        return BrushType.airbrush;
      case 3:
        return BrushType.marker;
      case 4:
        return BrushType.watercolor;
      case 5:
        return BrushType.ink;
      case 6:
        return BrushType.gouache;
      case 7:
        return BrushType.charcoal;
      case 8:
        return BrushType.pastel;
      case 9:
        return BrushType.smudge;
      case 10:
        return BrushType.eraser;
      default:
        return BrushType.pencil;
    }
  }

  @override
  void write(BinaryWriter writer, BrushType obj) {
    switch (obj) {
      case BrushType.pencil:
        writer.writeByte(0);
        break;
      case BrushType.pen:
        writer.writeByte(1);
        break;
      case BrushType.airbrush:
        writer.writeByte(2);
        break;
      case BrushType.marker:
        writer.writeByte(3);
        break;
      case BrushType.watercolor:
        writer.writeByte(4);
        break;
      case BrushType.ink:
        writer.writeByte(5);
        break;
      case BrushType.gouache:
        writer.writeByte(6);
        break;
      case BrushType.charcoal:
        writer.writeByte(7);
        break;
      case BrushType.pastel:
        writer.writeByte(8);
        break;
      case BrushType.smudge:
        writer.writeByte(9);
        break;
      case BrushType.eraser:
        writer.writeByte(10);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
