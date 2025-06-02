import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../viewmodel/settings_viewmodel.dart';
import 'package:provider/provider.dart';

// 이용약관 화면
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 언어 설정 가져오기
    final language = Provider.of<SettingsViewModel>(context).language;
    final isKorean = language == '한국어';

    return Scaffold(
      appBar: AppBar(title: Text(isKorean ? '이용약관' : 'Terms of Service')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Text(
                  isKorean ? '이용약관' : 'Terms of Service',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isKorean
                      ? '최종 업데이트: 2024년 6월 12일'
                      : 'Last Updated: June 12, 2024',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).hintColor,
                  ),
                ),

                const SizedBox(height: 24),

                // 내용
                isKorean ? _buildKoreanTerms() : _buildEnglishTerms(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 한국어 이용약관
  Widget _buildKoreanTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          '1. 서비스 소개',
          '코인 알람("서비스")은 암호화폐 가격 모니터링, 알림 설정 및 관련 정보 제공을 목적으로 하는 모바일 애플리케이션입니다. 본 약관은 서비스 이용에 관한 권리와 의무, 책임사항 등 기본적인 사항을 규정합니다.',
        ),

        _buildSection(
          '2. 약관의 효력 및 변경',
          '본 약관은 서비스에 가입한 모든 사용자에게 적용됩니다. 당사는 법률 또는 서비스 정책의 변경사항을 반영하기 위해 본 약관을 변경할 수 있으며, 변경 시 앱 내 공지사항 또는 이메일을 통해 사용자에게 통지합니다. 변경된 약관은 공지일로부터 7일 후 효력이 발생하며, 계속해서 서비스를 이용하는 경우 약관 변경에 동의한 것으로 간주됩니다.',
        ),

        _buildSection(
          '3. 계정 관리',
          '• 서비스 이용을 위해 이메일 주소와 비밀번호로 계정을 생성해야 합니다.\n'
              '• 사용자는 계정 정보를 정확하게 제공하고 최신 상태로 유지해야 합니다.\n'
              '• 계정 정보 및 비밀번호는 본인만 사용해야 하며, 타인에게 공유하거나 양도할 수 없습니다.\n'
              '• 계정 정보 유출이나 무단 사용이 의심되는 경우 즉시 당사에 알려야 합니다.',
        ),

        _buildSection(
          '4. 서비스 이용',
          '• 당사는 서비스의 안정적인 운영을 위해 최선을 다하나, 기술적 문제, 천재지변, 법령 변경 등으로 서비스가 일시 중단될 수 있습니다.\n'
              '• 서비스 개선 또는 점검을 위해 일시적으로 서비스를 중단할 수 있으며, 이 경우 사전에 공지합니다.\n'
              '• 사용자는 서비스를 불법적인 목적이나 타인의 권리를 침해하는 방식으로 이용할 수 없습니다.\n'
              '• API 키 정보는 사용자의 로컬 기기에만 저장되며, 당사는 이에 대한 접근권한이 없습니다.',
        ),

        _buildSection(
          '5. 정보의 정확성',
          '• 당사는 가능한 정확한 정보를 제공하기 위해 노력하나, 제공되는 시세 정보, 뉴스 및 분석 자료의 정확성을 보장하지 않습니다.\n'
              '• 서비스를 통해 제공되는 정보는 투자 조언이 아니며, 투자 결정은 사용자 본인의 책임하에 이루어져야 합니다.\n'
              '• 제3자 서비스(거래소 API 등)로부터 제공받는 정보의 오류로 인한 손실에 대해 당사는 책임을 지지 않습니다.',
        ),

        _buildSection(
          '6. 알림 서비스',
          '• 가격 알림 기능은 최대한 실시간으로 제공되나, 네트워크 상태, 기기 설정 등에 따라 지연될 수 있습니다.\n'
              '• 알림 수신 실패로 인한 손실에 대해 당사는 책임을 지지 않습니다.\n'
              '• 과도한 알림 설정은 서비스 안정성에 영향을 줄 수 있어 제한될 수 있습니다.',
        ),

        _buildSection(
          '7. 저작권 및 지적재산권',
          '서비스 내 제공되는 모든 콘텐츠(텍스트, 이미지, 로고, 디자인 등)는 당사 또는 콘텐츠 제공자의 지적재산권에 의해 보호받으며, 무단 복제, 배포, 수정, 전송 등을 금지합니다.',
        ),

        _buildSection(
          '8. 면책조항',
          '• 당사는 서비스 이용으로 발생한 금전적 손실, 데이터 손실 등에 대해 책임을 지지 않습니다.\n'
              '• 투자 결정에 따른 결과는 전적으로 사용자의 책임입니다.\n'
              '• 천재지변, 전쟁, 해킹, 기술적 장애 등 불가항력적 사유로 인한 서비스 중단에 대해 책임을 지지 않습니다.',
        ),

        _buildSection(
          '9. 계약 해지',
          '• 사용자는 언제든지 계정 삭제를 통해 서비스 이용계약을 해지할 수 있습니다.\n'
              '• 약관 위반, 불법 행위, 타인의 권리 침해 등의 사유가 있는 경우 당사는 사용자의 서비스 이용을 제한하거나 계약을 해지할 수 있습니다.',
        ),

        _buildSection(
          '10. 준거법 및 분쟁해결',
          '본 약관은 대한민국 법률에 따라 규율되며, 서비스 이용과 관련하여 발생한 분쟁은 한국 내 관할 법원을 통해 해결합니다.',
        ),

        _buildSection(
          '11. 고객센터',
          '서비스 이용 관련 문의사항은 앱 내 고객센터 또는 support@coinalarm.com으로 연락 주시기 바랍니다.',
        ),
      ],
    );
  }

  // 영어 이용약관
  Widget _buildEnglishTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          '1. Service Introduction',
          'Coin Alarm ("Service") is a mobile application designed for cryptocurrency price monitoring, alert settings, and related information. These Terms govern the basic rights, obligations, and responsibilities regarding the use of the Service.',
        ),

        _buildSection(
          '2. Effect and Amendment of Terms',
          'These Terms apply to all users who have registered for the Service. We may amend these Terms to reflect changes in laws or service policies and will notify users through in-app announcements or email. Amended Terms will take effect 7 days after notification, and continued use of the Service will be deemed as acceptance of the changes.',
        ),

        _buildSection(
          '3. Account Management',
          '• To use the Service, you must create an account with an email address and password.\n'
              '• Users must provide accurate account information and keep it up to date.\n'
              '• Account information and passwords should only be used by the account owner and cannot be shared or transferred to others.\n'
              '• If you suspect that your account information has been leaked or unauthorized use has occurred, please notify us immediately.',
        ),

        _buildSection(
          '4. Service Usage',
          '• We strive to maintain stable operation of the Service, but it may be temporarily suspended due to technical issues, natural disasters, or changes in laws and regulations.\n'
              '• The Service may be temporarily suspended for improvements or maintenance, which will be announced in advance.\n'
              '• Users may not use the Service for illegal purposes or in ways that infringe upon the rights of others.\n'
              '• API key information is stored only on the user\'s local device, and we do not have access to this information.',
        ),

        _buildSection(
          '5. Accuracy of Information',
          '• While we strive to provide accurate information, we do not guarantee the accuracy of price information, news, and analysis materials provided.\n'
              '• Information provided through the Service is not investment advice, and investment decisions should be made at your own risk.\n'
              '• We are not responsible for losses due to errors in information received from third-party services (such as exchange APIs).',
        ),

        _buildSection(
          '6. Notification Service',
          '• Price alerts are provided as real-time as possible but may be delayed depending on network conditions, device settings, etc.\n'
              '• We are not responsible for losses due to failure to receive notifications.\n'
              '• Excessive alert settings may affect service stability and may be restricted.',
        ),

        _buildSection(
          '7. Copyright and Intellectual Property',
          'All content provided within the Service (text, images, logos, designs, etc.) is protected by our intellectual property rights or those of content providers, and unauthorized reproduction, distribution, modification, or transmission is prohibited.',
        ),

        _buildSection(
          '8. Disclaimer',
          '• We are not responsible for financial losses, data loss, etc. resulting from the use of the Service.\n'
              '• The results of investment decisions are entirely the responsibility of the user.\n'
              '• We are not responsible for service interruptions due to force majeure reasons such as natural disasters, war, hacking, or technical failures.',
        ),

        _buildSection(
          '9. Termination of Agreement',
          '• Users can terminate the Service usage agreement at any time by deleting their account.\n'
              '• We may restrict a user\'s use of the Service or terminate the agreement for reasons such as violations of these Terms, illegal activities, or infringement of others\' rights.',
        ),

        _buildSection(
          '10. Governing Law and Dispute Resolution',
          'These Terms are governed by the laws of the Republic of Korea, and disputes related to the use of the Service will be resolved through competent courts in Korea.',
        ),

        _buildSection(
          '11. Customer Support',
          'For inquiries regarding the use of the Service, please contact the in-app customer center or email support@coinalarm.com.',
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
