import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'core/theme.dart';
import 'services/supabase_service.dart';
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

// 앱 진입점
void main() async {
  // Flutter 엔진 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 세로 모드만 지원
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // .env 파일 로드
  await dotenv.load();

  // Hive 초기화 및 어댑터 등록 먼저 실행
  await Hive.initFlutter();
  Hive.registerAdapter(ChartDataAdapter());
  Hive.registerAdapter(ChartPointAdapter());
  Hive.registerAdapter(CandleDataAdapter());
  Hive.registerAdapter(CandleChartDataAdapter());
  Hive.registerAdapter(ChartTypeAdapter());
  Hive.registerAdapter(ChartTimeframeAdapter());
  Hive.registerAdapter(PriceAlertAdapter());

  // 뉴스 캐시 박스 미리 오픈 (속도 개선)
  await Hive.openBox('news_cache');

  // SettingsService 초기화
  final settingsService = SettingsService();
  await settingsService.initialize();

  // 캐시 서비스 초기화
  await ChartCacheService().initialize();
  await PriceAlertService().initialize();

  // Supabase 클라이언트 초기화
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    debugPrint('경고: SUPABASE_URL 또는 SUPABASE_ANON_KEY가 .env 파일에 설정되지 않았습니다.');
  } else {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('Supabase 클라이언트 초기화 성공');
    } catch (e) {
      debugPrint('Supabase 초기화 오류: $e');
    }
  }

  // 서비스 초기화 (실제 Supabase 연동 시도)
  final supabaseService = SupabaseService();
  try {
    // 실제 Supabase 연동 시도
    await supabaseService.initialize(useRealSupabase: true);
    debugPrint('실제 Supabase 연동 성공');
  } catch (e) {
    debugPrint('실제 Supabase 연동 실패: $e');
    // 실패 시 더미 데이터로 초기화
    await supabaseService.initialize(useRealSupabase: false);
    debugPrint('더미 데이터로 초기화됨');
  }

  // Workmanager 초기화 (백그라운드 태스크 등록)
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  // 15분마다 반복 태스크 등록
  Workmanager().registerPeriodicTask(
    'checkPriceAlertsTaskId',
    'checkPriceAlertsTask',
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(
    MyApp(supabaseService: supabaseService, settingsService: settingsService),
  );
}

// 앱의 루트 위젯
class MyApp extends StatelessWidget {
  final SupabaseService supabaseService;
  final SettingsService settingsService;

  const MyApp({
    super.key,
    required this.supabaseService,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    // 다양한 ViewModel 제공을 위한 MultiProvider 설정
    return MultiProvider(
      providers: [
        // 서비스 제공
        Provider<ChartCacheService>(create: (_) => ChartCacheService()),
        Provider<PriceAlertService>(create: (_) => PriceAlertService()),

        // 인증 관련 ViewModel
        ChangeNotifierProvider(create: (_) => AuthViewModel(supabaseService)),
        // 코인 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) => CoinViewModel(supabaseService),
        ),
        // 뉴스 관련 ViewModel
        ChangeNotifierProvider(create: (_) => NewsViewModel(supabaseService)),
        // 가격 알림 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) => PriceAlertViewModel(PriceAlertService()),
        ),
        // 설정 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(settingsService),
        ),
        // 실시간 암호화폐 API 데이터 ViewModel
        ChangeNotifierProvider(create: (context) => CryptoViewModel()),
        // 차트 데이터 ViewModel
        ChangeNotifierProvider(
          create: (context) => ChartViewModel(ChartCacheService()),
        ),
      ],
      builder: (context, child) {
        // SettingsViewModel에서 테마 모드 가져오기
        final settingsViewModel = Provider.of<SettingsViewModel>(context);
        final themeMode = settingsViewModel.themeMode;

        return MaterialApp(
          title: 'Coin Alarm',
          debugShowCheckedModeBanner: false, // 디버그 배너 숨김
          theme: AppTheme.lightTheme(), // 라이트 테마 적용
          darkTheme: AppTheme.darkTheme(), // 다크 테마 적용
          themeMode: themeMode, // 설정에서 선택한 테마 모드 적용
          home: const SplashScreen(), // 스플래시 화면으로 시작
          // 라우트 정의
          routes: {'/settings': (context) => const SettingsScreen()},

          // 상태바 아이콘 색상을 테마에 맞게 자동으로 조정
          builder: (context, child) {
            // 상태바 스타일을 테마에 맞게 설정
            final brightness = Theme.of(context).brightness;
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
                systemNavigationBarColor: brightness == Brightness.light
                    ? AppTheme.lightBackgroundColor
                    : AppTheme.darkBackgroundColor,
                systemNavigationBarIconBrightness:
                    brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
              ),
            );
            return child!;
          },
        );
      },
    );
  }
}
