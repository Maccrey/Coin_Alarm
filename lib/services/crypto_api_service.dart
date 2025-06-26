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
      final maxMarkets = min(100, krwMarkets.length);
      debugPrint('UpbitApiService: 최대 $maxMarkets개 마켓 데이터 요청');

      final marketsToFetch = krwMarkets.take(maxMarkets).join(',');
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
        throw Exception('업비트 시세 정보 조회 실패: ${tickerResponse.statusCode}');
      }

      debugPrint(
        'UpbitApiService: 시세 정보 응답 성공, ${(tickerResponse.data as List).length}개 코인 데이터 수신',
      );

      // 코인 모델 변환
      final List<Coin> coins = [];
      for (final ticker in tickerResponse.data) {
        final marketCode = ticker['market'] as String; // KRW-BTC
        final symbol = marketCode.split('-')[1]; // BTC
        final name = _getCoinName(symbol);

        coins.add(
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

      // 거래량 기준 정렬
      coins.sort((a, b) => (b.volume24h ?? 0).compareTo(a.volume24h ?? 0));

      // limit이 0이면 모든 코인 반환, 아니면 limit 수만큼 반환
      final result = limit > 0 ? coins.take(limit).toList() : coins;
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

// 암호화폐 서비스 팩토리
class CryptoServiceFactory {
  final SettingsService _settingsService = SettingsService();

  // 사용 가능한 서비스 가져오기
  List<CryptoApiService> getAvailableServices() {
    debugPrint('CryptoServiceFactory: 사용 가능한 서비스 확인 중');
    final List<CryptoApiService> services = [];

    final upbitService = UpbitApiService();
    final binanceService = BinanceApiService();
    final mockService = MockCryptoApiService(); // 모의 서비스 추가

    debugPrint(
      'CryptoServiceFactory: 업비트 서비스 구성됨: ${upbitService.isConfigured}',
    );
    debugPrint(
      'CryptoServiceFactory: 바이낸스 서비스 구성됨: ${binanceService.isConfigured}',
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

    // API 키가 설정되지 않은 경우 항상 모의 서비스 추가
    if (services.isEmpty) {
      services.add(mockService);
      debugPrint('CryptoServiceFactory: API 키가 없어 모의 서비스 추가됨');
    }

    debugPrint('CryptoServiceFactory: 총 ${services.length}개 서비스 사용 가능');
    return services;
  }

  // 우선순위에 따른 서비스 선택
  CryptoApiService? getPreferredService() {
    final services = getAvailableServices();
    if (services.isEmpty) {
      debugPrint('CryptoServiceFactory: 사용 가능한 서비스가 없음');
      return null;
    }

    // 만약 둘 다 사용 가능하면 업비트 우선
    for (final service in services) {
      if (service is UpbitApiService) {
        debugPrint('CryptoServiceFactory: 업비트 서비스 선택됨');
        return service;
      }
    }

    debugPrint('CryptoServiceFactory: ${services.first.exchangeName} 서비스 선택됨');
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

    final now = DateTime.now();
    final coins = [
      Coin(
        id: 'bitcoin',
        name: '비트코인',
        symbol: 'BTC',
        currentPrice: 67500.0 + _randomVariation(500),
        priceChange24h: 1200.0 + _randomVariation(100),
        priceChangePercentage24h: 1.8 + _randomVariation(0.2),
        marketCap: 1300000000000,
        volume24h: 25000000000,
        high24h: 68000.0 + _randomVariation(200),
        low24h: 66800.0 + _randomVariation(200),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/1/large/bitcoin.png',
      ),
      Coin(
        id: 'ethereum',
        name: '이더리움',
        symbol: 'ETH',
        currentPrice: 3450.0 + _randomVariation(50),
        priceChange24h: 120.0 + _randomVariation(20),
        priceChangePercentage24h: 3.5 + _randomVariation(0.5),
        marketCap: 415000000000,
        volume24h: 18000000000,
        high24h: 3500.0 + _randomVariation(30),
        low24h: 3400.0 + _randomVariation(30),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
      ),
      Coin(
        id: 'binancecoin',
        name: '바이낸스 코인',
        symbol: 'BNB',
        currentPrice: 570.0 + _randomVariation(10),
        priceChange24h: 15.0 + _randomVariation(5),
        priceChangePercentage24h: 2.7 + _randomVariation(0.3),
        marketCap: 87000000000,
        volume24h: 2500000000,
        high24h: 580.0 + _randomVariation(5),
        low24h: 560.0 + _randomVariation(5),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png',
      ),
      Coin(
        id: 'solana',
        name: '솔라나',
        symbol: 'SOL',
        currentPrice: 142.0 + _randomVariation(5),
        priceChange24h: 8.0 + _randomVariation(2),
        priceChangePercentage24h: 6.0 + _randomVariation(1),
        marketCap: 65000000000,
        volume24h: 3200000000,
        high24h: 145.0 + _randomVariation(3),
        low24h: 135.0 + _randomVariation(3),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/4128/large/solana.png',
      ),
      Coin(
        id: 'ripple',
        name: '리플',
        symbol: 'XRP',
        currentPrice: 0.52 + _randomVariation(0.01),
        priceChange24h: 0.02 + _randomVariation(0.005),
        priceChangePercentage24h: 4.0 + _randomVariation(0.5),
        marketCap: 28000000000,
        volume24h: 1500000000,
        high24h: 0.53 + _randomVariation(0.005),
        low24h: 0.50 + _randomVariation(0.005),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png',
      ),
      Coin(
        id: 'dogecoin',
        name: '도지코인',
        symbol: 'DOGE',
        currentPrice: 0.12 + _randomVariation(0.005),
        priceChange24h: 0.01 + _randomVariation(0.002),
        priceChangePercentage24h: 8.5 + _randomVariation(1),
        marketCap: 17000000000,
        volume24h: 1200000000,
        high24h: 0.125 + _randomVariation(0.002),
        low24h: 0.115 + _randomVariation(0.002),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/5/large/dogecoin.png',
      ),
      Coin(
        id: 'cardano',
        name: '에이다',
        symbol: 'ADA',
        currentPrice: 0.45 + _randomVariation(0.01),
        priceChange24h: 0.02 + _randomVariation(0.005),
        priceChangePercentage24h: 4.7 + _randomVariation(0.5),
        marketCap: 16000000000,
        volume24h: 800000000,
        high24h: 0.46 + _randomVariation(0.005),
        low24h: 0.44 + _randomVariation(0.005),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/975/large/cardano.png',
      ),
      Coin(
        id: 'polkadot',
        name: '폴카닷',
        symbol: 'DOT',
        currentPrice: 6.8 + _randomVariation(0.2),
        priceChange24h: 0.3 + _randomVariation(0.05),
        priceChangePercentage24h: 4.6 + _randomVariation(0.5),
        marketCap: 9500000000,
        volume24h: 350000000,
        high24h: 6.9 + _randomVariation(0.1),
        low24h: 6.5 + _randomVariation(0.1),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/12171/large/polkadot.png',
      ),
      Coin(
        id: 'matic-network',
        name: '폴리곤',
        symbol: 'MATIC',
        currentPrice: 0.58 + _randomVariation(0.01),
        priceChange24h: 0.03 + _randomVariation(0.005),
        priceChangePercentage24h: 5.5 + _randomVariation(0.5),
        marketCap: 5800000000,
        volume24h: 450000000,
        high24h: 0.59 + _randomVariation(0.005),
        low24h: 0.56 + _randomVariation(0.005),
        lastUpdated: now,
        imageUrl:
            'https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png',
      ),
      Coin(
        id: 'shiba-inu',
        name: '시바이누',
        symbol: 'SHIB',
        currentPrice: 0.000018 + _randomVariation(0.000001),
        priceChange24h: 0.000002 + _randomVariation(0.0000005),
        priceChangePercentage24h: 12.5 + _randomVariation(1.5),
        marketCap: 10500000000,
        volume24h: 850000000,
        high24h: 0.000019 + _randomVariation(0.0000005),
        low24h: 0.000017 + _randomVariation(0.0000005),
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
