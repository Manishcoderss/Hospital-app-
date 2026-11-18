import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'lab_report_page.dart';
import 'new_lab_order_page.dart';

const _cream = Color(0xFFF7F3EA),
    _green = Color(0xFF207361),
    _ink = Color(0xFF20312D),
    _muted = Color(0xFF566963);
const _stages = [
  (
    'ordered',
    'Awaiting sample',
    'Collect from the patient',
    Icons.science_outlined,
  ),
  (
    'sample_collected',
    'Sample collected',
    'Ready to process',
    Icons.biotech_outlined,
  ),
  ('processing', 'Processing', 'Results to enter', Icons.manage_search),
  ('completed', 'Reported', 'All time', Icons.task_alt),
];

class LaboratoryPage extends StatefulWidget {
  const LaboratoryPage({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<LaboratoryPage> createState() => _LaboratoryPageState();
}

class _LaboratoryPageState extends State<LaboratoryPage> {
  final search = TextEditingController();
  PatientRecordPage? data;
  Map<String, int>? counts;
  List<Map<String, dynamic>> categories = [];
  Map<String, dynamic>? patient;
  String status = 'ordered', orderSort = 'date', catalogSort = 'name';
  bool orderAscending = false,
      catalogAscending = true,
      catalog = false,
      loading = true;
  String? error, countsError, category, categoriesError;
  int page = 1, request = 0;
  @override
  void initState() {
    super.initState();
    load(1);
    refreshCounts();
    loadCategories();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refreshCounts() async {
    try {
      final result = await widget.service.fetchLaboratoryCounts(widget.session);
      if (mounted) {
        setState(() {
          counts = result;
          countsError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          counts = null;
          countsError = 'Stage totals unavailable';
        });
      }
    }
  }

  Future<void> loadCategories() async {
    try {
      final result = await widget.service.fetchLaboratoryCategories(
        widget.session,
      );
      if (mounted) {
        setState(() {
          categories = result;
          categoriesError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          categoriesError = 'Categories unavailable';
        });
      }
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
      final result = catalog
          ? await widget.service.fetchLaboratoryCatalog(
              widget.session,
              search: search.text,
              category: category,
              page: target,
              sort: catalogSort,
              order: catalogAscending ? 'asc' : 'desc',
            )
          : await widget.service.fetchLaboratoryOrders(
              widget.session,
              status: status,
              patientId: patient?['id'] as String?,
              page: target,
              sort: orderSort,
              order: orderAscending ? 'asc' : 'desc',
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
              : 'Unable to load laboratory records. Please retry.';
        });
      }
    }
  }

  Future<void> refresh() async {
    await Future.wait([load(page), refreshCounts()]);
  }

  Future<void> choosePatient() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cream,
      builder: (_) =>
          _LabPatientFilter(session: widget.session, service: widget.service),
    );
    if (!mounted || selected == null) return;
    setState(() {
      patient = selected.isEmpty ? null : selected;
    });
    await load(1);
  }

  Future<void> openOrder(Map<String, dynamic> row) async {
    final nested = row['patient'];
    final patientId =
        row['patient_id'] ?? (nested is Map ? nested['id'] : null);
    if (patientId is! String || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient link is unavailable for this report.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabReportPage(
          session: widget.session,
          patientId: patientId,
          orderId: row['id'] as String,
          service: widget.service,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  void openTest(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cream,
        title: Text(recordText(row, 'name') ?? 'Test details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in [
                ('code', 'Code'),
                ('category', 'Category'),
                ('sample_type', 'Sample'),
                ('normal_range', 'Normal range'),
                ('unit', 'Unit'),
                ('turnaround_hours', 'Turnaround (hours)'),
                ('price', 'Price'),
                ('preparation', 'Preparation'),
                ('description', 'Description'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${field.$2}: ${recordText(row, field.$1) ?? 'Not recorded'}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget surface(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE1E6DC)),
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
        title: const Text('Laboratory'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        color: _green,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if ([
              'doctor',
              'hospital_admin',
              'lab_technician',
              'receptionist',
            ].contains(widget.session.role))
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => NewLabOrderPage(
                          session: widget.session,
                          service: widget.service,
                        ),
                      ),
                    );
                    if (mounted && created == true) {
                      setState(() {
                        catalog = false;
                        status = 'ordered';
                      });
                      await load(1);
                      await refreshCounts();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New lab order'),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final tab in [(false, 'Orders'), (true, 'Test catalogue')])
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (catalog != tab.$1) {
                          setState(() {
                            catalog = tab.$1;
                          });
                          load(1);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: catalog == tab.$1
                                  ? _green
                                  : const Color(0xFFE1E6DC),
                              width: catalog == tab.$1 ? 2 : 1,
                            ),
                          ),
                        ),
                        child: Text(
                          tab.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: catalog == tab.$1 ? _green : _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (!catalog) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final stage in _stages)
                        SizedBox(
                          width: width,
                          child: surface(
                            InkWell(
                              onTap: loading
                                  ? null
                                  : () {
                                      setState(() {
                                        status = stage.$1;
                                      });
                                      load(1);
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stage.$2,
                                            style: const TextStyle(
                                              color: _ink,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(stage.$4, color: _green, size: 21),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      '${counts?[stage.$1] ?? '—'}',
                                      style: const TextStyle(
                                        color: _green,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      stage.$3,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
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
              if (countsError != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        countsError!,
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                    TextButton(
                      onPressed: refreshCounts,
                      child: const Text('Retry totals'),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
            ],
            surface(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: catalog
                        ? Column(
                            children: [
                              TextField(
                                controller: search,
                                onSubmitted: (_) => load(1),
                                decoration: InputDecoration(
                                  hintText: 'Search by name or code',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: IconButton(
                                    tooltip: 'Search catalogue',
                                    onPressed: () => load(1),
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: category,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All categories'),
                                  ),
                                  for (final c in categories)
                                    if (c['value'] is String)
                                      DropdownMenuItem(
                                        value: c['value'] as String,
                                        child: Text(
                                          (c['label'] ?? c['value']).toString(),
                                        ),
                                      ),
                                ],
                                onChanged: loading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          category = value;
                                        });
                                        load(1);
                                      },
                              ),
                              if (categoriesError != null)
                                TextButton(
                                  onPressed: loadCategories,
                                  child: Text('$categoriesError · Retry'),
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: loading ? null : choosePatient,
                                icon: const Icon(Icons.person_search_outlined),
                                label: Text(
                                  (patient?['full_name'] ??
                                          patient?['name'] ??
                                          patient?['label'] ??
                                          'All patients')
                                      .toString(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final stage in [
                                      ..._stages.map((s) => (s.$1, s.$2)),
                                      ('cancelled', 'Cancelled'),
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 7,
                                        ),
                                        child: ChoiceChip(
                                          selected: status == stage.$1,
                                          showCheckmark: false,
                                          label: Text(
                                            '${stage.$2}${counts?[stage.$1] == null ? '' : ' ${counts![stage.$1]}'}',
                                          ),
                                          selectedColor: _green,
                                          labelStyle: TextStyle(
                                            color: status == stage.$1
                                                ? Colors.white
                                                : _ink,
                                          ),
                                          shape: const StadiumBorder(),
                                          side: BorderSide(
                                            color: status == stage.$1
                                                ? _green
                                                : const Color(0xFFE1E6DC),
                                          ),
                                          onSelected: loading
                                              ? null
                                              : (_) {
                                                  setState(() {
                                                    status = stage.$1;
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
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth < 850
                            ? 850
                            : constraints.maxWidth,
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFFF0F4EB),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  for (final col
                                      in catalog
                                          ? const [
                                              ('name', 'TEST'),
                                              ('category', 'CATEGORY'),
                                              ('sample', 'SAMPLE'),
                                              ('', 'NORMAL RANGE'),
                                              ('turnaround', 'TURNAROUND'),
                                              ('price', 'PRICE'),
                                            ]
                                          : const [
                                              ('date', 'ORDER'),
                                              ('patient', 'PATIENT'),
                                              ('', 'TESTS'),
                                              ('doctor', 'DOCTOR'),
                                              ('', 'FROM'),
                                            ])
                                    Expanded(
                                      child: col.$1.isEmpty
                                          ? Text(
                                              col.$2,
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.centerLeft,
                                                foregroundColor: _green,
                                              ),
                                              onPressed: loading
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        if (catalog) {
                                                          catalogAscending =
                                                              catalogSort ==
                                                                  col.$1
                                                              ? !catalogAscending
                                                              : true;
                                                          catalogSort = col.$1;
                                                        } else {
                                                          orderAscending =
                                                              orderSort ==
                                                                  col.$1
                                                              ? !orderAscending
                                                              : col.$1 !=
                                                                    'date';
                                                          orderSort = col.$1;
                                                        }
                                                      });
                                                      load(1);
                                                    },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    col.$2,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Icon(
                                                    (catalog
                                                                ? catalogSort
                                                                : orderSort) ==
                                                            col.$1
                                                        ? (catalog
                                                                  ? catalogAscending
                                                                  : orderAscending)
                                                              ? Icons
                                                                    .arrow_upward
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
                            for (final row
                                in data?.items ?? <Map<String, dynamic>>[])
                              InkWell(
                                onTap: () =>
                                    catalog ? openTest(row) : openOrder(row),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
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
                                    children: catalog
                                        ? [
                                            cell(
                                              '${recordText(row, 'name') ?? 'Test'}\n${recordText(row, 'code') ?? ''}',
                                            ),
                                            cell(recordText(row, 'category')),
                                            cell(
                                              recordText(row, 'sample_type'),
                                            ),
                                            cell(
                                              recordText(row, 'normal_range'),
                                            ),
                                            cell(
                                              row['turnaround_hours'] == null
                                                  ? null
                                                  : '${row['turnaround_hours']} h',
                                            ),
                                            cell(
                                              row['price'] == null
                                                  ? null
                                                  : '₹${row['price']}',
                                            ),
                                          ]
                                        : [
                                            cell(
                                              recordText(row, 'order_number'),
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
                                              row['tests'] is List
                                                  ? (row['tests'] as List)
                                                        .whereType<Map>()
                                                        .map(
                                                          (t) =>
                                                              t['test_name'] ??
                                                              t['name'] ??
                                                              'Test',
                                                        )
                                                        .join(', ')
                                                  : null,
                                            ),
                                            cell(
                                              row['doctor'] is Map
                                                  ? recordText(
                                                      row['doctor'] as Map,
                                                      'name',
                                                    )
                                                  : null,
                                            ),
                                            cell(
                                              recordText(row, 'source') ??
                                                  (row['prescription_id'] !=
                                                          null
                                                      ? 'Prescription'
                                                      : null),
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
                      padding: EdgeInsets.all(32),
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
                        vertical: 38,
                        horizontal: 18,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 34,
                            color: _green,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            catalog
                                ? 'No tests match'
                                : 'Nothing in this stage',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            catalog ? 'Try another search or category.' : 'New orders from doctors and the wards will appear here.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted),
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
  Widget cell(String? text) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        text?.isNotEmpty == true ? text! : '—',
        style: const TextStyle(color: _ink, fontSize: 12, height: 1.5),
      ),
    ),
  );
}

class _LabPatientFilter extends StatefulWidget {
  const _LabPatientFilter({required this.session, required this.service});
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<_LabPatientFilter> createState() => _LabPatientFilterState();
}

class _LabPatientFilterState extends State<_LabPatientFilter> {
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
      final result = await widget.service.searchLaboratoryPatients(
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
