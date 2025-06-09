import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../services/strategy_monitoring_service.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Align(alignment: Alignment.centerLeft, child: Text('설정')),
      ),
      body: Consumer2<AuthViewModel, SettingsViewModel>(
        builder: (context, authViewModel, settingsViewModel, child) {
          return ListView(
            children: [
              // 계정 섹션
              _buildSectionHeader('계정'),
              if (authViewModel.isLoggedIn) _buildAccountInfo(authViewModel),

              // 로그인 관련 설정
              if (authViewModel.isLoggedIn)
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildLoginSettings(settingsViewModel),
                ),

              // 앱 설정 섹션
              _buildSectionHeader('앱 설정'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildThemeSettings(settingsViewModel),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildRefreshIntervalSettings(settingsViewModel),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildNotificationSettings(settingsViewModel),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildSecuritySettings(settingsViewModel),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildStrategyMonitoringSettings(),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildLanguageSettings(settingsViewModel),
              ),

              // 거래소 API 설정 섹션
              ExpansionTile(
                title: const Text('거래소 API 설정'),
                subtitle: const Text('거래소 API 키를 설정합니다'),
                leading: const Icon(Icons.api),
                children: [
                  // Upbit API 키 설정
                  ListTile(
                    title: const Text('Upbit API 키 설정'),
                    subtitle: Text(
                      settingsViewModel.upbitAccessKey != null &&
                              settingsViewModel.upbitAccessKey!.isNotEmpty
                          ? '설정됨 (${settingsViewModel.upbitAccessKey!.substring(0, min(4, settingsViewModel.upbitAccessKey!.length))}...)'
                          : '설정되지 않음',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () =>
                        _showApiKeyDialog(context, '업비트', settingsViewModel),
                  ),

                  // Binance API 키 설정
                  ListTile(
                    title: const Text('Binance API 키 설정'),
                    subtitle: Text(
                      settingsViewModel.binanceApiKey != null &&
                              settingsViewModel.binanceApiKey!.isNotEmpty
                          ? '설정됨 (${settingsViewModel.binanceApiKey!.substring(0, min(4, settingsViewModel.binanceApiKey!.length))}...)'
                          : '설정되지 않음',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () =>
                        _showApiKeyDialog(context, '바이낸스', settingsViewModel),
                  ),

                  // API 키 초기화 버튼
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('모든 API 키 초기화'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          _showClearApiKeysDialog(context, settingsViewModel),
                    ),
                  ),
                ],
              ),

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

  // API 키 설정 위젯
  Widget _buildApiKeySettings(SettingsViewModel viewModel) {
    return ExpansionTile(
      title: const Text('API 키 설정'),
      leading: const Icon(Icons.vpn_key_outlined),
      subtitle: Text(
        '${viewModel.hasUpbitApiKeys ? 'Upbit: 설정됨' : 'Upbit: 미설정'}, '
        '${viewModel.hasBinanceApiKeys ? 'Binance: 설정됨' : 'Binance: 미설정'}',
        style: TextStyle(fontSize: 12),
      ),
      children: [
        // Upbit API 키 설정
        ListTile(
          title: const Text('Upbit API 키 설정'),
          subtitle: Text(viewModel.hasUpbitApiKeys ? '설정됨' : '설정되지 않음'),
          leading: const Icon(Icons.security),
          onTap: viewModel.isLoading
              ? null
              : () => _showApiKeyDialog(context, '업비트', viewModel),
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // Binance API 키 설정
        ListTile(
          title: const Text('Binance API 키 설정'),
          subtitle: Text(viewModel.hasBinanceApiKeys ? '설정됨' : '설정되지 않음'),
          leading: const Icon(Icons.security),
          onTap: viewModel.isLoading
              ? null
              : () => _showApiKeyDialog(context, '바이낸스', viewModel),
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // API 키 초기화 버튼
        ListTile(
          title: Text(
            'API 키 초기화',
            style: TextStyle(color: Colors.orange.shade800),
          ),
          subtitle: const Text('저장된 모든 API 키를 삭제합니다'),
          leading: const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(Icons.delete_outline, color: Colors.orange),
          ),
          onTap: viewModel.isLoading
              ? null
              : () => _showClearApiKeysDialog(context, viewModel),
        ),
      ],
    );
  }

  // API 키 입력 다이얼로그
  Future<void> _showApiKeyDialog(
    BuildContext context,
    String exchange,
    SettingsViewModel viewModel,
  ) async {
    debugPrint('SettingsScreen: $exchange API 키 입력 다이얼로그 표시');

    // 기존 저장된 API 키 가져오기
    String initialApiKey = viewModel.hasUpbitApiKeys
        ? viewModel.upbitAccessKey!
        : '';
    String initialSecretKey = viewModel.hasUpbitApiKeys
        ? viewModel.upbitSecretKey!
        : '';

    // 다이얼로그에서 사용할 임시 값들 (초기값 설정)
    String apiKey = initialApiKey.trim();
    String secretKey = ''; // 시크릿 키는 변경 시 항상 새로 입력받음
    bool isSecretKeyChanged = false;

    // StatefulBuilder로 다이얼로그를 감싸서 다이얼로그 내부에서 상태 관리
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('$exchange API 키 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 안내 메시지
                  Text(
                    '${exchange}에서 발급받은 API 키를 입력하세요.\n해당 키는 로컬에만 저장되며, 서버로 전송되지 않습니다.',
                  ),
                  const SizedBox(height: 16),
                  // API 키 입력 - 초기값 설정
                  TextField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '$exchange Access Key',
                      helperText: '공백 없이 정확하게 입력하세요',
                    ),
                    controller: TextEditingController(text: initialApiKey),
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (value) {
                      apiKey = value.trim(); // 입력 시 trim() 적용
                    },
                  ),
                  const SizedBox(height: 12),
                  // Secret 키 입력
                  TextField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '$exchange Secret Key',
                      helperText: initialSecretKey.isNotEmpty
                          ? '변경 시에만 입력하세요. 공백 없이 정확하게 입력하세요.'
                          : '공백 없이 정확하게 입력하세요',
                    ),
                    controller: TextEditingController(),
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: true,
                    onChanged: (value) {
                      secretKey = value.trim(); // 입력 시 trim() 적용
                      isSecretKeyChanged = secretKey.isNotEmpty; // 트림된 값으로 체크
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    // 저장 전 마지막으로 공백 제거
                    apiKey = apiKey.trim();
                    secretKey = secretKey.trim();

                    // API 키가 비어있으면 경고
                    if (apiKey.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API Key를 입력해주세요')),
                      );
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    // 다이얼로그 결과 처리
    if (result == true) {
      // 저장 전 마지막으로 한 번 더 공백 제거
      apiKey = apiKey.trim();
      secretKey = secretKey.trim();

      if (apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('API Key를 입력해주세요')));
        }
        return;
      }

      try {
        if (exchange == '업비트') {
          // Secret 키는 변경된 경우만 저장, 아니면 기존 값 사용
          final finalSecretKey = isSecretKeyChanged
              ? secretKey
              : (viewModel.upbitSecretKey ?? '').trim();

          // Secret 키가 없는 경우 경고
          if (finalSecretKey.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Secret Key를 입력해주세요')),
              );
            }
            return;
          }

          await viewModel.setUpbitApiKeys(apiKey, finalSecretKey);
          debugPrint(
            'SettingsScreen: 업비트 API 키 저장 완료 - 길이: ${apiKey.length}, Secret 키 길이: ${finalSecretKey.length}',
          );
        } else if (exchange == '바이낸스') {
          // Secret 키는 변경된 경우만 저장, 아니면 기존 값 사용
          final finalSecretKey = isSecretKeyChanged
              ? secretKey
              : (viewModel.binanceSecretKey ?? '').trim();

          // Secret 키가 없는 경우 경고
          if (finalSecretKey.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Secret Key를 입력해주세요')),
              );
            }
            return;
          }

          await viewModel.setBinanceApiKeys(apiKey, finalSecretKey);
          debugPrint(
            'SettingsScreen: 바이낸스 API 키 저장 완료 - 길이: ${apiKey.length}, Secret 키 길이: ${finalSecretKey.length}',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$exchange API 키가 저장되었습니다')));

          // 저장 후 API 키 길이 확인
          if (exchange == '업비트') {
            debugPrint(
              'SettingsScreen: 저장 후 업비트 키 상태 - Access: ${viewModel.upbitAccessKey?.length ?? 0}, Secret: ${viewModel.upbitSecretKey?.length ?? 0}',
            );
          } else {
            debugPrint(
              'SettingsScreen: 저장 후 바이낸스 키 상태 - API: ${viewModel.binanceApiKey?.length ?? 0}, Secret: ${viewModel.binanceSecretKey?.length ?? 0}',
            );
          }
        }
      } catch (e) {
        debugPrint('SettingsScreen: API 키 저장 중 오류 발생 - $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('API 키 저장 중 오류가 발생했습니다: $e')));
        }
      }
    }
  }

  // API 키 초기화 확인 다이얼로그
  Future<void> _showClearApiKeysDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API 키 초기화'),
        content: const Text('저장된 모든 API 키를 삭제하시겠습니까?'),
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
      await viewModel.clearApiKeys();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모든 API 키가 삭제되었습니다')));
      }
    }
  }

  // 로그인 설정 위젯
  Widget _buildLoginSettings(SettingsViewModel viewModel) {
    return Column(
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
            // TODO: 추후 프로필 편집 기능 구현 예정
            // 아래 '프로필 편집' 버튼은 임시로 주석처리
            /*
            // 예시: 프로필 편집 버튼
            ElevatedButton(
              onPressed: () {
                // TODO: 프로필 편집 기능 구현 예정
              },
              child: Text('프로필 편집'),
            ),
            */
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
      subtitle: Text(AppTheme.getThemeModeName(viewModel.themeMode)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              const Divider(),

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

              const Divider(),

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
            ],
          ),
        ),
      ],
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
    // 간격 설명 생성 함수
    String getIntervalDescription(int seconds) {
      if (seconds < 5) return '매우 빠른 업데이트 (높은 배터리 소모)';
      if (seconds < 15) return '실시간에 가까운 빠른 업데이트';
      if (seconds < 60) return '균형 잡힌 업데이트 주기';
      if (seconds < 120) return '배터리 절약 모드';
      return '최대 배터리 절약 모드';
    }

    // 간격 표시 텍스트
    String getIntervalText(int seconds) {
      if (seconds < 60) return '$seconds초';
      if (seconds < 120) return '1분';
      return '${seconds ~/ 60}분';
    }

    // 슬라이더 값 계산 함수
    double getSliderValue(int seconds) {
      final index = TimeConstants.refreshIntervalOptions.indexOf(seconds);
      if (index != -1) {
        return index.toDouble();
      }
      // 현재 값이 옵션에 없는 경우 가장 가까운 값 찾기
      int nearestIndex = 0;
      int minDiff = (TimeConstants.refreshIntervalOptions[0] - seconds).abs();

      for (int i = 1; i < TimeConstants.refreshIntervalOptions.length; i++) {
        final diff = (TimeConstants.refreshIntervalOptions[i] - seconds).abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearestIndex = i;
        }
      }
      return nearestIndex.toDouble();
    }

    // 슬라이더 값으로부터 간격 가져오기
    int getIntervalFromSlider(double value) {
      final index = value.round();
      if (index >= 0 && index < TimeConstants.refreshIntervalOptions.length) {
        return TimeConstants.refreshIntervalOptions[index];
      }
      return TimeConstants.defaultRefreshIntervalSeconds;
    }

    return ExpansionTile(
      title: const Text('데이터 새로고침 간격'),
      leading: const Icon(Icons.refresh),
      subtitle: Text(getIntervalText(viewModel.refreshInterval)),
      children: [
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
                      getIntervalText(viewModel.refreshInterval),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getIntervalDescription(viewModel.refreshInterval),
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

              // 슬라이더 컨트롤
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.3),
                  thumbColor: Theme.of(context).colorScheme.primary,
                  overlayColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  valueIndicatorColor: Theme.of(context).colorScheme.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  tickMarkShape: const RoundSliderTickMarkShape(
                    tickMarkRadius: 2,
                  ),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                  ),
                  showValueIndicator: ShowValueIndicator.always,
                ),
                child: Slider(
                  min: 0,
                  max: (TimeConstants.refreshIntervalOptions.length - 1)
                      .toDouble(),
                  divisions: TimeConstants.refreshIntervalOptions.length - 1,
                  value: getSliderValue(viewModel.refreshInterval),
                  label: getIntervalText(viewModel.refreshInterval),
                  onChanged: (value) {
                    final interval = getIntervalFromSlider(value);
                    // 새로고침 간격 설정 변경 및 CryptoViewModel에도 알림
                    viewModel.setRefreshInterval(interval);
                    // CryptoViewModel에 변경 알림
                    Provider.of<CryptoViewModel>(
                      context,
                      listen: false,
                    ).updateRefreshInterval(interval);
                  },
                ),
              ),

              // 간격 라벨 표시
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getIntervalText(
                        TimeConstants.refreshIntervalOptions.first,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    Text(
                      getIntervalText(
                        TimeConstants.refreshIntervalOptions[TimeConstants
                                .refreshIntervalOptions
                                .length ~/
                            3],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    Text(
                      getIntervalText(
                        TimeConstants.refreshIntervalOptions[TimeConstants
                                .refreshIntervalOptions
                                .length *
                            2 ~/
                            3],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    Text(
                      getIntervalText(
                        TimeConstants.refreshIntervalOptions.last,
                      ),
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
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<SettingsViewModel>(
          builder: (context, vm, _) => SwitchListTile(
            title: const Text('생체 인증 사용'),
            value: vm.useBiometrics,
            onChanged: (value) async {
              await vm.toggleBiometrics(value);
            },
          ),
        ),
        if (viewModel.biometricErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              viewModel.biometricErrorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: const Text('이용약관'),
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
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
    final viewModel = Provider.of<SettingsViewModel>(context, listen: false);
    final isKorean = viewModel.language == '한국어';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.currency_bitcoin,
              size: 28,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(AppConstants.appName),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            bool _isKorean = viewModel.language == '한국어';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 버전 정보
                Text('버전: 1.0.0 (개발 버전)'),
                const SizedBox(height: 16),

                // 언어 전환 스위치
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '한국어',
                      style: TextStyle(
                        fontWeight: _isKorean
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Switch(
                      value: !_isKorean,
                      onChanged: (value) {
                        setState(() {
                          _isKorean = !_isKorean;
                          viewModel.setLanguage(value ? 'English' : '한국어');
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    Text(
                      'English',
                      style: TextStyle(
                        fontWeight: !_isKorean
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 설명
                Text(
                  _isKorean
                      ? '코인 알람은 가상화폐 가격 모니터링 및 알림 서비스를 제공합니다.'
                      : 'Coin Alarm provides cryptocurrency price monitoring and notification services.',
                ),
                const SizedBox(height: 8),
                Text(
                  _isKorean
                      ? '개발: Flutter, Supabase'
                      : 'Developed with: Flutter, Supabase',
                ),
                const SizedBox(height: 16),

                // 저작권
                Text(
                  _isKorean
                      ? '© 2025 코인알람. 모든 권리 보유.'
                      : '© 2025 CoinAlarm. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isKorean ? '닫기' : 'Close'),
          ),
        ],
      ),
    );
  }

  // 전략 모니터링 서비스 설정 위젯
  Widget _buildStrategyMonitoringSettings() {
    return ExpansionTile(
      title: const Text('전략 기반 알림 모니터링'),
      subtitle: const Text('단타매매 전략 알림을 백그라운드에서 모니터링합니다'),
      leading: const Icon(Icons.analytics_outlined),
      children: [
        // 서비스 상태 표시
        Consumer<SettingsViewModel>(
          builder: (context, settingsViewModel, child) {
            return FutureBuilder<bool>(
              future: _getMonitoringServiceStatus(),
              builder: (context, snapshot) {
                final isRunning = snapshot.data ?? false;

                return Column(
                  children: [
                    // 서비스 상태
                    ListTile(
                      leading: Icon(
                        isRunning ? Icons.play_circle : Icons.pause_circle,
                        color: isRunning ? Colors.green : Colors.grey,
                      ),
                      title: Text(isRunning ? '모니터링 서비스 실행 중' : '모니터링 서비스 중지됨'),
                      subtitle: Text(
                        isRunning
                            ? '전략 알림 조건을 30초마다 체크하고 있습니다'
                            : '전략 알림이 비활성화 상태입니다',
                      ),
                    ),

                    const Divider(height: 1),

                    // 서비스 제어 버튼
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                isRunning ? Icons.stop : Icons.play_arrow,
                              ),
                              label: Text(isRunning ? '서비스 중지' : '서비스 시작'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRunning
                                    ? Colors.red
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _toggleMonitoringService(isRunning),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => setState(() {}),
                            tooltip: '상태 새로고침',
                          ),
                        ],
                      ),
                    ),

                    // 권한 안내
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '서비스 시작 시 알림 권한과 배터리 최적화 설정이 필요할 수 있습니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  // 모니터링 서비스 상태 조회
  Future<bool> _getMonitoringServiceStatus() async {
    try {
      // StrategyMonitoringService의 isRunning 상태를 확인
      return await StrategyMonitoringService.isRunning;
    } catch (e) {
      print('모니터링 서비스 상태 확인 오류: $e');
      return false;
    }
  }

  // 모니터링 서비스 시작/중지 토글
  Future<void> _toggleMonitoringService(bool isCurrentlyRunning) async {
    try {
      bool success = false;

      if (isCurrentlyRunning) {
        // 서비스 중지
        print('[서비스토글] 서비스 중지 시작');
        success = await StrategyMonitoringService.stopService();

        if (success) {
          print('[서비스토글] 서비스 중지 성공');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전략 모니터링 서비스가 중지되었습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          print('[서비스토글] 서비스 중지 실패');
        }
      } else {
        // 서비스 시작
        print('[서비스토글] 서비스 시작 시작');

        // 권한 확인 (하지만 실패해도 서비스 시작 시도)
        bool hasPermissions = false;
        try {
          hasPermissions = await _checkAndRequestPermissions();
          print('[서비스토글] 권한 확인 결과: $hasPermissions');
        } catch (e) {
          print('[서비스토글] 권한 확인 실패: $e');
          hasPermissions = false;
        }

        // 권한이 없어도 서비스 시작 시도 (관대한 정책)
        if (!hasPermissions) {
          print('[서비스토글] 권한이 부족하지만 서비스 시작 시도');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '일부 권한이 부족하지만 서비스를 시작합니다. 알림이 정상적으로 작동하지 않을 수 있습니다.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }

        success = await StrategyMonitoringService.startService();
        print('[서비스토글] 서비스 시작 시도 결과: $success');

        if (success) {
          print('[서비스토글] 서비스 시작 성공');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasPermissions
                    ? '전략 모니터링 서비스가 시작되었습니다'
                    : '전략 모니터링 서비스가 시작되었습니다 (일부 권한 부족)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('[서비스토글] 서비스 시작 실패');
        }
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyRunning ? '서비스 중지에 실패했습니다' : '서비스 시작에 실패했습니다',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }

      // UI 업데이트
      setState(() {});
    } catch (e) {
      print('모니터링 서비스 토글 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서비스 제어 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 필요한 권한 확인 및 요청
  Future<bool> _checkAndRequestPermissions() async {
    try {
      print('[권한체크] 권한 확인 시작');

      // 플랫폼별로 분기하여 권한 처리
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        return await _checkIOSPermissions();
      } else {
        return await _checkAndroidPermissions();
      }
    } catch (e) {
      print('권한 확인 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('권한 확인 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // 에러 발생 시에도 서비스 시작을 허용 (권한은 선택사항으로 처리)
      return true;
    }
  }

  // iOS 권한 확인
  Future<bool> _checkIOSPermissions() async {
    print('[iOS권한] iOS 권한 확인 시작');

    try {
      // iOS에서는 flutter_local_notifications를 사용하여 알림 권한 확인
      // 하지만 여기서는 간단히 permission_handler를 시도하고, 실패해도 진행
      try {
        final notificationStatus = await Permission.notification.status;
        print('[iOS권한] 알림 권한 상태: $notificationStatus');

        if (notificationStatus.isDenied) {
          final result = await Permission.notification.request();
          print('[iOS권한] 알림 권한 요청 결과: $result');
        }
      } catch (e) {
        print('[iOS권한] 알림 권한 확인 실패 (정상적임): $e');
      }

      // iOS 백그라운드 제한 안내
      if (mounted) {
        _showIOSBackgroundLimitationDialog();
      }

      print('[iOS권한] iOS 권한 체크 완료 - 허용으로 처리');
      return true; // iOS에서는 관대하게 허용
    } catch (e) {
      print('[iOS권한] iOS 권한 체크 오류: $e');
      return true; // 오류 발생 시에도 허용
    }
  }

  // Android 권한 확인
  Future<bool> _checkAndroidPermissions() async {
    print('[Android권한] Android 권한 확인 시작');
    bool allPermissionsGranted = true;

    try {
      // 1. 알림 권한 확인 및 요청
      try {
        final notificationStatus = await Permission.notification.status;
        print('[Android권한] 알림 권한 상태: $notificationStatus');

        if (notificationStatus.isDenied) {
          final result = await Permission.notification.request();
          print('[Android권한] 알림 권한 요청 결과: $result');

          if (!result.isGranted) {
            allPermissionsGranted = false;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('알림 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } catch (e) {
        print('[Android권한] 알림 권한 확인 실패: $e');
        // 알림 권한 실패는 치명적이지 않으므로 계속 진행
      }

      // 2. 배터리 최적화 제외 권한 (선택사항)
      try {
        final batteryStatus =
            await Permission.ignoreBatteryOptimizations.status;
        print('[Android권한] 배터리 최적화 권한 상태: $batteryStatus');

        if (batteryStatus.isDenied) {
          final result = await Permission.ignoreBatteryOptimizations.request();
          print('[Android권한] 배터리 최적화 권한 요청 결과: $result');

          if (!result.isGranted) {
            // 배터리 최적화는 선택사항이므로 안내만 제공
            if (mounted) {
              _showBatteryOptimizationDialog();
            }
          }
        }
      } catch (e) {
        print('[Android권한] 배터리 최적화 권한 확인 실패: $e');
        // 배터리 최적화 권한 실패는 무시
      }

      // 3. 시스템 오버레이 권한 (선택사항)
      try {
        final systemAlertWindowStatus =
            await Permission.systemAlertWindow.status;
        print('[Android권한] 시스템 오버레이 권한 상태: $systemAlertWindowStatus');

        if (systemAlertWindowStatus.isDenied) {
          await Permission.systemAlertWindow.request();
        }
      } catch (e) {
        print('[Android권한] 시스템 오버레이 권한 확인 실패: $e');
        // 시스템 오버레이 권한 실패는 무시
      }

      print('[Android권한] Android 권한 체크 완료 - 결과: $allPermissionsGranted');

      // 알림 권한만 필수이고, 나머지는 선택사항으로 처리
      // 하지만 너무 엄격하지 않게 처리
      return true; // 관대하게 허용하여 서비스 시작 가능하도록
    } catch (e) {
      print('[Android권한] Android 권한 체크 오류: $e');
      return true; // 오류 발생 시에도 허용
    }
  }

  // 배터리 최적화 설정 안내 다이얼로그
  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배터리 최적화 설정'),
        content: const Text(
          '백그라운드에서 안정적인 모니터링을 위해 앱의 배터리 최적화를 해제해 주세요.\n\n'
          '설정 > 앱 > Coin Alarm > 배터리 > 배터리 최적화 안 함',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // iOS 백그라운드 제한 안내 다이얼로그
  void _showIOSBackgroundLimitationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('iOS 백그라운드 제한 안내'),
        content: const Text(
          'iOS는 백그라운드 작업에 제한이 있어 완전한 모니터링이 어려울 수 있습니다.\n\n'
          '최상의 경험을 위해:\n'
          '• 앱을 포그라운드에서 실행\n'
          '• 설정 > 일반 > 백그라운드 앱 새로고침 활성화\n'
          '• 배터리 절약 모드 비활성화\n\n'
          '그래도 일부 전략 알림이 누락될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
