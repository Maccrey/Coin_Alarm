// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_data_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChartDataAdapter extends TypeAdapter<ChartData> {
  @override
  final int typeId = 1;

  @override
  ChartData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChartData(
      symbol: fields[0] as String,
      timeframe: fields[1] as ChartTimeframe,
      points: (fields[2] as List).cast<ChartPoint>(),
      lastUpdated: fields[3] as DateTime,
      type: fields[4] as ChartType,
    );
  }

  @override
  void write(BinaryWriter writer, ChartData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.timeframe)
      ..writeByte(2)
      ..write(obj.points)
      ..writeByte(3)
      ..write(obj.lastUpdated)
      ..writeByte(4)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChartPointAdapter extends TypeAdapter<ChartPoint> {
  @override
  final int typeId = 2;

  @override
  ChartPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChartPoint(
      timestamp: fields[0] as DateTime,
      price: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ChartPoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.price);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CandleDataAdapter extends TypeAdapter<CandleData> {
  @override
  final int typeId = 3;

  @override
  CandleData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CandleData(
      timestamp: fields[0] as DateTime,
      open: fields[1] as double,
      high: fields[2] as double,
      low: fields[3] as double,
      close: fields[4] as double,
      volume: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CandleData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.open)
      ..writeByte(2)
      ..write(obj.high)
      ..writeByte(3)
      ..write(obj.low)
      ..writeByte(4)
      ..write(obj.close)
      ..writeByte(5)
      ..write(obj.volume);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandleDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CandleChartDataAdapter extends TypeAdapter<CandleChartData> {
  @override
  final int typeId = 4;

  @override
  CandleChartData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CandleChartData(
      symbol: fields[0] as String,
      timeframe: fields[1] as ChartTimeframe,
      candles: (fields[2] as List).cast<CandleData>(),
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CandleChartData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.timeframe)
      ..writeByte(2)
      ..write(obj.candles)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandleChartDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChartTypeAdapter extends TypeAdapter<ChartType> {
  @override
  final int typeId = 0;

  @override
  ChartType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChartType.candlestick;
      case 1:
        return ChartType.line;
      default:
        return ChartType.candlestick;
    }
  }

  @override
  void write(BinaryWriter writer, ChartType obj) {
    switch (obj) {
      case ChartType.candlestick:
        writer.writeByte(0);
        break;
      case ChartType.line:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChartTimeframeAdapter extends TypeAdapter<ChartTimeframe> {
  @override
  final int typeId = 5;

  @override
  ChartTimeframe read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChartTimeframe.minutes1;
      case 1:
        return ChartTimeframe.minutes3;
      case 2:
        return ChartTimeframe.minutes5;
      case 3:
        return ChartTimeframe.minutes10;
      case 4:
        return ChartTimeframe.minutes15;
      case 5:
        return ChartTimeframe.minutes30;
      case 6:
        return ChartTimeframe.minutes60;
      case 7:
        return ChartTimeframe.minutes240;
      case 8:
        return ChartTimeframe.days1;
      case 9:
        return ChartTimeframe.days7;
      case 10:
        return ChartTimeframe.days30;
      default:
        return ChartTimeframe.minutes1;
    }
  }

  @override
  void write(BinaryWriter writer, ChartTimeframe obj) {
    switch (obj) {
      case ChartTimeframe.minutes1:
        writer.writeByte(0);
        break;
      case ChartTimeframe.minutes3:
        writer.writeByte(1);
        break;
      case ChartTimeframe.minutes5:
        writer.writeByte(2);
        break;
      case ChartTimeframe.minutes10:
        writer.writeByte(3);
        break;
      case ChartTimeframe.minutes15:
        writer.writeByte(4);
        break;
      case ChartTimeframe.minutes30:
        writer.writeByte(5);
        break;
      case ChartTimeframe.minutes60:
        writer.writeByte(6);
        break;
      case ChartTimeframe.minutes240:
        writer.writeByte(7);
        break;
      case ChartTimeframe.days1:
        writer.writeByte(8);
        break;
      case ChartTimeframe.days7:
        writer.writeByte(9);
        break;
      case ChartTimeframe.days30:
        writer.writeByte(10);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartTimeframeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
