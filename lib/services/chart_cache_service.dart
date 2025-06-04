import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../model/chart_data_model.dart';

/// 차트 데이터 캐시 서비스
///
/// Hive를 사용하여 차트 데이터를 로컬에 캐싱하는 서비스
class ChartCacheService {
  static const String _lineChartBoxName = 'line_chart_data';
  static const String _candleChartBoxName = 'candle_chart_data';

  late Box<ChartData> _lineChartBox;
  late Box<CandleChartData> _candleChartBox;
  bool _isInitialized = false;

  /// 싱글톤 인스턴스
  static final ChartCacheService _instance = ChartCacheService._internal();

  /// 팩토리 생성자
  factory ChartCacheService() => _instance;

  /// 내부 생성자
  ChartCacheService._internal();

  /// 초기화 메서드
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('ChartCacheService: 이미 초기화되었습니다.');
      return;
    }

    try {
      debugPrint('ChartCacheService: 초기화 시작');

      // Hive 초기화
      await Hive.initFlutter();

      // 모델 어댑터 등록
      Hive.registerAdapter(ChartDataAdapter());
      Hive.registerAdapter(ChartPointAdapter());
      Hive.registerAdapter(CandleDataAdapter());
      Hive.registerAdapter(CandleChartDataAdapter());
      Hive.registerAdapter(ChartTypeAdapter());
      Hive.registerAdapter(ChartTimeframeAdapter());

      // 박스 열기
      _lineChartBox = await Hive.openBox<ChartData>(_lineChartBoxName);
      _candleChartBox = await Hive.openBox<CandleChartData>(
        _candleChartBoxName,
      );

      _isInitialized = true;
      debugPrint('ChartCacheService: 초기화 완료');
    } catch (e) {
      debugPrint('ChartCacheService: 초기화 오류 - $e');
      // 에러 발생 시 캐시 폴더 정리 시도
      await _clearCache();
      rethrow;
    }
  }

  /// 라인 차트 데이터 저장
  Future<void> saveLineChartData(ChartData chartData) async {
    await _ensureInitialized();

    try {
      await _lineChartBox.put(chartData.cacheKey, chartData);
      debugPrint(
        'ChartCacheService: 라인 차트 데이터 저장 완료 - ${chartData.symbol} (${chartData.timeframe.name})',
      );
    } catch (e) {
      debugPrint('ChartCacheService: 라인 차트 데이터 저장 오류 - $e');
    }
  }

  /// 캔들스틱 차트 데이터 저장
  Future<void> saveCandleChartData(CandleChartData chartData) async {
    await _ensureInitialized();

    try {
      await _candleChartBox.put(chartData.cacheKey, chartData);
      debugPrint(
        'ChartCacheService: 캔들 차트 데이터 저장 완료 - ${chartData.symbol} (${chartData.timeframe.name})',
      );
    } catch (e) {
      debugPrint('ChartCacheService: 캔들 차트 데이터 저장 오류 - $e');
    }
  }

  /// 라인 차트 데이터 조회
  ChartData? getLineChartData(String symbol, ChartTimeframe timeframe) {
    if (!_isInitialized) {
      debugPrint('ChartCacheService: 초기화되지 않았습니다.');
      return null;
    }

    final cacheKey = '${symbol}_${timeframe.name}_${ChartType.line.name}';
    final cachedData = _lineChartBox.get(cacheKey);

    if (cachedData != null && !cachedData.isExpired()) {
      debugPrint(
        'ChartCacheService: 캐시된 라인 차트 데이터 반환 - $symbol (${timeframe.name})',
      );
      return cachedData;
    }

    debugPrint(
      'ChartCacheService: 캐시된 라인 차트 데이터 없음 또는 만료됨 - $symbol (${timeframe.name})',
    );
    return null;
  }

  /// 캔들스틱 차트 데이터 조회
  CandleChartData? getCandleChartData(String symbol, ChartTimeframe timeframe) {
    if (!_isInitialized) {
      debugPrint('ChartCacheService: 초기화되지 않았습니다.');
      return null;
    }

    final cacheKey = '${symbol}_${timeframe.name}_candle';
    final cachedData = _candleChartBox.get(cacheKey);

    if (cachedData != null && !cachedData.isExpired()) {
      debugPrint(
        'ChartCacheService: 캐시된 캔들 차트 데이터 반환 - $symbol (${timeframe.name})',
      );
      return cachedData;
    }

    debugPrint(
      'ChartCacheService: 캐시된 캔들 차트 데이터 없음 또는 만료됨 - $symbol (${timeframe.name})',
    );
    return null;
  }

  /// 특정 심볼의 모든 캐시 데이터 삭제
  Future<void> clearSymbolCache(String symbol) async {
    await _ensureInitialized();

    try {
      // 라인 차트 데이터 삭제
      final lineKeysToDelete = _lineChartBox.keys
          .where((key) => (key as String).startsWith(symbol))
          .toList();

      for (final key in lineKeysToDelete) {
        await _lineChartBox.delete(key);
      }

      // 캔들 차트 데이터 삭제
      final candleKeysToDelete = _candleChartBox.keys
          .where((key) => (key as String).startsWith(symbol))
          .toList();

      for (final key in candleKeysToDelete) {
        await _candleChartBox.delete(key);
      }

      debugPrint('ChartCacheService: $symbol 심볼의 모든 캐시 데이터 삭제 완료');
    } catch (e) {
      debugPrint('ChartCacheService: 캐시 삭제 오류 - $e');
    }
  }

  /// 모든 만료된 캐시 데이터 정리
  Future<void> clearExpiredCache() async {
    await _ensureInitialized();

    try {
      // 만료된 라인 차트 데이터 삭제
      final expiredLineKeys = _lineChartBox.keys.where((key) {
        final data = _lineChartBox.get(key);
        return data != null && data.isExpired();
      }).toList();

      for (final key in expiredLineKeys) {
        await _lineChartBox.delete(key);
      }

      // 만료된 캔들 차트 데이터 삭제
      final expiredCandleKeys = _candleChartBox.keys.where((key) {
        final data = _candleChartBox.get(key);
        return data != null && data.isExpired();
      }).toList();

      for (final key in expiredCandleKeys) {
        await _candleChartBox.delete(key);
      }

      debugPrint(
        'ChartCacheService: 만료된 캐시 데이터 정리 완료 (${expiredLineKeys.length}개 라인, ${expiredCandleKeys.length}개 캔들)',
      );
    } catch (e) {
      debugPrint('ChartCacheService: 만료 캐시 정리 오류 - $e');
    }
  }

  /// 모든 캐시 데이터 삭제
  Future<void> clearAllCache() async {
    await _ensureInitialized();

    try {
      await _lineChartBox.clear();
      await _candleChartBox.clear();
      debugPrint('ChartCacheService: 모든 캐시 데이터 삭제 완료');
    } catch (e) {
      debugPrint('ChartCacheService: 캐시 삭제 오류 - $e');
    }
  }

  /// 캐시 크기 계산 (바이트)
  Future<int> getCacheSize() async {
    await _ensureInitialized();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDir.path}/hive';

      int totalSize = 0;
      final directory = Directory(hivePath);

      if (await directory.exists()) {
        await for (final file in directory.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('ChartCacheService: 캐시 크기 계산 오류 - $e');
      return 0;
    }
  }

  /// 캐시 폴더 정리 (오류 발생 시)
  Future<void> _clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDir.path}/hive';

      final directory = Directory(hivePath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        debugPrint('ChartCacheService: 캐시 폴더 정리 완료');
      }
    } catch (e) {
      debugPrint('ChartCacheService: 캐시 폴더 정리 오류 - $e');
    }
  }

  /// 초기화 확인 및 필요시 초기화
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
