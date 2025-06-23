import 'dart:async';
import 'dart:convert';
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

  // 검색어를 무시하고 코인 필터만 적용한 뉴스 리스트 반환
  List<News> get newsListWithoutSearch {
    var filtered = _newsList;
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

      // 서버에서 뉴스 데이터 로드
      final newsList = await _firebaseService.getNews(limit: 50);
      debugPrint('NewsViewModel: 뉴스 ${newsList.length}개 로드됨');

      if (newsList.isEmpty) {
        debugPrint('NewsViewModel: 로드된 뉴스가 없음');
        _errorMessage = '뉴스 데이터를 불러올 수 없습니다.';
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

  /// 캐시된 뉴스 데이터 로드
  Future<void> _loadCachedNews() async {
    try {
      debugPrint('NewsViewModel: 캐시된 뉴스 데이터 로드 시도');
      final cachedNews = await _getCachedNews();

      if (cachedNews.isNotEmpty) {
        _newsList = cachedNews;
        // 인기 뉴스는 캐시된 뉴스 중 조회수 상위 5개 사용
        _popularNews = List.of(cachedNews)
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
        _popularNews = _popularNews.take(5).toList();
        debugPrint('NewsViewModel: 캐시된 뉴스 데이터 로드 완료 - ${cachedNews.length}개');
      } else {
        debugPrint('NewsViewModel: 캐시된 뉴스 데이터가 없음');
        _errorMessage = '저장된 뉴스 데이터가 없습니다. 네트워크 연결을 확인해주세요.';
      }
    } catch (e) {
      debugPrint('NewsViewModel: 캐시된 뉴스 데이터 로드 실패 - $e');
      _errorMessage = '저장된 뉴스 데이터를 불러오는 중 오류가 발생했습니다.';
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

    final lowerCaseId = coinIdOrSymbol.toLowerCase();
    return idMap[lowerCaseId] ?? lowerCaseId;
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
    } else {
      _coinFilter = coinId;
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
}
