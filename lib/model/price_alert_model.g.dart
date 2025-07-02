// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_alert_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PriceAlertAdapter extends TypeAdapter<PriceAlert> {
  @override
  final int typeId = 10;

  @override
  PriceAlert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PriceAlert(
      id: fields[0] as String,
      userId: fields[1] as String,
      coinId: fields[2] as String,
      coinSymbol: fields[3] as String,
      priceTarget: fields[4] as double,
      isAbove: fields[5] as bool,
      isTriggered: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      triggeredAt: fields[8] as DateTime?,
      notes: fields[9] as String?,
      triggeredPrice: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, PriceAlert obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.coinId)
      ..writeByte(3)
      ..write(obj.coinSymbol)
      ..writeByte(4)
      ..write(obj.priceTarget)
      ..writeByte(5)
      ..write(obj.isAbove)
      ..writeByte(6)
      ..write(obj.isTriggered)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.triggeredAt)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.triggeredPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceAlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
