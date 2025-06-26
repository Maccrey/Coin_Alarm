import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/news_model.dart';
import '../../core/theme.dart';

class NewsDetailScreen extends StatelessWidget {
  final News news;

  const NewsDetailScreen({super.key, required this.news});

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
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  news.imageUrl!,
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
                    news.title,
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
                        news.source,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(news.publishedAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 관련 코인 태그
                  if (news.relatedCoins.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: news.relatedCoins.map((coin) {
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
                    news.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  // 원문 보기 버튼
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNewsUrl(news.url),
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
