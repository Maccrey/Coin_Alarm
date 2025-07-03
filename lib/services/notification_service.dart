import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  // 알림 채널 키 상수
  static const String mainChannelKey = 'coin_alarm_channel';
  static const String scheduleChannelKey = 'coin_alarm_schedule_channel';
  static const String debugChannelKey = 'coin_alarm_debug_channel';
  static const String channelGroupKey = 'coin_alarm_group';

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    // 이미 초기화된 경우 중복 초기화 방지
    if (_isInitialized) {
      debugPrint('NotificationService: 이미 초기화되었습니다.');
      return;
    }

    tz.initializeTimeZones();

    // 웹 환경에서는 알림을 초기화하지 않음
    if (kIsWeb) {
      debugPrint('웹 환경에서는 알림 기능을 사용할 수 없습니다.');
      return;
    }

    try {
      // 알림 채널 설정
      final result = await AwesomeNotifications().initialize(
        null, // 앱 아이콘 (null이면 앱 아이콘 사용)
        [
          NotificationChannel(
            channelKey: mainChannelKey,
            channelName: 'Coin Alarm',
            channelDescription: '코인 가격 알림',
            defaultColor: Colors.blue,
            ledColor: Colors.blue,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            vibrationPattern: highVibrationPattern,
            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
            enableVibration: true,
            soundSource: null, // 기본 시스템 알림음 사용
          ),
          NotificationChannel(
            channelKey: scheduleChannelKey,
            channelName: 'Scheduled Coin Alarm',
            channelDescription: '예약된 코인 가격 알림',
            defaultColor: Colors.green,
            ledColor: Colors.green,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            vibrationPattern: highVibrationPattern,
            playSound: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
            enableVibration: true,
            soundSource: null, // 기본 시스템 알림음 사용
          ),
          NotificationChannel(
            channelKey: debugChannelKey,
            channelName: 'Debug Notifications',
            channelDescription: '디버그 정보 알림 (개발용)',
            defaultColor: Colors.grey,
            ledColor: Colors.grey,
            importance: NotificationImportance.Low,
            channelShowBadge: false,
            playSound: false,
            enableVibration: false,
          ),
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: channelGroupKey,
            channelGroupName: 'Coin Alarm Group',
          ),
        ],
        debug: kDebugMode, // 디버그 모드에서만 디버그 활성화
      );

      if (result) {
        debugPrint('NotificationService: 알림 채널 초기화 성공');
      } else {
        debugPrint('NotificationService: 알림 채널 초기화 실패');
      }

      // 채널이 제대로 등록되었는지 확인
      try {
        // 알림 권한 요청
        await _requestPermissions();
        debugPrint('NotificationService: 알림 서비스 초기화 완료');

        _isInitialized = true;
      } catch (e) {
        debugPrint('NotificationService: 알림 서비스 초기화 오류: $e');
        // 오류가 발생해도 앱 실행은 계속
      }
    } catch (e) {
      debugPrint('NotificationService: 알림 서비스 초기화 오류: $e');
      // 오류가 발생해도 앱 실행은 계속
    }
  }

  /// 알림 서비스 초기화 여부 확인
  bool get isInitialized => _isInitialized;

  /// 알림 권한 요청
  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;

    try {
      return await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    } catch (e) {
      debugPrint('알림 권한 요청 오류: $e');
      return false;
    }
  }

  /// 즉시 알림 표시
  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('웹 환경에서는 알림을 표시할 수 없습니다.');
      return false;
    }

    try {
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: mainChannelKey,
          title: title,
          body: body,
          payload: payload != null ? {'data': payload} : null,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
        ),
      );
    } catch (e) {
      debugPrint('알림 표시 오류: $e');
      return false;
    }
  }

  /// 예약 알림 설정
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('웹 환경에서는 알림을 예약할 수 없습니다.');
      return false;
    }

    try {
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: scheduleChannelKey,
          title: title,
          body: body,
          payload: payload != null ? {'data': payload} : null,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
        ),
        schedule: NotificationCalendar.fromDate(date: scheduledDate),
      );
    } catch (e) {
      debugPrint('알림 예약 오류: $e');
      return false;
    }
  }

  /// 디버그 알림 표시 (개발 중에만 사용)
  Future<bool> showDebugNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!kDebugMode || kIsWeb) {
      return false;
    }

    try {
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: debugChannelKey,
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Service,
        ),
      );
    } catch (e) {
      debugPrint('디버그 알림 표시 오류: $e');
      return false;
    }
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;

    try {
      await AwesomeNotifications().cancelAll();
    } catch (e) {
      debugPrint('모든 알림 취소 오류: $e');
    }
  }

  /// 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;

    try {
      await AwesomeNotifications().cancel(id);
    } catch (e) {
      debugPrint('알림 취소 오류: $e');
    }
  }

  /// 알림 탭 이벤트 리스너 설정
  Future<void> setListeners({
    required Future<void> Function(ReceivedAction) onActionReceivedMethod,
  }) async {
    if (kIsWeb) return;

    try {
      // 알림 탭 이벤트 리스너
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
      );
      debugPrint('알림 리스너 설정 완료');
    } catch (e) {
      debugPrint('알림 리스너 설정 오류: $e');
      // 오류가 발생해도 앱 실행은 계속
    }
  }

  /// 알림 권한 상태 확인
  Future<bool> isNotificationAllowed() async {
    if (kIsWeb) return false;

    try {
      return await AwesomeNotifications().isNotificationAllowed();
    } catch (e) {
      debugPrint('알림 권한 상태 확인 오류: $e');
      return false;
    }
  }

  /// 알림 권한 요청 (사용자에게 권한 요청 이유 표시)
  static Future<List<NotificationPermission>> requestUserPermissions(
    BuildContext context, {
    required List<NotificationPermission> permissionList,
  }) async {
    if (kIsWeb) return [];

    try {
      // 기본 권한 확인
      if (!await AwesomeNotifications().isNotificationAllowed()) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      // 요청된 권한 중 이미 허용된 권한 확인
      List<NotificationPermission> permissionsAllowed =
          await AwesomeNotifications().checkPermissionList(
            permissions: permissionList,
          );

      // 모든 권한이 허용되었으면 반환
      if (permissionsAllowed.length == permissionList.length) {
        return permissionsAllowed;
      }

      // 허용되지 않은 권한만 추출
      List<NotificationPermission> permissionsNeeded = permissionList
          .toSet()
          .difference(permissionsAllowed.toSet())
          .toList();

      // 사용자 개입이 필요한 권한 확인
      List<NotificationPermission> lockedPermissions =
          await AwesomeNotifications().shouldShowRationaleToRequest(
            permissions: permissionsNeeded,
          );

      // 사용자 개입이 필요 없으면 바로 요청
      if (lockedPermissions.isEmpty) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          permissions: permissionsNeeded,
        );

        // 권한 요청 후 허용된 권한 확인
        permissionsAllowed = await AwesomeNotifications().checkPermissionList(
          permissions: permissionsNeeded,
        );
      } else {
        // 권한 요청 이유 표시
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xfffbfbfb),
            title: const Text(
              '알림 권한이 필요합니다',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '앱이 제대로 작동하려면 다음 권한이 필요합니다:',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  lockedPermissions
                      .join(', ')
                      .replaceAll('NotificationPermission.', ''),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  '거부',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // 권한 요청
                  await AwesomeNotifications()
                      .requestPermissionToSendNotifications(
                        permissions: lockedPermissions,
                      );

                  // 권한 요청 후 허용된 권한 확인
                  permissionsAllowed = await AwesomeNotifications()
                      .checkPermissionList(permissions: lockedPermissions);

                  Navigator.pop(context);
                },
                child: const Text(
                  '허용',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // 업데이트된 허용 권한 목록 반환
      return permissionsAllowed;
    } catch (e) {
      debugPrint('알림 권한 요청 중 오류 발생: $e');
      return [];
    }
  }
}
