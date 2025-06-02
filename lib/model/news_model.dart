// 뉴스 모델 클래스

class News {
  final String id;
  final String title;
  final String content;
  final String source;
  final String url;
  final DateTime publishedAt;
  final List<String> relatedCoins;
  final String? imageUrl;

  News({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.relatedCoins,
    this.imageUrl,
  });

  // JSON에서 변환
  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      source: json['source'],
      url: json['url'],
      publishedAt: DateTime.parse(json['published_at']),
      relatedCoins: List<String>.from(json['related_coins']),
      imageUrl: json['image_url'],
    );
  }

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'source': source,
      'url': url,
      'published_at': publishedAt.toIso8601String(),
      'related_coins': relatedCoins,
      'image_url': imageUrl,
    };
  }

  // 뉴스 게시 시간 포맷팅
  String get publishedTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 뉴스 내용 요약 (미리보기용)
  String get contentSummary {
    if (content.length > 100) {
      return '${content.substring(0, 100)}...';
    }
    return content;
  }

  // 콘텐츠 요약 (최대 100자)
  String get summary {
    if (content.length <= 100) {
      return content;
    }
    return '${content.substring(0, 97)}...';
  }

  // 시간 경과 표시
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inDays > 7) {
      return '${publishedAt.year}.${publishedAt.month}.${publishedAt.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // News 객체 복사본 생성 (필드 업데이트 가능)
  News copyWith({
    String? id,
    String? title,
    String? content,
    String? source,
    String? url,
    DateTime? publishedAt,
    List<String>? relatedCoins,
    String? imageUrl,
  }) {
    return News(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      source: source ?? this.source,
      url: url ?? this.url,
      publishedAt: publishedAt ?? this.publishedAt,
      relatedCoins: relatedCoins ?? this.relatedCoins,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
