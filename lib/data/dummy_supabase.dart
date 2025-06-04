// Supabase 연동 대신 사용할 더미데이터 파일입니다.
// 실제 Supabase 연동 시 이 파일은 제거하고 실제 Supabase 구현으로 대체할 예정입니다.

class DummySupabase {
  // 싱글톤 패턴 구현
  static final DummySupabase _instance = DummySupabase._internal();
  factory DummySupabase() => _instance;
  DummySupabase._internal();

  // Supabase 초기화 여부
  bool _initialized = false;

  // 가상의 Supabase URL과 anon key (실제 사용하지 않음)
  final String supabaseUrl = 'https://example.supabase.co';
  final String supabaseAnonKey = 'dummy-anon-key';

  // Supabase 초기화 함수 (더미)
  Future<void> initialize() async {
    // 실제 초기화 대신 딜레이만 추가해서 비동기 작업 흉내
    await Future.delayed(const Duration(milliseconds: 500));
    _initialized = true;
    print('더미 Supabase가 초기화되었습니다. (실제 연결 없음)');
  }

  // 초기화 상태 체크
  bool get isInitialized => _initialized;

  // 연결 상태 체크 (더미)
  Future<bool> checkConnection() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _initialized;
  }
}

// 더미 Supabase 클라이언트
class DummySupabaseClient {
  final auth = DummySupabaseAuth();
  final DummySupabaseDB from;

  DummySupabaseClient() : from = DummySupabaseDB();

  // Supabase 스토리지 더미 구현
  final storage = DummySupabaseStorage();

  // Supabase Functions 더미 구현
  final functions = DummySupabaseFunctions();

  // Supabase Realtime 더미 구현
  final realtime = DummySupabaseRealtime();
}

// 더미 Supabase Auth
class DummySupabaseAuth {
  // 현재 로그인된 사용자 (기본값: null = 로그인 안됨)
  DummyUser? _currentUser;

  // 로그인 상태
  bool get isLoggedIn => _currentUser != null;

  // 현재 사용자 가져오기
  DummyUser? get currentUser => _currentUser;

  // 이메일/비밀번호로 로그인 (더미)
  Future<DummyUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    // 테스트용 기본 계정으로 로그인 성공 가정
    if (email == 'test@example.com' && password == 'password') {
      _currentUser = DummyUser(
        id: 'user-123',
        email: email,
        name: '테스트 사용자',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      return _currentUser!;
    } else {
      throw Exception('잘못된 이메일 또는 비밀번호입니다.');
    }
  }

  // 회원가입 (더미)
  Future<DummyUser> signUp(
    String email,
    String password, {
    String? name,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // 회원가입 성공 가정
    _currentUser = DummyUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name ?? '신규 사용자',
      createdAt: DateTime.now(),
    );

    return _currentUser!;
  }

  // 로그아웃 (더미)
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  /// 비밀번호 재설정 이메일 전송 (더미)
  ///
  /// 사용자가 입력한 이메일로 비밀번호 재설정 링크를 전송하는 것처럼 동작합니다.
  /// 실제로는 이메일을 전송하지 않고 지연 시간만 시뮬레이션합니다.
  ///
  /// [email] 비밀번호를 재설정할 사용자의 이메일 주소
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    print('더미 비밀번호 재설정 이메일 전송 완료: $email');
  }

  // 소셜 로그인 (더미)
  Future<DummyUser> signInWithProvider(String provider) async {
    await Future.delayed(const Duration(seconds: 1));

    _currentUser = DummyUser(
      id: 'user-social-${DateTime.now().millisecondsSinceEpoch}',
      email: 'social@example.com',
      name: '$provider 사용자',
      createdAt: DateTime.now(),
      provider: provider,
    );

    return _currentUser!;
  }
}

// 더미 사용자 모델
class DummyUser {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? provider;

  DummyUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.provider,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'provider': provider,
    };
  }
}

// 더미 Supabase DB
class DummySupabaseDB {
  // 테이블 이름으로 쿼리 빌더 생성
  DummySupabaseQueryBuilder table(String tableName) {
    return DummySupabaseQueryBuilder(tableName);
  }
}

// 더미 쿼리 빌더
class DummySupabaseQueryBuilder {
  final String tableName;
  String? _filterColumn;
  dynamic _filterValue;
  int? _limitValue;
  String? _orderColumn;
  bool _isAscending = true;

  DummySupabaseQueryBuilder(this.tableName);

  // eq (equals) 필터
  DummySupabaseQueryBuilder eq(String column, dynamic value) {
    _filterColumn = column;
    _filterValue = value;
    return this;
  }

  // 결과 개수 제한
  DummySupabaseQueryBuilder limit(int limit) {
    _limitValue = limit;
    return this;
  }

  // 정렬
  DummySupabaseQueryBuilder order(String column, {bool ascending = true}) {
    _orderColumn = column;
    _isAscending = ascending;
    return this;
  }

  // 데이터 가져오기 (더미)
  Future<List<Map<String, dynamic>>> select() async {
    await Future.delayed(const Duration(milliseconds: 800));

    // 테이블에 따라 더미 데이터 반환
    switch (tableName) {
      case 'users':
        return _getDummyUsers();
      case 'coins':
        return _getDummyCoins();
      case 'price_alerts':
        return _getDummyPriceAlerts();
      case 'price_history':
        return _getDummyPriceHistory();
      case 'news':
        return _getDummyNews();
      default:
        return [];
    }
  }

  // 단일 항목 가져오기
  Future<Map<String, dynamic>?> selectOne() async {
    final results = await select();
    return results.isNotEmpty ? results.first : null;
  }

  // 데이터 삽입 (더미)
  Future<Map<String, dynamic>> insert(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 삽입 성공으로 가정하고 ID 추가하여 반환
    return {
      ...data,
      'id': 'dummy-id-${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // 데이터 업데이트 (더미)
  Future<List<Map<String, dynamic>>> update(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 업데이트 성공으로 가정하고 업데이트된 데이터 반환
    return [
      {...data, 'updated_at': DateTime.now().toIso8601String()},
    ];
  }

  // 데이터 삭제 (더미)
  Future<void> delete() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // 삭제 성공으로 가정
  }

  // 더미 사용자 데이터
  List<Map<String, dynamic>> _getDummyUsers() {
    return [
      {
        'id': 'user-1',
        'email': 'user1@example.com',
        'name': '사용자 1',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String(),
      },
      {
        'id': 'user-2',
        'email': 'user2@example.com',
        'name': '사용자 2',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 15))
            .toIso8601String(),
      },
    ];
  }

  // 더미 코인 데이터
  List<Map<String, dynamic>> _getDummyCoins() {
    return [
      {
        'id': 'btc',
        'name': '비트코인',
        'symbol': 'BTC',
        'current_price': 50000.00,
        'price_change_24h': 2.5,
        'market_cap': 950000000000,
        'last_updated': DateTime.now().toIso8601String(),
      },
      {
        'id': 'eth',
        'name': '이더리움',
        'symbol': 'ETH',
        'current_price': 3000.00,
        'price_change_24h': 1.8,
        'market_cap': 350000000000,
        'last_updated': DateTime.now().toIso8601String(),
      },
      {
        'id': 'xrp',
        'name': '리플',
        'symbol': 'XRP',
        'current_price': 0.75,
        'price_change_24h': -0.5,
        'market_cap': 35000000000,
        'last_updated': DateTime.now().toIso8601String(),
      },
      {
        'id': 'ada',
        'name': '에이다',
        'symbol': 'ADA',
        'current_price': 1.20,
        'price_change_24h': 3.2,
        'market_cap': 40000000000,
        'last_updated': DateTime.now().toIso8601String(),
      },
      {
        'id': 'sol',
        'name': '솔라나',
        'symbol': 'SOL',
        'current_price': 100.00,
        'price_change_24h': 5.0,
        'market_cap': 30000000000,
        'last_updated': DateTime.now().toIso8601String(),
      },
    ];
  }

  // 더미 가격 알림 데이터
  List<Map<String, dynamic>> _getDummyPriceAlerts() {
    return [
      {
        'id': 'alert-1',
        'user_id': 'user-1',
        'coin_id': 'btc',
        'price_target': 55000.00,
        'is_above': true,
        'is_triggered': false,
        'created_at': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      },
      {
        'id': 'alert-2',
        'user_id': 'user-1',
        'coin_id': 'eth',
        'price_target': 2800.00,
        'is_above': false,
        'is_triggered': false,
        'created_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
    ];
  }

  // 더미 가격 이력 데이터
  List<Map<String, dynamic>> _getDummyPriceHistory() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> history = [];

    // 24시간 데이터 생성 (1시간 간격)
    for (int i = 24; i >= 0; i--) {
      final time = now.subtract(Duration(hours: i));

      // BTC 데이터
      history.add({
        'id': 'history-btc-$i',
        'coin_id': 'btc',
        'price': 50000.0 + (500 * (24 - i % 12) * (i % 2 == 0 ? 1 : -1)),
        'market_cap': 950000000000 + (i * 1000000000),
        'volume': 30000000000 + (i * 100000000),
        'timestamp': time.toIso8601String(),
      });

      // ETH 데이터
      history.add({
        'id': 'history-eth-$i',
        'coin_id': 'eth',
        'price': 3000.0 + (30 * (24 - i % 12) * (i % 2 == 0 ? 1 : -1)),
        'market_cap': 350000000000 + (i * 500000000),
        'volume': 15000000000 + (i * 50000000),
        'timestamp': time.toIso8601String(),
      });
    }

    return history;
  }

  // 더미 뉴스 데이터
  List<Map<String, dynamic>> _getDummyNews() {
    return [
      {
        'id': 'news-1',
        'title': '비트코인, 사상 최고가 경신 전망',
        'content':
            '전문가들은 비트코인이 올해 안에 사상 최고가를 경신할 것으로 전망하고 있다. 이는 기관 투자자들의 참여 증가와 인플레이션 헷지 수단으로서의 역할 때문이다.',
        'source': '코인뉴스',
        'url': 'https://example.com/news/1',
        'published_at': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'related_coins': ['btc'],
      },
      {
        'id': 'news-2',
        'title': '이더리움 2.0 업그레이드 성공적으로 완료',
        'content':
            '이더리움 네트워크가 성공적으로 2.0 업그레이드를 완료했다. 이로써 에너지 소비량이 99% 감소하고, 초당 거래 처리량이 크게 증가할 전망이다.',
        'source': '크립토 데일리',
        'url': 'https://example.com/news/2',
        'published_at': DateTime.now()
            .subtract(const Duration(hours: 5))
            .toIso8601String(),
        'related_coins': ['eth'],
      },
      {
        'id': 'news-3',
        'title': '리플, SEC와의 소송에서 부분 승리',
        'content':
            '리플이 미국 증권거래위원회(SEC)와의 소송에서 부분적으로 승리했다. 법원은 XRP 자체가 증권이 아니라고 판결했으나, 일부 거래에 대해서는 증권법 위반으로 보았다.',
        'source': '블록체인 투데이',
        'url': 'https://example.com/news/3',
        'published_at': DateTime.now()
            .subtract(const Duration(hours: 10))
            .toIso8601String(),
        'related_coins': ['xrp'],
      },
      {
        'id': 'news-4',
        'title': '솔라나 네트워크, 새로운 기능 출시로 사용자 폭증',
        'content':
            '솔라나 네트워크가 새로운 스마트 컨트랙트 기능을 출시하면서 사용자 수가 급증하고 있다. 이로 인해 솔라나 토큰의 가격도 크게 상승했다.',
        'source': '디센트럴 포스트',
        'url': 'https://example.com/news/4',
        'published_at': DateTime.now()
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
        'related_coins': ['sol'],
      },
      {
        'id': 'news-5',
        'title': '한국 정부, 암호화폐 과세 방안 발표',
        'content':
            '한국 정부가 내년부터 적용될 암호화폐 과세 방안을 발표했다. 연간 250만원 이상의 수익에 대해 20%의 세금이 부과될 예정이다.',
        'source': '코인 저널',
        'url': 'https://example.com/news/5',
        'published_at': DateTime.now()
            .subtract(const Duration(hours: 12))
            .toIso8601String(),
        'related_coins': ['btc', 'eth', 'xrp', 'ada', 'sol'],
      },
    ];
  }
}

// 더미 Supabase 스토리지
class DummySupabaseStorage {
  // 버킷 가져오기 (더미)
  DummyStorageBucket from(String bucketName) {
    return DummyStorageBucket(bucketName);
  }
}

// 더미 스토리지 버킷
class DummyStorageBucket {
  final String bucketName;

  DummyStorageBucket(this.bucketName);

  // 파일 업로드 (더미)
  Future<String> upload(
    String path,
    List<int> fileBytes, {
    String? contentType,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // 성공적으로 업로드됐다고 가정하고 가상의 URL 반환
    return 'https://example.supabase.co/storage/v1/object/public/$bucketName/$path';
  }

  // 파일 다운로드 (더미)
  Future<List<int>> download(String path) async {
    await Future.delayed(const Duration(seconds: 1));

    // 가상의 바이트 배열 반환
    return List.generate(100, (index) => index % 256);
  }

  // 파일 삭제 (더미)
  Future<void> remove(String path) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // 성공적으로 삭제됐다고 가정
  }

  // 파일 목록 (더미)
  Future<List<String>> list({String? prefix}) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // 가상의 파일 목록 반환
    return ['image1.jpg', 'image2.png', 'document.pdf'];
  }
}

// 더미 Supabase Functions
class DummySupabaseFunctions {
  // 함수 호출 (더미)
  Future<Map<String, dynamic>> invoke(
    String functionName, {
    Map<String, dynamic>? payload,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // 함수 이름에 따라 다른 더미 응답 반환
    switch (functionName) {
      case 'check-price-alerts':
        return {
          'success': true,
          'triggered_alerts': 2,
          'timestamp': DateTime.now().toIso8601String(),
        };
      case 'fetch-latest-news':
        return {
          'success': true,
          'news_count': 10,
          'timestamp': DateTime.now().toIso8601String(),
        };
      default:
        return {
          'success': true,
          'message': '함수가 실행되었습니다.',
          'timestamp': DateTime.now().toIso8601String(),
        };
    }
  }
}

// 더미 Supabase Realtime
class DummySupabaseRealtime {
  // 채널 생성 (더미)
  DummyRealtimeChannel channel(String channelName) {
    return DummyRealtimeChannel(channelName);
  }
}

// 더미 Realtime 채널
class DummyRealtimeChannel {
  final String channelName;
  final Map<String, List<Function>> _subscribers = {};

  DummyRealtimeChannel(this.channelName);

  // 이벤트 구독 (더미)
  DummyRealtimeChannel on(String event, Function callback) {
    if (!_subscribers.containsKey(event)) {
      _subscribers[event] = [];
    }
    _subscribers[event]!.add(callback);
    return this;
  }

  // 구독 시작 (더미)
  Future<DummyRealtimeChannel> subscribe() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 가상의 이벤트 발생 시뮬레이션 (3초마다)
    Future.delayed(const Duration(seconds: 3), () {
      _simulateEvent('INSERT');
    });

    return this;
  }

  // 구독 해제 (더미)
  Future<void> unsubscribe() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _subscribers.clear();
  }

  // 이벤트 시뮬레이션
  void _simulateEvent(String eventType) {
    if (_subscribers.containsKey(eventType)) {
      final dummyPayload = {
        'table': channelName.split(':').last,
        'schema': 'public',
        'event': eventType,
        'new': {
          'id': 'dummy-${DateTime.now().millisecondsSinceEpoch}',
          'created_at': DateTime.now().toIso8601String(),
          'data': '더미 데이터',
        },
      };

      for (final callback in _subscribers[eventType]!) {
        callback(dummyPayload);
      }
    }

    // 이벤트 재귀적 시뮬레이션 (구독 중일 때만)
    if (_subscribers.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        _simulateEvent(eventType);
      });
    }
  }
}
