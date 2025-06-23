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

    try {
      // 인증 상태 확인
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      debugPrint('SplashScreen: AuthViewModel 가져오기 성공');

      // 로그인 상태에 따라 화면 전환
      final isLoggedIn = authViewModel.isLoggedIn;
      debugPrint('SplashScreen: 로그인 상태 - $isLoggedIn');

      // 안전하게 화면 전환
      if (!mounted) return;

      if (isLoggedIn) {
        debugPrint('SplashScreen: 홈 화면으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        debugPrint('SplashScreen: 로그인 화면으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('SplashScreen: 오류 발생 - $e');

      // 오류 발생 시 로그인 화면으로 이동
      if (mounted) {
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
