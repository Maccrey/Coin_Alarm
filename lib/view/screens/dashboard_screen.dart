import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../core/theme.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';

// 대시보드 화면 (홈 화면)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 검색창 컨트롤러
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 화면이 처음 로드될 때 API 키 확인 및 데이터 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cryptoViewModel = Provider.of<CryptoViewModel>(
        context,
        listen: false,
      );
      final settingsViewModel = Provider.of<SettingsViewModel>(
        context,
        listen: false,
      );

      if (cryptoViewModel.availableServices.isEmpty) {
        debugPrint('대시보드: API 서비스 사용 불가 - API 키 확인 중');
        final hasUpbitKeys = settingsViewModel.hasUpbitApiKeys;
        final hasBinanceKeys = settingsViewModel.hasBinanceApiKeys;

        debugPrint(
          '대시보드: API 키 상태 - Upbit: $hasUpbitKeys, Binance: $hasBinanceKeys',
        );

        // API 키가 설정되어 있다면 데이터 새로고침 시도
        if (hasUpbitKeys || hasBinanceKeys) {
          debugPrint('대시보드: API 키가 설정되어 있어 CryptoViewModel 새로고침 시도');
          cryptoViewModel.refresh();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CryptoViewModel 프로바이더 연결
    return Consumer<CryptoViewModel>(
      builder: (context, viewModel, _) {
        debugPrint(
          '대시보드 빌드: 서비스 있음=${viewModel.hasServices}, 코인 개수=${viewModel.topCoins.length}',
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('코인 알람'),
            actions: [
              // 새로고침 버튼
              IconButton(
                icon: viewModel.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: viewModel.isLoading
                    ? null
                    : () => viewModel.refresh(),
                tooltip: '데이터 새로고침',
              ),
              // 알림 버튼
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // 알림 화면으로 이동
                },
                tooltip: '알림',
              ),
              // 설정 버튼 추가
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                tooltip: '설정',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => viewModel.refresh(),
            child: _buildDashboardContent(viewModel),
          ),
        );
      },
    );
  }

  // 대시보드 콘텐츠 위젯
  Widget _buildDashboardContent(CryptoViewModel viewModel) {
    // API 서비스가 없는 경우
    if (!viewModel.hasServices) {
      return _buildNoApiServiceView();
    }

    // 에러가 있는 경우
    if (viewModel.error != null) {
      return _buildErrorView(viewModel.error!);
    }

    // 데이터 로딩 중이고 데이터가 없는 경우
    if (viewModel.isLoading && viewModel.topCoins.isEmpty) {
      return _buildLoadingView();
    }

    // 정상 데이터 표시
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 거래소 정보 표시
        if (viewModel.activeService != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildExchangeInfoCard(viewModel),
          ),

        // 검색창
        _buildSearchBar(),

        const SizedBox(height: 24),

        // 인기 코인 리스트
        _buildPopularCoinsSection(viewModel),

        const SizedBox(height: 24),

        // 최신 뉴스 섹션 (임시로 간소화)
        _buildSimpleNewsSection(),

        const SizedBox(height: 16),

        // 마지막 업데이트 시간 표시
        Center(
          child: Text(
            '마지막 업데이트: ${_formatUpdateTime(viewModel.lastUpdated)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // API 서비스가 없을 때 표시되는 화면
  Widget _buildNoApiServiceView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vpn_key_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'API 키 설정이 필요합니다',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '업비트 또는 바이낸스 API 키를 설정하면 실시간 시세 정보를 확인할 수 있습니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('API 키 설정하기'),
              onPressed: () {
                // 설정 화면으로 이동
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  // 에러 발생 시 표시되는 화면
  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              onPressed: () {
                // 데이터 새로고침
                context.read<CryptoViewModel>().refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 로딩 중 표시되는 화면
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('데이터를 불러오는 중...'),
        ],
      ),
    );
  }

  // 거래소 정보 카드
  Widget _buildExchangeInfoCard(CryptoViewModel viewModel) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${viewModel.activeService?.exchangeName} 실시간 시세',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (viewModel.availableServices.length > 1)
                    Row(
                      children: [
                        const Text('거래소 변경:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        ...viewModel.availableServices.map(
                          (service) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(service.exchangeName),
                              selected: service == viewModel.activeService,
                              onSelected: (selected) {
                                if (selected) {
                                  viewModel.setActiveService(service);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 검색창 위젯
  Widget _buildSearchBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '코인 검색 (BTC, ETH, ...)',
            border: InputBorder.none,
            icon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      FocusScope.of(context).unfocus();
                    },
                  ),
          ),
          onChanged: (value) {
            setState(() {});
          },
          onSubmitted: (value) {
            // 검색 기능 구현
            if (value.isNotEmpty) {
              // 코인 상세 페이지로 이동
            }
          },
        ),
      ),
    );
  }

  // 인기 코인 섹션 위젯
  Widget _buildPopularCoinsSection(CryptoViewModel viewModel) {
    final sortedCoins = viewModel.getSortedCoins();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '인기 코인',
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                // 순서 초기화 버튼
                IconButton(
                  icon: Icon(
                    Icons.restart_alt,
                    color: Theme.of(context).hintColor,
                    size: 20,
                  ),
                  tooltip: '순서 초기화',
                  onPressed: () => _showResetOrderConfirmDialog(viewModel),
                ),
                TextButton(
                  onPressed: () {
                    // 코인 목록 전체보기 화면으로 이동
                  },
                  child: const Text('더 보기'),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 코인 목록
        if (sortedCoins.isEmpty && !viewModel.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('표시할 코인 정보가 없습니다.'),
            ),
          )
        else
          Column(
            children: [
              // 순서 변경 안내 메시지
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '리스트 항목을 길게 누르고 드래그하여 순서 변경',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // 재정렬 가능한 코인 목록을 간단하게 다시 구현
              Container(
                height: min(sortedCoins.length * 92.0, 400),
                child: ReorderableListView(
                  children: [
                    for (int i = 0; i < sortedCoins.length; i++)
                      ListTile(
                        key: ValueKey(sortedCoins[i].id),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 드래그 핸들 아이콘
                            Icon(
                              Icons.drag_handle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            // 코인 아이콘
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: sortedCoins[i].imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        sortedCoins[i].imageUrl!,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.currency_bitcoin,
                                                ),
                                      ),
                                    )
                                  : const Icon(Icons.currency_bitcoin),
                            ),
                          ],
                        ),
                        title: Text(
                          '${sortedCoins[i].name} (${sortedCoins[i].symbol})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '₩${_formatPrice(sortedCoins[i].currentPrice)}',
                        ),
                        trailing: Text(
                          sortedCoins[i].isPriceUp
                              ? '+${sortedCoins[i].priceChangePercent}'
                              : sortedCoins[i].priceChangePercent,
                          style: TextStyle(
                            color: sortedCoins[i].isPriceUp
                                ? Colors.blue.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: () {
                          // 코인 상세 페이지로 이동
                        },
                      ),
                  ],
                  onReorder: (oldIndex, newIndex) {
                    debugPrint(
                      '코인 재정렬: oldIndex=$oldIndex, newIndex=$newIndex',
                    );
                    viewModel.reorderCoins(oldIndex, newIndex);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 순서 초기화 확인 다이얼로그
  Future<void> _showResetOrderConfirmDialog(CryptoViewModel viewModel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('순서 초기화'),
        content: const Text('코인 목록 순서를 기본 순서로 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (result == true) {
      viewModel.resetCoinOrder();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('코인 목록 순서가 초기화되었습니다')));
      }
    }
  }

  // 간소화된 뉴스 섹션
  Widget _buildSimpleNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최신 뉴스',
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // 뉴스 API 연동 전 임시 카드
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.update,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '뉴스 데이터는 추후 업데이트될 예정입니다.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 가격 포맷팅 함수
  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${price.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  // 업데이트 시간 포맷팅 함수
  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
