import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  dynamic _lastDoc; // Firestore: DocumentSnapshot, RealtimeDB: key
  bool _hasMore = true; // 더 불러올 뉴스가 있는지 여부
  bool _isLoadingMore = false; // 추가 로딩 중 여부
  int _loadCount = 0; // 데이터 로드 횟수 추적

  // 오프라인 조회수 동기화 관련
  List<Map<String, dynamic>> _pendingViewCounts = [];
  bool _isSyncingViewCounts = false;

  // 중복 뉴스 정리 타이머
  Timer? _duplicateCleanerTimer;

  // Firebase 실시간 리스너
  StreamSubscription? _newsDataSubscription;

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

        // 페이징 데이터도 동기 로드
        final cachedPagedData = box.get('cached_paged_news');
        if (cachedPagedData != null) {
          final List<dynamic> pagedNewsJsonList = cachedPagedData;
          _pagedNewsList = pagedNewsJsonList
              .map(
                (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
              )
              .toList();
        } else {
          _pagedNewsList = List.from(_newsList);
        }

        notifyListeners();
      }
    }

    // 비동기 초기화
    _initializeAsync();
  }

  // 비동기 초기화 메서드
  Future<void> _initializeAsync() async {
    // 캐시된 인기 뉴스 로드
    final cachedPopularNews = await _loadCachedPopularNews();
    if (cachedPopularNews.isNotEmpty) {
      _popularNews = cachedPopularNews;
      debugPrint('NewsViewModel: 생성자에서 캐시된 인기 뉴스 ${_popularNews.length}개 로드됨');
      notifyListeners();
    } else {
      // 캐시된 인기 뉴스가 없으면 현재 뉴스 데이터로 인기 뉴스 생성
      _updatePopularNews();
    }

    // 네트워크, 타이머 등 기존 초기화는 그대로 비동기 처리
    _initConnectivity();
    _setupConnectivityMonitoring();
    _loadPendingViewCounts(); // 저장된 조회수 로드

    // refreshNews() 대신 fetchInitialNewsPage() 사용으로 페이징과 조회수 보존 동시 적용
    fetchInitialNewsPage();

    _setupAutoRefresh();
    _setupDuplicateNewsCleaner(); // 중복 뉴스 정리 타이머 설정
    _initializeFirebaseListener(); // Firebase 초기화 후 리스너 설정
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
            news.content.toLowerCase().contains(query);
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

  // 네트워크 연결 모니터링 설정
  void _setupConnectivityMonitoring() {
    if (kIsWeb) {
      debugPrint('NewsViewModel: 웹 플랫폼에서는 연결 모니터링을 건너뜁니다.');
      return;
    }

    try {
      final checker = InternetConnectionChecker.createInstance();
      _connectivitySubscription = checker.onStatusChange.listen((status) {
        final isConnected = status == InternetConnectionStatus.connected;
        _onConnectivityChanged(isConnected);
      });
      debugPrint('NewsViewModel: 네트워크 연결 모니터링 설정 완료');
    } catch (e) {
      debugPrint('NewsViewModel: 네트워크 연결 모니터링 설정 실패 - $e');
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
    _duplicateCleanerTimer?.cancel();
    _connectivitySubscription?.cancel();
    _newsDataSubscription?.cancel();
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

  // 인기 뉴스 데이터를 캐시에 저장
  Future<void> _cachePopularNewsData(List<News> popularNews) async {
    try {
      // 인기 뉴스를 JSON으로 변환
      final List<Map<String, dynamic>> newsJsonList = popularNews
          .map((news) => news.toJson())
          .toList();

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_popular_news', jsonEncode(newsJsonList));

      debugPrint('NewsViewModel: ${popularNews.length}개의 인기 뉴스 캐시 저장 완료');
    } catch (e) {
      debugPrint('NewsViewModel: 인기 뉴스 캐시 저장 실패 - $e');
    }
  }

  // 캐시된 인기 뉴스 데이터 로드
  Future<List<News>> _loadCachedPopularNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_popular_news');

      if (cachedData != null) {
        final List<dynamic> newsJsonList = jsonDecode(cachedData);
        final List<News> popularNews = newsJsonList
            .map(
              (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
            )
            .toList();

        debugPrint('NewsViewModel: ${popularNews.length}개의 캐시된 인기 뉴스 로드됨');
        return popularNews;
      }
    } catch (e) {
      debugPrint('NewsViewModel: 인기 뉴스 캐시 로드 실패 - $e');
    }

    return [];
  }

  // 페이징된 뉴스 데이터를 캐시에서 가져오기
  Future<List<News>> _getCachedPagedNews() async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final cachedData = box.get('cached_paged_news');
        if (cachedData != null) {
          final List<dynamic> newsJsonList = cachedData;
          debugPrint(
            'NewsViewModel: 캐시된 페이징 뉴스 데이터 로드 시도 - ${newsJsonList.length}개 항목',
          );
          return newsJsonList
              .map(
                (json) => News.fromJson(Map<String, dynamic>.from(json as Map)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('NewsViewModel: 캐시된 페이징 뉴스 데이터 로드 실패: $e');
    }
    return [];
  }

  // 페이징된 뉴스 데이터를 캐시에 저장
  Future<void> _cachePagedNewsData(List<News> newsList) async {
    try {
      if (Hive.isBoxOpen('news_cache')) {
        final box = Hive.box('news_cache');
        final newsJsonList = newsList.map((news) => news.toJson()).toList();
        await box.put('cached_paged_news', newsJsonList);
        debugPrint('NewsViewModel: 페이징 뉴스 데이터 캐싱 완료: ${newsList.length}개');
      }
    } catch (e) {
      debugPrint('NewsViewModel: 페이징 뉴스 데이터 캐싱 실패: $e');
    }
  }

  // 모의 뉴스 데이터 생성 (이미지 포함)
  List<News> _generateMockNewsWithImages() {
    return [
      News(
        id: const Uuid().v4(),
        title: '비트코인 신규 고점 돌파',
        content:
            '비트코인이 새로운 역사적 고점을 돌파했습니다. 시장 전문가들은 이번 상승세가 기관 투자자들의 유입과 함께 지속될 것으로 전망하고 있습니다.',
        source: 'CoinNews',
        url: 'https://example.com/news/1',
        imageUrl:
            'https://images.unsplash.com/photo-1518546305927-5a555bb7020d?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        relatedCoins: ['bitcoin'],
      ),
      News(
        id: const Uuid().v4(),
        title: '이더리움 업데이트 예정',
        content:
            '이더리움 네트워크의 새로운 업데이트가 다음 주에 예정되어 있습니다. 이번 업데이트는 가스비 절감과 처리 속도 향상에 중점을 두고 있습니다.',
        source: 'CryptoDaily',
        url: 'https://example.com/news/2',
        imageUrl:
            'https://images.unsplash.com/photo-1622630998477-20aa696ecb05?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
        relatedCoins: ['ethereum'],
      ),
      News(
        id: const Uuid().v4(),
        title: '솔라나 생태계 확장',
        content:
            '솔라나 생태계가 빠르게 확장되고 있으며, 새로운 프로젝트들이 계속해서 추가되고 있습니다. 특히 DeFi와 NFT 분야에서 큰 성장을 보이고 있습니다.',
        source: 'BlockchainToday',
        url: 'https://example.com/news/3',
        imageUrl:
            'https://images.unsplash.com/photo-1639762681057-408e52192e55?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
        relatedCoins: ['solana'],
      ),
      News(
        id: const Uuid().v4(),
        title: '리플, 새로운 파트너십 발표',
        content:
            '리플이 글로벌 금융 기관과의 새로운 파트너십을 발표했습니다. 이번 협력을 통해 국제 송금 시장에서의 입지를 더욱 강화할 전망입니다.',
        source: 'CryptoNews',
        url: 'https://example.com/news/4',
        imageUrl:
            'https://images.unsplash.com/photo-1621761191319-c6fb62004040?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
        publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
        relatedCoins: ['ripple', 'xrp'],
      ),
      News(
        id: const Uuid().v4(),
        title: '바이낸스, 새로운 규제 준수 조치 발표',
        content:
            '바이낸스가 글로벌 규제 환경에 대응하기 위한 새로운 준수 조치를 발표했습니다. 이는 여러 국가에서의 법적 문제를 해결하기 위한 노력의 일환입니다.',
        source: 'CoinDesk',
        url: 'https://example.com/news/5',
        imageUrl:
            'https://images.unsplash.com/photo-1621504450181-5d356f61d307?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80',
        publishedAt: DateTime.now().subtract(const Duration(hours: 24)),
        relatedCoins: ['bnb', 'binancecoin'],
      ),
    ];
  }

  // 두 뉴스 목록 간에 내용이 변경되었는지 확인
  bool _hasNewsContentChanged(List<News> oldList, List<News> newList) {
    if (oldList.length != newList.length) return true;

    final Map<String, News> oldMap = {for (var news in oldList) news.id: news};

    for (final news in newList) {
      if (!oldMap.containsKey(news.id)) return true;

      final oldNews = oldMap[news.id]!;
      if (news.title != oldNews.title ||
          news.content != oldNews.content ||
          news.source != oldNews.source ||
          news.url != oldNews.url ||
          news.imageUrl != oldNews.imageUrl ||
          !_areListsEqual(news.relatedCoins, oldNews.relatedCoins)) {
        return true;
      }
    }

    return false;
  }

  // 두 리스트가 동일한지 확인
  bool _areListsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }

    return true;
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

      // 기존 조회수 데이터 보존을 위한 맵 생성
      final Map<String, int> existingViewCounts = {};
      for (final news in _newsList) {
        if (news.viewCount > 0) {
          existingViewCounts[news.id] = news.viewCount;
          debugPrint(
            'NewsViewModel: 기존 조회수 저장 - ID: ${news.id}, 조회수: ${news.viewCount}',
          );
        }
      }
      for (final news in _pagedNewsList) {
        if (news.viewCount > 0) {
          existingViewCounts[news.id] = news.viewCount;
          debugPrint(
            'NewsViewModel: 기존 페이징 조회수 저장 - ID: ${news.id}, 조회수: ${news.viewCount}',
          );
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

      // 조회수 보존하면서 뉴스 데이터 업데이트
      final updatedNewsList = newsList.map((news) {
        if (existingViewCounts.containsKey(news.id)) {
          final existingViewCount = existingViewCounts[news.id]!;
          debugPrint(
            'NewsViewModel: refreshNews - 조회수 보존 (ID: ${news.id}, 조회수: $existingViewCount)',
          );
          return news.copyWith(viewCount: existingViewCount);
        }
        return news;
      }).toList();

      _newsList = updatedNewsList;
      _pagedNewsList = List.from(updatedNewsList);

      // 인기 뉴스 업데이트 (조회수 기준)
      _updatePopularNews();

      // 뉴스 데이터 캐싱
      _cacheNewsData(_newsList);
      _cachePagedNewsData(_pagedNewsList);

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
      final cachedPopularNews = await _loadCachedPopularNews();

      if (cachedNews.isNotEmpty) {
        debugPrint('NewsViewModel: ${cachedNews.length}개의 캐시된 뉴스 로드 성공');
        _newsList = cachedNews;
        _pagedNewsList = List.from(cachedNews);

        // 캐시된 인기 뉴스가 있으면 로드
        if (cachedPopularNews.isNotEmpty) {
          _popularNews = cachedPopularNews;
          debugPrint('NewsViewModel: 캐시된 인기 뉴스 ${_popularNews.length}개 로드됨');
        } else {
          // 캐시된 인기 뉴스가 없으면 _updatePopularNews()로 생성
          _updatePopularNews();
        }
      } else {
        debugPrint('NewsViewModel: 캐시된 뉴스 없음, 모의 데이터 생성');
        // 캐시된 데이터가 없으면 모의 데이터 생성
        final mockNews = _generateMockNewsWithImages();
        _newsList = mockNews;
        _pagedNewsList = List.from(mockNews);
        _popularNews = mockNews.take(5).toList();

        // 모의 데이터 캐싱
        _cacheNewsData(mockNews);
        _cachePagedNewsData(_pagedNewsList);
        _cachePopularNewsData(_popularNews);
      }
    } catch (e) {
      debugPrint('NewsViewModel: 캐시된 뉴스 로드 실패 - $e');
      // 모의 데이터 생성
      final mockNews = _generateMockNewsWithImages();
      _newsList = mockNews;
      _pagedNewsList = List.from(mockNews);
      _popularNews = mockNews.take(5).toList();
    }
  }

  /// 최초 진입 시 캐시가 있으면 캐시, 없으면 Firestore에서 첫 페이지만 가져오기
  Future<void> fetchInitialNewsPage({int pageSize = 50}) async {
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
      // 캐시된 인기 뉴스 로드
      final cachedPopularNews = await _loadCachedPopularNews();

      // 캐시된 뉴스 조회수 맵 생성 (ID -> 조회수)
      final Map<String, int> cachedViewCounts = {};
      for (final news in cachedNews) {
        if (news.viewCount > 0) {
          cachedViewCounts[news.id] = news.viewCount;
          debugPrint(
            'NewsViewModel: 캐시된 조회수 - ID: ${news.id}, 조회수: ${news.viewCount}',
          );
        }
      }

      if (cachedNews.isNotEmpty) {
        debugPrint('NewsViewModel: 캐시된 뉴스 데이터 ${cachedNews.length}개 로드됨');
        _pagedNewsList = cachedNews;
        _newsList = List.from(cachedNews);
        _hasMore = true; // 더 데이터가 있다고 가정

        // 캐시된 인기 뉴스가 있으면 로드
        if (cachedPopularNews.isNotEmpty) {
          _popularNews = cachedPopularNews;
          debugPrint('NewsViewModel: 캐시된 인기 뉴스 ${_popularNews.length}개 로드됨');
        } else {
          // 캐시된 인기 뉴스가 없으면 _updatePopularNews()로 생성
          _updatePopularNews();
        }
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
              // 새로운 뉴스는 캐시된 조회수가 있으면 적용
              if (cachedViewCounts.containsKey(news.id)) {
                final cachedViewCount = cachedViewCounts[news.id]!;
                mergedNewsMap[news.id] = news.copyWith(
                  viewCount: cachedViewCount,
                );
                debugPrint(
                  'NewsViewModel: 캐시된 조회수 적용 - ID: ${news.id}, 조회수: $cachedViewCount',
                );
              } else {
                // 그 외에는 그대로 추가
                mergedNewsMap[news.id] = news;
              }
            }
          }

          // 3. 맵을 리스트로 변환하고 최신순으로 정렬
          final mergedNewsList = mergedNewsMap.values.toList()
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

          // 항상 병합된 데이터로 업데이트 (조회수 보존을 위해)
          _pagedNewsList = mergedNewsList;
          _newsList = List.from(mergedNewsList);
          _lastDoc = result.lastDoc;
          _hasMore = result.hasMore;

          debugPrint(
            'NewsViewModel: [데이터 상태] 병합된 데이터로 업데이트 (${mergedNewsList.length}개)',
          );

          // 인기 뉴스 업데이트 (조회수 기준)
          _updatePopularNews();

          // Hive에 저장
          await _cachePagedNewsData(_pagedNewsList);
          debugPrint(
            'NewsViewModel: [캐시 저장] ${_pagedNewsList.length}개 뉴스 캐시 저장 완료',
          );
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

  // 인기 뉴스 업데이트 (조회수 기준 정렬)
  void _updatePopularNews() {
    debugPrint(
      'NewsViewModel: _updatePopularNews 시작 - 전체 뉴스: ${_pagedNewsList.length}개',
    );

    // 조회수가 있는 뉴스만 필터링
    final newsWithViews = _pagedNewsList
        .where((news) => news.viewCount > 0)
        .toList();

    debugPrint('NewsViewModel: 조회수가 있는 뉴스: ${newsWithViews.length}개');

    // 조회수 로그 출력
    for (final news in newsWithViews) {
      debugPrint(
        'NewsViewModel: 조회수 뉴스 - ${news.title} (조회수: ${news.viewCount})',
      );
    }

    if (newsWithViews.isNotEmpty) {
      // 조회수 기준으로 내림차순 정렬
      newsWithViews.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      final previousPopularCount = _popularNews.length;
      _popularNews = newsWithViews.take(10).toList();

      debugPrint(
        'NewsViewModel: 인기 뉴스 업데이트 - 이전: ${previousPopularCount}개, 현재: ${_popularNews.length}개',
      );

      if (_popularNews.isNotEmpty) {
        debugPrint(
          'NewsViewModel: 가장 인기있는 뉴스 - 제목: ${_popularNews.first.title}, 조회수: ${_popularNews.first.viewCount}',
        );

        // 상위 3개 인기 뉴스 로그
        for (int i = 0; i < _popularNews.length && i < 3; i++) {
          debugPrint(
            'NewsViewModel: 인기 뉴스 ${i + 1}위 - ${_popularNews[i].title} (조회수: ${_popularNews[i].viewCount})',
          );
        }
      }

      // 인기 뉴스 정보를 캐시에 저장
      _cachePopularNewsData(_popularNews);
      debugPrint('NewsViewModel: 인기 뉴스 캐시 저장 완료');
    } else {
      final previousPopularCount = _popularNews.length;
      _popularNews = [];
      debugPrint(
        'NewsViewModel: 조회수 있는 뉴스 없음 - 이전 인기 뉴스: ${previousPopularCount}개 → 현재: 0개',
      );
    }

    debugPrint('NewsViewModel: _updatePopularNews 완료');
  }

  /// 다음 페이지 뉴스 로드
  Future<void> fetchNextNewsPage({int pageSize = 50}) async {
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

          // 인기 뉴스 업데이트
          _updatePopularNews();

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
        'NewsViewModel: 뉴스 조회수 증가 시작 - ID: ${news.id}, 제목: ${news.title}, 기존 조회수: ${news.viewCount}',
      );

      // 현재 조회수 확인 및 증가
      final updatedCount = news.viewCount + 1;
      final updatedNews = news.copyWith(viewCount: updatedCount);

      // 로컬 리스트에서 해당 뉴스 업데이트 (항상 수행)
      _updateNewsInLists(updatedNews);

      // 즉시 인기 뉴스 업데이트
      _updatePopularNews();

      // UI 즉시 업데이트
      notifyListeners();

      // 캐시 업데이트 (항상 수행)
      await _cacheNewsData(_newsList);
      await _cachePagedNewsData(_pagedNewsList);

      debugPrint(
        'NewsViewModel: 로컬 조회수 업데이트 완료 - ID: ${news.id}, 새 조회수: $updatedCount',
      );

      // 오프라인 모드이거나 네트워크 연결이 없는 경우 조회수를 저장했다가 나중에 동기화
      if (_isOfflineMode || !_isConnected) {
        debugPrint('NewsViewModel: 오프라인 모드 또는 네트워크 연결 없음 - 조회수 저장');
        await _savePendingViewCount(news.id, updatedCount);
        return;
      }

      // Firebase 서비스가 초기화되지 않았으면 초기화 시도
      if (!_firebaseService.isInitialized) {
        debugPrint('NewsViewModel: Firebase 초기화 안됨 - 초기화 시도');
        try {
          await _firebaseService.initialize();
          debugPrint('NewsViewModel: Firebase 초기화 성공');
        } catch (e) {
          debugPrint('NewsViewModel: Firebase 초기화 실패 - $e');
          // 초기화 실패 시 조회수를 저장했다가 나중에 동기화
          await _savePendingViewCount(news.id, updatedCount);
          return;
        }
      }

      // Firebase에 조회수 업데이트
      try {
        await _firebaseService.updateNewsViewCount(news.id, updatedCount);
        debugPrint(
          'NewsViewModel: Firebase에 조회수 업데이트 성공 - ID: ${news.id}, 새 조회수: $updatedCount',
        );
      } catch (e) {
        debugPrint('NewsViewModel: Firebase 조회수 업데이트 실패 - $e');
        // 업데이트 실패 시 조회수를 저장했다가 나중에 동기화
        await _savePendingViewCount(news.id, updatedCount);
      }

      debugPrint(
        'NewsViewModel: 뉴스 조회수 증가 완료 - ID: ${news.id}, 새 조회수: $updatedCount',
      );
    } catch (e) {
      debugPrint('NewsViewModel: 뉴스 조회수 증가 실패 - $e');
    }
  }

  // 오프라인 상태에서 조회수 저장
  Future<void> _savePendingViewCount(String newsId, int viewCount) async {
    try {
      // 기존 보류 중인 조회수 로드
      await _loadPendingViewCounts();

      // 이미 같은 뉴스 ID가 있는지 확인
      final existingIndex = _pendingViewCounts.indexWhere(
        (item) => item['id'] == newsId,
      );
      if (existingIndex >= 0) {
        // 기존 항목 업데이트
        _pendingViewCounts[existingIndex]['viewCount'] = viewCount;
      } else {
        // 새 항목 추가
        _pendingViewCounts.add({
          'id': newsId,
          'viewCount': viewCount,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_view_counts',
        jsonEncode(_pendingViewCounts),
      );

      debugPrint(
        'NewsViewModel: 보류 중인 조회수 저장 완료 - ${_pendingViewCounts.length}개 항목',
      );

      // 네트워크 연결이 있으면 동기화 시도
      if (_isConnected && !_isOfflineMode) {
        _syncPendingViewCounts();
      }
    } catch (e) {
      debugPrint('NewsViewModel: 보류 중인 조회수 저장 실패 - $e');
    }
  }

  // 저장된 조회수 로드
  Future<void> _loadPendingViewCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingViewCountsJson = prefs.getString('pending_view_counts');

      if (pendingViewCountsJson != null) {
        final List<dynamic> decoded = jsonDecode(pendingViewCountsJson);
        _pendingViewCounts = decoded
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        debugPrint(
          'NewsViewModel: 보류 중인 조회수 ${_pendingViewCounts.length}개 로드됨',
        );
      } else {
        _pendingViewCounts = [];
      }
    } catch (e) {
      debugPrint('NewsViewModel: 보류 중인 조회수 로드 실패 - $e');
      _pendingViewCounts = [];
    }
  }

  // 저장된 조회수 동기화
  Future<void> _syncPendingViewCounts() async {
    // 이미 동기화 중이면 무시
    if (_isSyncingViewCounts || _pendingViewCounts.isEmpty) {
      return;
    }

    _isSyncingViewCounts = true;
    debugPrint(
      'NewsViewModel: 보류 중인 조회수 동기화 시작 - ${_pendingViewCounts.length}개 항목',
    );

    try {
      // Firebase 서비스가 초기화되지 않았으면 초기화 시도
      if (!_firebaseService.isInitialized) {
        try {
          await _firebaseService.initialize();
          debugPrint('NewsViewModel: 동기화를 위한 Firebase 초기화 성공');
        } catch (e) {
          debugPrint('NewsViewModel: 동기화를 위한 Firebase 초기화 실패 - $e');
          _isSyncingViewCounts = false;
          return;
        }
      }

      // 성공적으로 동기화된 항목의 인덱스를 저장
      final List<int> syncedIndices = [];

      // 각 항목을 Firebase에 동기화
      for (int i = 0; i < _pendingViewCounts.length; i++) {
        final item = _pendingViewCounts[i];
        try {
          await _firebaseService.updateNewsViewCount(
            item['id'],
            item['viewCount'],
          );
          syncedIndices.add(i);
          debugPrint(
            'NewsViewModel: 조회수 동기화 성공 - ID: ${item['id']}, 조회수: ${item['viewCount']}',
          );
        } catch (e) {
          debugPrint('NewsViewModel: 조회수 동기화 실패 - ID: ${item['id']}, 오류: $e');
        }
      }

      // 성공적으로 동기화된 항목 제거 (역순으로 제거해야 인덱스가 변하지 않음)
      syncedIndices.sort((a, b) => b.compareTo(a));
      for (final index in syncedIndices) {
        _pendingViewCounts.removeAt(index);
      }

      // 남은 항목 저장
      final prefs = await SharedPreferences.getInstance();
      if (_pendingViewCounts.isEmpty) {
        await prefs.remove('pending_view_counts');
        debugPrint('NewsViewModel: 모든 조회수 동기화 완료, 저장된 데이터 삭제');
      } else {
        await prefs.setString(
          'pending_view_counts',
          jsonEncode(_pendingViewCounts),
        );
        debugPrint(
          'NewsViewModel: ${syncedIndices.length}개 동기화 완료, ${_pendingViewCounts.length}개 항목 남음',
        );
      }
    } catch (e) {
      debugPrint('NewsViewModel: 조회수 동기화 중 오류 발생 - $e');
    } finally {
      _isSyncingViewCounts = false;
    }
  }

  // 네트워크 연결 상태 변경 시 호출되는 메서드에 동기화 로직 추가
  void _onConnectivityChanged(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      debugPrint(
        'NewsViewModel: 네트워크 상태 변경 - ${isConnected ? "연결됨" : "연결 끊김"}',
      );

      // 연결이 복원되면 보류 중인 조회수 동기화 시도
      if (isConnected && !_isOfflineMode) {
        _syncPendingViewCounts();
      }

      notifyListeners();
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

  // 중복 뉴스 정리 타이머 설정
  void _setupDuplicateNewsCleaner() {
    // 앱 시작 시 한 번 실행 (1분 후)
    Future.delayed(const Duration(minutes: 1), () {
      _cleanupDuplicateNews();
    });

    // 주기적으로 중복 뉴스 정리 (6시간마다)
    _duplicateCleanerTimer?.cancel();
    _duplicateCleanerTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _cleanupDuplicateNews();
    });
  }

  // 중복 뉴스 정리 실행
  Future<void> _cleanupDuplicateNews() async {
    if (!_isConnected || _isOfflineMode || !_firebaseService.isInitialized) {
      debugPrint('NewsViewModel: 네트워크 연결 없거나 오프라인 모드이므로 중복 뉴스 정리 건너뜀');
      return;
    }

    try {
      debugPrint('NewsViewModel: 중복 뉴스 정리 시작');
      final removedCount = await _firebaseService.cleanupDuplicateNews();

      if (removedCount > 0) {
        debugPrint('NewsViewModel: 중복 뉴스 정리 완료 - $removedCount개 삭제됨');
        // 뉴스 목록 새로고침
        await refreshNews();
      } else if (removedCount == 0) {
        debugPrint('NewsViewModel: 중복 뉴스가 없습니다');
      } else {
        debugPrint('NewsViewModel: 중복 뉴스 정리 중 오류 발생');
      }
    } catch (e) {
      debugPrint('NewsViewModel: 중복 뉴스 정리 중 예외 발생 - $e');
    }
  }

  // Firebase 실시간 리스너 설정
  void _setupFirebaseListener() {
    if (!_firebaseService.isInitialized) {
      debugPrint('NewsViewModel: Firebase 초기화 안됨 - 리스너 설정 건너뜀');
      return;
    }

    try {
      debugPrint('NewsViewModel: Firebase 실시간 리스너 설정 시작');
      _newsDataSubscription = _firebaseService.getNewsStream().listen(
        (newData) {
          if (newData.isNotEmpty) {
            debugPrint('NewsViewModel: 실시간 뉴스 데이터 수신 - ${newData.length}개');

            // 기존 조회수 보존을 위한 맵 생성
            final Map<String, int> existingViewCounts = {};
            for (final news in _pagedNewsList) {
              if (news.viewCount > 0) {
                existingViewCounts[news.id] = news.viewCount;
              }
            }

            // 새 데이터에 기존 조회수 적용
            final updatedNews = newData.map((news) {
              if (existingViewCounts.containsKey(news.id)) {
                final existingViewCount = existingViewCounts[news.id]!;
                debugPrint(
                  'NewsViewModel: 실시간 업데이트 - 기존 조회수 보존 (ID: ${news.id}, 조회수: $existingViewCount)',
                );
                return news.copyWith(viewCount: existingViewCount);
              }
              return news;
            }).toList();

            // 데이터 업데이트
            _newsList = updatedNews;
            _pagedNewsList = updatedNews;

            // 인기 뉴스 업데이트
            _updatePopularNews();

            // 캐시 업데이트
            _cacheNewsData(_newsList);
            _cachePagedNewsData(_pagedNewsList);

            debugPrint('NewsViewModel: 실시간 데이터 업데이트 완료');
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('NewsViewModel: 실시간 리스너 에러 - $error');
        },
      );
      debugPrint('NewsViewModel: Firebase 실시간 리스너 설정 완료');
    } catch (e) {
      debugPrint('NewsViewModel: Firebase 실시간 리스너 설정 실패 - $e');
    }
  }

  // Firebase 리스너를 지연 초기화
  Future<void> _initializeFirebaseListener() async {
    // Firebase 서비스가 초기화될 때까지 대기
    await Future.delayed(const Duration(seconds: 2));

    if (_firebaseService.isInitialized) {
      _setupFirebaseListener();
    } else {
      // 추가 대기 후 재시도
      await Future.delayed(const Duration(seconds: 3));
      if (_firebaseService.isInitialized) {
        _setupFirebaseListener();
      } else {
        debugPrint('NewsViewModel: Firebase 초기화 시간 초과 - 실시간 리스너 설정 건너뜀');
      }
    }
  }
}
