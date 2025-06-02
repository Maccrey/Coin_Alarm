import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import 'login_screen.dart';

// 설정 화면
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 로그아웃
  Future<void> _logout() async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로그인 정보 저장 설정이 해제된 경우, 저장된 정보 삭제
    final settingsViewModel = Provider.of<SettingsViewModel>(
      context,
      listen: false,
    );
    if (!settingsViewModel.saveLoginInfo) {
      // ViewModel의 메서드에는 이미 로그인 정보 삭제 로직이 포함되어 있음
    }

    // 로그아웃 처리
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.signOut();

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Consumer2<AuthViewModel, SettingsViewModel>(
        builder: (context, authViewModel, settingsViewModel, child) {
          return ListView(
            children: [
              // 계정 섹션
              _buildSectionHeader('계정'),
              if (authViewModel.isLoggedIn) _buildAccountInfo(authViewModel),

              // 로그인 관련 설정
              if (authViewModel.isLoggedIn)
                _buildLoginSettings(settingsViewModel),

              // 앱 설정 섹션
              _buildSectionHeader('앱 설정'),
              _buildThemeSettings(settingsViewModel),
              _buildRefreshIntervalSettings(settingsViewModel),
              _buildNotificationSettings(settingsViewModel),
              _buildSecuritySettings(settingsViewModel),
              _buildLanguageSettings(settingsViewModel),

              // 기타 섹션
              _buildSectionHeader('기타'),
              _buildMiscSettings(),

              // 설정 초기화 및 로그아웃 버튼
              _buildActionButtons(authViewModel, settingsViewModel),
            ],
          );
        },
      ),
    );
  }

  // 로그인 설정 위젯
  Widget _buildLoginSettings(SettingsViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('로그인 정보 저장'),
            subtitle: const Text('이메일과 비밀번호를 기기에 저장합니다'),
            value: viewModel.saveLoginInfo,
            onChanged: (value) => viewModel.setSaveLoginInfo(value),
            secondary: const Icon(Icons.login),
          ),
          if (viewModel.saveLoginInfo)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '주의: 개인 기기가 아닌 경우 사용하지 마세요',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // 설정 초기화
  Future<void> _resetSettings(SettingsViewModel viewModel) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 설정을 기본값으로 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모든 설정이 초기화되었습니다')));
      }
    }
  }

  // 섹션 헤더 위젯
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // 계정 정보 위젯
  Widget _buildAccountInfo(AuthViewModel authViewModel) {
    final user = authViewModel.currentUser;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  radius: 32,
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '사용자',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'email@example.com',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // TODO: 프로필 편집 화면으로 이동
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('프로필 편집'),
            ),
          ],
        ),
      ),
    );
  }

  // 테마 설정 위젯
  Widget _buildThemeSettings(SettingsViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 16),
                const Text(
                  '테마',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  AppTheme.getThemeModeName(viewModel.themeMode),
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),

          const Divider(),

          // 시스템 설정 사용
          _buildThemeTile(
            title: '시스템 설정 사용',
            subtitle: '기기의 테마 설정을 따릅니다',
            icon: Icons.settings_brightness,
            selected: viewModel.themeMode == ThemeMode.system,
            onTap: viewModel.isLoading
                ? null
                : () => viewModel.setThemeMode(ThemeMode.system),
          ),

          // 라이트 모드
          _buildThemeTile(
            title: '라이트 모드',
            subtitle: '밝은 색상의 테마를 사용합니다',
            icon: Icons.wb_sunny_outlined,
            selected: viewModel.themeMode == ThemeMode.light,
            onTap: viewModel.isLoading
                ? null
                : () => viewModel.setThemeMode(ThemeMode.light),
            color: AppTheme.lightBackgroundColor,
            textColor: AppTheme.lightTextColor,
          ),

          // 다크 모드
          _buildThemeTile(
            title: '다크 모드',
            subtitle: '어두운 색상의 테마를 사용합니다',
            icon: Icons.nightlight_round,
            selected: viewModel.themeMode == ThemeMode.dark,
            onTap: viewModel.isLoading
                ? null
                : () => viewModel.setThemeMode(ThemeMode.dark),
            color: AppTheme.darkBackgroundColor,
            textColor: AppTheme.darkTextColor,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // 테마 선택 타일 위젯
  Widget _buildThemeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
    Color? color,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 테마 색상 미리보기
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryColor
                      : Colors.grey.withOpacity(0.3),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(
                icon,
                color: textColor ?? Theme.of(context).iconTheme.color,
              ),
            ),
            const SizedBox(width: 16),

            // 테마 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),

            // 선택 표시
            if (selected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  // 새로고침 간격 설정 위젯
  Widget _buildRefreshIntervalSettings(SettingsViewModel viewModel) {
    // 간격별 표시 정보
    final intervalInfo = {
      10: {'text': '10초', 'description': '실시간에 가까운 빠른 업데이트'},
      30: {'text': '30초', 'description': '균형 잡힌 업데이트 주기'},
      60: {'text': '1분', 'description': '배터리 절약 모드'},
      300: {'text': '5분', 'description': '최대 배터리 절약 모드'},
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.refresh),
                const SizedBox(width: 16),
                const Text(
                  '데이터 새로고침 간격',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  intervalInfo[viewModel.refreshInterval]?['text'] ??
                      '${viewModel.refreshInterval}초',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),

          const Divider(),

          // 간격 선택 슬라이더
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                // 현재 선택된 간격 표시
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        intervalInfo[viewModel.refreshInterval]?['text'] ??
                            '${viewModel.refreshInterval}초',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intervalInfo[viewModel
                                .refreshInterval]?['description'] ??
                            '사용자 지정 간격',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 슬라이더
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    trackHeight: 4,
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 2,
                    ),
                  ),
                  child: Slider(
                    value: _getSliderValue(viewModel.refreshInterval),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: viewModel.isLoading
                        ? null
                        : (value) {
                            final interval = _getIntervalFromSlider(value);
                            viewModel.setRefreshInterval(interval);
                          },
                  ),
                ),

                // 간격 라벨
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '10초',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      Text(
                        '30초',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      Text(
                        '1분',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      Text(
                        '5분',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 설명
                Text(
                  '새로고침 간격이 짧을수록 배터리 소모가 증가합니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 슬라이더 값 변환 (간격 -> 슬라이더 값)
  double _getSliderValue(int interval) {
    switch (interval) {
      case 10:
        return 0;
      case 30:
        return 1;
      case 60:
        return 2;
      case 300:
        return 3;
      default:
        return 1; // 기본값 30초
    }
  }

  // 슬라이더 값 변환 (슬라이더 값 -> 간격)
  int _getIntervalFromSlider(double value) {
    final intValue = value.round();
    switch (intValue) {
      case 0:
        return 10;
      case 1:
        return 30;
      case 2:
        return 60;
      case 3:
        return 300;
      default:
        return 30;
    }
  }

  // 알림 설정 위젯
  Widget _buildNotificationSettings(SettingsViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SwitchListTile(
          title: const Text('푸시 알림'),
          subtitle: const Text('가격 알림 및 중요 소식 알림 받기'),
          secondary: const Icon(Icons.notifications_outlined),
          value: viewModel.pushNotificationsEnabled,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setPushNotificationsEnabled(value),
        ),
      ),
    );
  }

  // 보안 설정 위젯
  Widget _buildSecuritySettings(SettingsViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SwitchListTile(
          title: const Text('생체 인증 사용'),
          subtitle: const Text('지문 또는 얼굴 인식으로 로그인'),
          secondary: const Icon(Icons.fingerprint),
          value: viewModel.useBiometricAuth,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setUseBiometricAuth(value),
        ),
      ),
    );
  }

  // 언어 설정 위젯
  Widget _buildLanguageSettings(SettingsViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: const Text('언어'),
        subtitle: Text(viewModel.language),
        leading: const Icon(Icons.language),
        trailing: const Icon(Icons.chevron_right),
        onTap: viewModel.isLoading
            ? null
            : () {
                // 언어 선택 바텀시트 표시
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.3),
                        child: const Text(
                          '언어 설정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('한국어'),
                        leading: Radio<String>(
                          value: '한국어',
                          groupValue: viewModel.language,
                          onChanged: null,
                        ),
                        trailing: viewModel.language == '한국어'
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          viewModel.setLanguage('한국어');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('English (준비 중)'),
                        leading: Radio<String>(
                          value: 'English',
                          groupValue: viewModel.language,
                          onChanged: null,
                        ),
                        enabled: false,
                        onTap: null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
      ),
    );
  }

  // 기타 섹션 위젯
  Widget _buildMiscSettings() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: const Text('앱 정보'),
            subtitle: const Text('버전, 라이선스 등'),
            leading: const Icon(Icons.info_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAppInfo,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: const Text('개인정보 처리방침'),
            leading: const Icon(Icons.privacy_tip_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 개인정보 처리방침 화면으로 이동
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: const Text('이용약관'),
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 이용약관 화면으로 이동
            },
          ),
        ],
      ),
    );
  }

  // 설정 초기화 및 로그아웃 버튼 위젯
  Widget _buildActionButtons(
    AuthViewModel authViewModel,
    SettingsViewModel settingsViewModel,
  ) {
    return Column(
      children: [
        // 설정 초기화 버튼
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: settingsViewModel.isLoading
                ? null
                : () => _resetSettings(settingsViewModel),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    '설정 초기화',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 로그아웃 버튼 (로그인된 경우에만 표시)
        if (authViewModel.isLoggedIn)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: authViewModel.isLoading ? null : _logout,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 하단 여백
        const SizedBox(height: 32),
      ],
    );
  }

  // 앱 정보 다이얼로그 표시
  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: '1.0.0 (개발 버전)',
      applicationIcon: Icon(
        Icons.currency_bitcoin,
        size: 48,
        color: AppTheme.primaryColor,
      ),
      applicationLegalese: '© 2024 CoinAlarm, Inc. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text('코인 알람은 가상화폐 가격 모니터링 및 알림 서비스를 제공합니다.'),
        const SizedBox(height: 8),
        const Text('개발: Flutter, Supabase'),
      ],
    );
  }
}
