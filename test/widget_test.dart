// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcs_front/main.dart';

void main() {
  testWidgets('Motor Control System UI renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MotorApp());

    // Verify that the app bar title is present
    expect(find.text('Motor Control System'), findsOneWidget);

    // Verify that the loading indicator or content is shown
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

