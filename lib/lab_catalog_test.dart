class LabCatalogTest {
  const LabCatalogTest({required this.id, required this.name, this.sampleType});
  final String id, name;
  final String? sampleType;
  factory LabCatalogTest.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty) {
      throw const FormatException('Invalid lab catalog entry');
    }
    return LabCatalogTest(
      id: json['id'] as String,
      name: (json['name'] as String).trim(),
      sampleType: json['sample_type'] is String
          ? json['sample_type'] as String
          : null,
    );
  }
}
