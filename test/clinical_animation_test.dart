import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayo_delivery_partner/clinical_home_page.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('clinical helix respects reduced motion: $reducedMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(body: ClinicalHomePage(onDirectory: (_) {})),
          ),
        ),
      );
      final graphic = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere(
            (widget) =>
                widget.painter.runtimeType.toString() ==
                '_ClinicalConnectionsPainter',
          );
      var repaints = 0;
      void onRepaint() => repaints++;
      graphic.painter!.addListener(onRepaint);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(repaints, reducedMotion ? 0 : greaterThan(0));
      graphic.painter!.removeListener(onRepaint);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
