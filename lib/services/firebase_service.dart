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
import '../firebase_options.dart';

/// 뉴스 페이징 결과 모델
class NewsPageResult {
  final List<News> news;
  final dynamic lastDoc; // Firestore: DocumentSnapshot, RealtimeDB: key
  final bool hasMore;
  NewsPageResult({required this.news, this.lastDoc, required this.hasMore});
}

/// Firebase 서비스
///
/// Firebase Realtime Database에서 데이터를 가져옵니다.
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

  // 초기화 상태 확인용 public getter
  bool get isInitialized => _isInitialized;
  bool get isWeb => _isWeb;

  /// Firebase 경로에서 유효하지 않은 문자를 인코딩하는 헬퍼 함수
  String _sanitizePathSegment(String segment) {
    if (segment.isEmpty) return segment;

    // Firebase 경로에서 사용할 수 없는 문자를 대체
    return segment
        .replaceAll('.', '_dot_')
        .replaceAll('\$', '_dollar_')
        .replaceAll('#', '_hash_')
        .replaceAll('[', '_lbracket_')
        .replaceAll(']', '_rbracket_')
        .replaceAll('/', '_slash_');
  }

  /// 안전한 데이터베이스 참조 생성
  DatabaseReference _safeRef(String path) {
    // .info로 시작하는 경로는 Firebase의 특별한 경로이므로 정리하지 않음
    if (path.startsWith('.info/')) {
      return _database.ref(path);
    }

    // 경로를 '/'로 분리하고 각 세그먼트를 정리한 후 다시 결합
    final segments = path.split('/');
    final sanitizedSegments = segments.map(_sanitizePathSegment).toList();
    final sanitizedPath = sanitizedSegments.join('/');

    debugPrint('FirebaseService: 경로 정리: $path -> $sanitizedPath');
    return _database.ref(sanitizedPath);
  }

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('FirebaseService: 이미 초기화되어 있습니다.');
      return;
    }

    debugPrint('FirebaseService: 초기화 시작');

    try {
      _isWeb = kIsWeb;
      debugPrint('FirebaseService: 플랫폼 - ${_isWeb ? "웹" : "모바일/데스크톱"}');

      // Firebase 앱 인스턴스 확인
      final apps = Firebase.apps;
      debugPrint('FirebaseService: Firebase 앱 수: ${apps.length}');

      FirebaseApp app;
      if (apps.isEmpty) {
        debugPrint('FirebaseService: Firebase 앱이 초기화되지 않았습니다. 초기화를 진행합니다.');
        try {
          app = await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint('FirebaseService: Firebase 앱 초기화 성공');
        } catch (e) {
          debugPrint('FirebaseService: Firebase 앱 초기화 실패 - $e');
          throw e;
        }
      } else {
        app = Firebase.app();
        debugPrint('FirebaseService: 기존 Firebase 앱 사용');
      }

      // 데이터베이스 인스턴스 생성 전에 URL 확인
      final databaseURL = app.options.databaseURL;
      if (databaseURL == null || databaseURL.isEmpty) {
        debugPrint('FirebaseService: 오류 - Firebase Database URL이 설정되지 않았습니다.');
        throw Exception('Firebase Database URL이 설정되지 않았습니다.');
      }

      debugPrint('FirebaseService: Database URL - $databaseURL');

      // 명시적으로 URL 설정하여 데이터베이스 인스턴스 생성
      _database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: databaseURL,
      );
      debugPrint('FirebaseService: Firebase Realtime Database 인스턴스 생성 성공');

      // 연결 설정
      _database.setLoggingEnabled(true); // 로깅 활성화
      _database.setPersistenceEnabled(true); // 오프라인 캐싱 활성화

      // 데이터베이스 연결 테스트 (오류가 발생해도 앱은 계속 실행)
      try {
        // 연결 확인 전 짧은 지연 추가
        await Future.delayed(const Duration(milliseconds: 500));

        // 연결 테스트는 건너뛰고 초기화 완료로 처리
        debugPrint('FirebaseService: 데이터베이스 연결 테스트 건너뜀');
      } catch (e) {
        // 연결 테스트 오류는 무시하고 계속 진행
        debugPrint('FirebaseService: 데이터베이스 연결 테스트 실패 - $e');
        debugPrint('FirebaseService: 연결 테스트 실패했지만 계속 진행합니다.');
      }

      // 데이터 마이그레이션 실행 (필요한 경우)
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasRunMigration =
            prefs.getBool('has_run_news_id_migration') ?? false;

        if (!hasRunMigration) {
          debugPrint('FirebaseService: 뉴스 ID 마이그레이션 시작');
          await _migrateNewsIds();
          await prefs.setBool('has_run_news_id_migration', true);
          debugPrint('FirebaseService: 뉴스 ID 마이그레이션 완료');
        } else {
          debugPrint('FirebaseService: 뉴스 ID 마이그레이션이 이미 실행되었습니다.');
        }
      } catch (e) {
        // 마이그레이션 실패 시 경고만 표시하고 계속 진행
        debugPrint('FirebaseService: 뉴스 ID 마이그레이션 실패 - $e');
        debugPrint('FirebaseService: 마이그레이션 오류가 발생했지만 계속 진행합니다.');
      }

      _isInitialized = true;
      debugPrint('FirebaseService: 초기화 완료');
    } catch (e) {
      debugPrint('FirebaseService: 초기화 실패 - $e');
      // 초기화 실패해도 앱은 계속 실행될 수 있도록 함
      _isInitialized = false;
      // 오류를 전파하지 않고 처리
      debugPrint('FirebaseService: 초기화 실패했지만 앱은 계속 실행됩니다.');
    }
  }

  /// 뉴스 ID 마이그레이션 - 안전한 ID 형식으로 변환
  Future<void> _migrateNewsIds() async {
    try {
      debugPrint('FirebaseService: 뉴스 ID 마이그레이션 시작');

      // 1. 기존 뉴스 데이터 가져오기
      final snapshot = await _database.ref('news').get();
      if (!snapshot.exists) {
        debugPrint('FirebaseService: 마이그레이션할 뉴스 데이터가 없습니다.');
        return;
      }

      final Map<dynamic, dynamic> newsData =
          snapshot.value as Map<dynamic, dynamic>;
      debugPrint('FirebaseService: ${newsData.length}개의 뉴스 데이터를 마이그레이션합니다.');

      // 2. 각 뉴스 항목을 안전한 ID로 변환
      int migratedCount = 0;
      for (final entry in newsData.entries) {
        try {
          final key = entry.key;
          final value = entry.value as Map<dynamic, dynamic>;

          // 기존 데이터에서 News 객체 생성
          final newsMap = <String, dynamic>{};
          value.forEach((k, v) {
            newsMap[k.toString()] = v;
          });

          // ID가 없으면 키를 ID로 사용
          if (!newsMap.containsKey('id')) {
            newsMap['id'] = key.toString();
          }

          // 필드명 정규화
          if (!newsMap.containsKey('title')) continue; // 제목이 없으면 건너뜀
          if (!newsMap.containsKey('url')) continue; // URL이 없으면 건너뜀

          // 안전한 ID 생성
          final news = News.fromJson(Map<String, dynamic>.from(newsMap));
          final safeNews = news.withSafeId();

          // 키와 ID가 다른 경우에만 마이그레이션 수행
          if (key.toString() != safeNews.id) {
            // 안전한 ID로 데이터 복사
            await _safeRef('news/${safeNews.id}').set({
              'id': safeNews.id,
              'title': safeNews.title,
              'content': safeNews.content,
              'source': safeNews.source,
              'url': safeNews.url,
              'pub_date': safeNews.publishedAt.toIso8601String(),
              'image_url': safeNews.imageUrl,
              'related_coins': safeNews.relatedCoins,
              'view_count': safeNews.viewCount,
              'timestamp': value['timestamp'] ?? ServerValue.timestamp,
              'migrated_from': key.toString(),
            });

            // 원본 데이터 삭제 (선택적)
            // await _database.ref('news/$key').remove();

            migratedCount++;
          }
        } catch (e) {
          debugPrint('FirebaseService: 뉴스 항목 마이그레이션 실패 - $e');
        }
      }

      debugPrint('FirebaseService: $migratedCount개의 뉴스 ID를 마이그레이션했습니다.');
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 ID 마이그레이션 중 오류 발생 - $e');
      rethrow;
    }
  }

  /// 뉴스 목록 가져오기
  Future<List<News>> getNews({int limit = 10}) async {
    try {
      // Firebase Realtime Database에서 뉴스 데이터 가져오기
      final snapshot = await _safeRef('news').limitToLast(limit).get();

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
      rethrow;
    }
  }

  /// 뉴스 추가 (중복 체크 포함)
  Future<void> addNews(News news) async {
    try {
      // 해시 중복 체크 후 추가
      final isDuplicate = await _checkAndRemoveDuplicateNews(news);
      if (isDuplicate) {
        debugPrint(
          'FirebaseService: 중복된 뉴스 발견 - ID: ${news.id}, 제목: ${news.title}',
        );
        // 중복된 뉴스는 이미 처리되었으므로 추가 작업 불필요
        return;
      }

      // Firebase Realtime Database에 뉴스 추가
      await _safeRef('news/${news.id}').set({
        'id': news.id,
        'title': news.title,
        'content': news.content,
        'source': news.source,
        'url': news.url,
        'pub_date': news.publishedAt.toIso8601String(),
        'image_url': news.imageUrl,
        'related_coins': news.relatedCoins,
        'view_count': news.viewCount,
        'timestamp': ServerValue.timestamp,
      });

      debugPrint('FirebaseService: 뉴스 추가 완료 - ${news.title}');
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 추가 실패 - $e');
      rethrow;
    }
  }

  /// 해시값이 동일한 중복 뉴스를 체크하고 삭제
  Future<bool> _checkAndRemoveDuplicateNews(News newNews) async {
    try {
      // 뉴스의 해시값(ID) 가져오기
      final newsHash = newNews.id;

      // 동일한 해시값을 가진 다른 뉴스 검색
      final snapshot = await _safeRef(
        'news',
      ).orderByChild('id').equalTo(newsHash).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // 이미 동일한 해시값을 가진 뉴스가 있는 경우
        if (data.isNotEmpty) {
          int removedCount = 0;

          // 모든 중복 항목 처리
          for (final entry in data.entries) {
            final key = entry.key;
            final value = entry.value as Map<dynamic, dynamic>;

            // 이미 존재하는 뉴스의 ID 가져오기
            final existingId = value['id'] ?? key.toString();

            // 조회수가 더 높은 뉴스 선택
            final existingViewCount = value['view_count'] as int? ?? 0;

            if (existingId != newNews.id) {
              // 새 뉴스의 조회수가 더 높으면 기존 뉴스 삭제
              if (newNews.viewCount > existingViewCount) {
                await _safeRef('news/$key').remove();
                removedCount++;
                debugPrint(
                  'FirebaseService: 중복 뉴스 삭제 (조회수 낮음) - 키: $key, ID: $existingId',
                );
              }
              // 기존 뉴스의 조회수가 더 높으면 새 뉴스 추가하지 않음
              else {
                debugPrint(
                  'FirebaseService: 중복 뉴스 발견 (기존 조회수 높음) - 키: $key, ID: $existingId',
                );
                return true; // 중복 발견, 새 뉴스 추가하지 않음
              }
            }
          }

          if (removedCount > 0) {
            debugPrint('FirebaseService: $removedCount개의 중복 뉴스 삭제됨');
          }

          // 모든 중복 항목이 삭제되었으면 새 뉴스 추가 가능
          return false;
        }
      }

      // 중복 없음, 새 뉴스 추가 가능
      return false;
    } catch (e) {
      debugPrint('FirebaseService: 중복 뉴스 체크 중 오류 발생 - $e');
      // 오류 발생 시 안전하게 추가 진행
      return false;
    }
  }

  /// 전체 뉴스에서 중복 항목 정리 (관리자용)
  Future<int> cleanupDuplicateNews() async {
    try {
      debugPrint('FirebaseService: 중복 뉴스 정리 시작');

      // 1. 모든 뉴스 데이터 가져오기
      final snapshot = await _safeRef('news').get();
      if (!snapshot.exists) {
        debugPrint('FirebaseService: 정리할 뉴스 데이터가 없습니다.');
        return 0;
      }

      final Map<dynamic, dynamic> newsData =
          snapshot.value as Map<dynamic, dynamic>;
      debugPrint('FirebaseService: ${newsData.length}개의 뉴스 데이터 검사 시작');

      // 2. 해시값(ID) 기준으로 그룹화
      final Map<String, List<MapEntry<dynamic, dynamic>>> groupedByHash = {};

      for (final entry in newsData.entries) {
        final key = entry.key;
        final value = entry.value as Map<dynamic, dynamic>;

        // ID 가져오기
        final id = value['id'] ?? key.toString();

        if (!groupedByHash.containsKey(id)) {
          groupedByHash[id] = [];
        }

        groupedByHash[id]!.add(entry);
      }

      // 3. 중복 항목 처리
      int removedCount = 0;

      for (final hash in groupedByHash.keys) {
        final entries = groupedByHash[hash]!;

        // 중복이 있는 경우만 처리
        if (entries.length > 1) {
          debugPrint(
            'FirebaseService: 해시값 "$hash"에 ${entries.length}개의 중복 항목 발견',
          );

          // 조회수가 가장 높은 항목 찾기
          MapEntry<dynamic, dynamic>? highestViewCountEntry;
          int maxViewCount = -1;

          for (final entry in entries) {
            final value = entry.value as Map<dynamic, dynamic>;
            final viewCount = value['view_count'] as int? ?? 0;

            if (viewCount > maxViewCount) {
              maxViewCount = viewCount;
              highestViewCountEntry = entry;
            }
          }

          // 조회수가 가장 높은 항목을 제외하고 모두 삭제
          for (final entry in entries) {
            if (entry != highestViewCountEntry) {
              await _safeRef('news/${entry.key}').remove();
              removedCount++;
              debugPrint('FirebaseService: 중복 뉴스 삭제 - 키: ${entry.key}');
            }
          }
        }
      }

      debugPrint('FirebaseService: 중복 뉴스 정리 완료 - $removedCount개 삭제됨');
      return removedCount;
    } catch (e) {
      debugPrint('FirebaseService: 중복 뉴스 정리 중 오류 발생 - $e');
      return -1;
    }
  }

  /// 뉴스 업데이트
  Future<void> updateNews(News news) async {
    try {
      // Firebase Realtime Database에서 뉴스 업데이트
      await _safeRef('news/${news.id}').update({
        'title': news.title,
        'content': news.content,
        'source': news.source,
        'url': news.url,
        'pub_date': news.publishedAt.toIso8601String(),
        'image_url': news.imageUrl,
        'related_coins': news.relatedCoins,
        'view_count': news.viewCount,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 뉴스 조회수만 업데이트
  Future<void> updateNewsViewCount(String newsId, int viewCount) async {
    try {
      debugPrint('FirebaseService: 뉴스 조회수 업데이트 - ID: $newsId, 조회수: $viewCount');
      await _safeRef('news/$newsId').update({'view_count': viewCount});
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 조회수 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 뉴스 데이터가 변경된 경우에만 업데이트
  Future<bool> updateNewsIfChanged(News news, News? existingNews) async {
    try {
      // 기존 뉴스가 없으면 새로 추가
      if (existingNews == null) {
        await addNews(news);
        return true;
      }

      // 변경 사항이 있는지 확인
      bool hasChanges = false;
      final updates = <String, dynamic>{};

      if (news.title != existingNews.title) {
        updates['title'] = news.title;
        hasChanges = true;
      }
      if (news.content != existingNews.content) {
        updates['content'] = news.content;
        hasChanges = true;
      }
      if (news.source != existingNews.source) {
        updates['source'] = news.source;
        hasChanges = true;
      }
      if (news.url != existingNews.url) {
        updates['url'] = news.url;
        hasChanges = true;
      }
      if (news.imageUrl != existingNews.imageUrl) {
        updates['image_url'] = news.imageUrl;
        hasChanges = true;
      }
      if (!_areListsEqual(news.relatedCoins, existingNews.relatedCoins)) {
        updates['related_coins'] = news.relatedCoins;
        hasChanges = true;
      }
      if (news.viewCount != existingNews.viewCount) {
        updates['view_count'] = news.viewCount;
        hasChanges = true;
      }

      // 변경 사항이 있는 경우에만 업데이트
      if (hasChanges) {
        updates['timestamp'] = ServerValue.timestamp;
        await _safeRef('news/${news.id}').update(updates);
        debugPrint(
          'FirebaseService: 뉴스 업데이트 완료 - ID: ${news.id}, 변경된 필드: ${updates.keys.join(", ")}',
        );
        return true;
      }

      debugPrint('FirebaseService: 뉴스 변경 사항 없음 - ID: ${news.id}');
      return false;
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 조건부 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 두 리스트가 같은지 비교
  bool _areListsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// 뉴스 삭제
  Future<void> deleteNews(String newsId) async {
    try {
      // Firebase Realtime Database에서 뉴스 삭제
      await _safeRef('news/$newsId').remove();
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 코인별 뉴스 가져오기
  Future<List<News>> getNewsByCoin(String coinId, {int limit = 5}) async {
    try {
      // Firebase Realtime Database에서 특정 코인 관련 뉴스 가져오기
      // 참고: 실제 구현에서는 쿼리 최적화가 필요할 수 있음
      final snapshot = await _safeRef('news').get();

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
      rethrow;
    }
  }

  /// 가격 알림 목록 가져오기
  Future<List<PriceAlert>> getPriceAlerts(String userId) async {
    try {
      final snapshot = await _safeRef('price_alerts/$userId').get();

      if (snapshot.exists) {
        final List<PriceAlert> alerts = [];
        final Map<dynamic, dynamic> values =
            snapshot.value as Map<dynamic, dynamic>;

        values.forEach((key, value) {
          final Map<String, dynamic> alertData = {
            'id': value['id'] ?? key,
            'user_id': value['user_id'] ?? userId,
            'coin_id': value['coin_id'] ?? '',
            'coin_symbol': value['coin_symbol'] ?? '',
            'price_target': value['price_target'] ?? 0.0,
            'is_above': value['is_above'] ?? true,
            'is_triggered': value['is_triggered'] ?? false,
            'created_at':
                value['created_at'] ?? DateTime.now().toIso8601String(),
            'triggered_at': value['triggered_at'],
            'notes': value['notes'],
          };

          alerts.add(PriceAlert.fromJson(alertData));
        });

        return alerts;
      }

      return [];
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 목록 가져오기 실패 - $e');
      rethrow;
    }
  }

  /// 가격 알림 추가
  Future<void> addPriceAlert(String userId, PriceAlert alert) async {
    try {
      await _safeRef('price_alerts/$userId/${alert.id}').set({
        'id': alert.id,
        'user_id': alert.userId,
        'coin_id': alert.coinId,
        'coin_symbol': alert.coinSymbol,
        'price_target': alert.priceTarget,
        'is_above': alert.isAbove,
        'is_triggered': alert.isTriggered,
        'created_at': alert.createdAt.toIso8601String(),
        'triggered_at': alert.triggeredAt?.toIso8601String(),
        'notes': alert.notes,
      });
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 추가 실패 - $e');
      rethrow;
    }
  }

  /// 가격 알림 업데이트
  Future<void> updatePriceAlert(String userId, PriceAlert alert) async {
    try {
      await _safeRef('price_alerts/$userId/${alert.id}').update({
        'price_target': alert.priceTarget,
        'is_above': alert.isAbove,
        'is_triggered': alert.isTriggered,
        'triggered_at': alert.triggeredAt?.toIso8601String(),
        'notes': alert.notes,
      });
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 업데이트 실패 - $e');
      rethrow;
    }
  }

  /// 가격 알림 삭제
  Future<void> deletePriceAlert(String userId, String alertId) async {
    try {
      await _safeRef('price_alerts/$userId/$alertId').remove();
    } catch (e) {
      debugPrint('FirebaseService: 가격 알림 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 이미지 업로드 (실제 구현은 Firebase Storage 필요)
  Future<String> uploadImage(String path, List<int> bytes) async {
    // 실제로는 Firebase Storage에 업로드 로직 구현 필요
    throw UnimplementedError('이미지 업로드 기능은 아직 구현되지 않았습니다.');
  }

  /// 리소스 정리
  void dispose() {
    // 리소스 정리가 필요한 경우 여기에 구현
  }

  /// Firebase Realtime Database에서 페이징된 뉴스 데이터 가져오기
  Future<NewsPageResult> getNewsPaged({
    int limit = 50, // 한 번에 가져오는 뉴스 개수를 20개에서 50개로 증가
    dynamic startAfter,
  }) async {
    debugPrint(
      'FirebaseService: [뉴스 요청] 시작 - limit: $limit, startAfter: $startAfter',
    );

    if (!isInitialized) {
      debugPrint('FirebaseService: [뉴스 요청] Firebase가 초기화되지 않음, 초기화 시도');
      await initialize();
    }

    try {
      final startTime = DateTime.now();
      final databaseRef = _database.ref();
      final newsRef = _safeRef('news');

      debugPrint(
        'FirebaseService: [뉴스 요청] Realtime Database 경로: ${newsRef.path}',
      );

      // 최신 뉴스부터 가져오기 위해 orderByChild('timestamp') 사용
      Query query = newsRef.orderByChild('timestamp').limitToLast(limit);

      // startAfter가 있으면 페이징 적용
      if (startAfter != null && startAfter is String) {
        try {
          debugPrint('FirebaseService: [뉴스 요청] startAfter 키 사용: $startAfter');
          // 이전 페이지의 마지막 항목의 타임스탬프 값을 가져와서 endBefore로 사용
          final lastItemRef = _safeRef('news/$startAfter');
          final lastItemSnapshot = await lastItemRef.get();
          if (lastItemSnapshot.exists && lastItemSnapshot.value != null) {
            final lastItemData = Map<String, dynamic>.from(
              lastItemSnapshot.value as Map,
            );
            final timestamp = lastItemData['timestamp'];
            if (timestamp != null) {
              debugPrint('FirebaseService: [뉴스 요청] 마지막 항목 타임스탬프: $timestamp');
              query = newsRef
                  .orderByChild('timestamp')
                  .endBefore(timestamp)
                  .limitToLast(limit);
            }
          }
        } catch (e) {
          debugPrint('FirebaseService: [뉴스 요청] startAfter 적용 실패 - $e');
          // 오류 발생 시 원래 쿼리 사용
        }
      }

      debugPrint('FirebaseService: [뉴스 요청] 쿼리 실행 중...');
      final snapshot = await query.get();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      debugPrint(
        'FirebaseService: [뉴스 요청] 응답 받음 - 소요 시간: ${duration.inMilliseconds}ms, 데이터 있음: ${snapshot.exists}',
      );

      if (!snapshot.exists) {
        debugPrint('FirebaseService: [뉴스 요청] 스냅샷에 데이터 없음');
        return NewsPageResult(news: [], lastDoc: null, hasMore: false);
      }

      final Map<dynamic, dynamic>? data =
          snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        debugPrint('FirebaseService: [뉴스 요청] 데이터가 null임');
        return NewsPageResult(news: [], lastDoc: null, hasMore: false);
      }

      debugPrint('FirebaseService: [뉴스 요청] 데이터 맵 크기: ${data.length}개 항목');

      int successCount = 0;
      int errorCount = 0;
      final newsList = <News>[];
      String? lastItemId;

      data.forEach((key, value) {
        try {
          // Firebase Realtime Database는 Map<dynamic, dynamic> 형태로 반환하므로 변환 필요
          final Map<String, dynamic> newsData = Map<String, dynamic>.from(
            value as Map,
          );

          // ID 필드가 없는 경우 키를 ID로 사용
          if (!newsData.containsKey('id')) {
            newsData['id'] = key.toString();
          }

          // 첫 번째 항목의 데이터 구조 로깅
          if (successCount == 0) {
            debugPrint(
              'FirebaseService: [뉴스 요청] 첫 번째 항목 데이터 구조: ${newsData.keys.join(", ")}',
            );
            debugPrint(
              'FirebaseService: [뉴스 요청] 첫 번째 항목 ID: ${newsData['id']}, 제목: ${newsData['title'] ?? "제목 없음"}',
            );
          }

          // 필드명 정규화 - Firebase Realtime Database는 카멜케이스를 사용할 수 있음
          if (!newsData.containsKey('published_at') &&
              newsData.containsKey('publishedAt')) {
            newsData['published_at'] = newsData['publishedAt'];
          }

          if (!newsData.containsKey('image_url') &&
              newsData.containsKey('imageUrl')) {
            newsData['image_url'] = newsData['imageUrl'];
          }

          if (!newsData.containsKey('view_count') &&
              newsData.containsKey('viewCount')) {
            newsData['view_count'] = newsData['viewCount'];
          }

          if (!newsData.containsKey('related_coins') &&
              newsData.containsKey('relatedCoins')) {
            newsData['related_coins'] = newsData['relatedCoins'];
          }

          final news = News.fromJson(newsData);
          newsList.add(news);
          successCount++;

          // 마지막 항목의 ID 저장 (다음 페이지를 위함)
          lastItemId = news.id;
        } catch (e) {
          errorCount++;
          debugPrint('FirebaseService: [뉴스 요청] 항목 변환 오류 - 키: $key, 오류: $e');

          // 첫 번째 오류 발생 시 데이터 구조 로깅
          if (errorCount == 1) {
            try {
              final rawData = value as Map;
              debugPrint(
                'FirebaseService: [뉴스 요청] 오류 항목 데이터 구조: ${rawData.keys.join(", ")}',
              );
              // 원본 데이터 출력
              debugPrint('FirebaseService: [뉴스 요청] 오류 항목 원본 데이터: $rawData');
            } catch (e2) {
              debugPrint('FirebaseService: [뉴스 요청] 오류 항목 데이터 구조 확인 실패: $e2');
            }
          }
        }
      });

      debugPrint(
        'FirebaseService: [뉴스 요청] 데이터 변환 결과 - 성공: $successCount개, 실패: $errorCount개',
      );

      // 최신순으로 정렬 (publishedAt 기준 내림차순)
      newsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (newsList.isNotEmpty) {
        debugPrint(
          'FirebaseService: [뉴스 요청] 첫 번째 뉴스 - ID: ${newsList.first.id}, 제목: ${newsList.first.title}, 시간: ${newsList.first.publishedAt}',
        );
        debugPrint(
          'FirebaseService: [뉴스 요청] 마지막 뉴스 - ID: ${newsList.last.id}, 제목: ${newsList.last.title}, 시간: ${newsList.last.publishedAt}',
        );
      }

      // 더 데이터가 있는지 여부 (Realtime Database에서는 정확한 판단이 어려움)
      // 요청한 limit보다 같거나 많은 데이터가 반환되면 더 데이터가 있다고 가정
      final hasMore = newsList.length >= limit;

      debugPrint(
        'FirebaseService: [뉴스 요청] 완료 - ${newsList.length}개 뉴스, 더 있음: $hasMore, 마지막 ID: $lastItemId',
      );

      return NewsPageResult(
        news: newsList,
        lastDoc: lastItemId, // 마지막 항목 ID를 다음 페이지 요청을 위해 반환
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('FirebaseService: [뉴스 요청] 예외 발생 - $e');
      rethrow;
    }
  }

  /// 뉴스 데이터 실시간 스트림 (실시간 업데이트 지원)
  Stream<List<News>> getNewsStream({int limit = 50}) {
    if (!isInitialized) {
      debugPrint('FirebaseService: Firebase가 초기화되지 않음 - 빈 스트림 반환');
      return Stream.value([]);
    }

    try {
      debugPrint('FirebaseService: 뉴스 실시간 스트림 시작 - limit: $limit');
      final newsRef = _safeRef('news');

      // 최신 뉴스부터 가져오기 위해 orderByChild('timestamp') 사용
      final query = newsRef.orderByChild('timestamp').limitToLast(limit);

      return query.onValue.map((event) {
        final List<News> newsList = [];

        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            debugPrint('FirebaseService: 스트림에서 ${data.length}개 뉴스 데이터 수신');

            // 각 뉴스 항목을 News 객체로 변환
            for (final entry in data.entries) {
              try {
                final newsData = Map<String, dynamic>.from(entry.value as Map);

                // 필수 필드 확인 및 기본값 설정
                final id = newsData['id']?.toString() ?? entry.key;
                final title = newsData['title']?.toString() ?? '';
                final content = newsData['content']?.toString() ?? '';
                final source = newsData['source']?.toString() ?? 'Unknown';
                final url = newsData['url']?.toString() ?? '';
                final imageUrl = newsData['image_url']?.toString() ?? '';

                // 날짜 처리
                DateTime publishedAt;
                try {
                  if (newsData['pub_date'] != null) {
                    publishedAt = DateTime.parse(
                      newsData['pub_date'].toString(),
                    );
                  } else {
                    publishedAt = DateTime.now();
                  }
                } catch (e) {
                  debugPrint('FirebaseService: 날짜 파싱 실패, 현재 시간 사용 - $e');
                  publishedAt = DateTime.now();
                }

                // 관련 코인 목록 처리
                List<String> relatedCoins = [];
                if (newsData['related_coins'] != null) {
                  try {
                    if (newsData['related_coins'] is List) {
                      relatedCoins = List<String>.from(
                        newsData['related_coins'],
                      );
                    } else if (newsData['related_coins'] is String) {
                      relatedCoins = [newsData['related_coins']];
                    }
                  } catch (e) {
                    debugPrint('FirebaseService: 관련 코인 파싱 실패 - $e');
                    relatedCoins = [];
                  }
                }

                // 조회수 처리 (중요!)
                int viewCount = 0;
                try {
                  if (newsData['view_count'] != null) {
                    viewCount = int.parse(newsData['view_count'].toString());
                  }
                } catch (e) {
                  debugPrint('FirebaseService: 조회수 파싱 실패, 0으로 설정 - $e');
                  viewCount = 0;
                }

                // 빈 제목이나 콘텐츠는 건너뛰기
                if (title.isNotEmpty || content.isNotEmpty) {
                  final news = News(
                    id: id,
                    title: title,
                    content: content,
                    source: source,
                    url: url,
                    imageUrl: imageUrl,
                    publishedAt: publishedAt,
                    relatedCoins: relatedCoins,
                    viewCount: viewCount,
                  );

                  newsList.add(news);

                  // 조회수가 있는 뉴스는 로그 출력
                  if (viewCount > 0) {
                    debugPrint(
                      'FirebaseService: 스트림 조회수 데이터 - ID: $id, 조회수: $viewCount',
                    );
                  }
                }
              } catch (e) {
                debugPrint(
                  'FirebaseService: 개별 뉴스 데이터 처리 실패 - ${entry.key}: $e',
                );
              }
            }

            // 최신순으로 정렬 (publishedAt 기준)
            newsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

            debugPrint('FirebaseService: 스트림에서 최종 ${newsList.length}개 뉴스 반환');

            // 조회수 통계 출력
            final newsWithViews = newsList
                .where((news) => news.viewCount > 0)
                .toList();
            if (newsWithViews.isNotEmpty) {
              debugPrint('FirebaseService: 조회수 있는 뉴스 ${newsWithViews.length}개');
              debugPrint(
                'FirebaseService: 최고 조회수 - ${newsWithViews.first.viewCount}',
              );
            }
          } catch (e) {
            debugPrint('FirebaseService: 스트림 데이터 처리 실패 - $e');
          }
        } else {
          debugPrint('FirebaseService: 스트림에서 데이터 없음');
        }

        return newsList;
      });
    } catch (e) {
      debugPrint('FirebaseService: 뉴스 실시간 스트림 생성 실패 - $e');
      return Stream.value([]);
    }
  }
}
