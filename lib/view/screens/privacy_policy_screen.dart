import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../viewmodel/settings_viewmodel.dart';
import 'package:provider/provider.dart';

// 개인정보 처리방침 화면
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // 언어 상태 (true: 한국어, false: 영어)
  bool _isKorean = true;

  @override
  void initState() {
    super.initState();
    // 초기 언어 설정은 앱 전체 설정을 따름
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final language = Provider.of<SettingsViewModel>(
        context,
        listen: false,
      ).language;
      setState(() {
        _isKorean = language == '한국어';
      });
    });
  }

  // 언어 변경 처리
  void _toggleLanguage() {
    setState(() {
      _isKorean = !_isKorean;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isKorean ? '개인정보 처리방침' : 'Privacy Policy')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 언어 전환 스위치
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isKorean ? '언어 / Language' : 'Language / 언어',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'English',
                        style: TextStyle(
                          fontWeight: !_isKorean
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !_isKorean
                              ? AppTheme.primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                      Switch(
                        value: _isKorean,
                        onChanged: (value) => _toggleLanguage(),
                        activeColor: AppTheme.primaryColor,
                      ),
                      Text(
                        '한국어',
                        style: TextStyle(
                          fontWeight: _isKorean
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _isKorean
                              ? AppTheme.primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // 문서 내용
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Text(
                        _isKorean ? '개인정보 처리방침' : 'Privacy Policy',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _isKorean
                            ? '최종 업데이트: 2024년 6월 12일'
                            : 'Last Updated: June 12, 2024',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).hintColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 내용
                      _isKorean
                          ? _buildKoreanPrivacyPolicy()
                          : _buildEnglishPrivacyPolicy(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 한국어 개인정보 처리방침
  Widget _buildKoreanPrivacyPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          '1. 개인정보 수집 항목',
          '코인 알람("당사")은 서비스 제공을 위해 다음과 같은 개인정보를 수집할 수 있습니다:\n\n'
              '• 필수 항목: 이메일 주소, 비밀번호\n'
              '• 선택 항목: 프로필 이름, 프로필 사진\n'
              '• 자동 수집 항목: 기기 정보, IP 주소, 앱 사용 기록, 오류 로그',
        ),

        _buildSection(
          '2. 개인정보 수집 목적',
          '당사는 다음과 같은 목적으로 개인정보를 수집 및 이용합니다:\n\n'
              '• 회원 식별 및 가입 의사 확인\n'
              '• 서비스 제공 및 개선\n'
              '• 알림 및 공지사항 전달\n'
              '• 앱 성능 분석 및 오류 해결',
        ),

        _buildSection(
          '3. 개인정보 보유 및 이용 기간',
          '개인정보는 회원 탈퇴 시 또는 수집 및 이용 목적이 달성된 후 지체없이 파기됩니다. 다만, 관련 법령에 따라 보존할 필요가 있는 경우 해당 기간 동안 보관됩니다.\n\n'
              '• 계정 정보: 회원 탈퇴 시까지\n'
              '• 거래 기록: 전자상거래법에 따라 5년\n'
              '• 접속 로그: 통신비밀보호법에 따라 3개월',
        ),

        _buildSection(
          '4. API 키 보안',
          '당사는 사용자가 입력한 Upbit, Binance 등의 암호화폐 거래소 API 키를 다음과 같이 처리합니다:\n\n'
              '• API 키는 사용자의 로컬 기기에만 저장되며, 당사의 서버로 전송되지 않습니다.\n'
              '• 저장된 API 키는 암호화되어 보관됩니다.\n'
              '• 앱 삭제 시 모든 API 키 정보는 자동으로 삭제됩니다.',
        ),

        _buildSection(
          '5. 제3자 제공',
          '당사는 원칙적으로 사용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외적으로 제공될 수 있습니다:\n\n'
              '• 사용자의 명시적 동의가 있는 경우\n'
              '• 법령에 의해 요구되는 경우\n'
              '• 서비스 제공에 필요한 업무 위탁 시',
        ),

        _buildSection(
          '6. 사용자의 권리',
          '사용자는 언제든지 자신의 개인정보에 대해 다음과 같은 권리를 행사할 수 있습니다:\n\n'
              '• 개인정보 열람 요청\n'
              '• 개인정보 정정 및 삭제 요청\n'
              '• 개인정보 처리 정지 요청\n'
              '• 회원 탈퇴',
        ),

        _buildSection(
          '7. 개인정보 보호 조치',
          '당사는 사용자의 개인정보를 안전하게 보호하기 위해 다음과 같은 조치를 취하고 있습니다:\n\n'
              '• 개인정보 암호화\n'
              '• 접근 제어 시스템 구축\n'
              '• 정기적인 보안 업데이트\n'
              '• 개인정보 취급자 교육',
        ),

        _buildSection(
          '8. 개인정보 관리 책임자',
          '개인정보 관리 책임자: 코인알람 개발팀\n'
              '이메일: privacy@coinalarm.com',
        ),

        _buildSection(
          '9. 개인정보 처리방침 변경',
          '본 개인정보 처리방침은 법률 또는 서비스 변경사항을 반영하기 위해 수시로 업데이트될 수 있습니다. 변경사항이 있을 경우 앱 내 공지사항 또는 이메일을 통해 사용자에게 알립니다.',
        ),
      ],
    );
  }

  // 영어 개인정보 처리방침
  Widget _buildEnglishPrivacyPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          '1. Information We Collect',
          'Coin Alarm ("we," "us," or "our") may collect the following personal information to provide our services:\n\n'
              '• Required: Email address, password\n'
              '• Optional: Profile name, profile picture\n'
              '• Automatically collected: Device information, IP address, app usage records, error logs',
        ),

        _buildSection(
          '2. Purpose of Data Collection',
          'We collect and use personal information for the following purposes:\n\n'
              '• Member identification and verification\n'
              '• Service provision and improvement\n'
              '• Notifications and announcements\n'
              '• App performance analysis and error resolution',
        ),

        _buildSection(
          '3. Data Retention Period',
          'Personal information is deleted promptly after account termination or when the purpose of collection is achieved. However, certain information may be retained as required by applicable laws.\n\n'
              '• Account information: Until account termination\n'
              '• Transaction records: 5 years (as required by e-commerce laws)\n'
              '• Access logs: 3 months (as required by telecommunications laws)',
        ),

        _buildSection(
          '4. API Key Security',
          'We handle cryptocurrency exchange API keys (such as Upbit, Binance) as follows:\n\n'
              '• API keys are stored only on the user\'s local device and are not transmitted to our servers.\n'
              '• Stored API keys are encrypted.\n'
              '• All API key information is automatically deleted when the app is uninstalled.',
        ),

        _buildSection(
          '5. Third-Party Disclosure',
          'We do not share your personal information with third parties, except in the following cases:\n\n'
              '• With your explicit consent\n'
              '• When required by law\n'
              '• For service-related operations that require outsourcing',
        ),

        _buildSection(
          '6. User Rights',
          'Users may exercise the following rights regarding their personal information at any time:\n\n'
              '• Request access to personal information\n'
              '• Request correction or deletion of personal information\n'
              '• Request restriction of processing\n'
              '• Account termination',
        ),

        _buildSection(
          '7. Security Measures',
          'We implement the following measures to protect your personal information:\n\n'
              '• Data encryption\n'
              '• Access control systems\n'
              '• Regular security updates\n'
              '• Training for personnel handling personal information',
        ),

        _buildSection(
          '8. Data Protection Officer',
          'Data Protection Officer: Coin Alarm Development Team\n'
              'Email: privacy@coinalarm.com',
        ),

        _buildSection(
          '9. Changes to Privacy Policy',
          'This Privacy Policy may be updated periodically to reflect changes in laws or our services. We will notify users of any changes through in-app announcements or email.',
        ),
      ],
    );
  }

  // 섹션 위젯
  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
        const SizedBox(height: 24),
      ],
    );
  }
}
