import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';

class PharmacyStockPage extends StatefulWidget {
  const PharmacyStockPage({
    super.key,
    required this.session,
    required this.service,
    this.initialView = 'all',
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final String initialView;
  @override
  State<PharmacyStockPage> createState() => _PharmacyStockPageState();
}

class _PharmacyStockPageState extends State<PharmacyStockPage> {
  final search = TextEditingController();
  late String view = widget.initialView;
  List<Map<String, dynamic>> rows = [];
  bool loading = true, hasNext = false;
  int page = 1, request = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load(1);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load(int target) async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
      rows = [];
      page = target;
    });
    try {
      final data = await widget.service.fetchPharmacyStock(
        widget.session,
        view: view,
        search: search.text,
        page: target,
      );
      final result = recordList(
        view == 'expiring' ? data['batches'] : data['items'],
      );
      final meta = data['meta'];
      if (mounted && current == request) {
        setState(() {
          rows = result;
          hasNext = meta is Map && meta['has_next'] == true;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load stock. Please retry.';
        });
      }
    }
  }

  String medicineName(Map row) {
    final medicine = row['medicine'];
    if (medicine is Map) {
      return recordText(medicine, 'name') ??
          recordText(medicine, 'label') ??
          [
            medicine['generic_name'],
            medicine['brand_name'],
            medicine['strength'],
          ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    }
    return recordText(row, 'medicine_name') ??
        recordText(row, 'name') ??
        'Medicine';
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: const Color(0xFF207361), surface: Colors.white),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F3EA),
        foregroundColor: const Color(0xFF207361),
        surfaceTintColor: Colors.transparent,
        title: const Text('Stock'),
      ),
      body: RefreshIndicator(
        onRefresh: () => load(page),
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'Stock',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20312D),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Batches are used earliest-expiry first.',
              style: TextStyle(color: Color(0xFF566963)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final tab in const [
                  ('all', 'All stock'),
                  ('low', 'Below reorder level'),
                  ('expiring', 'Expiring in 30 days'),
                ])
                  ChoiceChip(
                    label: Text(tab.$2),
                    selected: view == tab.$1,
                    onSelected: loading
                        ? null
                        : (_) {
                            setState(() {
                              view = tab.$1;
                            });
                            load(1);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (view != 'expiring')
              TextField(
                controller: search,
                onSubmitted: (_) => load(1),
                decoration: InputDecoration(
                  labelText: 'Search stock',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Search stock',
                    onPressed: () => load(1),
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null) ...[
              Text(error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => load(page),
                child: const Text('Retry'),
              ),
            ],
            if (!loading && error == null && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No stock records match this view.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final row in rows)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE1E6DC)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName(row),
                        style: const TextStyle(
                          color: Color(0xFF20312D),
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (view == 'expiring') ...[
                        Text(
                          'Batch: ${recordText(row, 'batch_number') ?? 'Not recorded'}',
                        ),
                        Text(
                          'Remaining: ${recordText(row, 'quantity_remaining') ?? 'Not recorded'}',
                        ),
                        Text(
                          'Expires: ${recordText(row, 'expiry_date') ?? 'Not recorded'}',
                        ),
                        if (row['days_to_expiry'] != null)
                          Text('${row['days_to_expiry']} days to expiry'),
                        if (row['storage_location'] != null)
                          Text('Location: ${row['storage_location']}'),
                      ] else ...[
                        Text(
                          'Available quantity: ${recordText(row, 'total_quantity') ?? 'Not recorded'}',
                        ),
                        if (row['reorder_level'] != null)
                          Text('Reorder level: ${row['reorder_level']}'),
                        if (row['nearest_expiry'] != null)
                          Text('Next expiry: ${row['nearest_expiry']}'),
                      ],
                    ],
                  ),
                ),
              ),
            if (!loading && error == null && (page > 1 || hasNext))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: page > 1 ? () => load(page - 1) : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page $page'),
                  TextButton(
                    onPressed: hasNext ? () => load(page + 1) : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
