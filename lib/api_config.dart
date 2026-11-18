class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'HOSPITAL_API_URL',
    defaultValue: 'https://samagati.migarch.in/api/v1',
  );
}
