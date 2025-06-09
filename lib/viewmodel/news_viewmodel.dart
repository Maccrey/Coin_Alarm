import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../services/supabase_service.dart';
import '../model/news_model.dart';
import '../core/constants.dart';

// 뉴스 데이터 관련 ViewModel 클래스
class NewsViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

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
  late StreamSubscription _connectivitySubscription;

  // 원본 값과 정규화된 값 모두 저장
  String? _rawCoinFilter;
  String? _normalizedCoinFilter;

  // 생성자
  NewsViewModel(this._supabaseService) {
    // 초기 뉴스 데이터 로드
    _initConnectivity();
    _setupConnectivityMonitoring();
    refreshNews();

    // 자동 갱신 타이머 설정
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
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // 뉴스 목록 갱신
  Future<void> refreshNews() async {
    // 현재 필터 상태 저장
    final currentFilter = _coinFilter;
    final currentQuery = _searchQuery;

    // 필터 초기화
    _coinFilter = null;
    _searchQuery = '';

    // 오프라인 모드이거나 네트워크 연결이 없는 경우 캐시된 데이터 사용
    if (_isOfflineMode || !_isConnected) {
      return _loadCachedNews();
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Supabase에서 뉴스 데이터 가져오기
      _newsList = await _supabaseService.getNews();
      debugPrint('refreshNews: 뉴스 ${_newsList.length}개 로드됨');

      try {
        // 인기 뉴스 로드 (별도 try-catch로 분리하여 인기 뉴스 로드 실패가 전체 로드에 영향 없게 함)
        _popularNews = await _supabaseService.getPopularNews();
        debugPrint('refreshNews: 인기 뉴스 ${_popularNews.length}개 로드됨');
      } catch (e) {
        debugPrint('인기 뉴스 로드 실패: $e');
        _popularNews = []; // 실패 시 빈 리스트로 설정
      }

      // 가져온 데이터 캐싱
      await _supabaseService.cacheNewsData(_newsList);

      _errorMessage = null;
    } catch (e) {
      _errorMessage = '뉴스 데이터 로드 실패: $e';
      debugPrint(_errorMessage);

      // 오류 발생 시 캐시된 데이터로 폴백
      await _loadCachedNews();
    } finally {
      // 필터 복원 (만약 필터가 적용된 상태였다면)
      if (currentFilter != null && currentFilter.isNotEmpty) {
        _coinFilter = currentFilter;
      }

      if (currentQuery.isNotEmpty) {
        _searchQuery = currentQuery;
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  // 캐시된 뉴스 데이터 로드
  Future<void> _loadCachedNews() async {
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final cachedNews = await _supabaseService.getCachedNews();
      if (cachedNews.isNotEmpty) {
        _newsList = cachedNews;
        // 인기 뉴스는 캐시된 뉴스 중 상위 3개만 사용
        _popularNews = List.of(cachedNews)
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        _popularNews = _popularNews.take(3).toList();

        debugPrint('캐시된 뉴스 데이터 로드 완료: ${cachedNews.length}개');
      } else {
        debugPrint('캐시된 뉴스 데이터가 없습니다');
      }
    } catch (e) {
      debugPrint('캐시된 뉴스 데이터 로드 실패: $e');

      // 오류 메시지 업데이트 (기존 오류 메시지가 없는 경우에만)
      if (_errorMessage == null) {
        _errorMessage = '뉴스 데이터 로드 실패: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 코인 관련 뉴스 로드
  Future<void> loadNewsByCoinId(String coinId) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (coinId.isEmpty || coinId == '전체') {
        // 전체 뉴스 로드
        await refreshNews();
        _coinFilter = null;
      } else {
        // 코인 ID 또는 심볼 정규화
        final normalizedCoinId = _normalizeCoinId(coinId);
        // 원본 값과 정규화된 값 모두 저장
        _coinFilter = coinId;
        _rawCoinFilter = coinId;
        _normalizedCoinFilter = normalizedCoinId;

        if (_isOfflineMode || !_isConnected) {
          // 오프라인 모드에서는 캐시된 데이터를 필터링
          await _loadCachedNews();
        } else {
          // 전체 뉴스만 받아오고, 필터는 클라이언트에서 적용
          _newsList = await _supabaseService.getNews();
        }
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = '코인 관련 뉴스 로드 실패: $e';
      debugPrint(_errorMessage);

      // 오류 발생 시 캐시된 데이터로 폴백
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
    notifyListeners();

    try {
      if (_isOfflineMode || !_isConnected) {
        // 오프라인 모드에서는 캐시된 데이터를 검색어로 필터링
        await _loadCachedNews();
      } else {
        // 서버에서 검색 수행
        _newsList = await _supabaseService.searchNews(query: query);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '뉴스 검색 실패: $e';
      debugPrint(_errorMessage);

      // 오류 발생 시 캐시된 데이터로 폴백
      await _loadCachedNews();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 뉴스 선택
  void selectNews(News news) {
    _selectedNews = news;

    // 오프라인 모드가 아니고 네트워크 연결이 있는 경우에만 조회수 증가 API 호출
    if (!_isOfflineMode && _isConnected) {
      _supabaseService
          .incrementNewsViewCount(news.id)
          .then((_) {
            debugPrint('뉴스 조회수 증가 완료: ${news.id}');
          })
          .catchError((e) {
            debugPrint('뉴스 조회수 증가 실패: $e');
          });
    }

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
