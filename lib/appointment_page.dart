import 'appointment.dart';

/// The confirmed paginated appointments envelope.
class AppointmentPage {
  const AppointmentPage({
    required this.items,
    required this.totalItems,
    required this.hasNext,
  });

  final List<Appointment> items;
  final int totalItems;
  final bool hasNext;

  bool get isEmpty => items.isEmpty && totalItems == 0 && !hasNext;

  factory AppointmentPage.fromJson(Object? response) {
    const invalid = FormatException('Invalid appointments page');
    if (response is! Map<String, dynamic> || response['success'] != true) {
      throw invalid;
    }
    final data = response['data'];
    if (data is! Map<String, dynamic>) throw invalid;
    final rows = data['items'];
    final meta = data['meta'];
    if (rows is! List || meta is! Map<String, dynamic>) throw invalid;
    final total = meta['total_items'];
    final hasNext = meta['has_next'];
    if (total is! int || total < 0 || hasNext is! bool || total < rows.length) {
      throw invalid;
    }
    final items = <Appointment>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) throw invalid;
      items.add(Appointment.fromJson(row));
    }
    return AppointmentPage(
      items: List.unmodifiable(items),
      totalItems: total,
      hasNext: hasNext,
    );
  }
}
