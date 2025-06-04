import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 서비스
///
/// 환경 변수에서 Supabase URL과 API 키를 가져와 연결을 설정하고
/// Supabase 인스턴스에 대한 접근을 제공합니다.
class SupabaseClientService {
  // 싱글톤 패턴
  static final SupabaseClientService _instance =
      SupabaseClientService._internal();
  factory SupabaseClientService() => _instance;
  SupabaseClientService._internal();

  // Supabase 인스턴스
  late final SupabaseClient _client;

  // 초기화 여부
  bool _initialized = false;

  // Supabase 클라이언트 인스턴스 getter
  SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
        'SupabaseClientService가 초기화되지 않았습니다. initialize() 메소드를 먼저 호출하세요.',
      );
    }
    return _client;
  }

  /// Supabase 클라이언트 초기화
  ///
  /// .env 파일에서 Supabase URL과 API 키를 로드하여 클라이언트를 초기화합니다.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // .env 파일에서 환경 변수 로드
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      // 환경 변수가 설정되어 있는지 확인
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Supabase 환경 변수가 설정되지 않았습니다. .env 파일을 확인하세요.');
      }

      // Supabase 초기화
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      // 클라이언트 인스턴스 저장
      _client = Supabase.instance.client;
      _initialized = true;

      debugPrint('SupabaseClientService: 초기화 완료');
    } catch (e) {
      debugPrint('SupabaseClientService: 초기화 실패 - $e');
      rethrow;
    }
  }

  /// Supabase 인스턴스 종료
  ///
  /// 앱 종료 시 호출하여 리소스를 정리합니다.
  Future<void> dispose() async {
    if (!_initialized) return;

    try {
      await Supabase.instance.dispose();
      _initialized = false;
      debugPrint('SupabaseClientService: 정상 종료됨');
    } catch (e) {
      debugPrint('SupabaseClientService: 종료 중 오류 발생 - $e');
      rethrow;
    }
  }

  // TODO: Supabase Realtime 기능은 나중에 구현
  // 현재 버전의 Supabase Flutter SDK에서 호환성 문제가 있어 구현 보류

  /*
  /// Supabase Realtime 채널 구독
  /// 
  /// 지정된 테이블의 변경 사항을 실시간으로 구독합니다.
  /// 콜백 함수를 통해 변경 사항을 처리할 수 있습니다.
  /// 
  /// [tableName] 구독할 테이블 이름
  /// [event] 구독할 이벤트 유형 (INSERT, UPDATE, DELETE, *)
  /// [callback] 이벤트 발생 시 호출할 콜백 함수
  RealtimeChannel subscribeToTable(
    String tableName,
    String event,
    Function(Map<String, dynamic>) callback,
  ) {
    if (!_initialized) {
      throw Exception(
        'SupabaseClientService가 초기화되지 않았습니다. initialize() 메소드를 먼저 호출하세요.',
      );
    }

    final channel = _client.channel('public:$tableName');
    
    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: event,
        schema: 'public',
        table: tableName,
      ),
      (payload, [ref]) {
        debugPrint('Realtime 이벤트 수신: $payload');
        callback(payload as Map<String, dynamic>);
      },
    ).subscribe();
    
    return channel;
  }

  /// Supabase Realtime 채널 구독 해제
  /// 
  /// [channel] 구독 해제할 채널
  Future<void> unsubscribeFromChannel(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }

  /// 가격 알림 채널 구독
  /// 
  /// 가격 알림 트리거 이벤트를 구독합니다.
  /// [callback] 알림 트리거 시 호출할 콜백 함수
  RealtimeChannel subscribeToPriceAlerts(
    Function(Map<String, dynamic>) callback,
  ) {
    if (!_initialized) {
      throw Exception(
        'SupabaseClientService가 초기화되지 않았습니다. initialize() 메소드를 먼저 호출하세요.',
      );
    }

    final channel = _client.channel('price_alerts');
    
    channel.on(
      RealtimeListenTypes.broadcast,
      ChannelFilter(event: 'price_alert_triggered'),
      (payload, [ref]) {
        debugPrint('가격 알림 트리거: $payload');
        callback(payload as Map<String, dynamic>);
      },
    ).subscribe();
    
    return channel;
  }
  */
}
