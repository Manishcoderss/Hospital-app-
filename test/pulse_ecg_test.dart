import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayo_delivery_partner/pulse_ecg.dart';

void main() {
  testWidgets('ECG keeps moving and releases its ticker when removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PulseEcg())),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(
      find.bySemanticsLabel('Decorative ECG animation, not live patient data'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ECG respects reduced motion and inactive tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PulseEcg()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(enabled: false, child: Scaffold(body: PulseEcg())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
