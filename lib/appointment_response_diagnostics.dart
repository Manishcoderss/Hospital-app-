/// Describes JSON structure without retaining or printing patient values.
/// Inspect only the first list item, with bounded depth and output size.
List<String> describeAppointmentResponse(Object? response) {
  final lines = <String>[];

  void visit(Object? value, String path, int depth) {
    if (lines.length >= 60) return;
    if (value is Map) {
      // API field names are expected to be identifiers. Redact dynamic keys.
      String safeKey(Object? key) {
        final text = key.toString();
        return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]{0,63}$').hasMatch(text)
            ? text
            : '<redacted-key>';
      }

      lines.add('$path: object; keys=${value.keys.map(safeKey).join(", ")}');
      if (depth >= 4) return;
      for (final entry in value.entries.take(20)) {
        visit(entry.value, '$path.${safeKey(entry.key)}', depth + 1);
      }
    } else if (value is List) {
      lines.add('$path: list; count=${value.length}');
      if (value.isNotEmpty && depth < 4) {
        visit(value.first, '$path[]', depth + 1);
      }
    } else {
      final type = switch (value) {
        null => 'null',
        bool() => 'bool',
        num() => 'number',
        String() => 'string',
        _ => 'unknown',
      };
      lines.add('$path: $type');
    }
  }

  visit(response, 'response', 0);
  return lines;
}
