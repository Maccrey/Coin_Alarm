import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/theme.dart';
import 'services/settings_service.dart';
import 'viewmodel/auth_viewmodel.dart';
import 'viewmodel/coin_viewmodel.dart';
import 'viewmodel/news_viewmodel.dart';
import 'viewmodel/price_alert_viewmodel.dart';
import 'viewmodel/settings_viewmodel.dart';
import 'viewmodel/crypto_viewmodel.dart';
import 'view/screens/splash_screen.dart';
import 'view/screens/settings_screen.dart';
import 'viewmodel/chart_viewmodel.dart';
import 'services/chart_cache_service.dart';
import 'model/chart_data_model.dart';
import 'model/price_alert_model.dart';
import 'services/price_alert_service.dart';
import 'model/coin_model.dart';
import 'model/news_model.dart';
import 'viewmodel/theme_viewmodel.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';

// 백그라운드에서 사용할 코인 가격 fetch 함수 (Upbit API 연동)
Future<List<Coin>> fetchCoinPricesForBackground() async {
  try {
    // Upbit에서 BTC, ETH 시세 조회 (필요시 코인 추가)
    final response = await http.get(
      Uri.parse('https://api.upbit.com/v1/ticker?markets=KRW-BTC,KRW-ETH'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) {
        final market = item['market'] as String;
        final symbol = market.split('-').last;
        return Coin(
          id: symbol.toLowerCase(),
          name: symbol,
          symbol: symbol,
          currentPrice: (item['trade_price'] as num).toDouble(),
          priceChange24h: null,
          priceChangePercentage24h: ((item['signed_change_rate'] as num) * 100)
              .toDouble(),
          marketCap: null,
          volume24h: null,
          high24h: null,
          low24h: null,
          lastUpdated: DateTime.now(),
          imageUrl: null,
        );
      }).toList();
    } else {
      debugPrint('Upbit API 오류: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('코인 시세 fetch 실패: ${e}');
    return [];
  }
}

// Workmanager 백그라운드 태스크 콜백
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[백그라운드] Workmanager 태스크 실행됨: $task');
    await Hive.initFlutter();
    await PriceAlertService().initialize();
    debugPrint('[백그라운드] PriceAlertService 초기화 완료');
    // 코인 가격 fetch 및 알림 체크
    final coinList = await fetchCoinPricesForBackground();
    final triggeredAlerts = await PriceAlertService().checkAndUpdateAlerts(
      coinList,
      'local-user', // 실제 사용자 ID로 대체
    );
    debugPrint('[백그라운드] 알림 체크 완료. 트리거된 알림 개수: ${triggeredAlerts.length}');
    return Future.value(true);
  });
}

// 테스트용 샘플 뉴스 데이터 추가
Future<void> addSampleNewsData(FirebaseService firebaseService) async {
  try {
    // 샘플 뉴스 데이터
    final sampleNews = News(
      id: '68bb7245c9945f331aab97ea8bd233e0',
      title: '美 와이오밍주, 공식 스테이블코인 WYST 8월 메인넷 출시 목표',
      content:
          "스테이블코인 [사진: Reve AI] [디지털투데이 황치규 기자]미국 와이오밍주는 공식 스테이블코인 프로젝트 WYST를 오는 8월 20일 출시하는 것을 목표로 하고 있다고 더블록이 20일(현지시간) 보도했다. 와이오밍스테이블토큰위원회는 최근 회의에서 블록체인 테스트 일정을 공개하고, 대상 체인 범위도 확대했다. WYST는 와이오밍스테이블토큰법에 따라 발행되는 달러 연동형 스테이블코인이다. 와이오밍주는 이 코인을 통해 블록체인 산업 중심지로 부상한다는 전략이다. 현재까지 후보에 오른 체인은 앱토스, 아비트럼, 아발란체, 베이스, 이더리움, 옵티미즘, 폴리곤, 세이, 솔라나, 스텔라, 수이 등 총 11개다. 이 중 앱토스와 세이는 지난 5월 회의에서 공식 후보로 추가됐다. 위원회는 오는 8월 열리는 와이오밍 블록체인 심포지엄에서 WYST 메인넷 출시를 발표할 계획이다. 이를 위해 6월과 7월 중 각 블록체인들에 WYST 테스트넷 컨트랙트를 재배포하고, 파이어블록스 인프라...",
      source: 'digitaltoday',
      url: 'https://www.digitaltoday.co.kr/news/articleView.html?idxno=572332',
      publishedAt: DateTime.parse('2025-06-22T12:44:47.226323+09:00'),
      relatedCoins: ['ethereum', 'solana', 'polygon'],
      imageUrl: '',
      viewCount: 0,
    );

    // 일시적으로 주석 처리
    // await firebaseService.addNews(sampleNews);
    debugPrint('샘플 뉴스 데이터 추가 기능 일시 중단');
  } catch (e) {
    debugPrint('샘플 뉴스 데이터 추가 실패: $e');
  }
}

// 앱 진입점
void main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 세로 모드만 지원
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // .env 파일 로드
  await dotenv.load();

  // Firebase 초기화
  try {
    if (kIsWeb) {
      debugPrint('웹 플랫폼에서는 Firebase 초기화를 건너뜁니다.');
    } else {
      await Firebase.initializeApp();
      debugPrint('Firebase 초기화 성공');
    }
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    debugPrint('Firebase 초기화 실패로 인해 모의 서비스로 대체됩니다.');
  }

  // Hive 초기화
  await Hive.initFlutter();

  // Hive 어댑터 등록
  if (Hive.isAdapterRegistered(36) == false) {
    debugPrint('Hive 어댑터 등록 생략 - 모의 서비스 사용 중');
  }

  await Hive.openBox('settings');
  await Hive.openBox('news_cache');

  // 설정 서비스 초기화
  final settingsService = SettingsService();
  await settingsService.initialize();

  // 캐시 서비스 초기화
  final chartCacheService = ChartCacheService();
  await chartCacheService.initialize();
  await PriceAlertService().initialize();

  // Firebase 서비스 초기화 (모의 서비스로 전환)
  final firebaseService = FirebaseService();
  try {
    await firebaseService.initialize();
    debugPrint('Firebase 서비스 초기화 성공 (모의 서비스)');
  } catch (e) {
    debugPrint('Firebase 서비스 초기화 실패: $e');
  }

  // Workmanager 초기화 (백그라운드 태스크 등록) - 모바일 플랫폼에서만 실행
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
      // 15분마다 반복 태스크 등록
      Workmanager().registerPeriodicTask(
        'checkPriceAlertsTaskId',
        'checkPriceAlertsTask',
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      debugPrint('Workmanager 초기화 성공');
    } catch (e) {
      debugPrint('Workmanager 초기화 실패: $e');
    }
  } else {
    debugPrint('웹 플랫폼에서는 Workmanager를 사용하지 않습니다.');
  }

  // 인증 서비스 초기화
  final authService = AuthService();
  try {
    await authService.initialize();
    debugPrint('인증 서비스 초기화 성공');
  } catch (e) {
    debugPrint('인증 서비스 초기화 실패: $e');
    // 초기화 실패해도 계속 진행
  }

  // 앱 실행
  runApp(
    MyApp(
      firebaseService: firebaseService,
      settingsService: settingsService,
      authService: authService,
      chartCacheService: chartCacheService,
    ),
  );
}

// 앱의 루트 위젯
class MyApp extends StatelessWidget {
  final FirebaseService firebaseService;
  final SettingsService settingsService;
  final AuthService authService;
  final ChartCacheService chartCacheService;

  const MyApp({
    super.key,
    required this.firebaseService,
    required this.settingsService,
    required this.authService,
    required this.chartCacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 테마 관련 ViewModel
        ChangeNotifierProvider(create: (_) => ThemeViewModel(settingsService)),

        // 인증 관련 ViewModel
        ChangeNotifierProvider(create: (_) => AuthViewModel(authService)),

        // 차트 캐시 서비스 Provider (다른 ViewModel에서 사용)
        Provider.value(value: chartCacheService),

        // 설정 서비스 Provider (다른 ViewModel에서 사용)
        Provider.value(value: settingsService),

        // 코인 관련 ViewModel
        ChangeNotifierProvider(create: (_) => CoinViewModel(firebaseService)),

        // 암호화폐 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) =>
              CryptoViewModel(settingsService: context.read<SettingsService>()),
        ),

        // 뉴스 관련 ViewModel
        ChangeNotifierProvider(create: (_) => NewsViewModel(firebaseService)),

        // 가격 알림 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => PriceAlertViewModel(PriceAlertService()),
        ),

        // 설정 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(settingsService),
        ),

        // 차트 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) =>
              ChartViewModel(context.read<ChartCacheService>()),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeViewModel, _) {
          return MaterialApp(
            title: '코인 알람',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeViewModel.themeMode,
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
