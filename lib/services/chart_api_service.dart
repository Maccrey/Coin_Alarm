import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../model/chart_data_model.dart';
import '../services/settings_service.dart';
import '../services/chart_cache_service.dart';

/// 차트 데이터 API 서비스 인터페이스
abstract class ChartApiService {
  /// 캔들스틱 차트 데이터 가져오기
  Future<CandleChartData?> getCandleData(
    String symbol,
    ChartTimeframe timeframe,
  );

  /// 라인 차트 데이터 가져오기
  Future<ChartData?> getLineData(String symbol, ChartTimeframe timeframe);

  /// API 서비스 이름
  String get exchangeName;

  /// API 설정 여부
  bool get isConfigured;

  /// 오프라인 모드 설정
  set offlineMode(bool value);

  /// 현재 오프라인 모드 상태
  bool get offlineMode;

  /// 네트워크 연결 상태 확인
  Future<bool> checkConnectivity();
}

/// 업비트 차트 API 서비스
class UpbitChartApiService implements ChartApiService {
  final Dio _dio = Dio();
  final SettingsService _settingsService = SettingsService();
  final ChartCacheService _cacheService = ChartCacheService();
  final InternetConnectionChecker _connectionChecker =
      InternetConnectionChecker.createInstance();

  static const String _baseUrl = 'https://api.upbit.com/v1';

  // 오프라인 모드 상태
  bool _offlineMode = false;

  @override
  String get exchangeName => '업비트';

  @override
  bool get isConfigured {
    final accessKey = _settingsService.getUpbitAccessKey();
    final secretKey = _settingsService.getUpbitSecretKey();
    return accessKey != null &&
        accessKey.isNotEmpty &&
        secretKey != null &&
        secretKey.isNotEmpty;
  }

  @override
  set offlineMode(bool value) {
    _offlineMode = value;
    debugPrint('UpbitChartApiService: 오프라인 모드 ${value ? "활성화" : "비활성화"}');
  }

  @override
  bool get offlineMode => _offlineMode;

  @override
  Future<bool> checkConnectivity() async {
    try {
      final hasConnection = await _connectionChecker.hasConnection;
      debugPrint(
        'UpbitChartApiService: 네트워크 연결 상태 - ${hasConnection ? "연결됨" : "연결 안됨"}',
      );
      return hasConnection;
    } catch (e) {
      debugPrint('UpbitChartApiService: 연결 상태 확인 오류 - $e');
      return false;
    }
  }

  /// 업비트 API 요청에 필요한 JWT 토큰 생성
  String _generateToken(String queryString) {
    final accessKey = _settingsService.getUpbitAccessKey();
    final secretKey = _settingsService.getUpbitSecretKey();

    debugPrint(
      'UpbitChartApiService: 토큰 생성 시도 - accessKey: ${accessKey?.substring(0, 4)}..., secretKey 있음: ${secretKey != null}',
    );

    if (accessKey == null || secretKey == null) {
      throw Exception('업비트 API 키가 설정되지 않았습니다.');
    }

    final uuid = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // 페이로드 생성
    final payload = {
      'access_key': accessKey,
      'nonce': uuid,
      'query_string': queryString,
      'timestamp': timestamp,
    };

    // 시크릿 키로 서명 생성
    final secretKeyBytes = utf8.encode(secretKey);
    final message = utf8.encode(
      queryString.isEmpty
          ? 'GET\n/v1/accounts\n$timestamp\n$uuid'
          : 'GET\n/v1/candles\n$timestamp\n$uuid\n$queryString',
    );

    final hmacSha512 = Hmac(sha512, secretKeyBytes);
    final signature = hmacSha512.convert(message).bytes;

    // JWT 토큰 생성
    final jwtToken = jsonEncode({'typ': 'JWT', 'alg': 'HS512'});

    // Base64 인코딩
    final jwtHeader = base64Url.encode(utf8.encode(jwtToken));
    final jwtPayload = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final jwtSignature = base64Url.encode(signature);

    final token = '$jwtHeader.$jwtPayload.$jwtSignature';
    debugPrint('UpbitChartApiService: 토큰 생성 완료 - 토큰 길이: ${token.length}');

    return token;
  }

  /// 업비트 시간 프레임을 API 파라미터로 변환
  String _getUpbitTimeframeParam(ChartTimeframe timeframe) {
    switch (timeframe) {
      case ChartTimeframe.minutes1:
        return 'minutes/1';
      case ChartTimeframe.minutes3:
        return 'minutes/3';
      case ChartTimeframe.minutes5:
        return 'minutes/5';
      case ChartTimeframe.minutes10:
        return 'minutes/10';
      case ChartTimeframe.minutes15:
        return 'minutes/15';
      case ChartTimeframe.minutes30:
        return 'minutes/30';
      case ChartTimeframe.minutes60:
        return 'minutes/60';
      case ChartTimeframe.minutes240:
        return 'minutes/240';
      case ChartTimeframe.days1:
        return 'days';
      case ChartTimeframe.days7:
        return 'weeks';
      case ChartTimeframe.days30:
        return 'months';
    }
  }

  /// 캔들스틱 데이터 요청 개수 결정 (시간 프레임별 최적화)
  int _getCandleCount(ChartTimeframe timeframe) {
    // 모든 시간 프레임에 대해 30개로 제한
    return 30;
  }

  // 타임스탬프가 현재 시간과 일치하는지 확인하고 필요한 경우 수정
  List<CandleData> _adjustTimestamps(
    List<CandleData> candles,
    ChartTimeframe timeframe,
  ) {
    if (candles.isEmpty) return candles;

    // 현재 시간과 가장 최근 캔들 시간 차이가 지나치게 크면 시간 조정
    final now = DateTime.now();

    // 수정된 캔들 목록
    final List<CandleData> adjustedCandles = [];

    // 마지막 캔들과 현재 시간의 시간 차이 계산
    final timeDifference = now.difference(candles.last.timestamp).inMinutes;

    // 시간 차이가 너무 크거나 15분, 1시간, 4시간 차트인 경우 항상 시간 조정
    final needsAdjustment =
        timeDifference > 30 ||
        timeframe == ChartTimeframe.minutes15 ||
        timeframe == ChartTimeframe.minutes60 ||
        timeframe == ChartTimeframe.minutes240;

    if (needsAdjustment) {
      debugPrint(
        'UpbitChartApiService: 타임스탬프 조정 중 - 시간 차이: $timeDifference분, 타임프레임: ${timeframe.name}',
      );

      // 타임프레임에 따른 간격 계산
      Duration interval;
      switch (timeframe) {
        case ChartTimeframe.minutes1:
          interval = const Duration(minutes: 1);
          break;
        case ChartTimeframe.minutes3:
          interval = const Duration(minutes: 3);
          break;
        case ChartTimeframe.minutes5:
          interval = const Duration(minutes: 5);
          break;
        case ChartTimeframe.minutes10:
          interval = const Duration(minutes: 10);
          break;
        case ChartTimeframe.minutes15:
          interval = const Duration(minutes: 15);
          break;
        case ChartTimeframe.minutes30:
          interval = const Duration(minutes: 30);
          break;
        case ChartTimeframe.minutes60:
          interval = const Duration(hours: 1);
          break;
        case ChartTimeframe.minutes240:
          interval = const Duration(hours: 4);
          break;
        case ChartTimeframe.days1:
          interval = const Duration(days: 1);
          break;
        case ChartTimeframe.days7:
          interval = const Duration(days: 7);
          break;
        case ChartTimeframe.days30:
          interval = const Duration(days: 30);
          break;
      }

      // 현재 시간에서 간격 * 개수만큼 빼서 시작 시간 계산
      DateTime startTime = now.subtract(interval * (candles.length - 1));

      // 시간 프레임에 맞게 시간 정렬
      switch (timeframe) {
        case ChartTimeframe.minutes15:
          // 15분 단위로 맞추기 (0, 15, 30, 45분)
          final minute = (startTime.minute ~/ 15) * 15;
          startTime = DateTime(
            startTime.year,
            startTime.month,
            startTime.day,
            startTime.hour,
            minute,
          );
          break;
        case ChartTimeframe.minutes60:
          // 정시에 맞추기
          startTime = DateTime(
            startTime.year,
            startTime.month,
            startTime.day,
            startTime.hour,
          );
          break;
        case ChartTimeframe.minutes240:
          // 4시간 단위로 맞추기 (0, 4, 8, 12, 16, 20시)
          final hour = (startTime.hour ~/ 4) * 4;
          startTime = DateTime(
            startTime.year,
            startTime.month,
            startTime.day,
            hour,
          );
          break;
        default:
          // 다른 타임프레임은 그대로 유지
          break;
      }

      // 각 캔들에 새 타임스탬프 할당
      for (int i = 0; i < candles.length; i++) {
        final candle = candles[i];
        final newTimestamp = startTime.add(interval * i);

        adjustedCandles.add(
          CandleData(
            timestamp: newTimestamp,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume,
          ),
        );
      }

      return adjustedCandles;
    }

    return candles;
  }

  @override
  Future<CandleChartData?> getCandleData(
    String symbol,
    ChartTimeframe timeframe,
  ) async {
    debugPrint('UpbitChartApiService: 캔들 데이터 요청 - $symbol (${timeframe.name})');

    try {
      // 1. 캐시 확인
      final cachedData = _cacheService.getCandleChartData(symbol, timeframe);

      // 2. 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터 반환
      final isConnected = await checkConnectivity();
      if (_offlineMode || !isConnected) {
        debugPrint('UpbitChartApiService: 오프라인 모드 또는 네트워크 연결 없음, 캐시 데이터 사용');
        if (cachedData != null) {
          return cachedData;
        } else {
          debugPrint('UpbitChartApiService: 오프라인 상태에서 캐시 데이터 없음');
          return null;
        }
      }

      // 3. 캐시가 유효한 경우 캐시 데이터 반환
      if (cachedData != null && !cachedData.isExpired()) {
        debugPrint(
          'UpbitChartApiService: 캐시된 캔들 데이터 사용 - $symbol (${timeframe.name})',
        );
        return cachedData;
      }

      // 4. API 요청
      final market = 'KRW-${symbol.toUpperCase()}';
      final timeframeParam = _getUpbitTimeframeParam(timeframe);
      final count = _getCandleCount(timeframe);

      final queryString = 'market=$market&count=$count';
      final token = _generateToken(queryString);

      final response = await _dio.get(
        '$_baseUrl/candles/$timeframeParam',
        queryParameters: {'market': market, 'count': count},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        debugPrint('UpbitChartApiService: API 응답 오류 - ${response.statusCode}');
        // 오류 발생 시 캐시된 데이터가 있으면 반환
        if (cachedData != null) {
          debugPrint('UpbitChartApiService: API 오류 발생, 만료된 캐시 데이터 사용');
          return cachedData;
        }
        return null;
      }

      // 5. 응답 데이터 처리
      final List<dynamic> candlesJson = response.data;
      final List<CandleData> candles = [];

      for (final candleJson in candlesJson) {
        candles.add(
          CandleData(
            timestamp: DateTime.parse(candleJson['candle_date_time_utc'] + 'Z'),
            open: (candleJson['opening_price'] is int)
                ? (candleJson['opening_price'] as int).toDouble()
                : candleJson['opening_price'] as double,
            high: (candleJson['high_price'] is int)
                ? (candleJson['high_price'] as int).toDouble()
                : candleJson['high_price'] as double,
            low: (candleJson['low_price'] is int)
                ? (candleJson['low_price'] as int).toDouble()
                : candleJson['low_price'] as double,
            close: (candleJson['trade_price'] is int)
                ? (candleJson['trade_price'] as int).toDouble()
                : candleJson['trade_price'] as double,
            volume: (candleJson['candle_acc_trade_volume'] is int)
                ? (candleJson['candle_acc_trade_volume'] as int).toDouble()
                : candleJson['candle_acc_trade_volume'] as double,
          ),
        );
      }

      // 6. 데이터 정렬 (시간 오름차순)
      candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 타임스탬프 조정
      final adjustedCandles = _adjustTimestamps(candles, timeframe);

      // 7. 캐시 저장 및 반환
      final chartData = CandleChartData(
        symbol: symbol,
        timeframe: timeframe,
        candles: adjustedCandles,
        lastUpdated: DateTime.now(),
      );

      await _cacheService.saveCandleChartData(chartData);
      debugPrint(
        'UpbitChartApiService: 캔들 데이터 저장 완료 - $symbol (${adjustedCandles.length}개)',
      );

      return chartData;
    } catch (e) {
      debugPrint('UpbitChartApiService: 캔들 데이터 요청 오류 - $e');

      // 오류 발생 시 캐시된 데이터가 있으면 반환
      final cachedData = _cacheService.getCandleChartData(symbol, timeframe);
      if (cachedData != null) {
        debugPrint('UpbitChartApiService: 오류 발생, 캐시 데이터 사용');
        return cachedData;
      }

      return null;
    }
  }

  @override
  Future<ChartData?> getLineData(
    String symbol,
    ChartTimeframe timeframe,
  ) async {
    debugPrint(
      'UpbitChartApiService: 라인 차트 데이터 요청 - $symbol (${timeframe.name})',
    );

    try {
      // 1. 캐시 확인
      final cachedData = _cacheService.getLineChartData(symbol, timeframe);

      // 2. 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터 반환
      final isConnected = await checkConnectivity();
      if (_offlineMode || !isConnected) {
        debugPrint('UpbitChartApiService: 오프라인 모드 또는 네트워크 연결 없음, 캐시 데이터 사용');
        if (cachedData != null) {
          return cachedData;
        } else {
          debugPrint('UpbitChartApiService: 오프라인 상태에서 캐시 데이터 없음');
          return null;
        }
      }

      // 3. 캐시가 유효한 경우 캐시 데이터 반환
      if (cachedData != null && !cachedData.isExpired()) {
        debugPrint(
          'UpbitChartApiService: 캐시된 라인 차트 데이터 사용 - $symbol (${timeframe.name})',
        );
        return cachedData;
      }

      // 4. 캔들 데이터 가져오기 (API 요청은 캔들 데이터로 통일)
      final candleData = await getCandleData(symbol, timeframe);
      if (candleData == null) {
        // 오류 발생 시 캐시된 데이터가 있으면 반환
        if (cachedData != null) {
          debugPrint('UpbitChartApiService: 캔들 데이터 오류, 만료된 캐시 데이터 사용');
          return cachedData;
        }
        return null;
      }

      // 5. 캔들 데이터를 라인 차트 데이터로 변환
      final List<ChartPoint> points = candleData.candles.map((candle) {
        return ChartPoint(timestamp: candle.timestamp, price: candle.close);
      }).toList();

      // 6. 캐시 저장 및 반환
      final chartData = ChartData(
        symbol: symbol,
        timeframe: timeframe,
        points: points,
        lastUpdated: DateTime.now(),
        type: ChartType.line,
      );

      await _cacheService.saveLineChartData(chartData);
      debugPrint(
        'UpbitChartApiService: 라인 차트 데이터 저장 완료 - $symbol (${points.length}개)',
      );

      return chartData;
    } catch (e) {
      debugPrint('UpbitChartApiService: 라인 차트 데이터 요청 오류 - $e');

      // 오류 발생 시 캐시된 데이터가 있으면 반환
      final cachedData = _cacheService.getLineChartData(symbol, timeframe);
      if (cachedData != null) {
        debugPrint('UpbitChartApiService: 오류 발생, 캐시 데이터 사용');
        return cachedData;
      }

      return null;
    }
  }
}

/// 차트 API 서비스 팩토리
class ChartApiServiceFactory {
  final SettingsService _settingsService = SettingsService();

  /// 사용 가능한 차트 API 서비스 가져오기
  ChartApiService? getPreferredService() {
    final upbitService = UpbitChartApiService();

    if (upbitService.isConfigured) {
      debugPrint('ChartApiServiceFactory: 업비트 차트 서비스 사용');
      return upbitService;
    }

    debugPrint('ChartApiServiceFactory: 사용 가능한 차트 API 서비스가 없습니다.');
    return null;
  }
}
