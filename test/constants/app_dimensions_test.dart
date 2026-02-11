// Unit tests for AppDimensions
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lejeepney/constants/app_dimensions.dart';

void main() {
  group('AppDimensions', () {
    group('padding values', () {
      test('paddingXSmall is smallest', () {
        expect(
          AppDimensions.paddingXSmall,
          lessThan(AppDimensions.paddingSmall),
        );
      });

      test('paddingSmall is less than paddingMedium', () {
        expect(
          AppDimensions.paddingSmall,
          lessThan(AppDimensions.paddingMedium),
        );
      });

      test('paddingMedium is less than paddingLarge', () {
        expect(
          AppDimensions.paddingMedium,
          lessThan(AppDimensions.paddingLarge),
        );
      });

      test('paddingLarge is less than paddingXLarge', () {
        expect(
          AppDimensions.paddingLarge,
          lessThan(AppDimensions.paddingXLarge),
        );
      });
    });

    group('radius values', () {
      test('radiusSmall is less than radiusMedium', () {
        expect(AppDimensions.radiusSmall, lessThan(AppDimensions.radiusMedium));
      });

      test('radiusMedium is less than radiusLarge', () {
        expect(AppDimensions.radiusMedium, lessThan(AppDimensions.radiusLarge));
      });

      test('radiusXLarge is less than radiusRound', () {
        expect(AppDimensions.radiusXLarge, lessThan(AppDimensions.radiusRound));
      });
    });

    group('icon sizes', () {
      test('iconSmall is smallest', () {
        expect(AppDimensions.iconSmall, lessThan(AppDimensions.iconMedium));
      });

      test('iconMedium is less than iconLarge', () {
        expect(AppDimensions.iconMedium, lessThan(AppDimensions.iconLarge));
      });
    });

    group('button dimensions', () {
      test('buttonHeightSmall is smallest', () {
        expect(
          AppDimensions.buttonHeightSmall,
          lessThan(AppDimensions.buttonHeight),
        );
      });

      test('buttonHeight is less than buttonHeightLarge', () {
        expect(
          AppDimensions.buttonHeight,
          lessThan(AppDimensions.buttonHeightLarge),
        );
      });
    });
  });

  group('AppPadding', () {
    test('allSmall returns EdgeInsets with paddingSmall', () {
      expect(
        AppPadding.allSmall,
        equals(const EdgeInsets.all(AppDimensions.paddingSmall)),
      );
    });

    test('allMedium returns EdgeInsets with paddingMedium', () {
      expect(
        AppPadding.allMedium,
        equals(const EdgeInsets.all(AppDimensions.paddingMedium)),
      );
    });

    test('allLarge returns EdgeInsets with paddingLarge', () {
      expect(
        AppPadding.allLarge,
        equals(const EdgeInsets.all(AppDimensions.paddingLarge)),
      );
    });

    test('horizontalSmall returns horizontal EdgeInsets', () {
      expect(
        AppPadding.horizontalSmall,
        equals(
          const EdgeInsets.symmetric(horizontal: AppDimensions.paddingSmall),
        ),
      );
    });

    test('verticalSmall returns vertical EdgeInsets', () {
      expect(
        AppPadding.verticalSmall,
        equals(
          const EdgeInsets.symmetric(vertical: AppDimensions.paddingSmall),
        ),
      );
    });
  });

  group('AppSpacing', () {
    testWidgets('hSmall creates SizedBox with paddingSmall width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Row(children: [AppSpacing.hSmall])),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, equals(AppDimensions.paddingSmall));
    });

    testWidgets('vMedium creates vertical SizedBox', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Column(children: [AppSpacing.vMedium])),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, equals(AppDimensions.paddingMedium));
    });

    testWidgets('hMedium creates horizontal SizedBox', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Row(children: [AppSpacing.hMedium])),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, equals(AppDimensions.paddingMedium));
    });
  });

  group('AppBorderRadius', () {
    test('small returns BorderRadius with radiusSmall', () {
      expect(
        AppBorderRadius.small,
        equals(BorderRadius.circular(AppDimensions.radiusSmall)),
      );
    });

    test('medium returns BorderRadius with radiusMedium', () {
      expect(
        AppBorderRadius.medium,
        equals(BorderRadius.circular(AppDimensions.radiusMedium)),
      );
    });

    test('large returns BorderRadius with radiusLarge', () {
      expect(
        AppBorderRadius.large,
        equals(BorderRadius.circular(AppDimensions.radiusLarge)),
      );
    });

    test('round returns BorderRadius with radiusRound', () {
      expect(
        AppBorderRadius.round,
        equals(BorderRadius.circular(AppDimensions.radiusRound)),
      );
    });

    test('topMedium returns top-only BorderRadius', () {
      expect(
        AppBorderRadius.topMedium,
        equals(
          const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusMedium),
          ),
        ),
      );
    });

    test('topLarge returns top-only BorderRadius with radiusLarge', () {
      expect(
        AppBorderRadius.topLarge,
        equals(
          const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLarge),
          ),
        ),
      );
    });
  });
}
