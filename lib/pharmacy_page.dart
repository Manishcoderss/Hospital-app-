import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'clinical_directory.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'prescription_detail_page.dart';
import 'pharmacy_stock_page.dart';

const _cream = Color(0xFFF7F3EA),
    _green = Color(0xFF207361),
    _ink = Color(0xFF20312D),
    _muted = Color(0xFF566963);

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({super.key, required this.session, required this.service});
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  PatientRecordPage? data;
  Map<String, int?>? summary;
  Map<String, dynamic>? patient;
  String status = 'issued', sort = 'date';
  bool ascending = true, loading = true;
  int page = 1, request = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load(1);
    loadSummary();
  }

  Future<void> loadSummary() async {
    final result = await widget.service.fetchPharmacySummary(widget.session);
    if (mounted) {
      setState(() {
        summary = result;
      });
    }
  }

  Future<void> load(int target) async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
      data = null;
      page = target;
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
              : 'Unable to load pharmacy prescriptions. Please retry.';
        });
      }
    }
  }

  Future<void> refresh() async {
    await Future.wait([load(page), loadSummary()]);
  }

  Future<void> openStock(String view) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyStockPage(
          session: widget.session,
          service: widget.service,
          initialView: view,
        ),
      ),
    );
    if (mounted) await loadSummary();
  }

  Future<void> filterPatient() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cream,
      builder: (_) => _PharmacyPatientFilter(
        session: widget.session,
        service: widget.service,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      patient = selected.isEmpty ? null : selected;
    });
    await load(1);
  }

  Future<void> openPrescription(Map<String, dynamic> row) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionDetailPage(
          session: widget.session,
          id: row['id'] as String,
          service: widget.service,
          pharmacyContext: true,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  Widget surface(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE2E7DE)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
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
        foregroundColor: _green,
        surfaceTintColor: Colors.transparent,
        title: const Text('Pharmacy'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        color: _green,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => openStock('all'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Stock'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 750
                    ? 3
                    : constraints.maxWidth >= 330
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final card in const [
                      (
                        'issued',
                        'To dispense',
                        'Issued prescriptions',
                        Icons.medication_outlined,
                        Color(0xFF207361),
                      ),
                      (
                        'low',
                        'Below reorder level',
                        'Order these soon',
                        Icons.inventory_2_outlined,
                        Color(0xFFD34B63),
                      ),
                      (
                        'expiring',
                        'Expiring in 30 days',
                        'Batches to use first',
                        Icons.event_busy_outlined,
                        Color(0xFFB87919),
                      ),
                    ])
                      SizedBox(
                        width: width,
                        child: surface(
                          InkWell(
                            onTap: () => card.$1 == 'issued'
                                ? selectStage('issued')
                                : openStock(card.$1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card.$2,
                                          style: const TextStyle(
                                            color: _ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: card.$5.withValues(alpha: .08),
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                          border: Border.all(
                                            color: card.$5.withValues(
                                              alpha: .15,
                                            ),
                                          ),
                                        ),
                                        child: Icon(
                                          card.$4,
                                          color: card.$5,
                                          size: 21,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '${summary?[card.$1] ?? '—'}',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card.$3,
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (card.$1 != 'issued')
                                        const Icon(
                                          Icons.arrow_forward,
                                          size: 17,
                                          color: _muted,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (summary != null && summary!.values.any((v) => v == null))
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Some totals are unavailable for this account.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: loadSummary,
                    child: const Text('Retry totals'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            surface(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in const [
                                ('issued', 'To dispense'),
                                ('dispensed', 'Dispensed'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    selected: status == tab.$1,
                                    showCheckmark: false,
                                    selectedColor: _green,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: status == tab.$1
                                          ? Colors.white
                                          : _ink,
                                    ),
                                    side: BorderSide(
                                      color: status == tab.$1
                                          ? _green
                                          : const Color(0xFFE1E6DC),
                                    ),
                                    shape: const StadiumBorder(),
                                    label: Text(
                                      '${tab.$2}${tab.$1 == 'issued' && summary?['issued'] != null ? ' ${summary!['issued']}' : ''}',
                                    ),
                                    onSelected: loading
                                        ? null
                                        : (_) => selectStage(tab.$1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: loading ? null : filterPatient,
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: _green,
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
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth < 800
                            ? 800
                            : constraints.maxWidth,
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFFF0F4EB),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  for (final column in const [
                                    ('date', 'PRESCRIPTION'),
                                    ('patient', 'PATIENT'),
                                    ('', 'MEDICINES'),
                                    ('doctor', 'DOCTOR'),
                                  ])
                                    Expanded(
                                      flex: column.$2 == 'MEDICINES' ? 3 : 2,
                                      child: column.$1.isEmpty
                                          ? const Text(
                                              'MEDICINES',
                                              style: TextStyle(
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
                                                            : true;
                                                        sort = column.$1;
                                                      });
                                                      load(1);
                                                    },
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.centerLeft,
                                                foregroundColor:
                                                    sort == column.$1
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    sort == column.$1
                                                        ? ascending
                                                              ? Icons
                                                                    .arrow_upward
                                                              : Icons
                                                                    .arrow_downward
                                                        : Icons.unfold_more,
                                                    size: 14,
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                            ),
                            for (final row
                                in data?.items ?? <Map<String, dynamic>>[])
                              InkWell(
                                onTap: () => openPrescription(row),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE9EDE4),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      cell(
                                        '${recordText(row, 'prescription_number') ?? 'Prescription'}\n${recordText(row, status == 'issued' ? 'issued_at' : 'dispensed_at') ?? recordText(row, 'created_at') ?? ''}',
                                      ),
                                      cell(
                                        row['patient'] is Map
                                            ? recordText(
                                                row['patient'] as Map,
                                                'full_name',
                                              )
                                            : null,
                                      ),
                                      cell(
                                        row['medications'] is List
                                            ? (row['medications'] as List)
                                                  .whereType<Map>()
                                                  .map(
                                                    (m) =>
                                                        '${m['medicine_name'] ?? 'Medicine'}${m['quantity'] == null ? '' : ' × ${m['quantity']}'}',
                                                  )
                                                  .join('\n')
                                            : null,
                                        flex: 3,
                                      ),
                                      cell(
                                        row['doctor'] is Map
                                            ? recordText(
                                                row['doctor'] as Map,
                                                'name',
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                        horizontal: 20,
                        vertical: 45,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF2F6EF),
                              border: Border.all(
                                color: const Color(0xFFE1E6DC),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: _green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            status == 'issued'
                                ? 'Nothing waiting'
                                : 'Nothing dispensed yet',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status == 'issued'
                                ? 'Prescriptions appear here as soon as a doctor issues them.'
                                : 'Dispensed prescriptions will appear here.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted, height: 1.5),
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
  void selectStage(String stage) {
    setState(() {
      status = stage;
    });
    load(1);
  }

  Widget cell(String? text, {int flex = 2}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Text(
        text?.isNotEmpty == true ? text! : '—',
        style: const TextStyle(color: _ink, fontSize: 12, height: 1.5),
      ),
    ),
  );
}

class _PharmacyPatientFilter extends StatefulWidget {
  const _PharmacyPatientFilter({required this.session, required this.service});
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<_PharmacyPatientFilter> createState() => _PharmacyPatientFilterState();
}

class _PharmacyPatientFilterState extends State<_PharmacyPatientFilter> {
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool loading = false;
  String? error;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> find() async {
    if (search.text.trim().isEmpty || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.service.searchPharmacyPatients(
        widget.session,
        search.text,
      );
      if (mounted) {
        setState(() {
          rows = result;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to search patients. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SizedBox(
        height: 380,
        child: Column(
          children: [
            const Text(
              'Filter by patient',
              style: TextStyle(
                color: _green,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextField(
              controller: search,
              onSubmitted: (_) => find(),
              decoration: InputDecoration(
                labelText: 'Search patients',
                suffixIcon: IconButton(
                  onPressed: find,
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
