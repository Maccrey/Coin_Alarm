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
  late List<News> _popularNews;

  @override
  void initState() {
    super.initState();
    _filteredNews = DummyNews.newsList;
    _popularNews = DummyNews.getPopularNews();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Align(alignment: Alignment.centerLeft, child: Text('뉴스')),
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
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _performSearch,
            ),
          ),
        ),
        actions: [
          // 필터 버튼
          PopupMenuButton<String>(
            tooltip: '코인별 필터링',
            offset: const Offset(0, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedFilter == '전체'
                        ? '전체'
                        : DummyCoins.getCoinById(_selectedFilter)?.symbol ??
                              _selectedFilter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            onSelected: _applyFilter,
            itemBuilder: (context) {
              // 코인 목록으로 필터 메뉴 아이템 생성
              final allCoins = [
                {'id': '전체', 'name': '전체', 'imageUrl': null},
                ...DummyCoins.popularCoins
                    .map(
                      (coin) => {
                        'id': coin.id,
                        'name': coin.symbol,
                        'imageUrl': coin.imageUrl,
                      },
                    )
                    .toList(),
              ];

              return allCoins.map((coin) {
                final bool isSelected = _selectedFilter == coin['id'];

                return PopupMenuItem<String>(
                  value: coin['id'] as String,
                  child: Row(
                    children: [
                      // 선택 표시
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 18,
                        )
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),

                      // 코인 아이콘
                      if (coin['imageUrl'] != null) ...[
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              coin['imageUrl'] as String,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.currency_bitcoin, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (coin['id'] != '전체') ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.currency_bitcoin,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // 코인 이름
                      Text(
                        coin['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _searchQuery.isNotEmpty || _selectedFilter != '전체'
          ? _buildNewsList()
          : _buildNewsPageWithSections(),
    );
  }

  // 섹션으로 구분된 뉴스 페이지
  Widget _buildNewsPageWithSections() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인기 뉴스 섹션
          const Text(
            '인기 뉴스',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 인기 뉴스 가로 스크롤
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _popularNews.length,
              itemBuilder: (context, index) {
                final news = _popularNews[index];
                return _buildFeaturedNewsItem(news);
              },
            ),
          ),

          const SizedBox(height: 24),

          // 최신 뉴스 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최신 뉴스',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: () {}, child: const Text('전체 보기')),
            ],
          ),
          const SizedBox(height: 8),

          // 최신 뉴스 목록
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredNews.length,
            itemBuilder: (context, index) {
              final news = _filteredNews[index];
              return _buildNewsItem(news);
            },
          ),
        ],
      ),
    );
  }

  // 인기 뉴스 아이템 (가로 스크롤용)
  Widget _buildFeaturedNewsItem(News news) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: InkWell(
          onTap: () => _showNewsDetailDialog(news),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뉴스 이미지
              SizedBox(
                height: 160,
                width: double.infinity,
                child: news.imageUrl != null
                    ? Image.network(
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
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.article,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // 시간 및 소스
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          news.getTimeAgo(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            news.source,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
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
      ),
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
      clipBehavior: Clip.antiAlias,
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
