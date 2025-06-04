import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../viewmodel/auth_viewmodel.dart';

/// 비밀번호 찾기 화면
/// 사용자가 이메일을 입력하면 비밀번호 재설정 링크를 보내는 기능을 제공합니다.
/// 이메일 전송 성공 시 성공 메시지를 표시하고, 로그인 화면으로 돌아갈 수 있는 버튼을 제공합니다.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  // 이메일 입력 컨트롤러
  final _emailController = TextEditingController();

  // 이메일 전송 완료 상태 (UI 표시 분기 처리용)
  bool _emailSent = false;

  @override
  void dispose() {
    // 컨트롤러 해제
    _emailController.dispose();
    super.dispose();
  }

  /// 비밀번호 재설정 이메일 전송 처리
  /// 1. 폼 유효성 검사
  /// 2. 키보드 닫기
  /// 3. AuthViewModel을 통해 비밀번호 재설정 이메일 전송
  /// 4. 성공 시 UI 상태 업데이트
  Future<void> _sendPasswordResetEmail() async {
    // 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 키보드 닫기
    FocusScope.of(context).unfocus();

    // 비밀번호 재설정 이메일 전송
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    // 성공 시 UI 상태 업데이트
    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 테마 데이터
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기'), elevation: 0),
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
                      // 아이콘
                      Icon(
                        Icons.lock_reset,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 24),

                      // 제목
                      Text(
                        '비밀번호를 잊으셨나요?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),

                      // 설명 텍스트 (상태에 따라 다른 메시지 표시)
                      Text(
                        _emailSent
                            ? '입력하신 이메일로 비밀번호 재설정 링크를 발송했습니다. 이메일을 확인해주세요.'
                            : '가입하신 이메일 주소를 입력하시면 비밀번호 재설정 링크를 보내드립니다.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // 에러 메시지 (에러 발생 및 이메일 전송 전에만 표시)
                      if (authViewModel.errorMessage != null && !_emailSent)
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

                      // 이메일 전송 완료 시 성공 메시지
                      if (_emailSent)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green.shade800,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '비밀번호 재설정 이메일이 발송되었습니다!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '이메일의 링크를 클릭하여 비밀번호를 재설정해주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 이메일 입력 필드 (이메일 전송 전에만 표시)
                      if (!_emailSent)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _sendPasswordResetEmail(),
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
                      const SizedBox(height: 24),

                      // 주요 액션 버튼
                      // 이메일 전송 전: 재설정 링크 전송 버튼
                      // 이메일 전송 후: 로그인 화면으로 돌아가기 버튼
                      ElevatedButton(
                        onPressed: authViewModel.isLoading
                            ? null
                            : _emailSent
                            ? () => Navigator.of(context).pop()
                            : _sendPasswordResetEmail,
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
                            : Text(_emailSent ? '로그인 화면으로 돌아가기' : '재설정 링크 전송'),
                      ),
                      const SizedBox(height: 16),

                      // 이메일 전송 전에만 로그인 화면으로 돌아가기 링크 표시
                      if (!_emailSent)
                        TextButton(
                          onPressed: authViewModel.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('로그인 화면으로 돌아가기'),
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
