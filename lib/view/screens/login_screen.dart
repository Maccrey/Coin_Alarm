import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

// 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  // 텍스트 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 비밀번호 표시 여부
  bool _isPasswordVisible = false;

  // 로그인 정보 저장
  bool _saveLoginInfo = false;

  @override
  void initState() {
    super.initState();
    debugPrint('LoginScreen: initState 호출됨');

    // 화면이 마운트된 후에 저장된 데이터 로드 및 상태 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('LoginScreen: postFrameCallback 호출됨');
      final settingsViewModel = Provider.of<SettingsViewModel>(
        context,
        listen: false,
      );
      debugPrint('LoginScreen: SettingsViewModel 가져오기 성공');

      // Hive에서 저장된 이메일/비밀번호/저장여부 불러오기
      final saveLoginInfo = settingsViewModel.saveLoginInfo;
      setState(() {
        _saveLoginInfo = saveLoginInfo;
      });
      debugPrint('LoginScreen: 로그인 정보 저장 설정 - $_saveLoginInfo');

      if (saveLoginInfo) {
        // 이메일/비밀번호 자동 입력
        final email = settingsViewModel.getSavedEmail();
        final password = settingsViewModel.getSavedPassword();
        if (email != null) _emailController.text = email;
        if (password != null) _passwordController.text = password;
        debugPrint('LoginScreen: 저장된 이메일/비밀번호 로드 완료');
      }
    });

    debugPrint('LoginScreen: initState 완료');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 로그인 시도
  Future<void> _login() async {
    debugPrint('LoginScreen: 로그인 시도 시작');

    // 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      debugPrint('LoginScreen: 폼 유효성 검사 실패');
      return;
    }

    // 키보드 닫기
    FocusScope.of(context).unfocus();
    debugPrint('LoginScreen: 키보드 닫기');

    // 로그인 정보 저장 설정
    try {
      debugPrint('LoginScreen: 로그인 정보 저장 설정 시작');
      final settingsViewModel = Provider.of<SettingsViewModel>(
        context,
        listen: false,
      );
      await settingsViewModel.setSaveLoginInfo(_saveLoginInfo);
      // saveLoginInfo가 true면 이메일/비밀번호 저장, false면 삭제
      if (_saveLoginInfo) {
        await settingsViewModel.setSavedEmail(_emailController.text.trim());
        await settingsViewModel.setSavedPassword(_passwordController.text);
        debugPrint('LoginScreen: 로그인 정보 저장 완료');
      } else {
        await settingsViewModel.clearLoginInfo();
        debugPrint('LoginScreen: 로그인 정보 삭제 완료');
      }
    } catch (e) {
      debugPrint('LoginScreen: 로그인 정보 저장 설정 오류: $e');
    }

    // 로그인 시도
    debugPrint('LoginScreen: AuthViewModel에서 로그인 시도');
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );
    debugPrint('LoginScreen: 로그인 결과 - $success');

    if (success && mounted) {
      // 로그인 성공 시 홈 화면으로 이동
      debugPrint('LoginScreen: 로그인 성공, 홈 화면으로 이동 시작');
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      debugPrint('LoginScreen: 홈 화면으로 이동 완료');
    } else {
      debugPrint('LoginScreen: 로그인 실패 또는 위젯이 마운트되지 않음');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Consumer2<AuthViewModel, SettingsViewModel>(
        builder: (context, authViewModel, settingsViewModel, child) {
          // ViewModel의 saveLoginInfo 값과 체크박스 동기화
          if (_saveLoginInfo != settingsViewModel.saveLoginInfo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _saveLoginInfo = settingsViewModel.saveLoginInfo;
              });
            });
          }
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
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
                        '코인 알람에 오신 것을 환영합니다',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '계정에 로그인하세요',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 48),

                      // 에러 메시지
                      if (authViewModel.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            authViewModel.errorMessage!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),

                      // 이메일 입력 필드
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '이메일을 입력하세요';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return '유효한 이메일 주소를 입력하세요';
                          }
                          return null;
                        },
                        enabled: !authViewModel.isLoading,
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호 입력 필드
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          hintText: '비밀번호를 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력하세요';
                          }
                          if (value.length < 6) {
                            return '비밀번호는 최소 6자 이상이어야 합니다';
                          }
                          return null;
                        },
                        enabled: !authViewModel.isLoading,
                      ),
                      const SizedBox(height: 8),

                      // 로그인 정보 저장 체크박스
                      Row(
                        children: [
                          Checkbox(
                            value: _saveLoginInfo,
                            onChanged: authViewModel.isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _saveLoginInfo = value!;
                                    });
                                    // 체크박스 변경 시 ViewModel에도 반영
                                    settingsViewModel.setSaveLoginInfo(value!);
                                  },
                            activeColor: AppTheme.primaryColor,
                          ),
                          const Text(
                            '로그인 정보 저장',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          // 비밀번호 찾기 링크
                          // 클릭 시 비밀번호 찾기 화면으로 이동
                          TextButton(
                            onPressed: authViewModel.isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              '비밀번호를 잊으셨나요?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 로그인 버튼
                      ElevatedButton(
                        onPressed: authViewModel.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: authViewModel.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('로그인'),
                      ),
                      const SizedBox(height: 16),

                      // 회원가입 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('계정이 없으신가요?'),
                          TextButton(
                            onPressed: authViewModel.isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                            child: const Text('회원가입'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
