import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'clinical_directory.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'prescription_detail_page.dart';
import 'new_prescription_page.dart';

const _cream = Color(0xFFF7F3EA);
const _green = Color(0xFF207361);
const _ink = Color(0xFF20312D);
const _muted = Color(0xFF566963);

class PrescriptionsPage extends StatefulWidget {
  const PrescriptionsPage({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<PrescriptionsPage> createState() => _PrescriptionsPageState();
}

class _PrescriptionsPageState extends State<PrescriptionsPage> {
  PatientRecordPage? data;
  String? status, error;
  Map<String, dynamic>? patient;
  String sort = 'date';
  bool ascending = false, loading = true;
  int page = 1, request = 0;
  @override
  void initState() {
    super.initState();
    load(1);
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
      final result = await widget.service.fetchDirectory(
        widget.session,
        ClinicalDirectory.prescriptions,
        page: target,
        patientId: patient?['id'] as String?,
        prescriptionStatus: status,
        prescriptionSort: sort,
        prescriptionOrder: ascending ? 'asc' : 'desc',
      );
      if (!mounted || current != request) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load prescriptions. Please try again.';
        });
      }
    }
  }

  Future<void> choosePatient() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cream,
      builder: (_) =>
          _PatientFilter(session: widget.session, service: widget.service),
    );
    if (!mounted || selected == null) return;
    setState(() {
      patient = selected.isEmpty ? null : selected;
    });
    await load(1);
  }

  Future<void> openRecord(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionDetailPage(
          session: widget.session,
          id: item['id'] as String,
          service: widget.service,
        ),
      ),
    );
    if (mounted) await load(page);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: _green, surface: Colors.white),
    ),
    child: Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _green,
        title: const Text('Prescriptions'),
      ),
      body: RefreshIndicator(
        onRefresh: () => load(page),
        color: _green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (['doctor', 'hospital_admin'].contains(widget.session.role))
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewPrescriptionPage(
                          session: widget.session,
                          service: widget.service,
                        ),
                      ),
                    );
                    if (mounted) await load(1);
                  },
                  icon: const Icon(Icons.note_add_outlined, size: 19),
                  label: const Text('New prescription'),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E6DC)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: loading ? null : choosePatient,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.person_search_outlined),
                          label: Text(
                            (patient?['full_name'] ??
                                    patient?['name'] ??
                                    patient?['label'] ??
                                    'All patients')
                                .toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in const [
                                ('all', 'All'),
                                ('draft', 'Drafts'),
                                ('issued', 'Issued'),
                                ('dispensed', 'Dispensed'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(tab.$2),
                                    selected: (status ?? 'all') == tab.$1,
                                    showCheckmark: false,
                                    selectedColor: _green,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: (status ?? 'all') == tab.$1
                                          ? Colors.white
                                          : _ink,
                                    ),
                                    side: BorderSide(
                                      color: (status ?? 'all') == tab.$1
                                          ? _green
                                          : const Color(0xFFE1E6DC),
                                    ),
                                    shape: const StadiumBorder(),
                                    onSelected: loading
                                        ? null
                                        : (_) {
                                            setState(() {
                                              status = tab.$1 == 'all'
                                                  ? null
                                                  : tab.$1;
                                            });
                                            load(1);
                                          },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > 792
                          ? MediaQuery.sizeOf(context).width - 34
                          : 760,
                      child: Column(
                        children: [
                          Container(
                            color: const Color(0xFFF2F5ED),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                for (final column in const [
                                  ('patient', 'PATIENT'),
                                  ('doctor', 'DOCTOR'),
                                  ('', 'DIAGNOSIS'),
                                  ('', 'ITEMS'),
                                  ('date', 'DATE'),
                                  ('status', 'STATUS'),
                                ])
                                  Expanded(
                                    child: column.$1.isEmpty
                                        ? Text(
                                            column.$2,
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: loading
                                                ? null
                                                : () {
                                                    setState(() {
                                                      ascending =
                                                          sort == column.$1
                                                          ? !ascending
                                                          : column.$1 != 'date';
                                                      sort = column.$1;
                                                    });
                                                    load(1);
                                                  },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              alignment: Alignment.centerLeft,
                                              foregroundColor: sort == column.$1
                                                  ? _green
                                                  : _muted,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  column.$2,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(
                                                  sort == column.$1
                                                      ? ascending
                                                            ? Icons.arrow_upward
                                                            : Icons
                                                                  .arrow_downward
                                                      : Icons.unfold_more,
                                                  size: 13,
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                          for (final item
                              in data?.items ?? <Map<String, dynamic>>[])
                            Material(
                              color: Colors.white,
                              child: InkWell(
                                onTap: () => openRecord(item),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFEBEEE6),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _cell(
                                        item['patient'] is Map
                                            ? recordText(
                                                item['patient'] as Map,
                                                'full_name',
                                              )
                                            : null,
                                      ),
                                      _cell(
                                        item['doctor'] is Map
                                            ? recordText(
                                                item['doctor'] as Map,
                                                'name',
                                              )
                                            : null,
                                      ),
                                      _cell(
                                        recordText(item, 'diagnosis') ??
                                            recordText(item, 'chief_complaint'),
                                      ),
                                      _cell(
                                        [
                                          if (item['medications'] is List)
                                            '${(item['medications'] as List).length} medicines',
                                          if (item['lab_tests'] is List)
                                            '${(item['lab_tests'] as List).length} tests',
                                        ].join(' · '),
                                      ),
                                      _cell(
                                        recordText(item, 'issued_at') ??
                                            recordText(item, 'created_at'),
                                      ),
                                      _cell(recordText(item, 'status')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 45,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: _green,
                            size: 35,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'No prescriptions here',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Prescriptions matching your filters will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  if (!loading &&
                      error == null &&
                      (page > 1 || data?.hasNext == true))
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: page > 1 ? () => load(page - 1) : null,
                            child: const Text('Previous'),
                          ),
                          Text('Page $page'),
                          TextButton(
                            onPressed: data?.hasNext == true
                                ? () => load(page + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _cell(String? value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        value?.isNotEmpty == true ? value! : '—',
        style: const TextStyle(color: _ink, fontSize: 12),
      ),
    ),
  );
}

class _PatientFilter extends StatefulWidget {
  const _PatientFilter({required this.session, required this.service});
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<_PatientFilter> createState() => _PatientFilterState();
}

class _PatientFilterState extends State<_PatientFilter> {
  final controller = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool loading = false, searched = false;
  String? error;
  int request = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (controller.text.trim().isEmpty) return;
    final id = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.service.searchPrescriptionPatients(
        widget.session,
        controller.text,
      );
      if (mounted && id == request) {
        setState(() {
          rows = result;
          searched = true;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && id == request) {
        setState(() {
          loading = false;
          error = 'Patient search failed. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SizedBox(
        height: 380,
        child: Column(
          children: [
            const Text(
              'Filter by patient',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextField(
              controller: controller,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                labelText: 'Search patients',
                suffixIcon: IconButton(
                  onPressed: loading ? null : search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            ListTile(
              title: const Text('All patients'),
              onTap: () => Navigator.pop(context, <String, dynamic>{}),
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (searched && rows.isEmpty && !loading)
              const Text('No matching patients.'),
            Expanded(
              child: ListView(
                children: [
                  for (final row in rows)
                    ListTile(
                      title: Text(
                        (row['full_name'] ??
                                row['name'] ??
                                row['label'] ??
                                'Patient')
                            .toString(),
                      ),
                      onTap: () => Navigator.pop(context, row),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
