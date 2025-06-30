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
      if (newsViewModel.filteredNewsList.isEmpty) {
        debugPrint('뉴스 화면 초기화: 데이터가 없어 첫 페이지 로드 요청');
        newsViewModel.fetchInitialNewsPage();
      } else {
        debugPrint(
          '뉴스 화면 초기화: 이미 ${newsViewModel.filteredNewsList.length}개 데이터가 있어 로드 건너뜀',
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

  // 검색어 처리
  void _performSearch(String query) {
    _lastSearchQuery = query;

    // 디바운스 처리 (타이핑 중에 API 호출 방지)
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);
      newsViewModel.searchNews(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<NewsViewModel>(
      builder: (context, newsViewModel, _) {
        debugPrint(
          'NewsScreen: 뉴스 화면 빌드 - 로딩 상태: ${newsViewModel.isLoading}, 뉴스 개수: ${newsViewModel.filteredNewsList.length}, 에러: ${newsViewModel.errorMessage != null}',
        );

        // 뉴스 데이터가 있으면 바로 표시
        final hasNewsData =
            newsViewModel.filteredNewsList.isNotEmpty ||
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                              newsViewModel.searchNews('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  enabled: !newsViewModel.isLoading,
                ),
              ),
            ),
          ),
          body: Stack(
            children: [
              // 메인 콘텐츠
              hasNewsData
                  ? _searchController.text.isNotEmpty
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
          const SizedBox(height: 24),
          Text(
            '뉴스를 불러오는 중입니다...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '최신 암호화폐 뉴스를 준비 중입니다',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // 빈 화면 (데이터가 없을 때)
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
            '뉴스를 불러올 수 없습니다',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.errorMessage ?? '뉴스 데이터가 없습니다',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (viewModel.filteredNewsList.isEmpty && viewModel.newsList.isEmpty)
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
      'NewsScreen: 섹션별 뉴스 페이지 빌드 - ${viewModel.filteredNewsList.length}개 뉴스',
    );

    // 조회수가 있는 뉴스만 필터링하고 조회수에 따라 정렬
    final popularNews =
        viewModel.filteredNewsList.where((news) => news.viewCount > 0).toList()
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    // 조회수가 있는 뉴스와 없는 뉴스를 분리
    final remainingNews =
        viewModel.filteredNewsList.where((news) => news.viewCount <= 0).toList()
          // 최신 뉴스는 업데이트 시간이 가까운 순서대로 정렬
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return Column(
      children: [
        // 뉴스 목록 (섹션별)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              debugPrint('NewsScreen: 당겨서 새로고침 요청');
              await viewModel.fetchInitialNewsPage();
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                // 주요 뉴스 섹션 (조회수 있는 뉴스만)
                if (popularNews.isNotEmpty) ...[
                  _buildNewsSection('주요 뉴스', popularNews, isMainNews: true),
                  const SizedBox(height: 16),
                ],

                // 최신 뉴스 섹션 (나머지 뉴스)
                if (remainingNews.isNotEmpty) ...[
                  _buildNewsSection(
                    '최신 뉴스',
                    remainingNews,
                    isHorizontal: false,
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

  // 뉴스 목록 위젯 (페이징 적용)
  Widget _buildNewsList(NewsViewModel viewModel) {
    // 검색 결과를 최신순으로 정렬
    final newsList = List.from(viewModel.filteredNewsList)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    debugPrint(
      'NewsScreen: 뉴스 목록 빌드 - ${newsList.length}개 뉴스, 필터링됨: ${viewModel.filteredNewsList.isNotEmpty}',
    );

    return Column(
      children: [
        // 뉴스 목록
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              debugPrint('NewsScreen: 당겨서 새로고침 요청');
              await viewModel.fetchInitialNewsPage();
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: _buildNewsItem(news),
                );
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
      margin: EdgeInsets.zero,
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
                    Text(
                      news.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          news.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            // 조회수 표시
                            if (news.viewCount > 0) ...[
                              Icon(
                                Icons.visibility,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${news.viewCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _formatDate(news.publishedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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

  // 뉴스 섹션 위젯
  Widget _buildNewsSection(
    String title,
    List<News> newsList, {
    bool isMainNews = false,
    bool isHorizontal = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (title == '주요 뉴스')
                Text(
                  '조회수 높은 순',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )
              else if (title == '최신 뉴스')
                Text(
                  '최신순',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 뉴스 목록
        isHorizontal
            ? SizedBox(
                height: isMainNews ? 260 : 200,
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
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: newsList.length,
                        itemBuilder: (context, index) {
                          return _buildFeaturedNewsItem(newsList[index]);
                        },
                      ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: newsList.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _buildNewsItem(newsList[index]),
                  );
                },
              ),
      ],
    );
  }

  // 인기 뉴스 아이템 (가로 스크롤용)
  Widget _buildFeaturedNewsItem(News news) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16, left: 2, bottom: 2),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/news_detail', arguments: news);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뉴스 이미지
              if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    news.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 48,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 130,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.article,
                    color: Colors.grey,
                    size: 48,
                  ),
                ),

              // 뉴스 정보
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      news.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          news.source,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            // 조회수 표시
                            if (news.viewCount > 0) ...[
                              Icon(
                                Icons.visibility,
                                size: 11,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${news.viewCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _formatDate(news.publishedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      // 7일 이상이면 날짜 표시
      return '${date.month}월 ${date.day}일';
    } else if (difference.inDays > 0) {
      // 1일 이상이면 n일 전
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      // 1시간 이상이면 n시간 전
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      // 1분 이상이면 n분 전
      return '${difference.inMinutes}분 전';
    } else {
      // 1분 미만이면 방금 전
      return '방금 전';
    }
  }

  // 뉴스 URL 열기
  Future<void> _openNewsUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('뉴스 URL을 열 수 없습니다: $url');
      }
    } catch (e) {
      debugPrint('뉴스 URL 열기 오류: $e');
    }
  }
}
