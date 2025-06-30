import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../services/firebase_service.dart';
import '../model/news_model.dart';
import '../core/constants.dart';

/// 뉴스 관련 ViewModel
///
/// 뉴스 데이터 로드, 필터링, 검색 등의 기능을 제공합니다.
class NewsViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;

  // 상태 관리
  bool _isLoading = false;
  List<News> _newsList = [];
  List<News> _popularNews = []; // 인기 뉴스 목록 추가
  News? _selectedNews;
  String? _errorMessage;

  // 자동 갱신 타이머
  Timer? _refreshTimer;

  // 필터링
  String? _coinFilter;
  String _searchQuery = ''; // 검색어 추가

  // 오프라인 모드 관련
  bool _isOfflineMode = false;
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;

  // 원본 값과 정규화된 값 모두 저장
  String? _rawCoinFilter;
  String? _normalizedCoinFilter;

  // 페이징 관련 상태 변수
  List<News> _pagedNewsList = []; // 화면에 표시할 뉴스(페이징 누적)
  dynamic _lastDoc; // Firestore에서 마지막으로 가져온 문서(페이징용)
  bool _hasMore = true; // 더 불러올 뉴스가 있는지 여부
  bool _isLoadingMore = false; // 추가 로딩 중 여부
  int _loadCount = 0; // 데이터 로드 횟수 추적

  // 생성자
  NewsViewModel(this._firebaseService) {
    // Hive 박스가 열려 있으면 즉시 캐시 데이터를 동기 로드
    if (Hive.isBoxOpen('news_cache')) {
      final box = Hive.box('news_cache');
      final cachedData = box.get('cached_news');
      if (cachedData != null) {
        final List<dynamic> newsJsonList = cachedData;
        _newsList = newsJsonList
            .map(
              (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
            )
            .toList();
        notifyListeners();
      }
    }
    // 네트워크, 타이머 등 기존 초기화는 그대로 비동기 처리
    _initConnectivity();
    _setupConnectivityMonitoring();
    refreshNews();
    _setupAutoRefresh();
  }

  // Getters
  bool get isLoading => _isLoading;
  List<News> get newsList => _applyFilters(_newsList);
  List<News> get popularNews => _popularNews;
  News? get selectedNews => _selectedNews;
  String? get errorMessage => _errorMessage;
  String? get coinFilter => _coinFilter;
  String get searchQuery => _searchQuery;
  bool get isOfflineMode => _isOfflineMode;
  bool get isConnected => _isConnected;

  // 페이징용 getter
  List<News> get pagedNewsList => _applyFilters(_pagedNewsList);
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  // 필터링된 뉴스 목록 (검색어와 코인 필터 모두 적용)
  List<News> get filteredNewsList {
    if (_searchQuery.isEmpty && (_coinFilter == null || _coinFilter!.isEmpty)) {
      return _pagedNewsList.isNotEmpty
          ? _pagedNewsList
          : _newsList; // 필터 없음, 페이징 데이터 또는 기본 데이터 반환
    }

    var filtered = _pagedNewsList.isNotEmpty ? _pagedNewsList : _newsList;

    // 코인 필터 적용
    if (_coinFilter != null && _coinFilter!.isNotEmpty && _coinFilter != '전체') {
      final normalizedFilter =
          _normalizedCoinFilter ?? _normalizeCoinId(_coinFilter!);
      final rawFilter = _rawCoinFilter ?? _coinFilter!;

      final symbolToId = {
        'btc': 'bitcoin',
        'eth': 'ethereum',
        'bnb': 'binancecoin',
        'sol': 'solana',
        'xrp': 'ripple',
        'doge': 'dogecoin',
        'ada': 'cardano',
      };
      final idToSymbol = {
        'bitcoin': 'btc',
        'ethereum': 'eth',
        'binancecoin': 'bnb',
        'solana': 'sol',
        'ripple': 'xrp',
        'dogecoin': 'doge',
        'cardano': 'ada',
      };

      final filterVariants = <String>{
        normalizedFilter.toLowerCase(),
        normalizedFilter.toUpperCase(),
        rawFilter.toLowerCase(),
        rawFilter.toUpperCase(),
      };

      if (symbolToId.containsKey(rawFilter.toLowerCase())) {
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!);
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!.toUpperCase());
      }
      if (idToSymbol.containsKey(normalizedFilter.toLowerCase())) {
        filterVariants.add(idToSymbol[normalizedFilter.toLowerCase()]!);
        filterVariants.add(
          idToSymbol[normalizedFilter.toLowerCase()]!.toUpperCase(),
        );
      }

      filtered = filtered.where((news) {
        for (final coin in news.relatedCoins) {
          final coinLower = coin.toLowerCase();
          final coinUpper = coin.toUpperCase();
          if (filterVariants.contains(coin) ||
              filterVariants.contains(coinLower) ||
              filterVariants.contains(coinUpper) ||
              (symbolToId.containsKey(coinLower) &&
                  filterVariants.contains(symbolToId[coinLower]!)) ||
              (idToSymbol.containsKey(coinLower) &&
                  filterVariants.contains(idToSymbol[coinLower]!))) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // 검색어 적용
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((news) {
        return news.title.toLowerCase().contains(query) ||
            news.content.toLowerCase().contains(query) ||
            news.source.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  // 검색어를 무시하고 코인 필터만 적용한 뉴스 리스트 반환
  List<News> get newsListWithoutSearch {
    var filtered = _pagedNewsList;
    if (_coinFilter != null && _coinFilter!.isNotEmpty && _coinFilter != '전체') {
      final normalizedFilter =
          _normalizedCoinFilter ?? _normalizeCoinId(_coinFilter!);
      final rawFilter = _rawCoinFilter ?? _coinFilter!;

      final symbolToId = {
        'btc': 'bitcoin',
        'eth': 'ethereum',
        'bnb': 'binancecoin',
        'sol': 'solana',
        'xrp': 'ripple',
        'doge': 'dogecoin',
        'ada': 'cardano',
      };
      final idToSymbol = {
        'bitcoin': 'btc',
        'ethereum': 'eth',
        'binancecoin': 'bnb',
        'solana': 'sol',
        'ripple': 'xrp',
        'dogecoin': 'doge',
        'cardano': 'ada',
      };

      final filterVariants = <String>{
        normalizedFilter.toLowerCase(),
        normalizedFilter.toUpperCase(),
        rawFilter.toLowerCase(),
        rawFilter.toUpperCase(),
      };

      if (symbolToId.containsKey(rawFilter.toLowerCase())) {
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!);
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!.toUpperCase());
      }
      if (idToSymbol.containsKey(normalizedFilter.toLowerCase())) {
        filterVariants.add(idToSymbol[normalizedFilter.toLowerCase()]!);
        filterVariants.add(
          idToSymbol[normalizedFilter.toLowerCase()]!.toUpperCase(),
        );
      }

      filtered = filtered.where((news) {
        for (final coin in news.relatedCoins) {
          final coinLower = coin.toLowerCase();
          final coinUpper = coin.toUpperCase();
          // 심볼/ID 매핑까지 모두 비교
          if (filterVariants.contains(coin) ||
              filterVariants.contains(coinLower) ||
              filterVariants.contains(coinUpper) ||
              (symbolToId.containsKey(coinLower) &&
                  filterVariants.contains(symbolToId[coinLower]!)) ||
              (idToSymbol.containsKey(coinLower) &&
                  filterVariants.contains(idToSymbol[coinLower]!))) {
            return true;
          }
        }
        return false;
      }).toList();
    }
    return filtered;
  }

  // 네트워크 연결 상태 초기화
  Future<void> _initConnectivity() async {
    // 웹 플랫폼에서는 항상 연결된 것으로 가정
    if (kIsWeb) {
      _isConnected = true;
      debugPrint('NewsViewModel: 웹 플랫폼에서는 항상 연결된 것으로 가정합니다.');
      return;
    }

    try {
      final checker = InternetConnectionChecker.createInstance();
      _isConnected = await checker.hasConnection;
      debugPrint('NewsViewModel: 네트워크 상태 - ${_isConnected ? "연결됨" : "연결 끊김"}');
    } catch (e) {
      _isConnected = false;
      debugPrint('NewsViewModel: 네트워크 연결 확인 오류 - $e');
    }
  }

  // 네트워크 연결 상태 모니터링
  void _setupConnectivityMonitoring() {
    // 웹 플랫폼에서는 연결 모니터링을 건너뜁니다
    if (kIsWeb) {
      debugPrint('NewsViewModel: 웹 플랫폼에서는 연결 모니터링을 건너뜁니다.');
      return;
    }

    try {
      final checker = InternetConnectionChecker.createInstance();
      _connectivitySubscription = checker.onStatusChange.listen((status) {
        final isConnected = status == InternetConnectionStatus.connected;

        if (_isConnected != isConnected) {
          _isConnected = isConnected;
          debugPrint(
            'NewsViewModel: 네트워크 상태 변경 - ${_isConnected ? "연결됨" : "연결 끊김"}',
          );

          // 오프라인 모드가 아니고 연결이 복구된 경우 데이터 새로고침
          if (_isConnected && !_isOfflineMode) {
            refreshNews();
          }

          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('NewsViewModel: 연결 모니터링 설정 오류 - $e');
    }
  }

  // 오프라인 모드 설정
  void setOfflineMode(bool value) {
    if (_isOfflineMode != value) {
      _isOfflineMode = value;
      debugPrint('NewsViewModel: 오프라인 모드 ${value ? "활성화" : "비활성화"}');

      // 오프라인 모드를 끄고 네트워크가 연결된 경우 데이터 새로고침
      if (!value && _isConnected) {
        refreshNews();
      }

      notifyListeners();
    }
  }

  // 필터링된 뉴스 반환
  List<News> _applyFilters(List<News> news) {
    var filtered = news;

    // 코인 필터 적용
    if (_coinFilter != null && _coinFilter!.isNotEmpty) {
      final normalizedFilter =
          _normalizedCoinFilter ?? _normalizeCoinId(_coinFilter!);
      final rawFilter = _rawCoinFilter ?? _coinFilter!;

      final symbolToId = {
        'btc': 'bitcoin',
        'eth': 'ethereum',
        'bnb': 'binancecoin',
        'sol': 'solana',
        'xrp': 'ripple',
        'doge': 'dogecoin',
        'ada': 'cardano',
      };
      final idToSymbol = {
        'bitcoin': 'btc',
        'ethereum': 'eth',
        'binancecoin': 'bnb',
        'solana': 'sol',
        'ripple': 'xrp',
        'dogecoin': 'doge',
        'cardano': 'ada',
      };

      final filterVariants = <String>{
        normalizedFilter.toLowerCase(),
        normalizedFilter.toUpperCase(),
        rawFilter.toLowerCase(),
        rawFilter.toUpperCase(),
      };
      if (symbolToId.containsKey(rawFilter.toLowerCase())) {
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!);
        filterVariants.add(symbolToId[rawFilter.toLowerCase()]!.toUpperCase());
      }
      if (idToSymbol.containsKey(normalizedFilter.toLowerCase())) {
        filterVariants.add(idToSymbol[normalizedFilter.toLowerCase()]!);
        filterVariants.add(
          idToSymbol[normalizedFilter.toLowerCase()]!.toUpperCase(),
        );
      }

      filtered = filtered.where((news) {
        for (final coin in news.relatedCoins) {
          final coinLower = coin.toLowerCase();
          final coinUpper = coin.toUpperCase();
          if (filterVariants.contains(coin) ||
              filterVariants.contains(coinLower) ||
              filterVariants.contains(coinUpper) ||
              (symbolToId.containsKey(coinLower) &&
                  filterVariants.contains(symbolToId[coinLower]!)) ||
              (idToSymbol.containsKey(coinLower) &&
                  filterVariants.contains(idToSymbol[coinLower]!))) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // 검색어 필터 적용
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (news) =>
                news.title.toLowerCase().contains(query) ||
                news.content.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  // 자동 갱신 타이머 설정
  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: TimeConstants.newsRefreshIntervalMinutes),
      (_) {
        if (_isConnected && !_isOfflineMode) {
          refreshNews();
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // 캐시된 뉴스 데이터 가져오기
  Future<List<News>> _getCachedNews() async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final cachedData = box.get('cached_news');
        if (cachedData != null) {
          final List<dynamic> newsJsonList = cachedData;
          return newsJsonList
              .map(
                (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('캐시된 뉴스 데이터 로드 실패: $e');
    }
    return [];
  }

  // 뉴스 데이터를 캐시에 저장
  Future<void> _cacheNewsData(List<News> newsList) async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final newsJsonList = newsList.map((news) => news.toJson()).toList();
        await box.put('cached_news', newsJsonList);
        debugPrint('뉴스 데이터 캐싱 완료: ${newsList.length}개');
      }
    } catch (e) {
      debugPrint('뉴스 데이터 캐싱 실패: $e');
    }
  }

  // 모의 뉴스 데이터 생성
  List<News> _generateMockNews() {
    return [
      News(
        id: const Uuid().v4(),
        title: '비트코인 신규 고점 돌파',
        content: '비트코인이 새로운 역사적 고점을 돌파했습니다.',
        source: 'CoinNews',
        url: 'https://example.com/news/1',
        imageUrl: 'https://example.com/images/1.jpg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        relatedCoins: ['bitcoin'],
      ),
      News(
        id: const Uuid().v4(),
        title: '이더리움 업데이트 예정',
        content: '이더리움 네트워크의 새로운 업데이트가 다음 주에 예정되어 있습니다.',
        source: 'CryptoDaily',
        url: 'https://example.com/news/2',
        imageUrl: 'https://example.com/images/2.jpg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
        relatedCoins: ['ethereum'],
      ),
      News(
        id: const Uuid().v4(),
        title: '솔라나 생태계 확장',
        content: '솔라나 생태계가 빠르게 확장되고 있으며, 새로운 프로젝트들이 계속해서 추가되고 있습니다.',
        source: 'BlockchainToday',
        url: 'https://example.com/news/3',
        imageUrl: 'https://example.com/images/3.jpg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
        relatedCoins: ['solana'],
      ),
    ];
  }

  /// 뉴스 데이터 새로고침
  Future<void> refreshNews() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('NewsViewModel: 뉴스 데이터 새로고침 시작');

      // 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터 사용
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음 - 캐시 데이터 사용');
        await _loadCachedNews();
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Firebase 서비스 초기화 확인
      if (!_firebaseService.isInitialized) {
        debugPrint('NewsViewModel: Firebase 서비스가 초기화되지 않음, 초기화 시도');
        try {
          await _firebaseService.initialize();
          debugPrint('NewsViewModel: Firebase 서비스 초기화 성공');
        } catch (e) {
          debugPrint('NewsViewModel: Firebase 서비스 초기화 실패 - $e');
          _errorMessage = 'Firebase 서비스 초기화 실패';
          await _loadCachedNews();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // 서버에서 뉴스 데이터 로드
      debugPrint('NewsViewModel: Firebase에서 뉴스 데이터 로드 시작');
      final newsList = await _firebaseService.getNews(limit: 50);
      debugPrint('NewsViewModel: 뉴스 ${newsList.length}개 로드됨');

      if (newsList.isEmpty) {
        debugPrint('NewsViewModel: 로드된 뉴스가 없음, 캐시 데이터 사용');
        _errorMessage = '뉴스 데이터를 불러올 수 없습니다.';
        await _loadCachedNews();
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 뉴스 데이터 업데이트
      _newsList = newsList;

      // 인기 뉴스 정렬 (조회수 기준)
      _popularNews = List.from(_newsList)
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      _popularNews = _popularNews.take(5).toList();

      // 뉴스 데이터 캐싱
      _cacheNewsData(_newsList);

      debugPrint('NewsViewModel: 뉴스 데이터 새로고침 완료');
    } catch (e) {
      debugPrint('NewsViewModel: 뉴스 데이터 새로고침 실패 - $e');
      _errorMessage = '뉴스를 불러오는 중 오류가 발생했습니다: $e';

      // 오류 발생 시 캐시 데이터 사용 시도
      await _loadCachedNews();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 캐시된 뉴스 데이터 로드
  Future<void> _loadCachedNews() async {
    try {
      debugPrint('NewsViewModel: 캐시된 뉴스 데이터 로드 시도');
      final cachedNews = await _getCachedNews();

      if (cachedNews.isNotEmpty) {
        debugPrint('NewsViewModel: ${cachedNews.length}개의 캐시된 뉴스 로드 성공');
        _newsList = cachedNews;

        // 인기 뉴스 정렬 (조회수 기준)
        _popularNews = List.from(_newsList)
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        _popularNews = _popularNews.take(5).toList();
      } else {
        debugPrint('NewsViewModel: 캐시된 뉴스 없음, 모의 데이터 생성');
        // 캐시된 데이터가 없으면 모의 데이터 생성
        final mockNews = _generateMockNews();
        _newsList = mockNews;
        _popularNews = mockNews.take(5).toList();

        // 모의 데이터 캐싱
        _cacheNewsData(mockNews);
      }
    } catch (e) {
      debugPrint('NewsViewModel: 캐시된 뉴스 로드 실패 - $e');
      // 모의 데이터 생성
      final mockNews = _generateMockNews();
      _newsList = mockNews;
      _popularNews = mockNews.take(5).toList();
    }
  }

  /// 최초 진입 시 캐시가 있으면 캐시, 없으면 Firestore에서 첫 페이지만 가져오기
  Future<void> fetchInitialNewsPage({int pageSize = 20}) async {
    if (_isLoading) {
      debugPrint('NewsViewModel: 이미 로딩 중입니다.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint('NewsViewModel: 뉴스 초기 페이지 로드 시작');

    try {
      // 1. 캐시된 데이터 확인
      final cachedNews = await _getCachedPagedNews();
      if (cachedNews.isNotEmpty) {
        debugPrint('NewsViewModel: 캐시된 뉴스 데이터 ${cachedNews.length}개 로드됨');
        _pagedNewsList = cachedNews;
        _newsList = List.from(cachedNews);
        _hasMore = true; // 더 데이터가 있다고 가정
      }

      // 2. 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터만 사용
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음');
        if (_pagedNewsList.isEmpty) {
          debugPrint('NewsViewModel: 캐시된 데이터 없음, 모의 데이터 사용');
          final mockNews = _generateMockNewsWithImages();
          _pagedNewsList = mockNews;
          _newsList = List.from(mockNews);
          _hasMore = false;
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3. Firebase 서비스 초기화 확인
      if (!_firebaseService.isInitialized) {
        debugPrint('NewsViewModel: Firebase 서비스가 초기화되지 않음');

        // Firebase 서비스가 초기화되지 않았을 때 모의 데이터 사용
        if (_pagedNewsList.isEmpty) {
          debugPrint('NewsViewModel: Firebase 초기화 안됨, 모의 데이터 사용');
          final mockNews = _generateMockNewsWithImages();
          _pagedNewsList = mockNews;
          _newsList = List.from(mockNews);
          _hasMore = false;

          // 캐시에 모의 데이터 저장
          await _cachePagedNewsData(_pagedNewsList);
        }

        _isLoading = false;
        notifyListeners();
        return;
      }

      // 4. Firebase에서 데이터 요청
      debugPrint(
        'NewsViewModel: [Firebase] 뉴스 데이터 요청 시작 (pageSize: $pageSize)',
      );
      final startTime = DateTime.now();
      try {
        // 로딩 상태 재확인
        _isLoading = true;
        notifyListeners();

        debugPrint('NewsViewModel: [Firebase] 뉴스 데이터 요청 시작');
        final result = await _firebaseService.getNewsPaged(limit: pageSize);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        debugPrint(
          'NewsViewModel: [Firebase] 요청 완료 - 소요 시간: ${duration.inMilliseconds}ms',
        );

        if (result.news.isNotEmpty) {
          debugPrint(
            'NewsViewModel: [Firebase] ${result.news.length}개 뉴스 로드됨, 더 있음: ${result.hasMore}',
          );
          debugPrint(
            'NewsViewModel: [Firebase] 첫 번째 뉴스: ${result.news.first.title}',
          );
          debugPrint(
            'NewsViewModel: [Firebase] 마지막 뉴스: ${result.news.last.title}',
          );

          // 새로운 데이터가 있는 경우에만 업데이트
          final existingIds = _pagedNewsList.map((news) => news.id).toSet();
          final newIds = result.news.map((news) => news.id).toSet();

          final commonIds = existingIds.intersection(newIds);
          final onlyInExisting = existingIds.difference(newIds);
          final onlyInNew = newIds.difference(existingIds);

          debugPrint(
            'NewsViewModel: [데이터 비교] 기존 데이터: ${existingIds.length}개, 새 데이터: ${newIds.length}개',
          );
          debugPrint(
            'NewsViewModel: [데이터 비교] 공통 ID: ${commonIds.length}개, 기존에만 있음: ${onlyInExisting.length}개, 새로 추가됨: ${onlyInNew.length}개',
          );

          // 기존 데이터와 새 데이터 병합
          final Map<String, News> mergedNewsMap = {};

          // 1. 기존 데이터 먼저 맵에 추가
          for (final news in _pagedNewsList) {
            mergedNewsMap[news.id] = news;
          }

          // 2. 새 데이터로 업데이트 또는 추가 (조회수 보존)
          for (final news in result.news) {
            // 이미 존재하는 뉴스인 경우 조회수 보존
            if (mergedNewsMap.containsKey(news.id)) {
              final existingNews = mergedNewsMap[news.id]!;
              // 조회수만 기존 값으로 유지하고 나머지는 새 데이터로 업데이트
              mergedNewsMap[news.id] = news.copyWith(
                viewCount: existingNews.viewCount,
              );
            } else {
              // 새로운 뉴스는 그대로 추가
              mergedNewsMap[news.id] = news;
            }
          }

          // 3. 맵을 리스트로 변환하고 최신순으로 정렬
          final mergedNewsList = mergedNewsMap.values.toList()
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

          // 데이터가 변경된 경우에만 업데이트
          if (onlyInNew.isNotEmpty ||
              onlyInExisting.isNotEmpty ||
              _hasNewsContentChanged(_pagedNewsList, result.news)) {
            _pagedNewsList = mergedNewsList;
            _newsList = List.from(mergedNewsList);
            _lastDoc = result.lastDoc;
            _hasMore = result.hasMore;

            debugPrint(
              'NewsViewModel: [데이터 상태] 병합된 데이터로 업데이트 (${mergedNewsList.length}개)',
            );

            // Hive에 저장
            await _cachePagedNewsData(_pagedNewsList);
            debugPrint(
              'NewsViewModel: [캐시 저장] ${_pagedNewsList.length}개 뉴스 캐시 저장 완료',
            );
          } else {
            debugPrint('NewsViewModel: [데이터 상태] 실질적인 변경사항 없어 업데이트 건너뜀');
          }
        } else {
          debugPrint('NewsViewModel: [Firebase] 로드된 뉴스 없음');

          // 데이터가 없는 경우 모의 데이터 생성
          if (_pagedNewsList.isEmpty) {
            debugPrint('NewsViewModel: [Firebase] 데이터가 없어 모의 데이터 사용');
            final mockNews = _generateMockNewsWithImages();
            _pagedNewsList = mockNews;
            _newsList = List.from(mockNews);
            _hasMore = false;

            // Hive에 저장
            await _cachePagedNewsData(_pagedNewsList);
            debugPrint(
              'NewsViewModel: [모의 데이터] ${mockNews.length}개 생성 및 캐시 저장',
            );
          }
        }
      } catch (e) {
        debugPrint('NewsViewModel: [Firebase] 요청 중 예외 발생 - $e');
        _errorMessage = '뉴스 데이터를 불러오는 중 오류가 발생했습니다';

        // 오류 발생 시 모의 데이터 사용 (이미 표시된 데이터가 없는 경우)
        if (_pagedNewsList.isEmpty) {
          debugPrint('NewsViewModel: [오류 처리] 모의 데이터로 대체');
          final mockNews = _generateMockNewsWithImages();
          _pagedNewsList = mockNews;
          _newsList = List.from(mockNews);
          _hasMore = false;

          // Hive에 저장
          await _cachePagedNewsData(_pagedNewsList);
        }
      }
    } catch (e) {
      debugPrint('NewsViewModel: 뉴스 초기 페이지 로드 오류 - $e');
      _errorMessage = '뉴스를 불러오는 중 오류가 발생했습니다';

      // 치명적 오류 발생 시 모의 데이터 사용 (이미 표시된 데이터가 없는 경우)
      if (_pagedNewsList.isEmpty) {
        debugPrint('NewsViewModel: [치명적 오류] 모의 데이터로 대체');
        final mockNews = _generateMockNewsWithImages();
        _pagedNewsList = mockNews;
        _newsList = List.from(mockNews);
        _hasMore = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint(
        'NewsViewModel: [데이터 상태] 최종 - ${_pagedNewsList.length}개 뉴스, 에러: ${_errorMessage != null}, 더 있음: $_hasMore',
      );
    }
  }

  // 뉴스 내용이 변경되었는지 확인
  bool _hasNewsContentChanged(List<News> oldList, List<News> newList) {
    final oldMap = {for (var news in oldList) news.id: news};
    final newMap = {for (var news in newList) news.id: news};

    // 공통 ID를 가진 뉴스들에 대해 내용 비교
    for (final id in oldMap.keys.where((id) => newMap.containsKey(id))) {
      final oldNews = oldMap[id]!;
      final newNews = newMap[id]!;

      // 조회수를 제외한 내용 비교
      if (oldNews.title != newNews.title ||
          oldNews.content != newNews.content ||
          oldNews.source != newNews.source ||
          oldNews.url != newNews.url ||
          oldNews.imageUrl != newNews.imageUrl ||
          !_areListsEqual(oldNews.relatedCoins, newNews.relatedCoins)) {
        return true;
      }
    }

    return false;
  }

  // 두 리스트가 같은지 비교
  bool _areListsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// Hive에 페이징된 뉴스 데이터 저장
  Future<void> _cachePagedNewsData(List<News> newsList) async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final newsJsonList = newsList.map((news) => news.toJson()).toList();
        await box.put('paged_news', newsJsonList);
        debugPrint('NewsViewModel: [캐시 저장] ${newsList.length}개 뉴스 캐싱 완료');

        // 첫 번째와 마지막 뉴스 제목 로깅
        if (newsList.isNotEmpty) {
          debugPrint('NewsViewModel: [캐시 저장] 첫 번째 뉴스: ${newsList.first.title}');
          debugPrint('NewsViewModel: [캐시 저장] 마지막 뉴스: ${newsList.last.title}');
        }
      } else {
        debugPrint('NewsViewModel: [캐시 저장] 실패: news_cache 박스가 열려있지 않음');
      }
    } catch (e) {
      debugPrint('NewsViewModel: [캐시 저장] 실패: $e');
    }
  }

  /// Hive에서 페이징된 뉴스 데이터 불러오기
  Future<List<News>> _getCachedPagedNews() async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final cachedData = box.get('paged_news');
        if (cachedData != null) {
          debugPrint('NewsViewModel: [캐시 로드] 캐시된 페이징 뉴스 데이터 발견');
          final List<dynamic> newsJsonList = cachedData;
          final cachedNews = newsJsonList
              .map(
                (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
              )
              .toList();

          // 첫 번째와 마지막 뉴스 제목 로깅
          if (cachedNews.isNotEmpty) {
            debugPrint('NewsViewModel: [캐시 로드] ${cachedNews.length}개 뉴스 로드됨');
            debugPrint(
              'NewsViewModel: [캐시 로드] 첫 번째 뉴스: ${cachedNews.first.title}',
            );
            debugPrint(
              'NewsViewModel: [캐시 로드] 마지막 뉴스: ${cachedNews.last.title}',
            );
          }

          return cachedNews;
        } else {
          debugPrint('NewsViewModel: [캐시 로드] 캐시된 페이징 뉴스 데이터 없음');
        }
      } else {
        debugPrint('NewsViewModel: [캐시 로드] 실패: news_cache 박스가 열려있지 않음');
      }
    } catch (e) {
      debugPrint('NewsViewModel: [캐시 로드] 실패: $e');
    }
    return [];
  }

  // 모의 뉴스 데이터 생성 (이미지 URL 포함)
  List<News> _generateMockNewsWithImages() {
    return [
      News(
        id: '003f6eebef791b3f9182f4c127d214db',
        title: '[주요 뉴스] 바운드리스, 블록체인 인프라 혁신 ... 조연이 빛나는 무대',
        content:
            "[블록미디어] 2025년 블록체인 산업은 '무대 위'가 아닌 '무대 뒤'로 중심이 이동했다. 스마트라이트 경쟁이 끝나고, 다른 프로젝트들이 빛날 수 있도록 설계된 인프라 기술이 주목받고 있다. 바운드리스는 이러한 변화의 중심에 있다.",
        source: 'blockmedia',
        url: 'https://www.blockmedia.co.kr/archives/932666',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
        relatedCoins: ['bitcoin', 'ethereum'],
        imageUrl:
            'https://images.unsplash.com/photo-1639322537228-f710d846310a?q=80&w=500',
        viewCount: 10,
      ),
      News(
        id: '01412db61ea7feaae4f314669b9ca9d3',
        title: '비트코인, 6만 달러 돌파... 기관 투자자 유입 증가',
        content:
            "비트코인이 6만 달러를 돌파했다. 이는 기관 투자자들의 유입이 증가하면서 나타난 현상으로 분석된다. 특히 블랙록의 비트코인 ETF가 출시된 이후 기관 자금의 유입이 크게 늘어났다. 전문가들은 이러한 추세가 계속될 경우 연말까지 7만 달러 돌파도 가능할 것으로 전망하고 있다.",
        source: 'cryptonews',
        url: 'https://example.com/bitcoin-60k',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
        relatedCoins: ['bitcoin'],
        imageUrl:
            'https://images.unsplash.com/photo-1518546305927-5a555bb7020d?q=80&w=500',
        viewCount: 8,
      ),
      News(
        id: '02423db61ea7feaae4f314669b9ca9d3',
        title: '이더리움 업그레이드, 가스비 50% 절감 효과',
        content:
            "이더리움 재단이 발표한 최신 업그레이드는 네트워크 가스비를 약 50% 절감하는 효과를 가져올 것으로 예상된다. 이번 업그레이드는 롤업 기술을 개선하고 L2 솔루션과의 통합을 강화하는 내용을 담고 있다.",
        source: 'ethernews',
        url: 'https://example.com/eth-upgrade',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
        relatedCoins: ['ethereum'],
        imageUrl:
            'https://images.unsplash.com/photo-1622790698141-94e30457ef12?q=80&w=500',
        viewCount: 15,
      ),
      News(
        id: '03534db61ea7feaae4f314669b9ca9d3',
        title: '솔라나 네트워크, 초당 트랜잭션 처리량 100만 TPS 달성',
        content:
            "솔라나 네트워크가 최근 업그레이드를 통해 초당 트랜잭션 처리량(TPS)을 100만까지 확장하는 데 성공했다. 이는 기존 블록체인 네트워크의 처리 속도를 크게 뛰어넘는 수치로, 대규모 분산 애플리케이션 운영에 새로운 가능성을 열었다는 평가를 받고 있다.",
        source: 'solananews',
        url: 'https://example.com/solana-tps',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
        relatedCoins: ['solana'],
        imageUrl:
            'https://images.unsplash.com/photo-1620321023374-d1a68fbc720d?q=80&w=500',
        viewCount: 12,
      ),
      News(
        id: '04645db61ea7feaae4f314669b9ca9d3',
        title: '리플, SEC와의 소송에서 최종 승리... XRP 가격 급등',
        content:
            "리플이 미국 증권거래위원회(SEC)와의 장기 소송에서 최종 승리를 거두었다. 법원은 XRP가 증권이 아니라는 리플 측의 주장을 인정했으며, 이 소식이 알려지자 XRP 가격은 24시간 만에 50% 이상 급등했다. 이번 판결은 암호화폐 산업 전반에 긍정적인 영향을 미칠 것으로 예상된다.",
        source: 'cryptoinsider',
        url: 'https://example.com/ripple-sec',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
        relatedCoins: ['xrp', 'ripple'],
        imageUrl:
            'https://images.unsplash.com/photo-1622630998477-20aa696ecb05?q=80&w=500',
        viewCount: 25,
      ),
      News(
        id: '05756db61ea7feaae4f314669b9ca9d3',
        title: '카르다노, 스마트 계약 기능 대폭 강화... DeFi 생태계 확장 기대',
        content:
            "카르다노 네트워크가 새로운 업데이트를 통해 스마트 계약 기능을 대폭 강화했다. 이번 업데이트로 카르다노 기반 DeFi 애플리케이션 개발이 더욱 용이해질 전망이며, 이미 여러 프로젝트들이 카르다노 생태계로의 이전을 검토 중인 것으로 알려졌다.",
        source: 'cardanonews',
        url: 'https://example.com/cardano-defi',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
        relatedCoins: ['cardano', 'ada'],
        imageUrl:
            'https://images.unsplash.com/photo-1621761191319-c6fb62004040?q=80&w=500',
        viewCount: 9,
      ),
      News(
        id: '06867db61ea7feaae4f314669b9ca9d3',
        title: '도지코인, 일론 머스크의 새 프로젝트에 통합... 가격 30% 상승',
        content:
            "일론 머스크가 이끄는 새로운 금융 서비스 플랫폼이 도지코인을 결제 수단으로 통합한다고 발표했다. 이 소식이 알려지자 도지코인 가격은 단 몇 시간 만에 30% 이상 급등했다. 머스크는 트위터를 통해 '도지코인은 인터넷의 화폐가 될 것'이라고 언급했다.",
        source: 'cryptodaily',
        url: 'https://example.com/doge-musk',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
        relatedCoins: ['dogecoin', 'doge'],
        imageUrl:
            'https://images.unsplash.com/photo-1622020457014-aed1cc44f25e?q=80&w=500',
        viewCount: 30,
      ),
      News(
        id: '07978db61ea7feaae4f314669b9ca9d3',
        title: '바이낸스, 규제 준수 강화로 글로벌 확장 가속화',
        content:
            "세계 최대 암호화폐 거래소 바이낸스가 글로벌 규제 준수 강화 전략을 발표했다. 이를 통해 유럽과 중동 지역에서의 사업 확장을 가속화할 계획이다. 바이낸스는 각국의 규제 당국과 적극 협력하며 라이선스 취득에 주력하고 있다.",
        source: 'binanceblog',
        url: 'https://example.com/binance-regulation',
        publishedAt: DateTime.now().subtract(const Duration(days: 8)),
        relatedCoins: ['bnb', 'binancecoin'],
        imageUrl:
            'https://images.unsplash.com/photo-1622473590773-f588134b6ce7?q=80&w=500',
        viewCount: 14,
      ),
      News(
        id: '08089db61ea7feaae4f314669b9ca9d3',
        title: '폴카닷, 파라체인 생태계 확장... 50개 이상의 프로젝트 온보딩',
        content:
            "폴카닷이 파라체인 생태계에 50개 이상의 새로운 프로젝트를 온보딩했다고 발표했다. 이를 통해 폴카닷의 멀티체인 아키텍처가 본격적으로 확장되기 시작했으며, 크로스체인 상호운용성이 크게 향상될 것으로 기대된다.",
        source: 'polkadotnews',
        url: 'https://example.com/polkadot-parachains',
        publishedAt: DateTime.now().subtract(const Duration(days: 9)),
        relatedCoins: ['polkadot', 'dot'],
        imageUrl:
            'https://images.unsplash.com/photo-1622473590773-f588134b6ce7?q=80&w=500',
        viewCount: 11,
      ),
      News(
        id: '09190db61ea7feaae4f314669b9ca9d3',
        title: '폴리곤, 이더리움 확장성 솔루션으로 사용자 1억명 돌파',
        content:
            "이더리움 확장성 솔루션인 폴리곤이 월간 활성 사용자 수 1억명을 돌파했다고 발표했다. 이는 Web3 플랫폼 중 가장 많은 사용자 기반으로, 폴리곤의 낮은 수수료와 빠른 처리 속도가 주요 성공 요인으로 분석된다.",
        source: 'polygonnews',
        url: 'https://example.com/polygon-users',
        publishedAt: DateTime.now().subtract(const Duration(days: 10)),
        relatedCoins: ['polygon', 'matic'],
        imageUrl:
            'https://images.unsplash.com/photo-1621761191319-c6fb62004040?q=80&w=500',
        viewCount: 18,
      ),
      News(
        id: '10201db61ea7feaae4f314669b9ca9d3',
        title: '시바이누, 메타버스 플랫폼 출시 예정... 게임 산업 진출',
        content:
            "밈 코인으로 알려진 시바이누가 자체 메타버스 플랫폼 '시바버스'를 출시할 예정이라고 발표했다. 이 플랫폼은 NFT와 게임 요소를 결합하여 사용자들에게 새로운 경험을 제공할 계획이다. 시바이누 개발팀은 여러 게임 스튜디오와의 협력도 추진 중이다.",
        source: 'shibainunews',
        url: 'https://example.com/shiba-metaverse',
        publishedAt: DateTime.now().subtract(const Duration(days: 11)),
        relatedCoins: ['shiba', 'shib'],
        imageUrl:
            'https://images.unsplash.com/photo-1622020457014-aed1cc44f25e?q=80&w=500',
        viewCount: 22,
      ),
      News(
        id: '11312db61ea7feaae4f314669b9ca9d3',
        title: '비트코인 채굴 난이도 사상 최고치 기록... 해시레이트 급증',
        content:
            "비트코인 채굴 난이도가 사상 최고치를 기록했다. 이는 글로벌 해시레이트의 급증에 따른 것으로, 최근 북미 지역의 대규모 채굴 시설 확장이 주요 원인으로 분석된다. 채굴 난이도 증가로 소규모 채굴자들의 수익성은 더욱 악화될 것으로 예상된다.",
        source: 'miningnews',
        url: 'https://example.com/bitcoin-mining',
        publishedAt: DateTime.now().subtract(const Duration(days: 12)),
        relatedCoins: ['bitcoin', 'btc'],
        imageUrl:
            'https://images.unsplash.com/photo-1518546305927-5a555bb7020d?q=80&w=500',
        viewCount: 16,
      ),
      News(
        id: '12423db61ea7feaae4f314669b9ca9d3',
        title: '이더리움 2.0 스테이킹 참여율 40% 돌파... 네트워크 안정성 강화',
        content:
            "이더리움 2.0 스테이킹에 참여하는 ETH의 비율이 전체 공급량의 40%를 돌파했다. 이는 네트워크의 안정성과 보안을 크게 강화하는 요소로, 지속적인 스테이킹 참여율 증가는 이더리움 생태계에 대한 신뢰를 반영한다는 분석이다.",
        source: 'ethereumfoundation',
        url: 'https://example.com/ethereum-staking',
        publishedAt: DateTime.now().subtract(const Duration(days: 13)),
        relatedCoins: ['ethereum', 'eth'],
        imageUrl:
            'https://images.unsplash.com/photo-1622790698141-94e30457ef12?q=80&w=500',
        viewCount: 19,
      ),
    ];
  }

  /// 다음 페이지 뉴스 로드
  Future<void> fetchNextNewsPage({int pageSize = 20}) async {
    // 이미 로딩 중이거나 더 이상 데이터가 없으면 요청 무시
    if (_isLoadingMore || !_hasMore) {
      debugPrint(
        'NewsViewModel: 추가 데이터 로드 건너뜀 - 로딩 중: $_isLoadingMore, 더 있음: $_hasMore',
      );
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      debugPrint('NewsViewModel: 다음 페이지 로드 시작');

      // Firebase 서비스 초기화 확인
      if (!_firebaseService.isInitialized) {
        try {
          await _firebaseService.initialize();
        } catch (e) {
          debugPrint('NewsViewModel: Firebase 서비스 초기화 실패 - $e');
          _isLoadingMore = false;
          notifyListeners();
          return;
        }
      }

      // 데이터 요청
      final result = await _firebaseService.getNewsPaged(
        limit: pageSize,
        startAfter: _lastDoc,
      );

      if (result.news.isNotEmpty) {
        debugPrint('NewsViewModel: 다음 페이지 로드 성공 - ${result.news.length}개 뉴스');

        // 중복 제거 및 조회수 보존을 위한 병합 로직
        final existingIds = _pagedNewsList.map((news) => news.id).toSet();
        final Map<String, News> existingNewsMap = {
          for (var news in _pagedNewsList) news.id: news,
        };

        final List<News> newUniqueNews = [];

        // 새로운 뉴스만 필터링하면서 조회수 보존
        for (final news in result.news) {
          if (!existingIds.contains(news.id)) {
            // 새로운 뉴스는 그대로 추가
            newUniqueNews.add(news);
          } else {
            // 이미 있는 뉴스는 조회수만 보존하고 내용 업데이트
            final existingNews = existingNewsMap[news.id]!;
            if (news.title != existingNews.title ||
                news.content != existingNews.content ||
                news.source != existingNews.source ||
                news.url != existingNews.url ||
                news.imageUrl != existingNews.imageUrl ||
                !_areListsEqual(news.relatedCoins, existingNews.relatedCoins)) {
              // 내용이 변경된 경우 조회수만 유지하고 업데이트
              final updatedNews = news.copyWith(
                viewCount: existingNews.viewCount,
              );
              // 기존 뉴스 교체
              final index = _pagedNewsList.indexWhere((n) => n.id == news.id);
              if (index >= 0) {
                _pagedNewsList[index] = updatedNews;
              }
            }
          }
        }

        if (newUniqueNews.isNotEmpty) {
          debugPrint('NewsViewModel: 중복 제거 후 ${newUniqueNews.length}개 뉴스 추가');
          _pagedNewsList.addAll(newUniqueNews);
          _newsList = List.from(_pagedNewsList);
          _lastDoc = result.lastDoc;
          _hasMore = result.hasMore;

          // 최신순으로 정렬
          _pagedNewsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          _newsList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

          // 캐시 업데이트
          await _cachePagedNewsData(_pagedNewsList);
        } else {
          debugPrint('NewsViewModel: 모든 뉴스가 중복, 다음 페이지 요청');
          // 모든 뉴스가 중복인 경우 다음 페이지 요청
          _lastDoc = result.lastDoc;
          _hasMore = result.hasMore;

          // 중복이 많은 경우 무한 루프 방지
          _loadCount++;
          if (_loadCount > 3) {
            debugPrint('NewsViewModel: 연속 중복 데이터 3회 초과, 더 이상 로드하지 않음');
            _hasMore = false;
          }
        }
      } else {
        debugPrint('NewsViewModel: 더 이상 로드할 뉴스 없음');
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('NewsViewModel: 다음 페이지 로드 실패 - $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // 특정 코인 관련 뉴스 로드
  Future<void> loadNewsByCoinId(String coinId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('NewsViewModel: 코인별 뉴스 로드 시작 - $coinId');

      if (coinId.isEmpty || coinId == '전체') {
        // 전체 뉴스 로드
        await refreshNews();
        _coinFilter = null;
        _rawCoinFilter = null;
        _normalizedCoinFilter = null;
        return;
      }

      // 코인 ID 또는 심볼 정규화
      final normalizedCoinId = _normalizeCoinId(coinId);
      // 원본 값과 정규화된 값 모두 저장
      _coinFilter = coinId;
      _rawCoinFilter = coinId;
      _normalizedCoinFilter = normalizedCoinId;

      debugPrint('NewsViewModel: 코인 ID 정규화 - $coinId -> $normalizedCoinId');

      // 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터 사용
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음 - 캐시 데이터 사용');
        await _loadCachedNews();
        // 필터는 _applyFilters 메서드에서 자동으로 적용됨
        return;
      }

      // Firebase에서 특정 코인 관련 뉴스 로드
      final newsList = await _firebaseService.getNewsByCoin(
        normalizedCoinId,
        limit: 20,
      );
      debugPrint('NewsViewModel: 코인별 뉴스 ${newsList.length}개 로드됨');

      if (newsList.isEmpty) {
        debugPrint('NewsViewModel: 로드된 코인별 뉴스가 없음');
        _errorMessage = '해당 코인에 관련된 뉴스가 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 뉴스 데이터 업데이트
      _newsList = newsList;

      // 인기 뉴스 정렬 (조회수 기준)
      _popularNews = List.from(_newsList)
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      _popularNews = _popularNews.take(5).toList();

      // 뉴스 데이터 캐싱
      _cacheNewsData(_newsList);

      debugPrint('NewsViewModel: 코인별 뉴스 로드 완료');
    } catch (e) {
      debugPrint('NewsViewModel: 코인별 뉴스 로드 실패 - $e');
      _errorMessage = '코인 관련 뉴스를 불러오는 중 오류가 발생했습니다: $e';

      // 오류 발생 시 캐시 데이터 사용 시도
      await _loadCachedNews();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 코인 ID 또는 심볼을 정규화하는 함수
  String _normalizeCoinId(String coinIdOrSymbol) {
    final idMap = {
      'btc': 'bitcoin',
      'eth': 'ethereum',
      'bnb': 'binancecoin',
      'sol': 'solana',
      'xrp': 'ripple',
      'doge': 'dogecoin',
      'ada': 'cardano',
    };

    final symbolMap = {
      'bitcoin': 'btc',
      'ethereum': 'eth',
      'binancecoin': 'bnb',
      'solana': 'sol',
      'ripple': 'xrp',
      'dogecoin': 'doge',
      'cardano': 'ada',
    };

    final lowerCaseId = coinIdOrSymbol.toLowerCase();

    // 매핑 정보 로깅
    debugPrint(
      'NewsViewModel: 코인 ID 정규화 - 입력: $coinIdOrSymbol, 소문자: $lowerCaseId',
    );
    if (idMap.containsKey(lowerCaseId)) {
      debugPrint(
        'NewsViewModel: 심볼->ID 매핑 적용 - $lowerCaseId -> ${idMap[lowerCaseId]}',
      );
      return idMap[lowerCaseId]!;
    } else if (symbolMap.containsKey(lowerCaseId)) {
      debugPrint('NewsViewModel: ID->심볼 매핑 확인 - $lowerCaseId는 이미 ID 형태');
      return lowerCaseId;
    }

    debugPrint('NewsViewModel: 매핑 없음, 원본 반환 - $lowerCaseId');
    return lowerCaseId;
  }

  // 뉴스 검색
  Future<void> searchNews(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      // 검색어가 비어있으면 전체 뉴스 다시 로드
      await refreshNews();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('NewsViewModel: 뉴스 검색 시작 - 검색어: "$query"');

      // 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시 데이터 사용
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음 - 캐시 데이터 사용');
        await _loadCachedNews();
        // 검색어는 _applyFilters 메서드에서 자동으로 적용됨
        return;
      }

      // 모든 뉴스 로드 후 클라이언트 측에서 검색
      // 참고: 실제 구현에서는 서버 측 검색 API를 사용하는 것이 더 효율적임
      final allNews = await _firebaseService.getNews(limit: 50);
      debugPrint('NewsViewModel: 검색용 뉴스 ${allNews.length}개 로드됨');

      if (allNews.isEmpty) {
        debugPrint('NewsViewModel: 검색할 뉴스가 없음');
        _errorMessage = '검색할 뉴스 데이터가 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 검색어로 필터링
      final lowerQuery = query.toLowerCase();
      final filteredNews = allNews.where((news) {
        return news.title.toLowerCase().contains(lowerQuery) ||
            news.content.toLowerCase().contains(lowerQuery);
      }).toList();

      debugPrint('NewsViewModel: 검색 결과 ${filteredNews.length}개 찾음');

      // 검색 결과가 없는 경우
      if (filteredNews.isEmpty) {
        _errorMessage = '"$query"에 대한 검색 결과가 없습니다.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 뉴스 데이터 업데이트
      _newsList = filteredNews;

      // 인기 뉴스 정렬 (조회수 기준)
      _popularNews = List.from(_newsList)
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      _popularNews = _popularNews.take(5).toList();

      debugPrint('NewsViewModel: 뉴스 검색 완료');
    } catch (e) {
      debugPrint('NewsViewModel: 뉴스 검색 실패 - $e');
      _errorMessage = '뉴스 검색 중 오류가 발생했습니다: $e';

      // 오류 발생 시 캐시 데이터 사용 시도
      await _loadCachedNews();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 뉴스 선택
  void selectNews(News news) {
    _selectedNews = news;
    debugPrint('뉴스 선택됨: ${news.title}');
    notifyListeners();
  }

  // 필터 설정
  void setFilter(String? coinId) {
    if (coinId == '전체') {
      _coinFilter = null;
      _rawCoinFilter = null;
      _normalizedCoinFilter = null;
    } else {
      _coinFilter = coinId;
      _rawCoinFilter = coinId;
      _normalizedCoinFilter = _normalizeCoinId(coinId ?? '');
      debugPrint(
        'NewsViewModel: 필터 설정 - 원본: $_rawCoinFilter, 정규화: $_normalizedCoinFilter',
      );
    }
    notifyListeners();
  }

  // 필터 초기화
  void clearFilter() {
    _coinFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 뉴스 조회수 증가
  Future<void> incrementViewCount(News news) async {
    try {
      debugPrint(
        'NewsViewModel: 뉴스 조회수 증가 시작 - ID: ${news.id}, 제목: ${news.title}',
      );

      // 현재 조회수 확인 및 증가
      final updatedCount = news.viewCount + 1;
      final updatedNews = news.copyWith(viewCount: updatedCount);

      // 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시만 업데이트
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음 - 캐시만 업데이트');
        _updateNewsInLists(updatedNews);
        await _cacheNewsData(_newsList);
        return;
      }

      // Firebase에 조회수 업데이트
      if (_firebaseService.isInitialized) {
        await _firebaseService.updateNewsViewCount(news.id, updatedCount);
        debugPrint(
          'NewsViewModel: Firebase에 조회수 업데이트 완료 - 새 조회수: $updatedCount',
        );
      } else {
        debugPrint('NewsViewModel: Firebase 초기화 안됨 - 조회수 업데이트 건너뜀');
      }

      // 로컬 리스트에서 해당 뉴스 업데이트
      _updateNewsInLists(updatedNews);

      // 캐시 업데이트
      await _cacheNewsData(_newsList);

      // 인기 뉴스 재정렬
      _popularNews = List.from(_newsList)
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      _popularNews = _popularNews.take(5).toList();

      notifyListeners();
      debugPrint(
        'NewsViewModel: 뉴스 조회수 증가 완료 - ID: ${news.id}, 새 조회수: $updatedCount',
      );
    } catch (e) {
      debugPrint('NewsViewModel: 뉴스 조회수 증가 실패 - $e');
    }
  }

  // 로컬 리스트에서 뉴스 업데이트
  void _updateNewsInLists(News updatedNews) {
    // _newsList 업데이트
    final newsIndex = _newsList.indexWhere((item) => item.id == updatedNews.id);
    if (newsIndex >= 0) {
      _newsList[newsIndex] = updatedNews;
    }

    // _pagedNewsList 업데이트
    final pagedNewsIndex = _pagedNewsList.indexWhere(
      (item) => item.id == updatedNews.id,
    );
    if (pagedNewsIndex >= 0) {
      _pagedNewsList[pagedNewsIndex] = updatedNews;
    }

    // _popularNews 업데이트
    final popularNewsIndex = _popularNews.indexWhere(
      (item) => item.id == updatedNews.id,
    );
    if (popularNewsIndex >= 0) {
      _popularNews[popularNewsIndex] = updatedNews;
    }
  }
}
