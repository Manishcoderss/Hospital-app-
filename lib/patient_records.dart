class PatientRecordPage {
  const PatientRecordPage(this.items, this.total, this.hasNext);
  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasNext;

  factory PatientRecordPage.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    final rows = value['items'];
    final meta = value['meta'];
    if (rows is! List ||
        meta is! Map ||
        meta['total_items'] is! int ||
        meta['has_next'] is! bool) {
      throw const FormatException();
    }
    final items = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! String ||
          (row['id'] as String).isEmpty) {
        throw const FormatException();
      }
      items.add(Map.unmodifiable(row));
    }
    final total = meta['total_items'] as int;
    if (total < items.length) throw const FormatException();
    return PatientRecordPage(
      List.unmodifiable(items),
      total,
      meta['has_next'] as bool,
    );
  }
}

String? recordText(Map value, String key) {
  final item = value[key];
  return item is String && item.trim().isNotEmpty
      ? item.trim()
      : item is num
      ? item.toString()
      : null;
}

List<Map<String, dynamic>> recordList(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
    throw const FormatException();
  }
  return value.cast<Map<String, dynamic>>();
}
