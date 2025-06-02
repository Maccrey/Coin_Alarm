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

              // 앱 설정 섹션
              _buildSectionHeader('앱 설정'),
              _buildThemeSettings(settingsViewModel),
              _buildRefreshIntervalSettings(settingsViewModel),
              _buildNotificationSettings(settingsViewModel),
              _buildSecuritySettings(settingsViewModel),
              _buildLanguageSettings(settingsViewModel),

              // 기타 섹션
              _buildSectionHeader('기타'),
              _buildListTile(
                title: '앱 정보',
                subtitle: '버전, 라이선스 등',
                icon: Icons.info_outline,
                onTap: _showAppInfo,
              ),
              _buildListTile(
                title: '개인정보 처리방침',
                icon: Icons.privacy_tip_outlined,
                onTap: () {
                  // TODO: 개인정보 처리방침 화면으로 이동
                },
              ),
              _buildListTile(
                title: '이용약관',
                icon: Icons.description_outlined,
                onTap: () {
                  // TODO: 이용약관 화면으로 이동
                },
              ),

              // 설정 초기화 버튼
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton(
                  onPressed: settingsViewModel.isLoading
                      ? null
                      : () => _resetSettings(settingsViewModel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                  ),
                  child: const Text('설정 초기화'),
                ),
              ),

              // 로그아웃 버튼
              if (authViewModel.isLoggedIn)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: authViewModel.isLoading ? null : _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const Text('로그아웃'),
                  ),
                ),

              // 하단 여백
              const SizedBox(height: 32),
            ],
          );
        },
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
    return ExpansionTile(
      title: const Text('테마'),
      leading: const Icon(Icons.palette_outlined),
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('시스템 설정 사용'),
          value: ThemeMode.system,
          groupValue: viewModel.themeMode,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setThemeMode(value!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('라이트 모드'),
          value: ThemeMode.light,
          groupValue: viewModel.themeMode,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setThemeMode(value!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('다크 모드'),
          value: ThemeMode.dark,
          groupValue: viewModel.themeMode,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setThemeMode(value!),
        ),
      ],
    );
  }

  // 새로고침 간격 설정 위젯
  Widget _buildRefreshIntervalSettings(SettingsViewModel viewModel) {
    return ExpansionTile(
      title: const Text('데이터 새로고침 간격'),
      leading: const Icon(Icons.refresh),
      children: [
        RadioListTile<int>(
          title: const Text('10초'),
          value: 10,
          groupValue: viewModel.refreshInterval,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setRefreshInterval(value!),
        ),
        RadioListTile<int>(
          title: const Text('30초'),
          value: 30,
          groupValue: viewModel.refreshInterval,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setRefreshInterval(value!),
        ),
        RadioListTile<int>(
          title: const Text('1분'),
          value: 60,
          groupValue: viewModel.refreshInterval,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setRefreshInterval(value!),
        ),
        RadioListTile<int>(
          title: const Text('5분'),
          value: 300,
          groupValue: viewModel.refreshInterval,
          onChanged: viewModel.isLoading
              ? null
              : (value) => viewModel.setRefreshInterval(value!),
        ),
      ],
    );
  }

  // 알림 설정 위젯
  Widget _buildNotificationSettings(SettingsViewModel viewModel) {
    return SwitchListTile(
      title: const Text('푸시 알림'),
      subtitle: const Text('가격 알림 및 중요 소식 알림 받기'),
      secondary: const Icon(Icons.notifications_outlined),
      value: viewModel.pushNotificationsEnabled,
      onChanged: viewModel.isLoading
          ? null
          : (value) => viewModel.setPushNotificationsEnabled(value),
    );
  }

  // 보안 설정 위젯
  Widget _buildSecuritySettings(SettingsViewModel viewModel) {
    return SwitchListTile(
      title: const Text('생체 인증 사용'),
      subtitle: const Text('지문 또는 얼굴 인식으로 로그인'),
      secondary: const Icon(Icons.fingerprint),
      value: viewModel.useBiometricAuth,
      onChanged: viewModel.isLoading
          ? null
          : (value) => viewModel.setUseBiometricAuth(value),
    );
  }

  // 언어 설정 위젯
  Widget _buildLanguageSettings(SettingsViewModel viewModel) {
    return _buildListTile(
      title: '언어',
      subtitle: viewModel.language,
      icon: Icons.language,
      onTap: viewModel.isLoading
          ? null
          : () {
              // 언어 선택 바텀시트 표시
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('한국어'),
                      leading: Radio<String>(
                        value: '한국어',
                        groupValue: viewModel.language,
                        onChanged: null,
                      ),
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
                  ],
                ),
              );
            },
    );
  }

  // 기본 리스트 아이템 위젯
  Widget _buildListTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
