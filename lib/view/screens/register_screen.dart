import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../viewmodel/auth_viewmodel.dart';
import 'home_screen.dart';

// 회원가입 화면
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  // 텍스트 컨트롤러
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 비밀번호 표시 여부
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 회원가입 시도
  Future<void> _signUp() async {
    // 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 키보드 닫기
    FocusScope.of(context).unfocus();

    // 회원가입 시도
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      name: _nameController.text.trim(),
    );

    if (success && mounted) {
      // 회원가입 성공 시 홈 화면으로 이동
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 테마 데이터
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
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
                      // 앱 아이콘
                      Icon(
                        Icons.currency_bitcoin,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '새 계정 만들기',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),

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

                      // 이름 입력 필드
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          hintText: '이름을 입력하세요',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '이름을 입력하세요';
                          }
                          return null;
                        },
                        enabled: !authViewModel.isLoading,
                      ),
                      const SizedBox(height: 16),

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
                      const SizedBox(height: 16),

                      // 비밀번호 확인 입력 필드
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: '비밀번호 확인',
                          hintText: '비밀번호를 다시 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 다시 입력하세요';
                          }
                          if (value != _passwordController.text) {
                            return '비밀번호가 일치하지 않습니다';
                          }
                          return null;
                        },
                        enabled: !authViewModel.isLoading,
                      ),
                      const SizedBox(height: 32),

                      // 회원가입 버튼
                      ElevatedButton(
                        onPressed: authViewModel.isLoading ? null : _signUp,
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
                            : const Text('회원가입'),
                      ),
                      const SizedBox(height: 16),

                      // 로그인 화면으로 돌아가기
                      TextButton(
                        onPressed: authViewModel.isLoading
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text('이미 계정이 있으신가요? 로그인하기'),
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
