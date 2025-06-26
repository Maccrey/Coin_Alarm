// 뉴스 모델 클래스

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class News {
  final String id;
  final String title;
  final String content;
  final String source;
  final String url;
  final DateTime publishedAt;
  final List<String> relatedCoins;
  final String? imageUrl;
  final int viewCount;

  News({
    String? id,
    required this.title,
    required this.content,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.imageUrl,
    List<String>? relatedCoins,
    this.viewCount = 0,
  }) : id = id ?? _generateSafeId(title, url),
       relatedCoins = relatedCoins ?? [];

  /// Firebase 경로에 안전한 ID 생성
  static String _generateSafeId(String title, String url) {
    // 1. URL과 제목을 합쳐서 해시 생성
    final String input = '$url-$title';
    final bytes = utf8.encode(input);
    final hash = md5.convert(bytes).toString();

    // 2. 특수 문자가 없는 안전한 ID 반환
    return hash;
  }

  /// 새로운 안전한 ID로 뉴스 객체 복제
  News withSafeId() {
    final safeId = _generateSafeId(title, url);
    return News(
      id: safeId,
      title: title,
      content: content,
      source: source,
      url: url,
      publishedAt: publishedAt,
      imageUrl: imageUrl,
      relatedCoins: List.from(relatedCoins),
      viewCount: viewCount,
    );
  }

  // JSON에서 변환
  factory News.fromJson(Map<String, dynamic> json) {
    // related_coins가 String(예: '["xrp"]')으로 들어오는 경우도 robust하게 처리
    dynamic coins = json['related_coins'];
    if (coins == null) {
      // Firebase Realtime Database 구조에 맞게 필드 이름 확인
      coins = json['relatedCoins'];
    }

    List<String> relatedCoins;
    if (coins is String) {
      try {
        relatedCoins = List<String>.from(jsonDecode(coins));
      } catch (_) {
        relatedCoins = [coins];
      }
    } else if (coins is List) {
      relatedCoins = List<String>.from(coins);
    } else {
      relatedCoins = [];
    }

    // Firebase Realtime Database의 필드 이름 매핑
    String? publishedAtStr = json['published_at'] ?? json['pub_date'];

    // publishedAt이 없는 경우 timestamp 필드 확인 (Firebase Realtime Database에서 자주 사용)
    if (publishedAtStr == null) {
      final timestamp = json['timestamp'] ?? json['publishedAt'];
      if (timestamp is int) {
        // Unix timestamp (밀리초)
        return News(
          id: json['id'],
          title: json['title'],
          content: json['content'],
          source: json['source'],
          url: json['url'],
          publishedAt: DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal(),
          relatedCoins: relatedCoins,
          imageUrl: json['image_url'] ?? json['imageUrl'],
          viewCount:
              json['view_count'] as int? ?? json['viewCount'] as int? ?? 0,
        );
      } else if (timestamp is String) {
        // ISO 문자열
        publishedAtStr = timestamp;
      } else {
        // 기본값
        publishedAtStr = DateTime.now().toIso8601String();
      }
    }

    final String imageUrlStr = json['image_url'] ?? json['imageUrl'] ?? '';

    return News(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      source: json['source'],
      url: json['url'],
      publishedAt: DateTime.parse(publishedAtStr).toLocal(),
      relatedCoins: relatedCoins,
      imageUrl: imageUrlStr,
      viewCount: json['view_count'] as int? ?? json['viewCount'] as int? ?? 0,
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
      'view_count': viewCount,
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
    int? viewCount,
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
      viewCount: viewCount ?? this.viewCount,
    );
  }
}
