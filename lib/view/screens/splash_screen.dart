import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../viewmodel/auth_viewmodel.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// 스플래시 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 설정
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    // 애니메이션 시작
    _animationController.forward();

    // 일정 시간 후 다음 화면으로 이동
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 다음 화면으로 이동 (로그인 여부에 따라)
  Future<void> _navigateToNextScreen() async {
    debugPrint('SplashScreen: 다음 화면 이동 준비 시작');

    // 화면 전환 전 약간의 지연 추가 (애니메이션 효과를 보여주기 위함)
    await Future.delayed(const Duration(seconds: 2));

    debugPrint('SplashScreen: 지연 완료, 화면 전환 시도');

    // mounted 체크
    if (!mounted) {
      debugPrint('SplashScreen: 위젯이 더 이상 마운트되어 있지 않음');
      return;
    }

    // 전체 타임아웃 설정 (10초)
    bool timeoutOccurred = false;
    Timer? timeoutTimer;

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      timeoutOccurred = true;
      debugPrint('SplashScreen: 전체 프로세스 타임아웃 발생, 강제로 로그인 화면으로 이동');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });

    try {
      // 인증 상태 확인
      debugPrint('SplashScreen: AuthViewModel 가져오기 시도');
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      debugPrint('SplashScreen: AuthViewModel 가져오기 성공');

      // AuthViewModel이 초기화될 때까지 기다림 (최대 5초)
      if (!authViewModel.isInitialized) {
        debugPrint('SplashScreen: AuthViewModel 초기화 대기 시작');

        // 타임아웃 설정 (5초)
        bool isInitialized = false;
        int attempts = 0;
        const maxAttempts = 50; // 100ms 간격으로 50번 시도 (총 5초)

        while (!isInitialized &&
            attempts < maxAttempts &&
            mounted &&
            !timeoutOccurred) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;

          // 현재 상태 확인
          isInitialized = authViewModel.isInitialized;

          if (attempts % 10 == 0) {
            debugPrint(
              'SplashScreen: AuthViewModel 초기화 대기 중... ($attempts/$maxAttempts)',
            );
          }
        }

        if (!isInitialized && !timeoutOccurred) {
          debugPrint('SplashScreen: AuthViewModel 초기화 타임아웃, 강제로 진행');
        } else if (isInitialized) {
          debugPrint('SplashScreen: AuthViewModel 초기화 완료 확인');
        }
      }

      // 타임아웃이 발생했는지 확인
      if (timeoutOccurred) {
        debugPrint('SplashScreen: 이미 타임아웃으로 화면 전환됨');
        timeoutTimer.cancel();
        return;
      }

      // 로그인 상태에 따라 화면 전환
      final isLoggedIn = authViewModel.isLoggedIn;
      debugPrint('SplashScreen: 로그인 상태 - $isLoggedIn');
      debugPrint(
        'SplashScreen: 현재 사용자 - ${authViewModel.currentUser?.email ?? "없음"}',
      );

      // 안전하게 화면 전환
      if (!mounted) {
        debugPrint('SplashScreen: 화면 전환 전 위젯이 마운트 해제됨');
        timeoutTimer.cancel();
        return;
      }

      // 타임아웃 타이머 취소
      timeoutTimer.cancel();

      debugPrint(
        'SplashScreen: 화면 전환 시도 - ${isLoggedIn ? "홈 화면" : "로그인 화면"}으로 이동',
      );
      if (isLoggedIn) {
        debugPrint('SplashScreen: 홈 화면으로 이동 시작');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        debugPrint('SplashScreen: 홈 화면으로 이동 완료');
      } else {
        debugPrint('SplashScreen: 로그인 화면으로 이동 시작');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        debugPrint('SplashScreen: 로그인 화면으로 이동 완료');
      }
    } catch (e) {
      // 타임아웃 타이머 취소
      timeoutTimer.cancel();

      debugPrint('SplashScreen: 오류 발생 - $e');
      debugPrint('SplashScreen: 오류 스택 트레이스 - ${StackTrace.current}');

      // 오류 발생 시 로그인 화면으로 이동
      if (mounted && !timeoutOccurred) {
        debugPrint('SplashScreen: 오류로 인해 로그인 화면으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고 (실제로는 앱 로고 이미지 사용)
                    Icon(Icons.currency_bitcoin, size: 80, color: Colors.white),
                    const SizedBox(height: 24),
                    // 앱 이름
                    Text(
                      AppConstants.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 앱 설명
                    Text(
                      AppConstants.appDescription,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // 로딩 인디케이터
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
