import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart'; // DummyCoins 추가
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/settings_viewmodel.dart' show SettingsViewModel;
import '../../services/haptic_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'alerts_screen.dart';
import 'news_screen.dart';
import 'chart_screen.dart';
import 'biometric_login_screen.dart';

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
  List<String> _selectedCoins = [];

  // 햅틱 서비스 인스턴스
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen: initState 호출됨');

    // 기본적으로 DefaultSettings에서 기본 코인 목록을 가져옴
    _selectedCoins = List<String>.from(DefaultSettings.defaultFavoriteCoins);
    debugPrint('HomeScreen: 기본 코인 목록 설정 - $_selectedCoins');

    // CryptoViewModel의 새로고침 간격이 변경될 때마다 UI 업데이트를 위한 리스너 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('HomeScreen: postFrameCallback 호출됨');
      final cryptoViewModel = Provider.of<CryptoViewModel>(
        context,
        listen: false,
      );
      debugPrint('HomeScreen: CryptoViewModel 가져오기 성공');

      // 화면이 처음 로드될 때 데이터 가져오기
      if (cryptoViewModel.topCoins.isEmpty) {
        debugPrint('HomeScreen: 코인 데이터가 비어있어 새로고침 시작');
        cryptoViewModel.refresh();
      } else {
        debugPrint(
          'HomeScreen: 이미 코인 데이터가 있음 (${cryptoViewModel.topCoins.length}개)',
        );
      }
    });

    debugPrint('HomeScreen: initState 완료');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 바텀 네비게이션 아이템 선택 처리
  void _onItemTapped(int index) async {
    // 햅틱 피드백 실행
    await _hapticService.navigationTap();

    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  // 로그아웃
  Future<void> _logout() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final settingsViewModel = Provider.of<SettingsViewModel>(
      context,
      listen: false,
    );

    final success = await authViewModel.signOut();

    if (success && mounted) {
      // 생체인증 설정이 활성화되어 있고 로그인 정보가 저장되어 있으면 생체인증 화면으로 이동
      final useBiometrics = settingsViewModel.useBiometrics;
      final saveLoginInfo = settingsViewModel.saveLoginInfo;
      final hasSavedLoginInfo =
          settingsViewModel.getSavedEmail() != null &&
          settingsViewModel.getSavedPassword() != null;

      if (useBiometrics && hasSavedLoginInfo && saveLoginInfo) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BiometricLoginScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  // 코인 선택 변경 처리
  void _toggleCoinSelection(String symbol) {
    setState(() {
      if (_selectedCoins.contains(symbol)) {
        if (_selectedCoins.length > 1) {
          _selectedCoins.remove(symbol);
        }
      } else {
        _selectedCoins.add(symbol);
      }
    });
  }

  // 코인 선택 모달 표시
  void _showCoinSelectionModal() {
    // API에서 가져온 코인 목록 사용
    final cryptoViewModel = Provider.of<CryptoViewModel>(
      context,
      listen: false,
    );

    // 임시 선택 상태를 저장할 집합 생성
    List<String> tempSelectedCoins = List<String>.from(_selectedCoins);

    // 검색어 컨트롤러
    final searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 전체 화면의 80%까지 확장 가능
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 검색어에 따라 필터링된 코인 목록
            final filteredCoins = cryptoViewModel.topCoins.where((coin) {
              final symbolMatch = coin.symbol.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
              final nameMatch = coin.name.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
              return symbolMatch || nameMatch;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8, // 화면 높이의 80%
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
                      Row(
                        children: [
                          // 전체 선택 버튼
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                if (tempSelectedCoins.length ==
                                    filteredCoins.length) {
                                  // 모두 선택되어 있다면 모두 해제 (최소 1개는 유지)
                                  tempSelectedCoins = [
                                    filteredCoins.first.symbol,
                                  ];
                                } else {
                                  // 모두 선택
                                  tempSelectedCoins = filteredCoins
                                      .map((c) => c.symbol)
                                      .toList();
                                }
                              });
                            },
                            child: Text(
                              tempSelectedCoins.length == filteredCoins.length
                                  ? '모두 해제'
                                  : '모두 선택',
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // 모달을 닫기 전에 선택된 코인을 적용
                              setState(() {
                                _selectedCoins = List<String>.from(
                                  tempSelectedCoins,
                                );
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('완료'),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 검색창
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '코인 이름 또는 심볼 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0.0,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),

                  // 선택된 코인 수 표시
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${tempSelectedCoins.length}개 선택됨 (총 ${filteredCoins.length}개)',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // 코인 목록
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredCoins.length,
                      itemBuilder: (context, index) {
                        final coin = filteredCoins[index];
                        final isSelected = tempSelectedCoins.contains(
                          coin.symbol,
                        );

                        return CheckboxListTile(
                          title: Text('${coin.name} (${coin.symbol})'),
                          subtitle: Text(
                            '₩${_formatPrice(coin.currentPrice)} · ${coin.priceChangePercentage24h?.toStringAsFixed(2) ?? '0.00'}%',
                            style: TextStyle(
                              color: (coin.priceChangePercentage24h ?? 0) >= 0
                                  ? Colors.red
                                  : Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          value: isSelected,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (_) {
                            setModalState(() {
                              if (tempSelectedCoins.contains(coin.symbol)) {
                                if (tempSelectedCoins.length > 1) {
                                  tempSelectedCoins.remove(coin.symbol);
                                }
                              } else {
                                tempSelectedCoins.add(coin.symbol);
                              }
                            });
                          },
                          secondary: _buildCoinIcon(coin, size: 32),
                          controlAffinity: ListTileControlAffinity.trailing,
                          dense: true,
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

  // 가격을 천 단위 콤마로 표시하고, 12자리 이상이면 ...으로 말줄임 처리
  String _formatPrice(double price) {
    String formatted;
    if (price >= 1) {
      formatted = price
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } else {
      formatted = price.toStringAsFixed(6);
    }
    // 12자리(콤마 포함) 이상이면 ...으로 말줄임
    if (formatted.length > 15) {
      formatted = formatted.substring(0, 15) + '...';
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Align(
          alignment: Alignment.center,
          child: Text(AppConstants.appName),
        ),
        actions: [
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
        // API에서 가져온 코인 목록 사용
        final supportedCoins = cryptoViewModel.topCoins;

        // 지원되는 코인 심볼 목록 생성
        final supportedSymbols = supportedCoins.map((c) => c.symbol).toSet();

        // 선택된 코인 중 API에서 지원하는 코인만 필터링
        final displayCoins = cryptoViewModel.topCoins
            .where((coin) => _selectedCoins.contains(coin.symbol))
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

        // _selectedCoins의 순서대로 displayCoins를 정렬
        final sortedDisplayCoins = _selectedCoins
            .map(
              (symbol) => cryptoViewModel.topCoins.firstWhere(
                (c) => c.symbol == symbol,
                orElse: () => cryptoViewModel.topCoins.isNotEmpty
                    ? cryptoViewModel.topCoins.first
                    : Coin(
                        id: '',
                        name: '',
                        symbol: '',
                        currentPrice: 0,
                        lastUpdated: DateTime.now(),
                      ),
              ),
            )
            .where((c) => c.id.isNotEmpty)
            .toList();

        return RefreshIndicator(
          onRefresh: () => cryptoViewModel.refresh(),
          child: Column(
            children: [
              // 코인 선택 버튼 (상단에 추가)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '내 코인 리스트',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showCoinSelectionModal,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('코인 선택'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    for (int i = 0; i < sortedDisplayCoins.length; i++)
                      Card(
                        key: ValueKey(sortedDisplayCoins[i].id),
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _selectedCoin = sortedDisplayCoins[i];
                              _selectedIndex = 1; // 차트 탭으로 이동
                            });
                            _pageController.jumpToPage(1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // 코인 아이콘 (드래그 핸들 제거)
                                _buildCoinIcon(sortedDisplayCoins[i], size: 32),
                                const SizedBox(width: 12),
                                // 코인 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sortedDisplayCoins[i].name,
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              sortedDisplayCoins[i].symbol,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '₩${_formatPrice(sortedDisplayCoins[i].currentPrice)}',
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
                                        color:
                                            (sortedDisplayCoins[i].isPriceUp
                                                    ? AppTheme.positiveColor
                                                    : AppTheme.negativeColor)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sortedDisplayCoins[i]
                                            .priceChangePercent,
                                        style: TextStyle(
                                          color: sortedDisplayCoins[i].isPriceUp
                                              ? AppTheme.positiveColor
                                              : AppTheme.negativeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sortedDisplayCoins[i].priceChange24h
                                              ?.toStringAsFixed(2) ??
                                          '0.00',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: sortedDisplayCoins[i].isPriceUp
                                            ? AppTheme.positiveColor
                                            : AppTheme.negativeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final symbolList = List<String>.from(_selectedCoins);
                    final moved = symbolList.removeAt(oldIndex);
                    symbolList.insert(newIndex, moved);
                    setState(() {
                      _selectedCoins = symbolList;
                    });
                  },
                ),
              ),
              // 마지막 업데이트 시간 표시
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '마지막 업데이트: $lastUpdated',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
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
    final priceColor = isPriceUp
        ? AppTheme.positiveColor
        : AppTheme.negativeColor;

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
        final backgroundColor = hasPriceChanged
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
      child: coin.imageUrl != null && coin.imageUrl!.isNotEmpty
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
