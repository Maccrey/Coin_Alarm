// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_alarm/services/supabase_service.dart';
import 'package:coin_alarm/services/settings_service.dart';
import 'package:coin_alarm/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 서비스 초기화
    final supabaseService = SupabaseService();
    await supabaseService.initialize();

    final settingsService = SettingsService();
    await settingsService.initialize();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(supabaseService: supabaseService, settingsService: settingsService),
    );

    // TODO: 실제 앱 흐름에 맞는 테스트 코드 작성
    // 현재는 기본 템플릿의 카운터 테스트가 남아있으므로 실제 앱에 맞게 수정 필요

    /*
    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    */
  });
}
