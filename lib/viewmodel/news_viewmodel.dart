import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../model/news_model.dart';
import '../core/constants.dart';

// 뉴스 데이터 관련 ViewModel 클래스
class NewsViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // 상태 관리
  bool _isLoading = false;
  List<News> _newsList = [];
  News? _selectedNews;
  String? _errorMessage;

  // 자동 갱신 타이머
  Timer? _refreshTimer;

  // 필터링
  String? _coinFilter;

  // 생성자
  NewsViewModel(this._supabaseService) {
    // 초기 뉴스 데이터 로드
    refreshNews();

    // 자동 갱신 타이머 설정
    _setupAutoRefresh();
  }

  // Getters
  bool get isLoading => _isLoading;
  List<News> get newsList => _coinFilter != null
      ? _newsList
            .where((news) => news.relatedCoins.contains(_coinFilter))
            .toList()
      : _newsList;
  News? get selectedNews => _selectedNews;
  String? get errorMessage => _errorMessage;
  String? get coinFilter => _coinFilter;

  // 자동 갱신 타이머 설정
  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: TimeConstants.newsRefreshIntervalMinutes),
      (_) => refreshNews(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 뉴스 목록 갱신
  Future<void> refreshNews() async {
    _isLoading = true;
    notifyListeners();

    try {
      final newsList = await _supabaseService.getNews();
      _newsList = newsList;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '뉴스 데이터 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 코인 관련 뉴스 로드
  Future<void> loadNewsByCoinId(String coinId) async {
    _isLoading = true;
    _coinFilter = coinId;
    notifyListeners();

    try {
      final newsList = await _supabaseService.getNewsByCoinId(coinId);
      _newsList = newsList;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '코인 관련 뉴스 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 뉴스 선택
  void selectNews(News news) {
    _selectedNews = news;
    notifyListeners();
  }

  // 필터 설정
  void setFilter(String? coinId) {
    _coinFilter = coinId;
    notifyListeners();
  }

  // 필터 초기화
  void clearFilter() {
    _coinFilter = null;
    notifyListeners();
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
