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
      // 현재 SupabaseService에 getNews 메서드가 구현되지 않았으므로 더미 데이터 사용
      _newsList = [
        News(
          id: '1',
          title: '비트코인, 사상 최고가 경신',
          content: '비트코인이 사상 최고가를 경신했습니다. 전문가들은 이러한 추세가 계속될 것으로 전망합니다.',
          source: 'Crypto News',
          url: 'https://example.com/news/1',
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
          imageUrl: 'https://example.com/images/bitcoin.jpg',
          relatedCoins: ['BTC'],
        ),
        News(
          id: '2',
          title: '이더리움 2.0 업데이트 성공적으로 완료',
          content:
              '이더리움 네트워크가 2.0 업데이트를 성공적으로 완료했습니다. 이번 업데이트로 네트워크 속도와 확장성이 크게 향상될 전망입니다.',
          source: 'Ethereum Today',
          url: 'https://example.com/news/2',
          publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
          imageUrl: 'https://example.com/images/ethereum.jpg',
          relatedCoins: ['ETH'],
        ),
        News(
          id: '3',
          title: '리플, 국제 송금 시장 점유율 확대',
          content:
              '리플이 국제 송금 시장에서 점유율을 확대하고 있습니다. 여러 은행들이 리플의 기술을 도입하기 시작했습니다.',
          source: 'Ripple News',
          url: 'https://example.com/news/3',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          imageUrl: 'https://example.com/images/ripple.jpg',
          relatedCoins: ['XRP'],
        ),
      ];
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
      // 현재 SupabaseService에 getNewsByCoinId 메서드가 구현되지 않았으므로 로컬 필터링 사용
      await refreshNews(); // 모든 뉴스 로드
      // 필터링은 getter에서 처리됨
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
