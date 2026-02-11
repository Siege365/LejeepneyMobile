// Basic Flutter widget test for LeJeepney app
//
// This test verifies the app can be built and renders without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lejeepney/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Pump through the timer to avoid pending timer assertion
    await tester.pump(const Duration(seconds: 3));

    // Verify the app started (MaterialApp should be in the tree)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
