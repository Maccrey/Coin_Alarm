import 'package:flutter_test/flutter_test.dart';
import 'package:coin_alarm/services/notification_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:mockito/mockito.dart';

class MockAwesomeNotifications extends Mock implements AwesomeNotifications {}

void main() {
  test(
    'showNotification calls AwesomeNotifications.createNotification',
    () async {
      final mock = MockAwesomeNotifications();
      AwesomeNotifications().setMockInstance(mock);
      final service = NotificationService();
      await service.initialize();
      when(
        mock.createNotification(content: anyNamed('content')),
      ).thenAnswer((_) async => true);
      final result = await service.showNotification(
        id: 1,
        title: 'Test',
        body: 'Body',
      );
      expect(result, true);
      verify(mock.createNotification(content: anyNamed('content'))).called(1);
    },
  );
}
