import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    // 컴포넌트가 마운트되면 뉴스 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);
      // 모든 필터 초기화 후 전체 뉴스 로드
      _selectedFilter = '전체';
      newsViewModel.clearFilter(); // 필터 초기화
      newsViewModel.refreshNews(); // 전체 뉴스 로드
      debugPrint('뉴스 화면 초기화: 전체 뉴스 로드 요청');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // 검색 실행
  void _performSearch(String query) {
    // NewsViewModel을 통해 검색 실행
    final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);
    newsViewModel.searchNews(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Provider.of<NewsViewModel>(context) 대신 Consumer 사용
    return Consumer<NewsViewModel>(
      builder: (context, newsViewModel, _) {
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
          ),
          body: newsViewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : newsViewModel.errorMessage != null
              ? _buildErrorView(newsViewModel.errorMessage!)
              : _searchController.text.isNotEmpty || _selectedFilter != '전체'
              ? _buildNewsList(newsViewModel)
              : _buildNewsPageWithSections(newsViewModel),
        );
      },
    );
  }

  // 에러 화면
  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '데이터 로드 오류',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final newsViewModel = Provider.of<NewsViewModel>(
                context,
                listen: false,
              );
              newsViewModel.refreshNews();
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
    return RefreshIndicator(
      onRefresh: () => viewModel.refreshNews(),
      child: SingleChildScrollView(
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
              child: viewModel.popularNews.isEmpty
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
                      itemCount: viewModel.popularNews.length,
                      itemBuilder: (context, index) {
                        final news = viewModel.popularNews[index];
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
                TextButton(
                  onPressed: () {
                    // 모든 뉴스 보기 기능
                    setState(() {
                      _selectedFilter = '전체';
                    });
                    final newsViewModel = Provider.of<NewsViewModel>(
                      context,
                      listen: false,
                    );
                    viewModel.loadNewsByCoinId('');
                  },
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 최신 뉴스 목록
            viewModel.newsList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Text('뉴스가 없습니다'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.newsList.length,
                    itemBuilder: (context, index) {
                      final news = viewModel.newsList[index];
                      return _buildNewsItem(news);
                    },
                  ),
          ],
        ),
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
  Widget _buildNewsList(NewsViewModel viewModel) {
    // 디버깅용 로그 추가
    debugPrint(
      '뉴스 목록 표시: 필터=[38;5;2m${_selectedFilter}[0m, 뉴스 개수=${viewModel.newsList.length}',
    );

    final filteredList = viewModel.newsList;
    final onlyFilterList = viewModel.newsListWithoutSearch;

    if (filteredList.isEmpty) {
      debugPrint('뉴스 목록이 비어있음');
      // 검색어가 있고, 필터만 적용하면 뉴스가 있을 때 fallback
      if (_searchController.text.isNotEmpty && onlyFilterList.isNotEmpty) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '검색 결과가 없습니다.\n필터에 해당하는 모든 뉴스를 보여드립니다.',
                style: TextStyle(color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: onlyFilterList.length,
                itemBuilder: (context, index) {
                  final news = onlyFilterList[index];
                  return _buildNewsItem(news);
                },
              ),
            ),
          ],
        );
      }
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
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 로드'),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedFilter = '전체';
                });
                final newsViewModel = Provider.of<NewsViewModel>(
                  context,
                  listen: false,
                );
                newsViewModel.clearFilter(); // 필터와 검색어 모두 초기화
                newsViewModel.refreshNews(); // 전체 뉴스 로드
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshNews(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final news = filteredList[index];
          return _buildNewsItem(news);
        },
      ),
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
                        final symbol = coinId.toUpperCase();

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
}
