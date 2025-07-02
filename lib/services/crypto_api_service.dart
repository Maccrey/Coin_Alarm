import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../model/coin_model.dart';
import 'settings_service.dart';

// 암호화폐 API 서비스 인터페이스
abstract class CryptoApiService {
  Future<List<Coin>> getTopCoins({int limit = 10});
  Future<Coin?> getCoinBySymbol(String symbol);
  String get exchangeName;
  bool get isConfigured;
}

// 업비트 API 서비스
class UpbitApiService implements CryptoApiService {
  final Dio _dio = Dio();
  final SettingsService _settingsService = SettingsService();
  static const String _baseUrl = 'https://api.upbit.com/v1';

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

  // 업비트 API 요청에 필요한 JWT 토큰 생성
  String _generateToken(String queryString) {
    final accessKey = _settingsService.getUpbitAccessKey();
    final secretKey = _settingsService.getUpbitSecretKey();

    debugPrint(
      'UpbitApiService: 토큰 생성 시도 - accessKey: ${accessKey?.substring(0, 4)}..., secretKey 있음: ${secretKey != null}',
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

    debugPrint(
      'UpbitApiService: 페이로드 생성 완료 - nonce: $uuid, timestamp: $timestamp',
    );

    // 시크릿 키로 서명 생성
    final secretKeyBytes = utf8.encode(secretKey);
    final message = utf8.encode(
      queryString.isEmpty
          ? 'GET\n/v1/accounts\n$timestamp\n$uuid'
          : 'GET\n/v1/market/ticker\n$timestamp\n$uuid\n$queryString',
    );

    debugPrint(
      'UpbitApiService: 서명 메시지 생성 - ${queryString.isEmpty ? 'accounts 요청' : 'ticker 요청'}',
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
    debugPrint('UpbitApiService: 토큰 생성 완료 - 토큰 길이: ${token.length}');

    return token;
  }

  @override
  Future<List<Coin>> getTopCoins({int limit = 10}) async {
    debugPrint('UpbitApiService: getTopCoins 호출 (limit: $limit)');
    try {
      debugPrint('UpbitApiService: API 키 확인');
      final accessKey = _settingsService.getUpbitAccessKey();
      final secretKey = _settingsService.getUpbitSecretKey();
      debugPrint(
        'UpbitApiService: API 키 존재 여부 - Access: ${accessKey != null}, Secret: ${secretKey != null}',
      );

      // 마켓 코드 목록 가져오기
      debugPrint('UpbitApiService: 마켓 목록 요청 중...');
      final marketResponse = await _dio.get(
        '$_baseUrl/market/all',
        queryParameters: {'isDetails': 'false'},
      );

      if (marketResponse.statusCode != 200) {
        throw Exception('업비트 마켓 목록 조회 실패: ${marketResponse.statusCode}');
      }

      debugPrint(
        'UpbitApiService: 마켓 목록 응답 성공, ${(marketResponse.data as List).length}개 마켓 수신',
      );

      // KRW 마켓 코드만 필터링
      final krwMarkets = (marketResponse.data as List)
          .where((market) => (market['market'] as String).startsWith('KRW-'))
          .map((market) => market['market'] as String)
          .toList();

      debugPrint('UpbitApiService: KRW 마켓 필터링 결과 - ${krwMarkets.length}개 마켓');

      // 업비트 API는 한 번에 최대 100개 마켓 지원 (API 제한)
      // 따라서 여러 번 호출하여 모든 코인 데이터를 가져옴
      final List<Coin> allCoins = [];

      // 100개씩 나누어 API 호출
      for (int i = 0; i < krwMarkets.length; i += 100) {
        final int endIdx = (i + 100 < krwMarkets.length)
            ? i + 100
            : krwMarkets.length;
        final List<String> marketsBatch = krwMarkets.sublist(i, endIdx);

        debugPrint(
          'UpbitApiService: ${i + 1}~${endIdx}번째 마켓 데이터 요청 (${marketsBatch.length}개)',
        );

        final marketsToFetch = marketsBatch.join(',');
        final queryString = 'markets=$marketsToFetch';

        // 토큰 생성
        debugPrint('UpbitApiService: JWT 토큰 생성 중...');
        final token = _generateToken(queryString);
        debugPrint('UpbitApiService: JWT 토큰 생성 완료');

        // 시세 정보 가져오기
        debugPrint('UpbitApiService: 시세 정보 요청 중...');
        final tickerResponse = await _dio.get(
          '$_baseUrl/ticker',
          queryParameters: {'markets': marketsToFetch},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (tickerResponse.statusCode != 200) {
          debugPrint(
            'UpbitApiService: API 응답 오류 - 상태 코드: ${tickerResponse.statusCode}',
          );
          continue; // 오류 발생시 다음 배치로 진행
        }

        debugPrint(
          'UpbitApiService: 시세 정보 응답 성공, ${(tickerResponse.data as List).length}개 코인 데이터 수신',
        );

        // 코인 모델 변환
        for (final ticker in tickerResponse.data) {
          final marketCode = ticker['market'] as String; // KRW-BTC
          final symbol = marketCode.split('-')[1]; // BTC
          final name = _getCoinName(symbol);

          allCoins.add(
            Coin(
              id: symbol.toLowerCase(),
              name: name,
              symbol: symbol,
              currentPrice: (ticker['trade_price'] is int)
                  ? (ticker['trade_price'] as int).toDouble()
                  : ticker['trade_price'] as double,
              priceChange24h: (ticker['signed_change_price'] is int)
                  ? (ticker['signed_change_price'] as int).toDouble()
                  : ticker['signed_change_price'] as double,
              priceChangePercentage24h: (ticker['signed_change_rate'] is int)
                  ? (ticker['signed_change_rate'] as int) * 100.0
                  : ticker['signed_change_rate'] * 100 as double,
              marketCap: (ticker['acc_trade_price_24h'] is int)
                  ? (ticker['acc_trade_price_24h'] as int).toDouble()
                  : ticker['acc_trade_price_24h'] as double,
              volume24h: (ticker['acc_trade_volume_24h'] is int)
                  ? (ticker['acc_trade_volume_24h'] as int).toDouble()
                  : ticker['acc_trade_volume_24h'] as double,
              high24h: (ticker['high_price'] is int)
                  ? (ticker['high_price'] as int).toDouble()
                  : ticker['high_price'] as double,
              low24h: (ticker['low_price'] is int)
                  ? (ticker['low_price'] as int).toDouble()
                  : ticker['low_price'] as double,
              lastUpdated: DateTime.fromMillisecondsSinceEpoch(
                ticker['timestamp'],
              ),
              imageUrl: 'https://static.upbit.com/logos/$symbol.png',
            ),
          );
        }

        // API 호출 간격 조절 (업비트 API 제한 고려)
        if (i + 100 < krwMarkets.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 거래량 기준 정렬
      allCoins.sort((a, b) => (b.volume24h ?? 0).compareTo(a.volume24h ?? 0));

      // limit이 0이면 모든 코인 반환, 아니면 limit 수만큼 반환
      final result = limit > 0 ? allCoins.take(limit).toList() : allCoins;
      debugPrint('UpbitApiService: 최종 반환 데이터 - ${result.length}개 코인');

      return result;
    } catch (e) {
      debugPrint('UpbitApiService: API 오류 발생!');
      debugPrint('UpbitApiService 오류 상세: $e');
      if (e is DioException) {
        debugPrint('UpbitApiService Dio 오류: ${e.message}');
        debugPrint('UpbitApiService Dio 응답: ${e.response?.data}');
      }
      return [];
    }
  }

  @override
  Future<Coin?> getCoinBySymbol(String symbol) async {
    try {
      final marketCode = 'KRW-${symbol.toUpperCase()}';
      final queryString = 'markets=$marketCode';

      // 토큰 생성
      final token = _generateToken(queryString);

      final response = await _dio.get(
        '$_baseUrl/ticker',
        queryParameters: {'markets': marketCode},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 || (response.data as List).isEmpty) {
        return null;
      }

      final ticker = response.data[0];
      final name = _getCoinName(symbol);

      return Coin(
        id: symbol.toLowerCase(),
        name: name,
        symbol: symbol.toUpperCase(),
        currentPrice: (ticker['trade_price'] is int)
            ? (ticker['trade_price'] as int).toDouble()
            : ticker['trade_price'] as double,
        priceChange24h: (ticker['signed_change_price'] is int)
            ? (ticker['signed_change_price'] as int).toDouble()
            : ticker['signed_change_price'] as double,
        priceChangePercentage24h: (ticker['signed_change_rate'] is int)
            ? (ticker['signed_change_rate'] as int) * 100.0
            : ticker['signed_change_rate'] * 100 as double,
        marketCap: (ticker['acc_trade_price_24h'] is int)
            ? (ticker['acc_trade_price_24h'] as int).toDouble()
            : ticker['acc_trade_price_24h'] as double,
        volume24h: (ticker['acc_trade_volume_24h'] is int)
            ? (ticker['acc_trade_volume_24h'] as int).toDouble()
            : ticker['acc_trade_volume_24h'] as double,
        high24h: (ticker['high_price'] is int)
            ? (ticker['high_price'] as int).toDouble()
            : ticker['high_price'] as double,
        low24h: (ticker['low_price'] is int)
            ? (ticker['low_price'] as int).toDouble()
            : ticker['low_price'] as double,
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(ticker['timestamp']),
        imageUrl: 'https://static.upbit.com/logos/${symbol.toUpperCase()}.png',
      );
    } catch (e) {
      debugPrint('업비트 API 오류: $e');
      return null;
    }
  }

  // 심볼로 코인 이름 추정 (업비트는 마켓 정보에 코인 이름이 없음)
  String _getCoinName(String symbol) {
    final Map<String, String> nameMap = {
      'BTC': '비트코인',
      'ETH': '이더리움',
      'XRP': '리플',
      'DOGE': '도지코인',
      'SOL': '솔라나',
      'ADA': '에이다',
      'DOT': '폴카닷',
      'AVAX': '아발란체',
      'MATIC': '폴리곤',
      'LINK': '체인링크',
    };

    return nameMap[symbol] ?? symbol;
  }
}

// 바이낸스 API 서비스
class BinanceApiService implements CryptoApiService {
  final Dio _dio = Dio();
  final SettingsService _settingsService = SettingsService();
  static const String _baseUrl = 'https://api.binance.com/api/v3';

  @override
  String get exchangeName => '바이낸스';

  @override
  bool get isConfigured {
    final apiKey = _settingsService.getBinanceApiKey();
    final secretKey = _settingsService.getBinanceSecretKey();
    return apiKey != null &&
        apiKey.isNotEmpty &&
        secretKey != null &&
        secretKey.isNotEmpty;
  }

  // 바이낸스 API 요청에 필요한 서명 생성
  Map<String, dynamic> _createSignedParams(Map<String, dynamic> params) {
    final apiKey = _settingsService.getBinanceApiKey();
    final secretKey = _settingsService.getBinanceSecretKey();

    if (apiKey == null || secretKey == null) {
      throw Exception('바이낸스 API 키가 설정되지 않았습니다.');
    }

    // 타임스탬프 추가
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

    // 쿼리 문자열 생성
    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    // HMAC-SHA256 서명 생성
    final secretKeyBytes = utf8.encode(secretKey);
    final message = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, secretKeyBytes);
    final signature = hmacSha256.convert(message).toString();

    // 서명 추가
    params['signature'] = signature;

    return params;
  }

  @override
  Future<List<Coin>> getTopCoins({int limit = 10}) async {
    try {
      // 24시간 티커 정보 가져오기
      final response = await _dio.get('$_baseUrl/ticker/24hr');

      if (response.statusCode != 200) {
        throw Exception('바이낸스 티커 정보 조회 실패: ${response.statusCode}');
      }

      // USDT 마켓 필터링
      final usdtMarkets = (response.data as List)
          .where(
            (ticker) =>
                (ticker['symbol'] as String).endsWith('USDT') &&
                !(ticker['symbol'] as String).contains('UPUSDT'),
          )
          .toList();

      // 거래량 기준 정렬
      usdtMarkets.sort(
        (a, b) => double.parse(
          b['quoteVolume'].toString(),
        ).compareTo(double.parse(a['quoteVolume'].toString())),
      );

      // 코인 모델 변환
      final List<Coin> coins = [];
      for (final ticker in usdtMarkets.take(limit)) {
        final symbol = (ticker['symbol'] as String).replaceAll('USDT', '');
        final name = _getCoinName(symbol);

        coins.add(
          Coin(
            id: symbol.toLowerCase(),
            name: name,
            symbol: symbol,
            currentPrice: double.parse(ticker['lastPrice']),
            priceChange24h: double.parse(ticker['priceChange']),
            priceChangePercentage24h: double.parse(
              ticker['priceChangePercent'],
            ),
            marketCap: null, // 바이낸스 API에서는 제공하지 않음
            volume24h: double.parse(ticker['quoteVolume']),
            high24h: double.parse(ticker['highPrice']),
            low24h: double.parse(ticker['lowPrice']),
            lastUpdated: DateTime.now(),
            imageUrl:
                'https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-380c-43c9-8170-19fbe963b7c1.png', // 바이낸스 코인 이미지는 별도 API 필요
          ),
        );
      }

      return coins;
    } catch (e) {
      debugPrint('바이낸스 API 오류: $e');
      return [];
    }
  }

  @override
  Future<Coin?> getCoinBySymbol(String symbol) async {
    try {
      final marketSymbol = '${symbol.toUpperCase()}USDT';

      // 24시간 티커 정보 가져오기
      final response = await _dio.get(
        '$_baseUrl/ticker/24hr',
        queryParameters: {'symbol': marketSymbol},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final ticker = response.data;
      final name = _getCoinName(symbol);

      return Coin(
        id: symbol.toLowerCase(),
        name: name,
        symbol: symbol.toUpperCase(),
        currentPrice: double.parse(ticker['lastPrice']),
        priceChange24h: double.parse(ticker['priceChange']),
        priceChangePercentage24h: double.parse(ticker['priceChangePercent']),
        marketCap: null,
        volume24h: double.parse(ticker['quoteVolume']),
        high24h: double.parse(ticker['highPrice']),
        low24h: double.parse(ticker['lowPrice']),
        lastUpdated: DateTime.now(),
        imageUrl:
            'https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-380c-43c9-8170-19fbe963b7c1.png',
      );
    } catch (e) {
      debugPrint('바이낸스 API 오류: $e');
      return null;
    }
  }

  // 심볼로 코인 이름 추정
  String _getCoinName(String symbol) {
    final Map<String, String> nameMap = {
      'BTC': '비트코인',
      'ETH': '이더리움',
      'XRP': '리플',
      'DOGE': '도지코인',
      'SOL': '솔라나',
      'ADA': '에이다',
      'DOT': '폴카닷',
      'AVAX': '아발란체',
      'MATIC': '폴리곤',
      'LINK': '체인링크',
    };

    return nameMap[symbol] ?? symbol;
  }
}

// CoinGecko API 서비스 (API 키 없이 사용 가능)
class CoinGeckoApiService implements CryptoApiService {
  final Dio _dio = Dio();
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';

  // 속도 제한 관련 변수
  static DateTime _lastRequestTime = DateTime.now().subtract(
    const Duration(seconds: 30),
  );
  static const Duration _minRequestInterval = Duration(
    seconds: 10,
  ); // 최소 10초 간격으로 요청
  static int _consecutiveFailures = 0;
  static const int _maxRetries = 3;

  @override
  String get exchangeName => 'CoinGecko';

  @override
  bool get isConfigured => true; // API 키가 필요 없으므로 항상 구성됨

  // 요청 간격 제어 메서드
  Future<void> _throttleRequest() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);

    // 마지막 요청 이후 최소 간격이 지나지 않았다면 대기
    if (timeSinceLastRequest < _minRequestInterval) {
      final waitTime = _minRequestInterval - timeSinceLastRequest;
      debugPrint(
        'CoinGeckoApiService: 속도 제한 - ${waitTime.inMilliseconds}ms 대기',
      );
      await Future.delayed(waitTime);
    }

    // 연속 실패 횟수에 따라 추가 대기 시간 설정
    if (_consecutiveFailures > 0) {
      final backoffTime = Duration(
        seconds: pow(2, _consecutiveFailures).toInt(),
      );
      debugPrint(
        'CoinGeckoApiService: 연속 실패 $_consecutiveFailures회 - ${backoffTime.inSeconds}초 추가 대기',
      );
      await Future.delayed(backoffTime);
    }

    _lastRequestTime = DateTime.now();
  }

  @override
  Future<List<Coin>> getTopCoins({int limit = 10}) async {
    debugPrint('CoinGeckoApiService: getTopCoins 호출 (limit: $limit)');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // 요청 간격 제어
        if (attempt > 0) {
          debugPrint('CoinGeckoApiService: 재시도 $attempt/$_maxRetries');
        }
        await _throttleRequest();

        // 시장 데이터 가져오기 (원화 기준)
        final response = await _dio.get(
          '$_baseUrl/coins/markets',
          queryParameters: {
            'vs_currency': 'krw',
            'order': 'market_cap_desc',
            'per_page': limit > 0 ? limit : 100,
            'page': 1,
            'sparkline': false,
            'price_change_percentage': '24h',
          },
        );

        if (response.statusCode != 200) {
          throw Exception('CoinGecko API 응답 오류: ${response.statusCode}');
        }

        debugPrint(
          'CoinGeckoApiService: API 응답 성공, ${(response.data as List).length}개 코인 데이터 수신',
        );

        // 연속 실패 카운터 초기화
        _consecutiveFailures = 0;

        // 코인 모델 변환
        final List<Coin> coins = [];
        for (final data in response.data) {
          coins.add(
            Coin(
              id: data['id'],
              name: _getKoreanName(data['id'], data['name']),
              symbol: data['symbol'].toUpperCase(),
              currentPrice: data['current_price'].toDouble(),
              priceChange24h: data['price_change_24h']?.toDouble(),
              priceChangePercentage24h: data['price_change_percentage_24h']
                  ?.toDouble(),
              marketCap: data['market_cap']?.toDouble(),
              volume24h: data['total_volume']?.toDouble(),
              high24h: data['high_24h']?.toDouble(),
              low24h: data['low_24h']?.toDouble(),
              lastUpdated: DateTime.parse(data['last_updated']),
              imageUrl: data['image'],
            ),
          );
        }

        debugPrint('CoinGeckoApiService: ${coins.length}개 코인 데이터 변환 완료');
        return coins;
      } catch (e) {
        debugPrint('CoinGeckoApiService: API 오류 발생!');
        debugPrint('CoinGeckoApiService 오류 상세: $e');

        if (e is DioException) {
          debugPrint('CoinGeckoApiService Dio 오류: ${e.message}');
          debugPrint('CoinGeckoApiService Dio 응답: ${e.response?.data}');

          // 속도 제한(429) 오류인 경우 연속 실패 카운터 증가
          if (e.response?.statusCode == 429) {
            _consecutiveFailures++;
            if (attempt < _maxRetries) {
              continue; // 재시도
            }
          }
        }

        // 모든 재시도 실패 또는 다른 오류인 경우 빈 목록 반환
        debugPrint('CoinGeckoApiService: API 호출 실패, 빈 목록 반환');
        return [];
      }
    }

    // 이 코드는 실행되지 않지만 컴파일러 오류를 방지하기 위해 필요
    throw Exception('예상치 못한 오류');
  }

  @override
  Future<Coin?> getCoinBySymbol(String symbol) async {
    try {
      debugPrint('CoinGeckoApiService: getCoinBySymbol 호출 - $symbol');

      // 요청 간격 제어
      await _throttleRequest();

      // 심볼로 코인 ID 찾기
      final idResponse = await _dio.get('$_baseUrl/coins/list');

      if (idResponse.statusCode != 200) {
        throw Exception('CoinGecko API 응답 오류: ${idResponse.statusCode}');
      }

      final coinData = (idResponse.data as List).firstWhere(
        (coin) =>
            coin['symbol'].toString().toLowerCase() == symbol.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (coinData.isEmpty) {
        debugPrint('CoinGeckoApiService: 해당 심볼의 코인을 찾을 수 없음 - $symbol');
        return null;
      }

      final coinId = coinData['id'];

      // 요청 간격 제어 (두 번째 요청을 위해)
      await _throttleRequest();

      // 코인 상세 정보 가져오기
      final response = await _dio.get(
        '$_baseUrl/coins/$coinId',
        queryParameters: {
          'localization': false,
          'tickers': false,
          'market_data': true,
          'community_data': false,
          'developer_data': false,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('CoinGecko API 응답 오류: ${response.statusCode}');
      }

      // 연속 실패 카운터 초기화
      _consecutiveFailures = 0;

      final data = response.data;
      final marketData = data['market_data'];

      return Coin(
        id: data['id'],
        name: _getKoreanName(data['id'], data['name']),
        symbol: data['symbol'].toUpperCase(),
        currentPrice: marketData['current_price']['krw'].toDouble(),
        priceChange24h: marketData['price_change_24h_in_currency']['krw']
            ?.toDouble(),
        priceChangePercentage24h: marketData['price_change_percentage_24h']
            ?.toDouble(),
        marketCap: marketData['market_cap']['krw']?.toDouble(),
        volume24h: marketData['total_volume']['krw']?.toDouble(),
        high24h: marketData['high_24h']['krw']?.toDouble(),
        low24h: marketData['low_24h']['krw']?.toDouble(),
        lastUpdated: DateTime.parse(data['last_updated']),
        imageUrl: data['image']['large'],
      );
    } catch (e) {
      debugPrint('CoinGeckoApiService: API 오류 발생!');
      debugPrint('CoinGeckoApiService 오류 상세: $e');

      if (e is DioException && e.response?.statusCode == 429) {
        _consecutiveFailures++;
      }

      // API 호출 실패 시 null 반환
      debugPrint('CoinGeckoApiService: API 호출 실패, null 반환');
      return null;
    }
  }

  // 코인 이름을 한국어로 변환
  String _getKoreanName(String id, String name) {
    final Map<String, String> nameMap = {
      'bitcoin': '비트코인',
      'ethereum': '이더리움',
      'ripple': '리플',
      'dogecoin': '도지코인',
      'solana': '솔라나',
      'cardano': '에이다',
      'polkadot': '폴카닷',
      'avalanche-2': '아발란체',
      'polygon': '폴리곤',
      'chainlink': '체인링크',
      'binancecoin': '바이낸스 코인',
      'shiba-inu': '시바이누',
    };

    return nameMap[id] ?? name;
  }
}

// 암호화폐 서비스 팩토리
class CryptoServiceFactory {
  final SettingsService _settingsService = SettingsService();

  // 사용 가능한 서비스 가져오기
  List<CryptoApiService> getAvailableServices() {
    debugPrint('CryptoServiceFactory: 사용 가능한 서비스 확인 중');
    final List<CryptoApiService> services = [];

    final upbitService = UpbitApiService();
    final binanceService = BinanceApiService();
    final coinGeckoService = CoinGeckoApiService(); // CoinGecko 서비스 추가

    debugPrint(
      'CryptoServiceFactory: 업비트 서비스 구성됨: ${upbitService.isConfigured}',
    );
    debugPrint(
      'CryptoServiceFactory: 바이낸스 서비스 구성됨: ${binanceService.isConfigured}',
    );
    debugPrint(
      'CryptoServiceFactory: CoinGecko 서비스 구성됨: ${coinGeckoService.isConfigured}',
    );

    final upbitAccessKey = _settingsService.getUpbitAccessKey();
    final upbitSecretKey = _settingsService.getUpbitSecretKey();
    final binanceApiKey = _settingsService.getBinanceApiKey();
    final binanceSecretKey = _settingsService.getBinanceSecretKey();

    debugPrint(
      'CryptoServiceFactory: 저장된 키 정보 - Upbit A: ${upbitAccessKey?.isNotEmpty}, S: ${upbitSecretKey?.isNotEmpty}, Binance A: ${binanceApiKey?.isNotEmpty}, S: ${binanceSecretKey?.isNotEmpty}',
    );

    if (upbitService.isConfigured) {
      services.add(upbitService);
      debugPrint('CryptoServiceFactory: 업비트 서비스 추가됨');
    }

    if (binanceService.isConfigured) {
      services.add(binanceService);
      debugPrint('CryptoServiceFactory: 바이낸스 서비스 추가됨');
    }

    // API 키가 설정되지 않은 경우 CoinGecko 서비스 추가
    if (services.isEmpty) {
      services.add(coinGeckoService);
      debugPrint('CryptoServiceFactory: API 키가 없어 CoinGecko 서비스 추가됨');
    }

    return services;
  }

  // 기본 서비스 가져오기
  CryptoApiService getDefaultService() {
    debugPrint('CryptoServiceFactory: 기본 서비스 가져오기');
    final services = getAvailableServices();

    if (services.isEmpty) {
      debugPrint('CryptoServiceFactory: 사용 가능한 서비스가 없어 CoinGecko 서비스 반환');
      return CoinGeckoApiService();
    }

    // 우선순위: 업비트 > 바이낸스 > CoinGecko
    for (final service in services) {
      if (service is UpbitApiService) {
        debugPrint('CryptoServiceFactory: 업비트 서비스 반환');
        return service;
      }
    }

    for (final service in services) {
      if (service is BinanceApiService) {
        debugPrint('CryptoServiceFactory: 바이낸스 서비스 반환');
        return service;
      }
    }

    debugPrint('CryptoServiceFactory: ${services.first.exchangeName} 서비스 반환');
    return services.first;
  }
}

// 모의 암호화폐 API 서비스
class MockCryptoApiService implements CryptoApiService {
  @override
  String get exchangeName => '모의 데이터';

  @override
  bool get isConfigured => true; // 항상 구성됨

  @override
  Future<List<Coin>> getTopCoins({int limit = 10}) async {
    debugPrint('MockCryptoApiService: 모의 코인 데이터 생성 (limit: $limit)');

    // 지연 시간 추가 (실제 API 호출처럼 보이게)
    await Future.delayed(const Duration(milliseconds: 500));

    // 원화 환율 적용 (대략 1달러 = 1300원)
    const double krwRate = 1300.0;

    final now = DateTime.now();
    final coins = [
      Coin(
        id: 'bitcoin',
        name: '비트코인',
        symbol: 'BTC',
        currentPrice: (67500.0 + _randomVariation(500)) * krwRate,
        priceChange24h: (1200.0 + _randomVariation(100)) * krwRate,
        priceChangePercentage24h: 1.8 + _randomVariation(0.2),
        marketCap: 1300000000000 * krwRate,
        volume24h: 25000000000 * krwRate,
        high24h: (68000.0 + _randomVariation(200)) * krwRate,
        low24h: (66800.0 + _randomVariation(200)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/1/large/bitcoin.png',
      ),
      Coin(
        id: 'ethereum',
        name: '이더리움',
        symbol: 'ETH',
        currentPrice: (3450.0 + _randomVariation(50)) * krwRate,
        priceChange24h: (120.0 + _randomVariation(20)) * krwRate,
        priceChangePercentage24h: 3.5 + _randomVariation(0.5),
        marketCap: 415000000000 * krwRate,
        volume24h: 18000000000 * krwRate,
        high24h: (3500.0 + _randomVariation(30)) * krwRate,
        low24h: (3400.0 + _randomVariation(30)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
      ),
      Coin(
        id: 'binancecoin',
        name: '바이낸스 코인',
        symbol: 'BNB',
        currentPrice: (570.0 + _randomVariation(10)) * krwRate,
        priceChange24h: (15.0 + _randomVariation(5)) * krwRate,
        priceChangePercentage24h: 2.7 + _randomVariation(0.3),
        marketCap: 87000000000 * krwRate,
        volume24h: 2500000000 * krwRate,
        high24h: (580.0 + _randomVariation(5)) * krwRate,
        low24h: (560.0 + _randomVariation(5)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png',
      ),
      Coin(
        id: 'solana',
        name: '솔라나',
        symbol: 'SOL',
        currentPrice: (142.0 + _randomVariation(5)) * krwRate,
        priceChange24h: (8.0 + _randomVariation(2)) * krwRate,
        priceChangePercentage24h: 6.0 + _randomVariation(1),
        marketCap: 65000000000 * krwRate,
        volume24h: 3200000000 * krwRate,
        high24h: (145.0 + _randomVariation(3)) * krwRate,
        low24h: (135.0 + _randomVariation(3)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/4128/large/solana.png',
      ),
      Coin(
        id: 'ripple',
        name: '리플',
        symbol: 'XRP',
        currentPrice: (0.52 + _randomVariation(0.01)) * krwRate,
        priceChange24h: (0.02 + _randomVariation(0.005)) * krwRate,
        priceChangePercentage24h: 4.0 + _randomVariation(0.5),
        marketCap: 28000000000 * krwRate,
        volume24h: 1500000000 * krwRate,
        high24h: (0.53 + _randomVariation(0.005)) * krwRate,
        low24h: (0.50 + _randomVariation(0.005)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png',
      ),
      Coin(
        id: 'dogecoin',
        name: '도지코인',
        symbol: 'DOGE',
        currentPrice: (0.12 + _randomVariation(0.005)) * krwRate,
        priceChange24h: (0.01 + _randomVariation(0.002)) * krwRate,
        priceChangePercentage24h: 8.5 + _randomVariation(1),
        marketCap: 17000000000 * krwRate,
        volume24h: 1200000000 * krwRate,
        high24h: (0.125 + _randomVariation(0.002)) * krwRate,
        low24h: (0.115 + _randomVariation(0.002)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/5/large/dogecoin.png',
      ),
      Coin(
        id: 'cardano',
        name: '에이다',
        symbol: 'ADA',
        currentPrice: (0.45 + _randomVariation(0.01)) * krwRate,
        priceChange24h: (0.02 + _randomVariation(0.005)) * krwRate,
        priceChangePercentage24h: 4.7 + _randomVariation(0.5),
        marketCap: 16000000000 * krwRate,
        volume24h: 800000000 * krwRate,
        high24h: (0.46 + _randomVariation(0.005)) * krwRate,
        low24h: (0.44 + _randomVariation(0.005)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/975/large/cardano.png',
      ),
      Coin(
        id: 'polkadot',
        name: '폴카닷',
        symbol: 'DOT',
        currentPrice: (6.8 + _randomVariation(0.2)) * krwRate,
        priceChange24h: (0.3 + _randomVariation(0.05)) * krwRate,
        priceChangePercentage24h: 4.6 + _randomVariation(0.5),
        marketCap: 9500000000 * krwRate,
        volume24h: 350000000 * krwRate,
        high24h: (6.9 + _randomVariation(0.1)) * krwRate,
        low24h: (6.5 + _randomVariation(0.1)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/12171/large/polkadot.png',
      ),
      Coin(
        id: 'matic-network',
        name: '폴리곤',
        symbol: 'MATIC',
        currentPrice: (0.58 + _randomVariation(0.01)) * krwRate,
        priceChange24h: (0.03 + _randomVariation(0.005)) * krwRate,
        priceChangePercentage24h: 5.5 + _randomVariation(0.5),
        marketCap: 5800000000 * krwRate,
        volume24h: 450000000 * krwRate,
        high24h: (0.59 + _randomVariation(0.005)) * krwRate,
        low24h: (0.56 + _randomVariation(0.005)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png',
      ),
      Coin(
        id: 'shiba-inu',
        name: '시바이누',
        symbol: 'SHIB',
        currentPrice: (0.000018 + _randomVariation(0.000001)) * krwRate,
        priceChange24h: (0.000002 + _randomVariation(0.0000005)) * krwRate,
        priceChangePercentage24h: 12.5 + _randomVariation(1.5),
        marketCap: 10500000000 * krwRate,
        volume24h: 850000000 * krwRate,
        high24h: (0.000019 + _randomVariation(0.0000005)) * krwRate,
        low24h: (0.000017 + _randomVariation(0.0000005)) * krwRate,
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/11939/large/shiba.png',
      ),
    ];

    // limit이 0이면 모든 코인 반환, 아니면 limit 수만큼 반환
    final result = limit > 0 ? coins.take(limit).toList() : coins;
    debugPrint('MockCryptoApiService: ${result.length}개 모의 코인 데이터 반환');

    return result;
  }

  @override
  Future<Coin?> getCoinBySymbol(String symbol) async {
    debugPrint('MockCryptoApiService: 모의 코인 데이터 조회 - $symbol');

    // 지연 시간 추가 (실제 API 호출처럼 보이게)
    await Future.delayed(const Duration(milliseconds: 300));

    // 원화 환율 적용 (대략 1달러 = 1300원)
    const double krwRate = 1300.0;

    final coins = await getTopCoins(limit: 0);
    final coin = coins.firstWhere(
      (coin) => coin.symbol.toUpperCase() == symbol.toUpperCase(),
      orElse: () => coins.first,
    );

    return coin;
  }

  // 약간의 무작위 변동을 추가하는 도우미 함수
  double _randomVariation(double maxVariation) {
    final random = Random();
    return (random.nextDouble() * 2 - 1) *
        maxVariation; // -maxVariation ~ +maxVariation
  }
}
