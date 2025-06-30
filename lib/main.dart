import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';
import 'dart:isolate';
import 'core/constants.dart';
import 'core/theme.dart';
import 'model/news_model.dart';
import 'services/auth_service.dart';
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
import 'viewmodel/theme_viewmodel.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'view/screens/news_detail_screen.dart';

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

    // Firebase 초기화
    try {
      // 백그라운드 전용 Firebase 앱 이름 지정
      const appName = 'coin_alarm_background';

      // 이미 해당 이름의 앱이 초기화되었는지 확인
      FirebaseApp app;
      try {
        app = Firebase.app(appName);
        debugPrint('[백그라운드] 기존 Firebase 앱($appName) 사용');
      } catch (e) {
        // 해당 이름의 앱이 없으면 새로 초기화 시도
        try {
          app = await Firebase.initializeApp(
            name: appName,
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint('[백그라운드] 새 Firebase 앱($appName) 초기화 성공');
        } catch (e) {
          if (e.toString().contains('duplicate-app')) {
            // 중복 앱 오류인 경우 기존 앱 사용
            app = Firebase.app(appName);
            debugPrint('[백그라운드] 중복 앱 오류 해결: 기존 Firebase 앱($appName) 사용');
          } else {
            debugPrint('[백그라운드] Firebase 초기화 실패: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[백그라운드] Firebase 초기화 오류: $e');
    }

    // Hive 초기화 및 알림 처리는 계속 진행
    await Hive.initFlutter();
    await PriceAlertService().initialize();
    debugPrint('[백그라운드] PriceAlertService 초기화 완료');

    // 알림 서비스 초기화
    final notificationService = NotificationService();
    await notificationService.initialize();
    debugPrint('[백그라운드] NotificationService 초기화 완료');

    // 코인 가격 fetch 및 알림 체크
    final coinList = await fetchCoinPricesForBackground();
    final triggeredAlerts = await PriceAlertService().checkAndUpdateAlerts(
      coinList,
      'local-user', // 실제 사용자 ID로 대체
    );

    debugPrint('[백그라운드] 알림 체크 완료. 트리거된 알림 개수: ${triggeredAlerts.length}');

    // 트리거된 알림이 있으면 사용자에게 알림 표시
    if (triggeredAlerts.isNotEmpty) {
      for (int i = 0; i < triggeredAlerts.length; i++) {
        final alert = triggeredAlerts[i];
        final coin = coinList.firstWhere(
          (c) => c.id == alert.coinId,
          orElse: () => Coin(
            id: '',
            symbol: alert.coinSymbol,
            name: alert.coinSymbol,
            currentPrice: 0,
            priceChangePercentage24h: 0,
            lastUpdated: DateTime.now(),
          ),
        );

        // 알림 발생 시간 포맷팅
        final now = alert.triggeredAt ?? DateTime.now();
        final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        final dateStr = '${now.year}-${now.month}-${now.day}';

        // 알림 제목 및 내용 구성
        final title = '${alert.coinSymbol} 가격 알림';
        final condition = alert.isAbove ? '이상' : '이하';
        final body =
            '[발생됨] $dateStr $timeStr\n${alert.coinSymbol} 현재가: ₩${coin.currentPrice}\n조건: ₩${alert.priceTarget} $condition';

        // 알림 표시
        await notificationService.showNotification(
          id: 1000 + i, // 고유한 알림 ID 생성
          title: title,
          body: body,
          payload: json.encode(alert.toJson()),
        );

        debugPrint('[백그라운드] 알림 표시: $title - $body');
      }
    }

    return Future.value(true);
  });
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
  FirebaseApp? app;
  try {
    debugPrint('Firebase 초기화 시도 (main)');
    debugPrint('플랫폼: ${defaultTargetPlatform.toString()}');

    if (Firebase.apps.isEmpty) {
      final options = DefaultFirebaseOptions.currentPlatform;
      debugPrint('Firebase 옵션: $options');

      try {
        // iOS에서는 특별히 처리
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('iOS 플랫폼에서 Firebase 초기화 시도');

          app = await Firebase.initializeApp(
            options: options,
            name: 'CoinAlarmApp', // iOS에서 명시적 앱 이름 지정
          );
          debugPrint('iOS에서 Firebase 초기화 성공 - 앱 이름: ${app.name}');

          // iOS에서 Firebase Auth 초기화 확인
          try {
            final auth = FirebaseAuth.instance;
            debugPrint('iOS에서 Firebase Auth 인스턴스 확인: $auth');

            // 현재 로그인된 사용자가 있다면 로그아웃 (초기 상태 정리)
            if (auth.currentUser != null) {
              await auth.signOut();
              debugPrint('iOS에서 기존 사용자 로그아웃 완료');
            }
          } catch (e) {
            debugPrint('iOS에서 Firebase Auth 확인 중 오류: $e');
          }
        } else {
          app = await Firebase.initializeApp(options: options);
          debugPrint('Firebase 초기화 성공 (main)');
        }
      } catch (e) {
        if (e.toString().contains('duplicate-app')) {
          // 중복 앱 오류인 경우 기존 앱 사용
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            try {
              app = Firebase.app('CoinAlarmApp');
              debugPrint('iOS에서 기존 Firebase 앱 사용 - 앱 이름: ${app.name}');
            } catch (_) {
              app = Firebase.app();
              debugPrint('iOS에서 기본 Firebase 앱 사용');
            }
          } else {
            app = Firebase.app();
            debugPrint('Firebase 중복 앱 오류 해결: 기존 앱 사용 (main)');
          }
        } else {
          debugPrint('Firebase 초기화 실패: $e');
          debugPrint('스택 트레이스: ${StackTrace.current}');
          throw e;
        }
      }
    } else {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          app = Firebase.app('CoinAlarmApp');
          debugPrint('iOS에서 기존 Firebase 앱 사용 - 앱 이름: ${app.name}');
        } catch (_) {
          app = Firebase.app();
          debugPrint('iOS에서 기본 Firebase 앱 사용');
        }
      } else {
        app = Firebase.app();
        debugPrint('Firebase 이미 초기화됨 (main) - 앱 이름: ${app.name}');
      }
    }
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    debugPrint('스택 트레이스: ${StackTrace.current}');
    // Firebase 초기화 실패 시 앱 실행을 중단합니다.
    throw Exception('Firebase 초기화 실패: $e');
  }

  // Hive 초기화
  await Hive.initFlutter();

  // Hive 어댑터 등록
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(PriceAlertAdapter());
    debugPrint('Hive 어댑터 등록 완료');
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

  // Firebase 서비스 초기화
  final firebaseService = FirebaseService();
  try {
    await firebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase 서비스 초기화 실패: $e');
    // 초기화 실패해도 앱은 계속 실행
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

  // 알림 서비스 초기화
  await NotificationService().initialize();

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
class MyApp extends StatefulWidget {
  // 전역 네비게이터 키 (알림 처리용)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 알림 권한 확인 및 요청
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        // 알림 권한 요청
        NotificationService.requestUserPermissions(
          context,
          permissionList: [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            NotificationPermission.Light,
            NotificationPermission.PreciseAlarms,
            NotificationPermission.FullScreenIntent,
            NotificationPermission.CriticalAlert,
          ],
        );
      }
    });

    // 알림 리스너 설정
    NotificationService().setListeners(
      onActionReceivedMethod: _onNotificationAction,
    );
  }

  // 알림 탭 이벤트 처리
  void _onNotificationAction(ReceivedAction receivedAction) {
    // 알림 탭 처리 로직
    debugPrint('알림 탭: ${receivedAction.payload}');

    // 필요한 경우 특정 화면으로 이동
    // MyApp.navigatorKey.currentState?.pushNamed('/notification-details', arguments: receivedAction);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: build 메서드 호출됨');
    return MultiProvider(
      providers: [
        // 테마 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => ThemeViewModel(widget.settingsService),
        ),

        // 인증 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('MyApp: AuthViewModel 생성');
            return AuthViewModel(widget.authService);
          },
        ),

        // 차트 캐시 서비스 Provider (다른 ViewModel에서 사용)
        Provider.value(value: widget.chartCacheService),

        // 설정 서비스 Provider (다른 ViewModel에서 사용)
        Provider.value(value: widget.settingsService),

        // 코인 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => CoinViewModel(widget.firebaseService),
        ),

        // 암호화폐 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) =>
              CryptoViewModel(settingsService: widget.settingsService),
        ),

        // 뉴스 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => NewsViewModel(widget.firebaseService),
        ),

        // 가격 알림 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => PriceAlertViewModel(PriceAlertService()),
        ),

        // 설정 관련 ViewModel
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(widget.settingsService),
        ),

        // 차트 관련 ViewModel
        ChangeNotifierProvider(
          create: (context) =>
              ChartViewModel(context.read<ChartCacheService>()),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeViewModel, _) {
          debugPrint('MyApp: ThemeViewModel Consumer 빌드');
          return MaterialApp(
            navigatorKey: MyApp.navigatorKey,
            title: '코인 알람',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeViewModel.themeMode,
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) {
                debugPrint('MyApp: SplashScreen 생성 시작');
                return const SplashScreen();
              },
            ),
            routes: {
              '/news_detail': (context) => NewsDetailScreen(
                news: ModalRoute.of(context)!.settings.arguments as News,
              ),
            },
          );
        },
      ),
    );
  }
}
