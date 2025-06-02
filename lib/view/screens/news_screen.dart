import 'package:flutter/material.dart';
import '../../data/dummy_news.dart';
import '../../data/dummy_coins.dart';
import '../../model/news_model.dart';
import '../../core/theme.dart';

// 뉴스 화면
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  // 선택된 필터
  String _selectedFilter = '전체';

  // 검색어
  String _searchQuery = '';

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 뉴스 데이터
  late List<News> _filteredNews;

  @override
  void initState() {
    super.initState();
    _filteredNews = DummyNews.newsList;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 필터 적용
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _updateFilteredNews();
    });
  }

  // 검색 실행
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredNews();
    });
  }

  // 필터 및 검색어에 따라 뉴스 목록 업데이트
  void _updateFilteredNews() {
    // 필터 적용
    List<News> newsAfterFilter;
    if (_selectedFilter == '전체') {
      newsAfterFilter = DummyNews.newsList;
    } else {
      newsAfterFilter = DummyNews.newsList
          .where(
            (news) => news.relatedCoins.contains(_selectedFilter.toLowerCase()),
          )
          .toList();
    }

    // 검색어 적용
    if (_searchQuery.isEmpty) {
      _filteredNews = newsAfterFilter;
    } else {
      _filteredNews = newsAfterFilter
          .where(
            (news) =>
                news.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                news.content.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('뉴스'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '뉴스 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _performSearch,
            ),
          ),
        ),
        actions: [
          // 필터 버튼
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '코인별 필터링',
            onSelected: _applyFilter,
            itemBuilder: (context) {
              // 코인 목록으로 필터 메뉴 아이템 생성
              final coins = [
                '전체',
                'bitcoin',
                'ethereum',
                'binancecoin',
                'ripple',
                'cardano',
                'solana',
                'dogecoin',
              ];
              return coins.map((coin) {
                final displayName = coin == '전체'
                    ? '전체'
                    : DummyCoins.getCoinById(coin)?.symbol ?? coin;
                return PopupMenuItem<String>(
                  value: coin,
                  child: Text(displayName),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _buildNewsList(),
    );
  }

  // 뉴스 목록 위젯
  Widget _buildNewsList() {
    if (_filteredNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              '뉴스가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).disabledColor,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != '전체') ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('필터 초기화'),
                onPressed: () {
                  _searchController.clear();
                  _applyFilter('전체');
                  _performSearch('');
                },
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredNews.length,
      itemBuilder: (context, index) {
        final news = _filteredNews[index];
        return _buildNewsItem(news);
      },
    );
  }

  // 뉴스 아이템 위젯
  Widget _buildNewsItem(News news) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias, // 이미지가 카드 경계를 넘어가지 않도록
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showNewsDetailDialog(news),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뉴스 이미지 (있는 경우)
            if (news.imageUrl != null)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(
                  news.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            // 뉴스 내용
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 요약
                  Text(
                    news.summary,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // 소스 및 시간
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 출처
                      Text(
                        news.source,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                        ),
                      ),
                      // 시간
                      Text(
                        news.getTimeAgo(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),

                  // 관련 코인 태그
                  if (news.relatedCoins.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: news.relatedCoins.map((coinId) {
                        final coin = DummyCoins.getCoinById(coinId);
                        final symbol = coin?.symbol ?? coinId.toUpperCase();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            symbol,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 뉴스 상세 다이얼로그
  void _showNewsDetailDialog(News news) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 (있는 경우)
            if (news.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(
                  news.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            // 뉴스 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 및 출처
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          news.source,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatDateTime(news.publishedAt)}',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 관련 코인 태그
                    if (news.relatedCoins.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: news.relatedCoins.map((coinId) {
                          final coin = DummyCoins.getCoinById(coinId);
                          final name = coin?.name ?? coinId;
                          final symbol = coin?.symbol ?? coinId.toUpperCase();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$name ($symbol)',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 본문
                    Text(
                      news.content,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // 링크 버튼
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('원문 보기'),
                        onPressed: () {
                          // 뉴스 URL 열기 기능 구현
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('URL: ${news.url}'),
                              action: SnackBarAction(
                                label: '닫기',
                                onPressed: () {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 날짜/시간 포맷팅 함수
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
