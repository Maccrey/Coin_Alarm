import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Clipboard 기능을 위해 추가
import '../../model/news_model.dart';
import '../../core/theme.dart';
import '../../viewmodel/news_viewmodel.dart';
import 'package:flutter/services.dart'; // Clipboard 기능을 위해 추가

class NewsDetailScreen extends StatefulWidget {
  final News news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  @override
  void initState() {
    super.initState();

    // 화면이 로드된 후 조회수 증가
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incrementViewCount();
    });
  }

  // 조회수 증가 메서드
  void _incrementViewCount() {
    final newsViewModel = Provider.of<NewsViewModel>(context, listen: false);
    newsViewModel.incrementViewCount(widget.news);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('뉴스 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 공유 기능 구현 (추후 추가 가능)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('공유 기능은 준비 중입니다')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뉴스 이미지
            if (widget.news.imageUrl != null &&
                widget.news.imageUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  widget.news.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 뉴스 내용
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    widget.news.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 출처 및 시간
                  Row(
                    children: [
                      Text(
                        widget.news.source,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(widget.news.publishedAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      // 조회수 표시
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.news.viewCount}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 관련 코인 태그
                  if (widget.news.relatedCoins.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.news.relatedCoins.map((coin) {
                        return Container(
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
                          child: Text(
                            coin.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),

                  // 본문
                  Text(
                    widget.news.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  // 원문 보기 버튼
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNewsUrl(widget.news.url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('원문 보기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 뉴스 URL 열기
  Future<void> _openNewsUrl(String url) async {
    try {
      // URL이 유효한지 확인
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        debugPrint('유효하지 않은 URL 형식: $url');
        url = 'https://$url'; // URL에 https:// 접두사 추가 시도
      }

      debugPrint('뉴스 URL 열기 시도: $url');
      final uri = Uri.parse(url);

      // 방법 1: 외부 애플리케이션으로 열기 시도
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('외부 애플리케이션으로 URL 열기 시도 결과: $launched');
      } catch (e) {
        debugPrint('외부 애플리케이션으로 URL 열기 실패: $e');
      }

      // 첫 번째 방법이 실패하면 다른 방법 시도
      if (!launched) {
        debugPrint('다른 방법으로 URL 열기 시도...');
        try {
          // 방법 2: 인앱 브라우저로 열기 시도
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
          debugPrint('인앱 브라우저로 URL 열기 시도 결과: $launched');
        } catch (e) {
          debugPrint('인앱 브라우저로 URL 열기 실패: $e');
        }
      }

      // 여전히 실패하면 플랫폼 기본 방식으로 시도
      if (!launched) {
        debugPrint('플랫폼 기본 방식으로 URL 열기 시도...');
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          debugPrint('플랫폼 기본 방식으로 URL 열기 시도 결과: $launched');
        } catch (e) {
          debugPrint('플랫폼 기본 방식으로 URL 열기 실패: $e');
        }
      }

      // 모든 방법이 실패하면 사용자에게 알림
      if (!launched) {
        debugPrint('모든 URL 열기 방법 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이 링크를 열 수 없습니다: $url'),
              action: SnackBarAction(
                label: 'URL 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url)).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL이 클립보드에 복사되었습니다')),
                    );
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('URL 처리 중 예외 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크를 처리하는 중 오류가 발생했습니다: ${e.toString()}')),
        );
      }
    }
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      // 7일 이상이면 날짜 표시
      return '${date.year}년 ${date.month}월 ${date.day}일';
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
}
