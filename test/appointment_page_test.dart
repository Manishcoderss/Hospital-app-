import 'package:flutter_test/flutter_test.dart';
import 'package:mayo_delivery_partner/appointment_page.dart';

Map<String, dynamic> envelope({
  List<Object?> items = const [],
  int total = 0,
  bool hasNext = false,
}) => {
  'success': true,
  'data': {
    'items': items,
    'meta': {'total_items': total, 'has_next': hasNext},
  },
};

void main() {
  test('confirmed empty envelope produces empty page', () {
    final page = AppointmentPage.fromJson(envelope());
    expect(page.isEmpty, isTrue);
    expect(page.totalItems, 0);
  });

  test('empty page with more results is not an empty schedule', () {
    expect(
      AppointmentPage.fromJson(envelope(total: 2, hasNext: true)).isEmpty,
      isFalse,
    );
  });

  test('parses confirmed appointment fields and pagination', () {
    final page = AppointmentPage.fromJson(
      envelope(
        items: [
          {
            'id': 'example',
            'appointment_date': '2026-10-16',
            'appointment_time': '11:30',
            'status': 'confirmed',
            'doctor_id': 'doctor-example',
            'patient': {'full_name': 'Example Patient'},
            'doctor': {
              'name': 'Example Doctor',
              'department_name': 'General Medicine',
            },
            'token_number': 1,
          },
        ],
        total: 3,
        hasNext: true,
      ),
    );
    expect(page.items.single.id, 'example');
    expect(page.items.single.patientName, 'Example Patient');
    expect(page.items.single.department, 'General Medicine');
    expect(page.items.single.tokenNumber, 1);
    expect(page.totalItems, 3);
    expect(page.hasNext, isTrue);
    expect(page.isEmpty, isFalse);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('malformed responses cannot silently become an empty schedule', () {
    for (final response in [
      null,
      {'success': false},
      {'success': true, 'data': []},
      {
        'success': true,
        'data': {'items': []},
      },
      envelope(items: ['invalid'], total: 1),
      envelope(total: -1),
      envelope(
        items: [
          {'id': 'example'},
        ],
      ),
    ]) {
      expect(() => AppointmentPage.fromJson(response), throwsFormatException);
    }
  });
}
