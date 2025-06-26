import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Firebase Realtime Database 서비스 클래스
/// 데이터베이스 연결 및 CRUD 작업을 처리합니다.
class FirebaseDatabaseService {
  late FirebaseDatabase _database;
  bool _isFirebaseAvailable = false;

  FirebaseDatabaseService() {
    _initialize();
  }

  void _initialize() {
    if (!kIsWeb) {
      try {
        _database = FirebaseDatabase.instance;
        _isFirebaseAvailable = true;
        debugPrint(
          'FirebaseDatabaseService: Firebase Realtime Database 초기화 성공',
        );
      } catch (e) {
        debugPrint(
          'FirebaseDatabaseService: Firebase Realtime Database 초기화 실패 - $e',
        );
        _isFirebaseAvailable = false;
      }
    } else {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database를 사용하지 않습니다.',
      );
      _isFirebaseAvailable = false;
    }
  }

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
    // 경로를 '/'로 분리하고 각 세그먼트를 정리한 후 다시 결합
    final segments = path.split('/');
    final sanitizedSegments = segments.map(_sanitizePathSegment).toList();
    final sanitizedPath = sanitizedSegments.join('/');

    debugPrint('FirebaseDatabaseService: 경로 정리: $path -> $sanitizedPath');
    return _database.ref(sanitizedPath);
  }

  /// 데이터 저장
  /// [path] 데이터를 저장할 경로
  /// [data] 저장할 데이터
  /// 성공 시 true 반환
  Future<bool> saveData(String path, Map<String, dynamic> data) async {
    if (!_isFirebaseAvailable) {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database 저장을 지원하지 않습니다.',
      );
      return false;
    }

    try {
      await _safeRef(path).set(data);
      return true;
    } catch (e) {
      debugPrint('데이터 저장 실패: $e');
      return false;
    }
  }

  /// 데이터 업데이트
  /// [path] 업데이트할 데이터 경로
  /// [data] 업데이트할 데이터
  /// 성공 시 true 반환
  Future<bool> updateData(String path, Map<String, dynamic> data) async {
    if (!_isFirebaseAvailable) {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database 업데이트를 지원하지 않습니다.',
      );
      return false;
    }

    try {
      await _safeRef(path).update(data);
      return true;
    } catch (e) {
      debugPrint('데이터 업데이트 실패: $e');
      return false;
    }
  }

  /// 데이터 조회
  /// [path] 조회할 데이터 경로
  /// 데이터가 없으면 null 반환
  Future<Map<String, dynamic>?> getData(String path) async {
    if (!_isFirebaseAvailable) {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database 조회를 지원하지 않습니다.',
      );
      return null;
    }

    try {
      final snapshot = await _safeRef(path).get();
      if (snapshot.exists) {
        return snapshot.value as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('데이터 조회 실패: $e');
      return null;
    }
  }

  /// 데이터 삭제
  /// [path] 삭제할 데이터 경로
  /// 성공 시 true 반환
  Future<bool> deleteData(String path) async {
    if (!_isFirebaseAvailable) {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database 삭제를 지원하지 않습니다.',
      );
      return false;
    }

    try {
      await _safeRef(path).remove();
      return true;
    } catch (e) {
      debugPrint('데이터 삭제 실패: $e');
      return false;
    }
  }

  /// 실시간 데이터 리스닝
  /// [path] 리스닝할 데이터 경로
  /// [onData] 데이터 변경 시 호출될 콜백
  Stream<DatabaseEvent> listenToData(String path) {
    if (!_isFirebaseAvailable) {
      debugPrint(
        'FirebaseDatabaseService: 웹 플랫폼에서는 Firebase Realtime Database 리스닝을 지원하지 않습니다.',
      );
      // 빈 스트림 반환
      return Stream.empty();
    }

    return _safeRef(path).onValue;
  }
}
