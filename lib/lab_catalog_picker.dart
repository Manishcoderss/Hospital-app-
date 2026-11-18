import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'lab_catalog_test.dart';

class LabCatalogPicker extends StatefulWidget {
  const LabCatalogPicker({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<LabCatalogPicker> createState() => _LabCatalogPickerState();
}

class _LabCatalogPickerState extends State<LabCatalogPicker> {
  final search = TextEditingController();
  List<LabCatalogTest> items = [];
  bool loading = true;
  String? error;
  String query = '';
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
      items = [];
      query = search.text.trim();
    });
    try {
      final result = await widget.service.fetchLabCatalog(
        widget.session,
        query,
      );
      if (mounted && current == request) {
        setState(() {
          items = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Lab catalog response could not be read. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose lab test')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
              load();
            },
            decoration: InputDecoration(
              labelText: 'Search lab catalog',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Search lab tests',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  load();
                },
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        FilledButton(
                          onPressed: load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : items.isEmpty
              ? const Center(child: Text('No matching lab tests.'))
              : ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Up to 30 matches · Search to narrow the list',
                      ),
                    ),
                    for (final test in items)
                      ListTile(
                        title: Text(test.name),
                        subtitle: test.sampleType == null
                            ? null
                            : Text('Sample: ${test.sampleType}'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.of(context).pop(test),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
