import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayo_delivery_partner/patient/patient_login.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'password login validates credentials and opens the matching patient',
    (tester) async {
      await tester.pumpWidget(const PatientDemoApp());
      await tap(tester, find.text('Password').first);
      await tap(tester, find.text('Login'));
      expect(find.text('This field is required'), findsOneWidget);
      expect(find.text('Enter your password'), findsWidgets);
      await tester.enterText(
        find.byType(TextFormField).first,
        'PRIYA@EXAMPLE.COM',
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tap(tester, find.text('Login'));
      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.byType(PatientDashboard), findsNothing);
      await tap(tester, find.byTooltip('Show password'));
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        false,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Patient@123');
      await tap(tester, find.text('Login'));
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.byType(PatientDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OTP resend and account changes do not reuse stale verification',
    (tester) async {
      await tester.pumpWidget(const PatientDemoApp());
      await tester.enterText(find.byType(TextFormField).first, '8886688856');
      await tap(tester, find.text('Send OTP'));
      expect(find.textContaining('Demo account not found.'), findsOneWidget);
      expect(find.text('Verify & Login'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '9876543210');
      await tap(tester, find.text('Send OTP'));
      await tester.enterText(find.byType(TextFormField).last, '12');
      await tap(tester, find.text('Verify & Login'));
      expect(find.text('Enter 6-digit OTP'), findsOneWidget);
      await tap(tester, find.text('Resend OTP'));
      expect(find.text('Enter 6-digit OTP'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tap(tester, find.text('Mobile OTP'));
      expect(find.text('Verify & Login'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        '123456',
      );
      await tester.enterText(find.byType(TextFormField).first, '9123456780');
      await tester.pumpAndSettle();
      expect(find.text('Verify & Login'), findsNothing);
      await tap(tester, find.text('Send OTP'));
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tap(tester, find.text('Verify & Login'));
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching from email to OTP clears invalid identifier and field errors',
    (tester) async {
      await tester.pumpWidget(const PatientDemoApp());
      await tap(tester, find.text('Password').first);
      await tester.enterText(
        find.byType(TextFormField).first,
        'aarav@example.com',
      );
      await tap(tester, find.text('Login'));
      await tap(tester, find.text('Mobile OTP'));
      expect(find.text('Enter your password'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Send OTP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login fits a small phone with keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 680),
            viewInsets: EdgeInsets.only(bottom: 260),
            textScaler: TextScaler.linear(1.3),
          ),
          child: const PatientLoginPage(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tap(tester, find.text('Send OTP'));
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tap(tester, find.text('Verify & Login'));
    expect(find.byType(PatientDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP demo signs in and signs out on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PatientDemoApp());
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tap(tester, find.text('Send OTP'));
    await tester.enterText(find.byType(TextFormField).last, '000000');
    await tap(tester, find.text('Verify & Login'));
    expect(find.byType(PatientDashboard), findsNothing);
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tap(tester, find.text('Verify & Login'));
    expect(find.byType(PatientDashboard), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Profile').last);
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Sign out'),
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tap(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
    await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
    expect(find.byType(PatientLoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking, rescheduling and cancellation update mock visits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PatientDashboard(patient: mockPatients.first)),
    );
    await tap(tester, find.text('Book appointment'));
    await tap(tester, find.text('09:00 AM'));
    await tester.enterText(find.byType(TextFormField), 'Demo consultation');
    await tap(tester, find.text('Confirm demo booking'));
    expect(find.text('Demo consultation'), findsOneWidget);
    await tap(tester, find.text('Book appointment'));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '09:00 AM'))
          .onSelected,
      isNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Reschedule').first);
    await tap(tester, find.text('09:30 AM'));
    await tap(tester, find.text('Confirm reschedule'));
    expect(find.textContaining('09:30 AM'), findsOneWidget);
    await tap(tester, find.text('Cancel visit').first);
    await tap(tester, find.widgetWithText(FilledButton, 'Cancel visit'));
    await tap(tester, find.text('Cancelled'));
    expect(find.text('Demo consultation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo registration validates and returns to OTP login', (
    tester,
  ) async {
    final initialPatients = [...mockPatients];
    addTearDown(() {
      mockPatients
        ..clear()
        ..addAll(initialPatients);
    });
    await tester.pumpWidget(const PatientDemoApp());
    await tap(tester, find.text('Create Account'));
    await tap(tester, find.text('Create demo account'));
    expect(find.text('Enter your name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Demo Patient');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'new@example.test',
    );
    await tap(tester, find.text('Create demo account'));
    expect(find.text('Mobile already registered'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '9000000001');
    await tap(tester, find.text('Create demo account'));
    expect(find.byType(PatientLoginPage), findsOneWidget);
    await tap(tester, find.text('Send OTP'));
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tap(tester, find.text('Verify & Login'));
    expect(find.byType(PatientDashboard), findsOneWidget);
    expect(find.text('Demo Patient'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records, simulated payments and profile changes work', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PatientDashboard(patient: mockPatients.last)),
    );
    await tap(tester, find.text('Records').last);
    await tap(tester, find.text('Consultation prescription'));
    expect(find.text('Priya Patel'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Reports'));
    await tap(tester, find.text('Laboratory report'));
    expect(find.text('13.5 g/dL'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Profile').last);
    await tap(tester, find.text('Edit demo profile'));
    await tester.enterText(find.byType(TextFormField).first, 'Priya Demo');
    await tap(tester, find.text('Save'));
    expect(find.text('Priya Demo'), findsOneWidget);
    await tap(tester, find.text('Bills & payments'));
    await tap(tester, find.text('Simulate payment'));
    await tap(
      tester,
      find.widgetWithText(FilledButton, 'Simulate payment').last,
    );
    expect(find.text('Paid · Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
