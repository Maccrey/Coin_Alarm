import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:coin_alarm/services/price_alert_service.dart';
import 'package:coin_alarm/model/price_alert_model.dart';
import 'package:coin_alarm/model/coin_model.dart';

void main() {
  group('PriceAlertService', () {
    late PriceAlertService service;
    late Box<PriceAlert> box;
    const userId = 'test-user';
    setUpAll(() async {
      final testDir = Directory.systemTemp.createTempSync();
      Hive.init(testDir.path);
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(PriceAlertAdapter());
      }
      box = await Hive.openBox<PriceAlert>('price_alerts');
      service = PriceAlertService();
      await service.initialize();
    });
    tearDownAll(() async {
      await box.clear();
      await box.close();
    });

    test('create and trigger alert (isAbove)', () async {
      final alert = await service.createAlert(
        userId,
        'btc',
        'BTC',
        100.0,
        true,
      );
      expect(alert, isNotNull);
      final coin = Coin(
        id: 'btc',
        symbol: 'BTC',
        name: 'BTC',
        currentPrice: 150.0,
        priceChangePercentage24h: 0,
        lastUpdated: DateTime.now(),
      );
      final triggered = await service.checkAndUpdateAlerts([coin], userId);
      expect(triggered.length, 1);
      expect(triggered.first.isTriggered, true);
      expect(triggered.first.triggeredPrice, 150.0);
    });

    test('does not trigger already triggered alert', () async {
      final alert = await service.createAlert(
        userId,
        'eth',
        'ETH',
        100.0,
        false,
      );
      // 1차 트리거
      final coin1 = Coin(
        id: 'eth',
        symbol: 'ETH',
        name: 'ETH',
        currentPrice: 50.0,
        priceChangePercentage24h: 0,
        lastUpdated: DateTime.now(),
      );
      final triggered1 = await service.checkAndUpdateAlerts([coin1], userId);
      expect(triggered1.length, 1);
      // 2차 트리거 시도 (이미 발생됨)
      final coin2 = Coin(
        id: 'eth',
        symbol: 'ETH',
        name: 'ETH',
        currentPrice: 40.0,
        priceChangePercentage24h: 0,
        lastUpdated: DateTime.now(),
      );
      final triggered2 = await service.checkAndUpdateAlerts([coin2], userId);
      expect(triggered2.length, 0);
    });
  });
}
