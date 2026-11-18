import 'package:flutter_test/flutter_test.dart';
import 'package:mayo_delivery_partner/appointment_response_diagnostics.dart';

void main() {
  test('describes nested appointment fields without printing values', () {
    final lines = describeAppointmentResponse({
      'success': true,
      'data': {
        'items': [
          {
            'patient_name': 'PRIVATE PATIENT',
            'token': 'PRIVATE TOKEN',
            'patient': {'full_name': 'PRIVATE NAME'},
          },
        ],
      },
    });
    final output = lines.join('\n');
    expect(output, contains('response.data.items: list; count=1'));
    expect(output, contains('patient_name: string'));
    expect(output, contains('patient: object; keys=full_name'));
    expect(output, isNot(contains('PRIVATE')));
  });

  test('redacts dynamic keys and limits traversal', () {
    final output = describeAppointmentResponse({
      'patient@example.com': 'secret',
      'items': List.generate(1000, (_) => {'name': 'secret'}),
    }).join('\n');
    expect(output, contains('<redacted-key>'));
    expect(output, contains('count=1000'));
    expect(output, isNot(contains('patient@example.com')));
    expect(output, isNot(contains('secret')));
    expect(output.split('name: string').length - 1, 1);
  });

  test('handles empty lists and null without claiming rows exist', () {
    expect(describeAppointmentResponse([]), ['response: list; count=0']);
    expect(describeAppointmentResponse(null), ['response: null']);
  });
}
