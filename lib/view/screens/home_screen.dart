import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/dummy_coins.dart'; // DummyCoins 추가
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../model/coin_model.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'alerts_screen.dart';
import 'news_screen.dart';
import 'chart_screen.dart';

// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 현재 선택된 바텀 네비게이션 아이템 인덱스
  int _selectedIndex = 0;

  // 페이지 컨트롤러
  final PageController _pageController = PageController();

  // 선택된 코인
  Coin? _selectedCoin;

  // 선택된 코인 심볼 목록 (대시보드에 표시할 코인)
  Set<String> _selectedCoins = {};

  @override
  void initState() {
    super.initState();

    // 기본적으로 BTC, ETH는 선택되도록 설정
    _selectedCoins = {'BTC', 'ETH'};
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 바텀 네비게이션 아이템 선택 처리
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  // 로그아웃
  Future<void> _logout() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.signOut();

    if (success && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // 코인 선택 변경 처리
  void _toggleCoinSelection(String symbol) {
    setState(() {
      if (_selectedCoins.contains(symbol)) {
        if (_selectedCoins.length > 1) {
          // 최소 1개 이상 선택되도록
          _selectedCoins.remove(symbol);
        }
      } else {
        _selectedCoins.add(symbol);
      }
    });
  }

  // 코인 선택 모달 표시
  void _showCoinSelectionModal() {
    final supportedCoins = DummyCoins.popularCoins;

    // 임시 선택 상태를 저장할 집합 생성
    Set<String> tempSelectedCoins = Set.from(_selectedCoins);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '표시할 코인 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // 모달을 닫기 전에 선택된 코인을 적용
                          setState(() {
                            _selectedCoins = Set.from(tempSelectedCoins);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: supportedCoins.length,
                      itemBuilder: (context, index) {
                        final coin = supportedCoins[index];
                        final isSelected = tempSelectedCoins.contains(
                          coin.symbol,
                        );

                        return CheckboxListTile(
                          title: Text('${coin.name} (${coin.symbol})'),
                          value: isSelected,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (_) {
                            setModalState(() {
                              if (tempSelectedCoins.contains(coin.symbol)) {
                                if (tempSelectedCoins.length > 1) {
                                  // 최소 1개 이상 선택되도록
                                  tempSelectedCoins.remove(coin.symbol);
                                }
                              } else {
                                tempSelectedCoins.add(coin.symbol);
                              }
                            });

                            // 즉시 적용을 위해 외부 setState도 호출
                            setState(() {
                              _selectedCoins = Set.from(tempSelectedCoins);
                            });
                          },
                          secondary: _buildCoinIcon(coin, size: 32),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 데이터 새로고침
              final cryptoViewModel = Provider.of<CryptoViewModel>(
                context,
                listen: false,
              );

              // 로딩 표시
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데이터를 새로고침 중입니다...'),
                  duration: Duration(seconds: 1),
                ),
              );

              // 강제 새로고침 실행
              await cryptoViewModel.refresh();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('데이터가 업데이트되었습니다.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          // 대시보드 페이지
          _buildDashboardPage(),

          // 차트 페이지 - 선택된 코인 전달
          ChartScreen(selectedCoin: _selectedCoin),

          // 알림 페이지
          const AlertsScreen(),

          // 뉴스 페이지
          const NewsScreen(),

          // 설정 페이지
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.primaryColor,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '대시보드'),
          BottomNavigationBarItem(
            icon: Icon(Icons.candlestick_chart),
            label: '차트',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: '뉴스'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  // 대시보드 페이지 빌드
  Widget _buildDashboardPage() {
    return Consumer<CryptoViewModel>(
      builder: (context, cryptoViewModel, child) {
        // 차트에서 지원하는 코인 목록을 가져옴
        final supportedCoins = DummyCoins.popularCoins;
        // 지원되는 코인 심볼 목록 생성
        final supportedSymbols = supportedCoins.map((c) => c.symbol).toSet();

        // 차트에서 지원하는 코인 중 선택된 코인만 필터링
        final displayCoins =
            cryptoViewModel.topCoins
                .where(
                  (coin) =>
                      supportedSymbols.contains(coin.symbol) &&
                      _selectedCoins.contains(coin.symbol),
                )
                .toList();

        if (cryptoViewModel.isLoading && displayCoins.isEmpty) {
          // 로딩 중이고 데이터가 없는 경우
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('코인 데이터를 불러오는 중...'),
              ],
            ),
          );
        }

        if (displayCoins.isEmpty && !cryptoViewModel.isLoading) {
          // 데이터가 없는 경우
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.currency_bitcoin,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text('표시할 코인이 없습니다'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _showCoinSelectionModal,
                  child: const Text('코인 선택하기'),
                ),
              ],
            ),
          );
        }

        // 마지막 업데이트 시간 포맷팅
        final lastUpdated = DateFormat(
          'HH:mm:ss',
        ).format(cryptoViewModel.lastUpdated);

        // 코인 목록 표시
        return RefreshIndicator(
          onRefresh: () => cryptoViewModel.refresh(),
          child: Column(
            children: [
              // 상단 정보 및 코인 선택 버튼
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '마지막 업데이트: $lastUpdated',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        if (cryptoViewModel.activeService != null)
                          Text(
                            '${cryptoViewModel.activeService!.exchangeName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _showCoinSelectionModal,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${_selectedCoins.length} 코인',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 코인 목록
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: displayCoins.length,
                  itemBuilder: (context, index) {
                    final coin = displayCoins[index];
                    return _buildCoinCard(coin, cryptoViewModel);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 코인 카드 위젯 - 디자인 개선
  Widget _buildCoinCard(Coin coin, CryptoViewModel cryptoViewModel) {
    final isPriceUp = coin.isPriceUp;
    final priceColor =
        isPriceUp ? AppTheme.positiveColor : AppTheme.negativeColor;

    // 가격 변화 확인 - 애니메이션 효과에 사용
    final hasPriceChanged = cryptoViewModel.hasPriceChanged(coin.symbol);
    final isPriceIncreased = cryptoViewModel.isPriceIncreased(coin.symbol);

    // 현재 가격 포맷팅
    final numberFormat = NumberFormat.currency(
      locale: 'ko_KR',
      symbol: '',
      decimalDigits: 2,
    );
    final formattedPrice = numberFormat.format(coin.currentPrice);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: hasPriceChanged ? 1 : 0),
      onEnd: () {
        // 애니메이션 종료 후 상태 리셋 (필요 시)
      },
      builder: (context, value, child) {
        // 가격 변화에 따른 배경색 애니메이션
        final backgroundColor =
            hasPriceChanged
                ? Color.lerp(
                  Colors.transparent,
                  isPriceIncreased
                      ? AppTheme.positiveColor.withOpacity(0.05)
                      : Colors.red.withOpacity(0.05),
                  value,
                )
                : Colors.transparent;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // 선택된 코인 저장 및 차트 화면으로 이동
                setState(() {
                  _selectedCoin = coin;
                  _selectedIndex = 1; // 차트 탭으로 이동
                });
                _pageController.jumpToPage(1);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    // 코인 아이콘 - 크기 줄임
                    _buildCoinIcon(coin, size: 32),
                    const SizedBox(width: 12),

                    // 코인 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coin.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  coin.symbol,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₩$formattedPrice',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 가격 변동 정보
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            coin.priceChangePercent,
                            style: TextStyle(
                              color: priceColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coin.priceChange24h?.toStringAsFixed(2) ?? '0.00',
                          style: TextStyle(fontSize: 11, color: priceColor),
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
    );
  }

  // 코인 아이콘 위젯 - 차트 화면과 동일하게 수정
  Widget _buildCoinIcon(Coin coin, {double size = 32}) {
    // 코인 심볼 기반 색상 선택
    final Color backgroundColor = Theme.of(context).colorScheme.surfaceVariant;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child:
          coin.imageUrl != null && coin.imageUrl!.isNotEmpty
              ? ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Image.network(
                  coin.imageUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 이미지 로드 실패 시 폴백 아이콘
                    return Icon(
                      Icons.currency_bitcoin,
                      size: size * 0.6,
                      color: Theme.of(context).primaryColor,
                    );
                  },
                ),
              )
              : Icon(
                Icons.currency_bitcoin,
                size: size * 0.6,
                color: Theme.of(context).primaryColor,
              ),
    );
  }
}
