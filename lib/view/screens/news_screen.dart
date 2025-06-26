import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../viewmodel/news_viewmodel.dart';
// import '../../data/dummy_coins.dart';
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

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 스크롤 컨트롤러(페이징용)
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(() {
      // 검색어가 변경될 때마다 검색 수행
      if (_searchController.text != _lastSearchQuery) {
        _performSearch(_searchController.text);
      }
    });

    // 화면 초기화 시 뉴스 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('뉴스 화면 초기화: 페이징 뉴스 첫 페이지 로드 요청');
      final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);

      // 데이터가 없는 경우에만 로드
      if (newsViewModel.pagedNewsList.isEmpty) {
        debugPrint('뉴스 화면 초기화: 데이터가 없어 첫 페이지 로드 요청');
        newsViewModel.fetchInitialNewsPage();
      } else {
        debugPrint(
          '뉴스 화면 초기화: 이미 ${newsViewModel.pagedNewsList.length}개 데이터가 있어 로드 건너뜀',
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 이벤트 처리
  void _scrollListener() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // 스크롤이 80% 이상 내려갔을 때 추가 데이터 로드
    if (currentScroll >= maxScroll * 0.8) {
      debugPrint('NewsScreen: 스크롤 80% 이상 도달, 추가 데이터 로드 요청');
      final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);

      // 이미 로딩 중이거나 더 이상 데이터가 없으면 건너뜀
      if (!newsViewModel.isLoadingMore && newsViewModel.hasMore) {
        debugPrint('NewsScreen: 다음 페이지 로드 요청');
        newsViewModel.fetchNextNewsPage();
      } else {
        debugPrint(
          'NewsScreen: 추가 데이터 로드 건너뜀 - 로딩 중: ${newsViewModel.isLoadingMore}, 더 있음: ${newsViewModel.hasMore}',
        );
      }
    }
  }

  // 필터 적용
  void _applyFilter(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _searchController.clear(); // 필터 선택 시 검색어도 초기화
    });

    final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);
    await newsViewModel.loadNewsByCoinId(filter);
  }

  // 검색어 처리
  void _performSearch(String query) {
    debugPrint('NewsScreen: 검색 수행 - 검색어: "$query"');
    _lastSearchQuery = query;

    final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);

    // 검색어가 비어있고 필터도 '전체'인 경우 전체 뉴스 표시
    if (query.isEmpty && _selectedFilter == '전체') {
      debugPrint('NewsScreen: 검색어와 필터 모두 없음, 전체 뉴스 표시');
      newsViewModel.clearFilter();
      newsViewModel.fetchInitialNewsPage();
      return;
    }

    // 검색어만 설정
    if (query.isNotEmpty) {
      debugPrint('NewsScreen: 검색어 설정 - "$query"');
      newsViewModel.searchNews(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Provider.of<NewsViewModel>(context) 대신 Consumer 사용
    return Consumer<NewsViewModel>(
      builder: (context, newsViewModel, _) {
        debugPrint(
          'NewsScreen: 뉴스 화면 빌드 - 로딩 상태: ${newsViewModel.isLoading}, 뉴스 개수: ${newsViewModel.pagedNewsList.length}, 에러: ${newsViewModel.errorMessage != null}',
        );

        // 뉴스 데이터가 있으면 바로 표시
        final hasNewsData =
            newsViewModel.pagedNewsList.isNotEmpty ||
            newsViewModel.newsList.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Align(
              alignment: Alignment.centerLeft,
              child: Text('뉴스'),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
              // 새로고침 버튼 추가
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  debugPrint('NewsScreen: 수동 새로고침 요청');
                  newsViewModel.fetchInitialNewsPage();
                },
                tooltip: '새로고침',
              ),
            ],
          ),
          body: Stack(
            children: [
              // 메인 콘텐츠
              hasNewsData
                  ? _searchController.text.isNotEmpty || _selectedFilter != '전체'
                        ? _buildNewsList(newsViewModel)
                        : _buildNewsPageWithSections(newsViewModel)
                  : _buildEmptyView(newsViewModel),

              // 로딩 인디케이터 (데이터가 없을 때만 전체 화면, 있을 때는 오버레이)
              if (newsViewModel.isLoading)
                hasNewsData
                    ? Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.1),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    '뉴스 업데이트 중...',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : _buildLoadingView(newsViewModel),

              // 에러 메시지 (데이터가 있을 때만 스낵바 형태로 표시)
              if (newsViewModel.errorMessage != null && hasNewsData)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.onError,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            newsViewModel.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onError),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onError,
                          ),
                          onPressed: () {
                            newsViewModel.clearError();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 로딩 화면 (상세 정보 포함)
  Widget _buildLoadingView(NewsViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '뉴스 데이터 로딩 중...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.pagedNewsList.isNotEmpty
                ? '${viewModel.pagedNewsList.length}개의 캐시된 뉴스 표시 중'
                : viewModel.newsList.isNotEmpty
                ? '${viewModel.newsList.length}개의 뉴스 표시 중'
                : '캐시된 데이터 확인 중...',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (viewModel.isLoadingMore) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '추가 데이터 로드 중...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (viewModel.pagedNewsList.isEmpty && viewModel.newsList.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                viewModel.fetchInitialNewsPage();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
        ],
      ),
    );
  }

  // 섹션으로 구분된 뉴스 페이지
  Widget _buildNewsPageWithSections(NewsViewModel viewModel) {
    debugPrint(
      'NewsScreen: 섹션별 뉴스 페이지 빌드 - ${viewModel.pagedNewsList.length}개 뉴스',
    );

    return Column(
      children: [
        // 필터 버튼 목록
        _buildFilterButtons(),

        // 뉴스 목록 (섹션별)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              debugPrint('NewsScreen: 당겨서 새로고침 요청');
              await viewModel.fetchInitialNewsPage();
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8),
              children: [
                // 주요 뉴스 섹션
                if (viewModel.pagedNewsList.isNotEmpty) ...[
                  _buildNewsSection(
                    '주요 뉴스',
                    viewModel.pagedNewsList.take(1).toList(),
                    isMainNews: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // 최신 뉴스 섹션
                if (viewModel.pagedNewsList.length > 1) ...[
                  _buildNewsSection(
                    '최신 뉴스',
                    viewModel.pagedNewsList.skip(1).toList(),
                  ),
                ],

                // 로딩 인디케이터 (바닥)
                if (viewModel.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // 바닥 여백
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
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
                child: news.imageUrl != null && news.imageUrl!.isNotEmpty
                    ? Image.network(
                        news.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('이미지 로드 오류: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
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

  // 뉴스 목록 위젯 (페이징 적용)
  Widget _buildNewsList(NewsViewModel viewModel) {
    final newsList = viewModel.filteredNewsList.isNotEmpty
        ? viewModel.filteredNewsList
        : viewModel.pagedNewsList;

    debugPrint(
      'NewsScreen: 뉴스 목록 빌드 - ${newsList.length}개 뉴스, 필터링됨: ${viewModel.filteredNewsList.isNotEmpty}',
    );

    return Column(
      children: [
        // 필터 버튼 목록
        _buildFilterButtons(),

        // 뉴스 목록
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              debugPrint('NewsScreen: 당겨서 새로고침 요청');
              await viewModel.fetchInitialNewsPage();
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8),
              itemCount: newsList.length + (viewModel.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // 로딩 인디케이터 표시 (마지막 아이템)
                if (index == newsList.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // 뉴스 아이템
                final news = newsList[index];
                return _buildNewsItem(news);
              },
            ),
          ),
        ),
      ],
    );
  }

  // 뉴스 아이템 위젯
  Widget _buildNewsItem(News news) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          debugPrint('NewsScreen: 뉴스 선택됨 - ${news.title}');
          Navigator.pushNamed(context, '/news_detail', arguments: news);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뉴스 이미지
              if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Image.network(
                      news.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article, color: Colors.grey),
                ),

              const SizedBox(width: 12),

              // 뉴스 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뉴스 제목
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // 뉴스 내용 요약
                    Text(
                      news.contentSummary,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // 뉴스 소스 및 시간
                    Row(
                      children: [
                        Text(
                          news.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          news.publishedTimeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),

                        // 관련 코인 태그
                        if (news.relatedCoins.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              news.relatedCoins.first.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
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
      ),
    );
  }

  // 뉴스 상세 다이얼로그
  void _showNewsDetailDialog(News news) {
    // ViewModel에 선택된 뉴스 설정
    Provider.of<NewsViewModel>(context, listen: false).selectNews(news);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 (있는 경우)
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
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
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('상세 뉴스 이미지 로드 오류: $error');
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    );
                  },
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
                          '• ${news.getTimeAgo()}',
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
                          final name = coinId;
                          final symbol = coinId.toUpperCase();

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
                          _openInExternalBrowser(news.url);
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

  void _openInExternalBrowser(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw '원문을 열 수 없습니다';
      }
    } catch (e) {
      // 오류 메시지 표시
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('원문을 열 수 없습니다: $e')));
    }
  }

  // 데이터가 없을 때 표시할 빈 화면
  Widget _buildEmptyView(NewsViewModel viewModel) {
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
          const SizedBox(height: 8),
          if (!viewModel.isLoading)
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 로드'),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedFilter = '전체';
                });
                viewModel.clearFilter();
                viewModel.fetchInitialNewsPage();
              },
            ),
        ],
      ),
    );
  }

  // 필터 버튼 목록
  Widget _buildFilterButtons() {
    final coinFilters = [
      '전체',
      'bitcoin',
      'ethereum',
      'solana',
      'cardano',
      'ripple',
      'dogecoin',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: coinFilters.map((filter) {
            final isSelected = _selectedFilter == filter;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  filter == 'bitcoin'
                      ? 'Bitcoin'
                      : filter == 'ethereum'
                      ? 'Ethereum'
                      : filter == 'solana'
                      ? 'Solana'
                      : filter == 'cardano'
                      ? 'Cardano'
                      : filter == 'ripple'
                      ? 'Ripple'
                      : filter == 'dogecoin'
                      ? 'Dogecoin'
                      : filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    debugPrint('NewsScreen: 필터 선택 - $filter');
                    _applyFilter(filter);
                  }
                },
                showCheckmark: false,
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 뉴스 섹션 위젯
  Widget _buildNewsSection(
    String title,
    List<News> newsList, {
    bool isMainNews = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isMainNews
                ? Theme.of(context).primaryColor
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isMainNews ? 300 : 200,
          child: newsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 48,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '아직 인기 뉴스가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '뉴스를 읽으면 인기 뉴스에 표시됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: newsList.length,
                  itemBuilder: (context, index) {
                    final news = newsList[index];
                    return _buildFeaturedNewsItem(news);
                  },
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
