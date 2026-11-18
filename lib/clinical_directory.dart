enum ClinicalDirectory { patients, prescriptions, labs, ipd, pharmacy }

extension ClinicalDirectoryLabel on ClinicalDirectory {
  String get title => switch (this) {
    ClinicalDirectory.patients => 'Patients',
    ClinicalDirectory.prescriptions => 'Prescriptions',
    ClinicalDirectory.labs => 'Lab Reports',
    ClinicalDirectory.ipd => 'IPD Patients',
    ClinicalDirectory.pharmacy => 'Pharmacy',
  };
}
