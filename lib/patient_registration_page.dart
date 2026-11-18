import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'prescription_draft.dart';

class PatientRegistrationPage extends StatefulWidget {
  const PatientRegistrationPage({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<PatientRegistrationPage> createState() =>
      _PatientRegistrationPageState();
}

class _PatientRegistrationPageState extends State<PatientRegistrationPage> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'first_name',
      'last_name',
      'age',
      'phone',
      'email',
      'address',
      'city',
      'state',
      'zip_code',
      'country',
      'id_proof_number',
      'emergency_contact_name',
      'emergency_contact_phone',
      'emergency_contact_relation',
      'insurance_number',
      'insurance_provider_other',
      'insurance_tpa',
      'referral_details',
      'allergies',
      'medical_history',
    ])
      key: TextEditingController(),
  };
  Map<String, dynamic>? lookups;
  String? gender, blood, proof, cover, provider, referral, error;
  DateTime? dob;
  bool loading = true,
      busy = false,
      uncertain = false,
      ageOnly = true,
      dirty = false;
  bool get locked => busy || uncertain;

  // Explicit opt-in QA control: fills an unsaved draft only. Never sends a request.
  void fillQaDraft() {
    if (locked || lookups == null) return;
    String? choice(String key, String label) {
      for (final item in options(key)) {
        if ('${item['label']}'.toLowerCase() == label ||
            '${item['value']}'.toLowerCase() == label) {
          return item['value'] as String;
        }
      }
      return null;
    }

    setState(() {
      for (final controller in fields.values) {
        controller.clear();
      }
      for (final entry in const {
        'first_name': 'QA',
        'last_name': 'Doctor Test',
        'age': '30',
        'phone': '9999999999',
        'address': 'QA TEST ONLY - NOT A REAL ADDRESS',
        'city': 'QA Test City',
        'id_proof_number': 'Q0000000',
        'emergency_contact_name': 'QA Contact',
        'emergency_contact_phone': '9999999998',
        'emergency_contact_relation': 'QA Test Contact',
      }.entries) {
        fields[entry.key]!.text = entry.value;
      }
      gender = choice('genders', 'male');
      proof = choice('id_proof_types', 'passport');
      blood = cover = provider = referral = null;
      ageOnly = true;
      dob = null;
      dirty = true;
      error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.service.fetchPatientLookups(widget.session);
      Map<String, dynamic> defaults = {};
      try {
        defaults = await widget.service.fetchPatientDefaults(widget.session);
      } catch (_) {}
      if (mounted) {
        setState(() {
          lookups = result;
          for (final key in ['city', 'state', 'country']) {
            if (fields[key]!.text.isEmpty && defaults[key] is String) {
              fields[key]!.text = defaults[key] as String;
            }
          }
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to load registration options. Please retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> options(String key) {
    final data = lookups?[key];
    return data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .where((r) => r['value'] is String)
              .toList()
        : [];
  }

  Widget input(
    String key,
    String label, {
    bool required = false,
    bool multiline = false,
    bool phone = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: fields[key],
      enabled: !locked,
      maxLines: multiline ? 3 : 1,
      keyboardType: phone
          ? TextInputType.phone
          : number
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(labelText: '$label${required ? ' *' : ''}'),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Enter $label';
        if (phone &&
            text.isNotEmpty &&
            !RegExp(r'^(?:\+91[ -]?)?[6-9]\d{9}$').hasMatch(text)) {
          return 'Enter a valid 10-digit mobile';
        }
        if (key == 'age' &&
            ageOnly &&
            (int.tryParse(text) == null ||
                int.parse(text) < 0 ||
                int.parse(text) > 130)) {
          return 'Enter age from 0 to 130';
        }
        if (key == 'email' &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Enter a valid email';
        }
        return null;
      },
    ),
  );
  Widget dropdown(
    String key,
    String label,
    String? value,
    ValueChanged<String?> change, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: '$label${required ? ' *' : ''}'),
      items: options(key)
          .map(
            (r) => DropdownMenuItem(
              value: r['value'] as String,
              child: Text(
                (r['label'] ?? r['value']).toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      validator: (v) =>
          required && (v == null || v.isEmpty) ? 'Choose $label' : null,
      onChanged: locked
          ? null
          : (value) => setState(() {
              change(value);
              dirty = true;
            }),
    ),
  );
  Widget section(String title, List<Widget> children) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE1E6DC)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF20312D),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  Future<void> save() async {
    if (locked ||
        lookups == null ||
        !(form.currentState?.validate() ?? false)) {
      return;
    }
    for (final entry in const {
      'first_name': 'First name',
      'phone': 'Mobile number',
      'address': 'Address',
      'id_proof_number': 'ID proof number',
      'emergency_contact_name': 'Emergency contact name',
      'emergency_contact_phone': 'Emergency contact mobile',
      'emergency_contact_relation': 'Relation',
    }.entries) {
      if (fields[entry.key]!.text.trim().isEmpty) {
        setState(() {
          error = 'Enter ${entry.value}.';
        });
        return;
      }
    }
    if (proof == null ||
        (ageOnly &&
            (int.tryParse(fields['age']!.text.trim()) == null ||
                int.parse(fields['age']!.text.trim()) < 0 ||
                int.parse(fields['age']!.text.trim()) > 130))) {
      setState(() {
        error = 'Choose an ID proof type and enter a valid age from 0 to 130.';
      });
      return;
    }
    for (final key in ['phone', 'emergency_contact_phone']) {
      if (!RegExp(r'^(?:\+91[ -]?)?[6-9]\d{9}$')
          .hasMatch(fields[key]!.text.trim())) {
        setState(() {
          error = 'Enter valid 10-digit mobile numbers.';
        });
        return;
      }
    }
    if (!ageOnly && dob == null) {
      setState(() {
        error = 'Choose a date of birth.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = <String, dynamic>{
        for (final entry in fields.entries)
          if (entry.key != 'age' && entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
        if (ageOnly) 'age': int.parse(fields['age']!.text.trim()),
        if (!ageOnly)
          'date_of_birth':
              '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
        if (gender != null) 'gender': gender,
        if (blood != null) 'blood_group': blood,
        'id_proof_type': proof,
        if (cover != null) 'insurance_category': cover,
        if (provider != null) 'insurance_provider': provider,
        if (referral != null) 'referral_source': referral,
      };
      final patient = await widget.service.registerPatient(
        widget.session,
        values,
      );
      if (mounted) {
        setState(() {
          dirty = false;
          busy = false;
        });
        Navigator.pop(context, patient.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          uncertain = e is DraftSaveException && e.uncertain;
          error = e is DraftSaveException
              ? e.message
              : 'Unable to register patient. Please review the form.';
        });
      }
    }
  }

  Future<void> leave() async {
    if (busy) return;
    final discard =
        !dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard registration changes?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ==
            true;
    if (mounted && discard) {
      setState(() {
        dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: const Color(0xFF207361), surface: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF207361), width: 1.5),
        ),
      ),
    ),
    child: PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EA),
          foregroundColor: const Color(0xFF207361),
          surfaceTintColor: Colors.transparent,
          title: const Text('Register patient'),
          actions: [
            if (kDebugMode && const bool.fromEnvironment('DOCTOR_LIVE_QA'))
              IconButton(
                tooltip: 'Fill unsaved QA dummy details',
                onPressed: locked || lookups == null ? null : fillQaDraft,
                icon: const Icon(Icons.science_outlined),
              ),
          ],
          leading: IconButton(
            onPressed: busy ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : lookups == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error ?? 'Registration unavailable'),
                    TextButton(onPressed: load, child: const Text('Retry')),
                  ],
                ),
              )
            : Form(
                key: form,
                onChanged: () {
                  if (!dirty) {
                    setState(() {
                      dirty = true;
                    });
                  }
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    18 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    section('Identity', [
                      input('first_name', 'First name', required: true),
                      input('last_name', 'Last name'),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Age'),
                            selected: ageOnly,
                            onSelected: locked
                                ? null
                                : (_) => setState(() {
                                    ageOnly = true;
                                    dirty = true;
                                  }),
                          ),
                          ChoiceChip(
                            label: const Text('Date of birth'),
                            selected: !ageOnly,
                            onSelected: locked
                                ? null
                                : (_) => setState(() {
                                    ageOnly = false;
                                    dirty = true;
                                  }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (ageOnly)
                        input(
                          'age',
                          'Age in years',
                          required: true,
                          number: true,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: OutlinedButton.icon(
                            onPressed: locked
                                ? null
                                : () async {
                                    final today = DateUtils.dateOnly(
                                      DateTime.now(),
                                    );
                                    final selected = await showDatePicker(
                                      context: context,
                                      initialDate: dob ?? today,
                                      firstDate: DateTime(1900),
                                      lastDate: today,
                                    );
                                    if (mounted && selected != null) {
                                      setState(() {
                                        dob = selected;
                                        dirty = true;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              dob == null
                                  ? 'Date of birth *'
                                  : MaterialLocalizations.of(context)
                                        .formatMediumDate(dob!),
                            ),
                          ),
                        ),
                      dropdown('genders', 'Sex', gender, (v) {
                        gender = v;
                      }),
                      dropdown('blood_groups', 'Blood group', blood, (v) {
                        blood = v;
                      }),
                      dropdown('id_proof_types', 'ID proof type', proof, (v) {
                        proof = v;
                      }, required: true),
                      input(
                        'id_proof_number',
                        'ID proof number',
                        required: true,
                      ),
                    ]),
                    section('Contact', [
                      input(
                        'phone',
                        'Mobile number',
                        required: true,
                        phone: true,
                      ),
                      input('email', 'Email'),
                      input(
                        'address',
                        'Address',
                        required: true,
                        multiline: true,
                      ),
                      input('city', 'City'),
                      input('state', 'State'),
                      input('zip_code', 'Postal code'),
                      input('country', 'Country'),
                    ]),
                    section('Emergency contact', [
                      input(
                        'emergency_contact_name',
                        'Emergency contact name',
                        required: true,
                      ),
                      input(
                        'emergency_contact_phone',
                        'Emergency contact mobile',
                        required: true,
                        phone: true,
                      ),
                      input(
                        'emergency_contact_relation',
                        'Relation',
                        required: true,
                      ),
                    ]),
                    section('Referral & cover', [
                      dropdown('insurance_categories', 'Cover', cover, (v) {
                        cover = v;
                      }),
                      dropdown(
                        'insurance_providers',
                        'Insurance provider',
                        provider,
                        (v) {
                          provider = v;
                        },
                      ),
                      input(
                        'insurance_provider_other',
                        'Other insurance provider',
                      ),
                      input('insurance_number', 'Insurance number'),
                      input('insurance_tpa', 'TPA'),
                      dropdown(
                        'referral_sources',
                        'Referral source',
                        referral,
                        (v) {
                          referral = v;
                        },
                      ),
                      input(
                        'referral_details',
                        'Referral details',
                        multiline: true,
                      ),
                    ]),
                    section('Clinical history', [
                      input('allergies', 'Allergies', multiline: true),
                      input(
                        'medical_history',
                        'Medical history',
                        multiline: true,
                      ),
                    ]),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: locked ? null : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF207361),
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: Icon(
                        busy
                            ? Icons.hourglass_top
                            : Icons.person_add_alt_outlined,
                      ),
                      label: Text(busy ? 'Registering…' : 'Register patient'),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
