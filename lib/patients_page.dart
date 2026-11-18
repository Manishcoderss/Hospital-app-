import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'patient_detail_page.dart';
import 'patient_registration_page.dart';

const _cream = Color(0xFFF7F3EA),
    _green = Color(0xFF207361),
    _ink = Color(0xFF20312D),
    _muted = Color(0xFF566963);

class PatientsPage extends StatefulWidget {
  const PatientsPage({
    super.key,
    required this.session,
    required this.service,
    this.embedded = false,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final bool embedded;
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final search = TextEditingController();
  PatientRecordPage? data;
  Map<String, dynamic>? lookups;
  String? gender, blood, cover, error, lookupError;
  String sort = 'registered', query = '';
  bool ascending = false, loading = true;
  int page = 1, perPage = 100, request = 0;
  @override
  void initState() {
    super.initState();
    load(1);
    loadLookups();
  }

  @override
  void dispose() {
    search.dispose();

    super.dispose();
  }

  Future<void> loadLookups() async {
    try {
      final result = await widget.service.fetchPatientLookups(widget.session);
      if (mounted) {
        setState(() {
          lookups = result;
          lookupError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          lookupError = 'Patient filters unavailable';
        });
      }
    }
  }

  Future<void> load(int target) async {
    final current = ++request;
    setState(() {
      page = target;
      loading = true;
      error = null;
      data = null;
    });
    try {
      final result = await widget.service.fetchPatients(
        widget.session,
        search: query,
        gender: gender,
        bloodGroup: blood,
        insuranceCategory: cover,
        page: target,
        perPage: perPage,
        sort: sort,
        order: ascending ? 'asc' : 'desc',
      );
      if (mounted && current == request) {
        setState(() {
          data = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load patients. Please retry.';
        });
      }
    }
  }

  void searchPatients() {
    query = search.text.trim();
    load(1);
  }

  List<Map<String, dynamic>> options(String key) {
    final value = lookups?[key];
    return value is List
        ? value
              .whereType<Map<String, dynamic>>()
              .where((row) => row['value'] is String)
              .toList()
        : [];
  }

  Future<void> openPatient(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailPage(
          session: widget.session,
          patientId: id,
          service: widget.service,
        ),
      ),
    );
    if (mounted) await load(page);
  }

  Future<void> register() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PatientRegistrationPage(
          session: widget.session,
          service: widget.service,
        ),
      ),
    );
    if (!mounted || id == null) return;
    await load(1);
    if (mounted) await openPatient(id);
  }

  String capital(String? text) => text == null || text.isEmpty
      ? ''
      : text[0].toUpperCase() + text.substring(1);
  String registered(Object? raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget filter(
    String label,
    String key,
    String? value,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$key:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    items: [
      DropdownMenuItem<String>(value: null, child: Text(label)),
      for (final item in options(key))
        DropdownMenuItem(
          value: item['value'] as String,
          child: Text(
            capital((item['label'] ?? item['value']).toString()),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: loading || lookups == null ? null : onChanged,
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: _green, surface: Colors.white),
    ),
    child: Scaffold(
      backgroundColor: _cream,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: _cream,
              foregroundColor: _green,
              surfaceTintColor: Colors.transparent,
              title: const Text('Patients'),
            ),
      body: RefreshIndicator(
        onRefresh: () => load(page),
        color: _green,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: register,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 19),
                  label: const Text('Register patient'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE1E6DC)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: search,
                          onSubmitted: (_) => searchPatients(),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText:
                                'Search by name, patient number or mobile',
                            prefixIcon: const Icon(Icons.search, color: _green),
                            suffixIcon: IconButton(
                              tooltip: 'Search',
                              onPressed: searchPatients,
                              icon: const Icon(
                                Icons.arrow_forward,
                                color: _green,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _green,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final filters = [
                              filter('Any sex', 'genders', gender, (value) {
                                setState(() {
                                  gender = value;
                                });
                                load(1);
                              }),
                              filter('Any blood group', 'blood_groups', blood, (
                                value,
                              ) {
                                setState(() {
                                  blood = value;
                                });
                                load(1);
                              }),
                              filter(
                                'Any cover',
                                'insurance_categories',
                                cover,
                                (value) {
                                  setState(() {
                                    cover = value;
                                  });
                                  load(1);
                                },
                              ),
                            ];
                            return constraints.maxWidth >= 650
                                ? Row(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < filters.length;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(width: 12),
                                        Expanded(child: filters[i]),
                                      ],
                                    ],
                                  )
                                : Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < filters.length;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(height: 10),
                                        filters[i],
                                      ],
                                    ],
                                  );
                          },
                        ),
                        if (lookupError != null)
                          TextButton(
                            onPressed: loadLookups,
                            child: Text('$lookupError · Retry'),
                          ),
                        if (query.isNotEmpty ||
                            gender != null ||
                            blood != null ||
                            cover != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      setState(() {
                                        query = '';
                                        search.clear();
                                        gender = null;
                                        blood = null;
                                        cover = null;
                                      });
                                      load(1);
                                    },
                              child: const Text('Clear filters'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final col in const [
                            ('name', 'PATIENT'),
                            ('city', 'CITY'),
                            ('registered', 'REGISTERED'),
                          ])
                            Expanded(
                              flex: col.$1 == 'registered' ? 4 : 3,
                              child: TextButton.icon(
                                onPressed: loading
                                    ? null
                                    : () {
                                        setState(() {
                                          ascending = sort == col.$1
                                              ? !ascending
                                              : col.$1 != 'registered';
                                          sort = col.$1;
                                        });
                                        load(1);
                                      },
                                icon: Icon(
                                  sort == col.$1
                                      ? ascending
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward
                                      : Icons.unfold_more,
                                  size: 16,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(col.$2),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  foregroundColor: sort == col.$1
                                      ? _green
                                      : _muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < (data?.items.length ?? 0); i++)
                  patientRow(data!.items[i], i),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(35),
                    child: Center(
                      child: CircularProgressIndicator(color: _green),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => load(page),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (!loading && error == null && data?.items.isEmpty == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 35,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person_search_outlined,
                          color: _green,
                          size: 34,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          query.isEmpty &&
                                  gender == null &&
                                  blood == null &&
                                  cover == null
                              ? 'No patients registered yet'
                              : 'No patients match',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try a name, patient number or mobile.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                if (data != null && !loading)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        Text(
                          'Showing ${data!.total == 0 ? 0 : (page - 1) * perPage + 1}–${(page - 1) * perPage + data!.items.length} of ${data!.total} patients',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Rows per page',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                            DropdownButton<int>(
                              value: perPage,
                              items: [
                                for (final count in [10, 25, 50, 100])
                                  DropdownMenuItem(
                                    value: count,
                                    child: Text('$count'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    perPage = value;
                                  });
                                  load(1);
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: page > 1 ? () => load(page - 1) : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$page',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed: data!.hasNext
                                  ? () => load(page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget patientRow(Map<String, dynamic> row, int index) {
    final name = recordText(row, 'full_name') ?? 'Name unavailable';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    final insurer = recordText(row, 'insurance_provider_name');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E7E0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPatient(row['id'] as String),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recordText(row, 'patient_number') ?? '—',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _green),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE5EADF)),
                ),
                patientDetail(
                  'Age / Sex',
                  [
                    if (row['age'] != null) '${row['age']} y',
                    if (recordText(row, 'gender') != null)
                      capital(recordText(row, 'gender')),
                  ].join(' · '),
                ),
                patientDetail('Mobile', recordText(row, 'phone')),
                patientDetail('Blood group', recordText(row, 'blood_group')),
                patientDetail('Cover', insurer ?? 'Self-pay'),
                patientDetail('City', recordText(row, 'city')),
                patientDetail('Registered', registered(row['created_at'])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget patientDetail(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value?.isNotEmpty == true ? value! : '—',
            style: const TextStyle(color: _ink, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
