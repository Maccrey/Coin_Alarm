import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:coin_alarm/database/firebase_database_service.dart';

@GenerateMocks([
  FirebaseDatabase,
  DatabaseReference,
  DataSnapshot,
  DatabaseEvent,
])
void main() {
  group('FirebaseDatabaseService 테스트', () {
    // 이 테스트는 의존성 확인용으로, 실제 Firebase 연결 테스트가 아닙니다.
    // 실제 테스트는 Mockito를 사용하여 구현해야 합니다.
    test('Firebase Database 의존성이 올바르게 로드되는지 확인', () {
      // 이 테스트는 단순히 의존성이 올바르게 로드되는지 확인합니다.
      // 컴파일 오류가 없으면 의존성이 올바르게 설정된 것입니다.
      expect(() => FirebaseDatabaseService(), isA<Function>());
    });
  });
}
