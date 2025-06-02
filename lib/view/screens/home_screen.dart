import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/coin_viewmodel.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 데이터 새로고침
              final coinViewModel = Provider.of<CoinViewModel>(
                context,
                listen: false,
              );
              coinViewModel.refreshCoins();
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

          // 차트 페이지
          const ChartScreen(),

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
    return Consumer<CoinViewModel>(
      builder: (context, coinViewModel, child) {
        if (coinViewModel.isLoading && coinViewModel.coins.isEmpty) {
          // 로딩 중이고 데이터가 없는 경우
          return const Center(child: CircularProgressIndicator());
        }

        if (coinViewModel.coins.isEmpty) {
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
                const Text('코인 데이터를 불러올 수 없습니다.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => coinViewModel.refreshCoins(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        // 코인 목록 표시
        return RefreshIndicator(
          onRefresh: () => coinViewModel.refreshCoins(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: coinViewModel.coins.length,
            itemBuilder: (context, index) {
              final coin = coinViewModel.coins[index];
              return _buildCoinCard(coin, coinViewModel);
            },
          ),
        );
      },
    );
  }

  // 코인 카드 위젯
  Widget _buildCoinCard(Coin coin, CoinViewModel coinViewModel) {
    final isPriceUp = coin.isPriceUp;
    final priceColor = isPriceUp
        ? AppTheme.positiveColor
        : AppTheme.negativeColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            coin.symbol.substring(0, 1),
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              coin.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              coin.symbol,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        subtitle: Text(
          '현재가: ${coin.currentPrice.toStringAsFixed(2)} KRW',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              coin.priceChangePercent,
              style: TextStyle(color: priceColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              coin.priceChange24h?.toStringAsFixed(2) ?? '0.00',
              style: TextStyle(fontSize: 12, color: priceColor),
            ),
          ],
        ),
        onTap: () {
          // 차트 화면으로 이동
          setState(() {
            _selectedIndex = 1; // 차트 탭으로 이동
          });
          _pageController.jumpToPage(1);
        },
      ),
    );
  }
}
