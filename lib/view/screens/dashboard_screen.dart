import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/dummy_coins.dart';
import '../../data/dummy_news.dart';
import '../../model/coin_model.dart';
import '../../model/news_model.dart';

// 대시보드 화면 (홈 화면)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 데이터 새로고침 관련 상태
  bool _isRefreshing = false;
  DateTime _lastUpdated = DateTime.now();

  // 검색창 컨트롤러
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 데이터 새로고침 함수
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    // 실제로는 API 호출 등을 통해 데이터를 가져오지만, 여기서는 지연만 시뮬레이션
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _lastUpdated = DateTime.now();
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('코인 알람'),
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 검색창
            _buildSearchBar(),

            const SizedBox(height: 24),

            // 인기 코인 리스트
            _buildPopularCoinsSection(),

            const SizedBox(height: 24),

            // 최신 뉴스 섹션
            _buildLatestNewsSection(),

            const SizedBox(height: 16),

            // 마지막 업데이트 시간 표시
            Center(
              child: Text(
                '마지막 업데이트: ${_formatUpdateTime(_lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
  Widget _buildPopularCoinsSection() {
    final popularCoins = DummyCoins.getPopularCoins();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '인기 코인',
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // 코인 목록 전체보기 화면으로 이동
              },
              child: const Text('더 보기'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 코인 목록
        ...popularCoins.map((coin) => _buildCoinListItem(coin)),
      ],
    );
  }

  // 코인 목록 아이템 위젯
  Widget _buildCoinListItem(Coin coin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 코인 상세 페이지로 이동
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 코인 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: coin.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          coin.imageUrl!,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.currency_bitcoin),
                        ),
                      )
                    : const Icon(Icons.currency_bitcoin),
              ),
              const SizedBox(width: 16),
              // 코인 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${coin.name} (${coin.symbol})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₩${_formatPrice(coin.currentPrice)}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              // 가격 변화 정보
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    coin.isPriceUp
                        ? '+${coin.priceChangePercent}'
                        : coin.priceChangePercent,
                    style: TextStyle(
                      color: coin.isPriceUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '24시간',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 최신 뉴스 섹션 위젯
  Widget _buildLatestNewsSection() {
    final latestNews = DummyNews.getLatestNews(limit: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '최신 뉴스',
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // 뉴스 목록 전체보기 화면으로 이동
              },
              child: const Text('더 보기'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 뉴스 목록
        ...latestNews.map((news) => _buildNewsListItem(news)),
      ],
    );
  }

  // 뉴스 목록 아이템 위젯
  Widget _buildNewsListItem(News news) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 뉴스 상세 페이지로 이동
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뉴스 제목 및 소스
              Row(
                children: [
                  Expanded(
                    child: Text(
                      news.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 뉴스 요약
              Text(
                news.summary,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 뉴스 소스 및 시간
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    news.source,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    news.getTimeAgo(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
