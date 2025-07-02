import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 화면이 로드된 후 자동으로 생체인증 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateWithBiometrics();
    });
  }

  // 생체인증 시도
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      // 생체인증 가능 여부 확인
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        setState(() {
          _errorMessage = '이 기기에서는 생체인증을 사용할 수 없습니다.';
          _isAuthenticating = false;
        });
        return;
      }

      // 생체인증 시도
      final authenticated = await _localAuth.authenticate(
        localizedReason: '생체인증으로 로그인하세요',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        // 인증 성공 시 저장된 로그인 정보로 로그인 시도
        final settingsViewModel = Provider.of<SettingsViewModel>(
          context,
          listen: false,
        );
        final authViewModel = Provider.of<AuthViewModel>(
          context,
          listen: false,
        );

        final email = settingsViewModel.getSavedEmail();
        final password = settingsViewModel.getSavedPassword();

        if (email != null && password != null) {
          final success = await authViewModel.signInWithEmailAndPassword(
            email,
            password,
          );

          if (success && mounted) {
            // 로그인 성공 시 홈 화면으로 이동
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            // 로그인 실패 시 오류 메시지 표시
            setState(() {
              _errorMessage = '자동 로그인에 실패했습니다. 이메일과 비밀번호를 직접 입력해주세요.';
              _isAuthenticating = false;
            });
          }
        } else {
          // 저장된 로그인 정보가 없는 경우
          setState(() {
            _errorMessage = '저장된 로그인 정보가 없습니다. 이메일과 비밀번호를 직접 입력해주세요.';
            _isAuthenticating = false;
          });
        }
      } else {
        // 인증 실패 시
        setState(() {
          _errorMessage = '생체인증에 실패했습니다. 다시 시도하거나 이메일과 비밀번호로 로그인하세요.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      // 오류 발생 시
      setState(() {
        _errorMessage = '생체인증 중 오류가 발생했습니다: ${e.toString()}';
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 로고 및 앱 이름
                Icon(
                  Icons.currency_bitcoin,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '생체인증 로그인',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '지문 또는 Face ID로 로그인하세요',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // 생체인증 아이콘
                Icon(Icons.fingerprint, size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 24),

                // 오류 메시지
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 생체인증 시도 버튼
                ElevatedButton(
                  onPressed: _isAuthenticating
                      ? null
                      : _authenticateWithBiometrics,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('생체인증 시도'),
                ),
                const SizedBox(height: 16),

                // 일반 로그인 화면으로 이동 버튼
                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                  child: const Text('이메일과 비밀번호로 로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
