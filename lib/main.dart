import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'services/supabase_client.dart';
import 'view/screens/settings_screen.dart';
import 'viewmodel/chart_viewmodel.dart';
import 'services/chart_cache_service.dart';

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

  // 설정 서비스 초기화
  final settingsService = SettingsService();
  await settingsService.initialize();

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

  // 차트 캐시 서비스 초기화
  final chartCacheService = ChartCacheService();
  await chartCacheService.initialize();

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

        // 인증 관련 ViewModel
        ChangeNotifierProvider(create: (_) => AuthViewModel(supabaseService)),
        // 코인 관련 ViewModel
        ChangeNotifierProvider(create: (_) => CoinViewModel(supabaseService)),
        // 뉴스 관련 ViewModel
        ChangeNotifierProvider(create: (_) => NewsViewModel(supabaseService)),
        // 가격 알림 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => PriceAlertViewModel(supabaseService),
        ),
        // 설정 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(settingsService),
        ),
        // 실시간 암호화폐 API 데이터 ViewModel
        ChangeNotifierProvider(
          create: (_) => CryptoViewModel(settingsService: settingsService),
        ),
        // 차트 데이터 ViewModel
        ChangeNotifierProvider(create: (_) => ChartViewModel()),
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
