import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';

import '../model/news_model.dart';
import '../model/coin_model.dart';
import '../model/price_alert_model.dart';

/// Firebase 서비스
///
/// Firebase Realtime Database에서 데이터를 가져오며, 웹 환경에서는 모의 서비스로 대체됩니다.
class FirebaseService {
  // 싱글톤 패턴 구현
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase 인스턴스
  late final FirebaseDatabase _database;

  // 초기화 여부
  bool _isInitialized = false;
  bool _isWeb = false;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('FirebaseService: 초기화 시작');

    try {
      _isWeb = kIsWeb;

      if (!_isWeb) {
        // 모바일 환경에서는 실제 Firebase 사용
        _database = FirebaseDatabase.instance;
        _database.setPersistenceEnabled(true); // 오프라인 캐싱 활성화
        _database.setPersistenceCacheSizeBytes(10000000); // 캐시 크기 설정 (10MB)
        _isInitialized = true;
        debugPrint('FirebaseService: 초기화 완료');
      } else {
        // 웹 환경에서는 모의 데이터 사용
        await _initializeMockData();
        _isInitialized = true;
        debugPrint('FirebaseService: 초기화 완료 (모의 서비스)');
      }
    } catch (e) {
      debugPrint('FirebaseService: 초기화 실패 - $e');
      // 실패 시 모의 데이터로 폴백
      await _initializeMockData();
      _isInitialized = true;
      debugPrint('FirebaseService: 모의 서비스로 폴백');
    }
  }

  /// 모의 데이터 초기화
  Future<void> _initializeMockData() async {
    final prefs = await SharedPreferences.getInstance();

    // 모의 뉴스 데이터 초기화
    if (prefs.getString('mock_news') == null) {
      final mockNews = [
        News(
          id: '003f6eebef791b3f9182f4c127d214db',
          title: '[주요 뉴스] 바운드리스, 블록체인 인프라 혁신 ... 조연이 빛나는 무대',
          content:
              "[블록미디어] 2025년 블록체인 산업은 '무대 위'가 아닌 '무대 뒤'로 중심이 이동했다. 스마트라이트 경쟁이 끝나고, 다른 프로젝트들이 빛날 수 있도록 설계된 인프라 기술이 주목받고 있다. 바운드리스는 이러한 변화의 중심에 있다.",
          source: 'blockmedia',
          url: 'https://www.blockmedia.co.kr/archives/932666',
          publishedAt: DateTime.parse('2025-06-23T12:04:16.450117+09:00'),
          relatedCoins: ['bitcoin', 'ethereum'],
          imageUrl:
              'https://www.blockmedia.co.kr/wp-content/uploads/2025/06/Screenshot-2025-06-19-at-5.39.27PM.png?v=1750645235',
          viewCount: 0,
        ),
        News(
          id: '01412db61ea7feaae4f314669b9ca9d3',
          title: '비트코인, 6만 달러 돌파... 기관 투자자 유입 증가',
          content:
              "비트코인이 6만 달러를 돌파했다. 이는 기관 투자자들의 유입이 증가하면서 나타난 현상으로 분석된다. 특히 블랙록의 비트코인 ETF가 출시된 이후 기관 자금의 유입이 크게 늘어났다. 전문가들은 이러한 추세가 계속될 경우 연말까지 7만 달러 돌파도 가능할 것으로 전망하고 있다. 한편, 이더리움 역시 강세를 보이며 3,500달러를 향해 상승 중이다.",
          source: 'cryptonews',
          url: 'https://example.com/bitcoin-60k',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          relatedCoins: ['bitcoin', 'ethereum'],
          imageUrl:
              'https://www.blockmedia.co.kr/wp-content/uploads/2025/06/Screenshot-2025-06-19-at-5.39.27PM.png?v=1750645235',
          viewCount: 0,
        ),
      ];

      await prefs.setString(
        'mock_news',
        json.encode(mockNews.map((e) => e.toJson()).toList()),
      );
    }
  }

  /// 뉴스 목록 가져오기
  Future<List<News>> getNews({int limit = 10}) async {
    try {
      if (_isWeb) {
        return _getMockNews(limit: limit);
      }

      // Firebase Realtime Database에서 뉴스 데이터 가져오기
      final snapshot = await _database.ref('news').limitToLast(limit).get();

      if (snapshot.exists) {
        final List<News> newsList = [];
        final Map<dynamic, dynamic> values =
            snapshot.value as Map<dynamic, dynamic>;

        values.forEach((key, value) {
          // Firebase Realtime Database 구조에 맞게 데이터 매핑
          final Map<String, dynamic> newsData = {
            'id': value['id'] ?? key,
            'title': value['title'] ?? '',
            'content': value['content'] ?? '',
            'source': value['source'] ?? '',
            'url': value['url'] ?? '',
            'published_at':
                value['pub_date'] ?? DateTime.now().toIso8601String(),
            'image_url': value['image_url'] ?? '',
            'related_coins': value['related_coins'] ?? [],
            'view_count': value['view_count'] ?? 0,
          };

          newsList.add(News.fromJson(newsData));
        });

        // 최신순으로 정렬
        newsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        return newsList.take(limit).toList();
      }

      return [];
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 가져오기 실패 - $e');
      // 오류 발생 시 모의 데이터로 폴백
      return _getMockNews(limit: limit);
    }
  }

  /// 모의 뉴스 데이터 가져오기
  Future<List<News>> _getMockNews({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newsJson = prefs.getString('mock_news');

      if (newsJson != null) {
        final List<dynamic> newsData = json.decode(newsJson);
        final newsList = newsData.map((data) => News.fromJson(data)).toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

        return newsList.take(limit).toList();
      }
      return [];
    } catch (e) {
      debugPrint('FirebaseService: 모의 뉴스 가져오기 실패 - $e');
      return [];
    }
  }

  /// 뉴스 추가
  Future<void> addNews(News news) async {
    try {
      if (_isWeb) {
        await _addMockNews(news);
        return;
      }

      // Firebase Realtime Database에 뉴스 추가
      await _database.ref('news/${news.id}').set({
        'id': news.id,
        'title': news.title,
        'content': news.content,
        'source': news.source,
        'url': news.url,
        'pub_date': news.publishedAt.toIso8601String(),
        'image_url': news.imageUrl,
        'related_coins': news.relatedCoins,
        'view_count': news.viewCount,
      });
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 추가 실패 - $e');
      // 오류 발생 시 모의 데이터에 추가
      await _addMockNews(news);
    }
  }

  /// 모의 뉴스 추가
  Future<void> _addMockNews(News news) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newsJson = prefs.getString('mock_news');

      final List<dynamic> newsData = newsJson != null
          ? json.decode(newsJson)
          : [];

      // 기존 뉴스 목록에 새 뉴스 추가
      newsData.add(news.toJson());

      await prefs.setString('mock_news', json.encode(newsData));
    } catch (e) {
      debugPrint('FirebaseService: 모의 뉴스 추가 실패 - $e');
      rethrow;
    }
  }

  /// 뉴스 업데이트
  Future<void> updateNews(News news) async {
    try {
      if (_isWeb) {
        await _updateMockNews(news);
        return;
      }

      // Firebase Realtime Database에서 뉴스 업데이트
      await _database.ref('news/${news.id}').update({
        'title': news.title,
        'content': news.content,
        'source': news.source,
        'url': news.url,
        'pub_date': news.publishedAt.toIso8601String(),
        'image_url': news.imageUrl,
        'related_coins': news.relatedCoins,
        'view_count': news.viewCount,
      });
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 업데이트 실패 - $e');
      // 오류 발생 시 모의 데이터 업데이트
      await _updateMockNews(news);
    }
  }

  /// 모의 뉴스 업데이트
  Future<void> _updateMockNews(News news) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newsJson = prefs.getString('mock_news');

      if (newsJson != null) {
        final List<dynamic> newsData = json.decode(newsJson);

        // 기존 뉴스 찾아 업데이트
        final index = newsData.indexWhere((data) => data['id'] == news.id);
        if (index != -1) {
          newsData[index] = news.toJson();
          await prefs.setString('mock_news', json.encode(newsData));
        }
      }
    } catch (e) {
      debugPrint('FirebaseService: 모의 뉴스 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 뉴스 삭제
  Future<void> deleteNews(String newsId) async {
    try {
      if (_isWeb) {
        await _deleteMockNews(newsId);
        return;
      }

      // Firebase Realtime Database에서 뉴스 삭제
      await _database.ref('news/$newsId').remove();
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 삭제 실패 - $e');
      // 오류 발생 시 모의 데이터에서 삭제
      await _deleteMockNews(newsId);
    }
  }

  /// 모의 뉴스 삭제
  Future<void> _deleteMockNews(String newsId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newsJson = prefs.getString('mock_news');

      if (newsJson != null) {
        final List<dynamic> newsData = json.decode(newsJson);

        // 해당 ID의 뉴스 삭제
        final filteredNews = newsData
            .where((data) => data['id'] != newsId)
            .toList();
        await prefs.setString('mock_news', json.encode(filteredNews));
      }
    } catch (e) {
      debugPrint('FirebaseService: 모의 뉴스 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 코인별 뉴스 가져오기
  Future<List<News>> getNewsByCoin(String coinId, {int limit = 5}) async {
    try {
      if (_isWeb) {
        return _getMockNewsByCoin(coinId, limit: limit);
      }

      // Firebase Realtime Database에서 특정 코인 관련 뉴스 가져오기
      // 참고: 실제 구현에서는 쿼리 최적화가 필요할 수 있음
      final snapshot = await _database.ref('news').get();

      if (snapshot.exists) {
        final List<News> newsList = [];
        final Map<dynamic, dynamic> values =
            snapshot.value as Map<dynamic, dynamic>;

        values.forEach((key, value) {
          // 관련 코인 확인
          List<String> relatedCoins = [];
          if (value['related_coins'] != null) {
            if (value['related_coins'] is List) {
              relatedCoins = List<String>.from(value['related_coins']);
            } else if (value['related_coins'] is String) {
              try {
                relatedCoins = List<String>.from(
                  jsonDecode(value['related_coins']),
                );
              } catch (_) {
                relatedCoins = [value['related_coins']];
              }
            }
          }

          // 해당 코인이 관련 코인 목록에 있는 경우만 추가
          if (relatedCoins.contains(coinId.toLowerCase()) ||
              relatedCoins.contains(coinId.toUpperCase())) {
            final Map<String, dynamic> newsData = {
              'id': value['id'] ?? key,
              'title': value['title'] ?? '',
              'content': value['content'] ?? '',
              'source': value['source'] ?? '',
              'url': value['url'] ?? '',
              'published_at':
                  value['pub_date'] ?? DateTime.now().toIso8601String(),
              'image_url': value['image_url'] ?? '',
              'related_coins': relatedCoins,
              'view_count': value['view_count'] ?? 0,
            };

            newsList.add(News.fromJson(newsData));
          }
        });

        // 최신순으로 정렬
        newsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        return newsList.take(limit).toList();
      }

      return [];
    } catch (e) {
      debugPrint('FirebaseService: 코인별 뉴스 가져오기 실패 - $e');
      // 오류 발생 시 모의 데이터로 폴백
      return _getMockNewsByCoin(coinId, limit: limit);
    }
  }

  /// 모의 코인별 뉴스 가져오기
  Future<List<News>> _getMockNewsByCoin(String coinId, {int limit = 5}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newsJson = prefs.getString('mock_news');

      if (newsJson != null) {
        final List<dynamic> newsData = json.decode(newsJson);
        final newsList =
            newsData
                .map((data) => News.fromJson(data))
                .where((news) => news.relatedCoins.contains(coinId))
                .toList()
              ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

        return newsList.take(limit).toList();
      }
      return [];
    } catch (e) {
      debugPrint('FirebaseService: 모의 코인별 뉴스 가져오기 실패 - $e');
      return [];
    }
  }

  /// 가격 알림 목록 가져오기
  Future<List<PriceAlert>> getPriceAlerts(String userId) async {
    // 가격 알림은 모의 데이터만 사용 (실제 Firebase 구현은 생략)
    return _getMockPriceAlerts(userId);
  }

  /// 모의 가격 알림 목록 가져오기
  Future<List<PriceAlert>> _getMockPriceAlerts(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString('mock_alerts_$userId');

      if (alertsJson != null) {
        final List<dynamic> alertsData = json.decode(alertsJson);
        return alertsData.map((data) => PriceAlert.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 목록 가져오기 실패 - $e');
      return [];
    }
  }

  /// 가격 알림 추가
  Future<void> addPriceAlert(String userId, PriceAlert alert) async {
    // 가격 알림은 모의 데이터만 사용 (실제 Firebase 구현은 생략)
    await _addMockPriceAlert(userId, alert);
  }

  /// 모의 가격 알림 추가
  Future<void> _addMockPriceAlert(String userId, PriceAlert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString('mock_alerts_$userId');

      final List<dynamic> alertsData = alertsJson != null
          ? json.decode(alertsJson)
          : [];

      // 기존 알림 목록에 새 알림 추가
      alertsData.add(alert.toJson());

      await prefs.setString('mock_alerts_$userId', json.encode(alertsData));
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 추가 실패 - $e');
      rethrow;
    }
  }

  /// 가격 알림 업데이트
  Future<void> updatePriceAlert(String userId, PriceAlert alert) async {
    // 가격 알림은 모의 데이터만 사용 (실제 Firebase 구현은 생략)
    await _updateMockPriceAlert(userId, alert);
  }

  /// 모의 가격 알림 업데이트
  Future<void> _updateMockPriceAlert(String userId, PriceAlert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString('mock_alerts_$userId');

      if (alertsJson != null) {
        final List<dynamic> alertsData = json.decode(alertsJson);

        // 기존 알림 찾아 업데이트
        final index = alertsData.indexWhere((data) => data['id'] == alert.id);
        if (index != -1) {
          alertsData[index] = alert.toJson();
          await prefs.setString('mock_alerts_$userId', json.encode(alertsData));
        }
      }
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 가격 알림 삭제
  Future<void> deletePriceAlert(String userId, String alertId) async {
    // 가격 알림은 모의 데이터만 사용 (실제 Firebase 구현은 생략)
    await _deleteMockPriceAlert(userId, alertId);
  }

  /// 모의 가격 알림 삭제
  Future<void> _deleteMockPriceAlert(String userId, String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString('mock_alerts_$userId');

      if (alertsJson != null) {
        final List<dynamic> alertsData = json.decode(alertsJson);

        // 해당 ID의 알림 삭제
        final filteredAlerts = alertsData
            .where((data) => data['id'] != alertId)
            .toList();
        await prefs.setString(
          'mock_alerts_$userId',
          json.encode(filteredAlerts),
        );
      }
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 이미지 업로드 (모의 구현)
  Future<String> uploadImage(String path, List<int> bytes) async {
    // 실제로는 이미지를 업로드하지 않고, 가상 URL 반환
    await Future.delayed(const Duration(seconds: 1));
    return 'https://example.com/mock-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  /// 리소스 정리
  void dispose() {
    // 리소스 정리가 필요한 경우 여기에 구현
  }
}
