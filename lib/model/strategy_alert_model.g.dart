// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strategy_alert_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StrategyAlertAdapter extends TypeAdapter<StrategyAlert> {
  @override
  final int typeId = 11;

  @override
  StrategyAlert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StrategyAlert(
      id: fields[0] as String,
      userId: fields[1] as String,
      coinId: fields[2] as String,
      coinSymbol: fields[3] as String,
      strategyName: fields[4] as String,
      riskLevel: fields[5] as String,
      triggerConditionJson: fields[6] as String,
      isTriggered: fields[7] as bool,
      triggeredAt: fields[8] as DateTime?,
      createdAt: fields[9] as DateTime,
      notes: fields[10] as String?,
      isEnabled: fields[11] as bool,
      alertType: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StrategyAlert obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.coinId)
      ..writeByte(3)
      ..write(obj.coinSymbol)
      ..writeByte(4)
      ..write(obj.strategyName)
      ..writeByte(5)
      ..write(obj.riskLevel)
      ..writeByte(6)
      ..write(obj.triggerConditionJson)
      ..writeByte(7)
      ..write(obj.isTriggered)
      ..writeByte(8)
      ..write(obj.triggeredAt)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.isEnabled)
      ..writeByte(12)
      ..write(obj.alertType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrategyAlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
