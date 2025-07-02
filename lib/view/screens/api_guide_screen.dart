import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

// API 발급 안내 화면
class ApiGuideScreen extends StatefulWidget {
  final String exchange;

  const ApiGuideScreen({super.key, required this.exchange});

  @override
  State<ApiGuideScreen> createState() => _ApiGuideScreenState();
}

class _ApiGuideScreenState extends State<ApiGuideScreen> {
  late final String exchangeName;
  late final String logoAsset;
  late final Color primaryColor;
  late final String websiteUrl;

  @override
  void initState() {
    super.initState();

    // 거래소에 따른 설정
    if (widget.exchange == 'upbit') {
      exchangeName = '업비트';
      logoAsset = 'assets/images/upbit_logo.png'; // 로고 에셋 경로 (추후 추가 필요)
      primaryColor = const Color(0xFF0062DF); // 업비트 메인 색상
      websiteUrl = 'https://upbit.com';
    } else {
      exchangeName = '바이낸스';
      logoAsset = 'assets/images/binance_logo.png'; // 로고 에셋 경로 (추후 추가 필요)
      primaryColor = const Color(0xFFF0B90B); // 바이낸스 메인 색상
      websiteUrl = 'https://www.binance.com';
    }
  }

  // 웹사이트 열기
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$url을 열 수 없습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$exchangeName API 발급 방법')),
      body: widget.exchange == 'upbit'
          ? _buildUpbitGuide()
          : _buildBinanceGuide(),
    );
  }

  // 업비트 API 발급 안내 위젯
  Widget _buildUpbitGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          _buildSectionTitle('1. 업비트 로그인'),
          _buildStep(
            '업비트 웹사이트(upbit.com)에 접속하여 로그인합니다.',
            'assets/images/upbit_guide_1.png', // 이미지 에셋 경로 (추후 추가 필요)
          ),

          _buildSectionTitle('2. 개발자 센터 접속'),
          _buildStep(
            '화면 하단의 푸터 메뉴에서 "개발자 센터"를 클릭하거나 직접 docs.upbit.com에 접속합니다.',
            'assets/images/upbit_guide_2.png',
          ),

          _buildSectionTitle('3. Open API 관리 페이지 접속'),
          _buildStep(
            '로그인 후 우측 상단의 프로필 아이콘을 클릭하고 "Open API 관리"를 선택합니다.',
            'assets/images/upbit_guide_3.png',
          ),

          _buildSectionTitle('4. API 키 발급'),
          _buildStep(
            '보안 인증 후 "Open API 키 관리" 페이지에서 "Open API 신청" 버튼을 클릭합니다.',
            'assets/images/upbit_guide_4.png',
          ),

          _buildSectionTitle('5. API 키 정보 확인'),
          _buildStep(
            'Access Key와 Secret Key가 발급됩니다. Secret Key는 발급 시에만 확인 가능하므로 반드시 안전한 곳에 저장해두세요.',
            'assets/images/upbit_guide_5.png',
          ),

          _buildSectionTitle('6. 앱에 API 키 입력'),
          _buildStep(
            '발급받은 Access Key와 Secret Key를 앱의 설정 화면에 입력합니다.',
            'assets/images/upbit_guide_6.png',
          ),

          const SizedBox(height: 24),
          _buildWarningBox(),
          const SizedBox(height: 16),
          _buildWebsiteButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 바이낸스 API 발급 안내 위젯
  Widget _buildBinanceGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          _buildSectionTitle('1. 바이낸스 로그인'),
          _buildStep(
            '바이낸스 웹사이트(binance.com)에 접속하여 로그인합니다.',
            'assets/images/binance_guide_1.png', // 이미지 에셋 경로 (추후 추가 필요)
          ),

          _buildSectionTitle('2. API 관리 페이지 접속'),
          _buildStep(
            '우측 상단의 프로필 아이콘을 클릭한 후 "API 관리"를 선택합니다.',
            'assets/images/binance_guide_2.png',
          ),

          _buildSectionTitle('3. API 키 생성'),
          _buildStep(
            '"새 API 키 생성" 버튼을 클릭하고, API 키의 이름을 입력합니다.',
            'assets/images/binance_guide_3.png',
          ),

          _buildSectionTitle('4. 보안 인증'),
          _buildStep(
            '이메일 인증 및 2단계 인증(2FA)을 완료합니다.',
            'assets/images/binance_guide_4.png',
          ),

          _buildSectionTitle('5. API 키 권한 설정'),
          _buildStep(
            '필요한 API 권한을 선택합니다. 기본적으로 "읽기 전용" 권한만 선택하는 것이 안전합니다.',
            'assets/images/binance_guide_5.png',
          ),

          _buildSectionTitle('6. API 키 정보 확인'),
          _buildStep(
            'API Key와 Secret Key가 발급됩니다. Secret Key는 발급 시에만 확인 가능하므로 반드시 안전한 곳에 저장해두세요.',
            'assets/images/binance_guide_6.png',
          ),

          _buildSectionTitle('7. 앱에 API 키 입력'),
          _buildStep(
            '발급받은 API Key와 Secret Key를 앱의 설정 화면에 입력합니다.',
            'assets/images/binance_guide_7.png',
          ),

          const SizedBox(height: 24),
          _buildWarningBox(),
          const SizedBox(height: 16),
          _buildWebsiteButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 헤더 위젯
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 로고 이미지 (실제 이미지로 교체 필요)
        Container(
          height: 60,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              exchangeName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$exchangeName API 키 발급 가이드',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '$exchangeName API 키를 발급받아 앱에 연동하는 방법을 안내합니다.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // 섹션 제목 위젯
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  // 단계별 설명 위젯
  Widget _buildStep(String description, String imagePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        // 이미지 (실제 이미지로 교체 필요)
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: const Center(child: Text('스크린샷 이미지')),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 경고 박스 위젯
  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                '보안 주의사항',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• API 키는 절대 타인과 공유하지 마세요.\n'
            '• Secret Key는 안전한 곳에 보관하세요.\n'
            '• 필요한 권한만 선택적으로 부여하세요.\n'
            '• 더 이상 사용하지 않는 API 키는 삭제하세요.\n'
            '• 정기적으로 API 키를 갱신하는 것이 좋습니다.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 웹사이트 버튼 위젯
  Widget _buildWebsiteButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(websiteUrl),
        icon: const Icon(Icons.open_in_new),
        label: Text('$exchangeName 웹사이트 방문하기'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
