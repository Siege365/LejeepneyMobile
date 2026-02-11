// Widget tests for common widgets
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lejeepney/widgets/common/common_widgets.dart';

void main() {
  group('AppButton', () {
    testWidgets('displays text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(text: 'Test Button', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppButton(text: 'Loading', isLoading: true)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('displays icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'With Icon',
              icon: Icons.check,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(text: 'Tap Me', onPressed: () => pressed = true),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      expect(pressed, isTrue);
    });

    testWidgets('is disabled when onPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppButton(text: 'Disabled', onPressed: null)),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppTextField', () {
    testWidgets('displays hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(hintText: 'Enter text')),
        ),
      );

      expect(find.text('Enter text'), findsOneWidget);
    });

    testWidgets('displays label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(labelText: 'Label')),
        ),
      );

      expect(find.text('Label'), findsOneWidget);
    });

    testWidgets('displays prefix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(prefixIcon: Icon(Icons.search))),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('obscures text when obscureText is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(obscureText: true)),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('uses provided controller', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Initial');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppTextField(controller: controller)),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      controller.dispose();
    });
  });

  group('AppLoadingIndicator', () {
    testWidgets('displays CircularProgressIndicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoadingIndicator())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoadingIndicator(message: 'Loading...')),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });
  });

  group('AppErrorState', () {
    testWidgets('displays error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppErrorState(message: 'Error occurred')),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppErrorState(message: 'Something went wrong')),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(message: 'Error', onRetry: () {}),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is tapped', (
      WidgetTester tester,
    ) async {
      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              message: 'Error',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });
  });

  group('AppEmptyState', () {
    testWidgets('displays empty icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmptyState(message: 'No items')),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('displays message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmptyState(message: 'No data available')),
        ),
      );

      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('displays custom icon when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(message: 'No items', icon: Icons.search_off),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });
  });

  group('AppSectionHeader', () {
    testWidgets('displays title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppSectionHeader(title: 'Section Title')),
        ),
      );

      expect(find.text('Section Title'), findsOneWidget);
    });

    testWidgets('displays action when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSectionHeader(
              title: 'Section',
              actionText: 'View All',
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('View All'), findsOneWidget);
    });
  });

  group('BottomSheetHandle', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BottomSheetHandle())),
      );

      // Should find Container widget (the handle)
      expect(find.byType(Container), findsWidgets);
    });
  });
}
