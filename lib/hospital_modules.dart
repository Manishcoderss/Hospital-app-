import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'api_catalog.dart';
import 'hospital_api.dart';
import 'hospital_theme.dart';

/// Complete collection-backed forms. Backend permissions remain authoritative.
class HospitalModulesPage extends StatefulWidget {
  const HospitalModulesPage({super.key, required this.api, this.allowedGroups});
  final HospitalApi api;
  final Set<String>? allowedGroups;
  @override
  State<HospitalModulesPage> createState() => _HospitalModulesPageState();
}

class _HospitalModulesPageState extends State<HospitalModulesPage> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final groups = hospitalOperations
        .map((o) => o['group'] as String)
        .toSet()
        .where(
          (g) => (widget.allowedGroups ?? roleGroups(widget.api.session.role))
              .contains(g),
        )
        .where((g) => g.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Hospital workspace')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Everything you need, in one place.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a department or service. Your account permissions determine what you can access.',
            style: TextStyle(color: HospitalTheme.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Find a service',
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 18),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.grid_view_rounded,
                    color: HospitalTheme.blue,
                  ),
                  title: Text(
                    g.replaceAll(' / ', ' · '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          HospitalModulePage(api: widget.api, group: g),
                    ),
                  ),
                ),
              ),
            ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching services.'),
            ),
        ],
      ),
    );
  }
}

class HospitalModulePage extends StatelessWidget {
  const HospitalModulePage({super.key, required this.api, required this.group});
  final HospitalApi api;
  final String group;
  @override
  Widget build(BuildContext context) {
    final ops = hospitalOperations
        .where(
          (o) =>
              o['group'] == group &&
              (api.session.role.toLowerCase() != 'patient' ||
                  o['method'] == 'GET'),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(group)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (final readonly in [true, false]) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                readonly ? 'View & search' : 'Manage & update',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final op in ops.where(
              (o) => (o['method'] == 'GET') == readonly,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    title: Text(
                      op['title'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                    leading: Icon(
                      readonly ? Icons.article_outlined : Icons.edit_outlined,
                      color: HospitalTheme.blue,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HospitalOperationPage(api: api, operation: op),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HospitalOperationPage extends StatefulWidget {
  const HospitalOperationPage({
    super.key,
    required this.api,
    required this.operation,
    this.initialParameters = const {},
    this.initialBody = const {},
  });
  final HospitalApi api;
  final Map<String, dynamic> operation, initialBody;
  final Map<String, String> initialParameters;
  @override
  State<HospitalOperationPage> createState() => _HospitalOperationPageState();
}

class _HospitalOperationPageState extends State<HospitalOperationPage> {
  final form = GlobalKey<FormState>();
  final values = <String, dynamic>{},
      params = <String, String>{},
      query = <String, String>{};
  final picked = <String, XFile>{};
  bool loading = false, uncertain = false;
  String? error;
  HospitalResult? result;
  int page = 1;
  bool get readonly => widget.operation['method'] == 'GET';
  @override
  void initState() {
    super.initState();
    params.addAll(widget.initialParameters);
    values.addAll(widget.initialBody);
    if (readonly && (widget.operation['parameters'] as List).isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) run();
      });
    }
  }

  Future<bool> confirm() async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(widget.operation['title'] as String),
          content: const Text(
            'Continue with this action? Check the account, record and details before confirming.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> run() async {
    if (loading || uncertain || !form.currentState!.validate()) return;
    form.currentState!.save();
    if (!readonly && !await confirm()) return;
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final files = <http.MultipartFile>[];
      for (final e in picked.entries) {
        final bytes = await e.value.readAsBytes();
        if (bytes.length > 15 * 1024 * 1024) {
          throw const HospitalApiException('Choose a file smaller than 15 MB.');
        }
        files.add(
          http.MultipartFile.fromBytes(e.key, bytes, filename: e.value.name),
        );
      }
      final multipart = widget.operation['multipart'] as List? ?? [];
      final answer = await widget.api.execute(
        widget.operation,
        parameters: params,
        query: query,
        body: values,
        files: files,
        fields: {
          for (final f in multipart)
            if (f['type'] != 'file' && values[f['name']] != null)
              f['name'] as String: values[f['name']] is String
                  ? values[f['name']] as String
                  : jsonEncode(values[f['name']]),
        },
      );
      if (mounted) setState(() => result = answer);
    } on HospitalApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          uncertain = e.uncertain;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This action could not be completed. Please check the details.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> share() async {
    try {
      final mime =
          result!.contentType?.split(';').first ?? 'application/octet-stream';
      final ext = mime.contains('pdf')
          ? 'pdf'
          : mime.contains('csv')
          ? 'csv'
          : mime.contains('png')
          ? 'png'
          : 'bin';
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(result!.bytes!, mimeType: mime)],
          fileNameOverrides: ['hospital-document.$ext'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the save/share menu. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final fields = (operation['body']?['fields'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text(operation['title'] as String)),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if ((operation['parameters'] as List).isNotEmpty) ...[
              const Text(
                'Choose the record',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 16),
              for (final key in operation['parameters'] as List)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: EntityField(
                    api: widget.api,
                    name: key as String,
                    initial: params[key],
                    required: true,
                    onChanged: (v) => params[key] = v,
                  ),
                ),
            ],
            if ((operation['query'] as List).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Search & filters',
                  style: TextStyle(fontSize: 15),
                ),
                children: [
                  for (final key in operation['query'] as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SchemaField(
                        api: widget.api,
                        schema: {'name': key, 'type': 'string'},
                        onChanged: (v) {
                          if (v == null) {
                            query.remove(key);
                          } else {
                            query[key] = v.toString();
                          }
                        },
                      ),
                    ),
                ],
              ),
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SchemaField(
                  api: widget.api,
                  schema: field,
                  initial: values[field['name']],
                  onChanged: (v) {
                    if (v == null) {
                      values.remove(field['name']);
                    } else {
                      values[field['name'] as String] = v;
                    }
                  },
                ),
              ),
            for (final field in operation['multipart'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: field['type'] == 'file'
                    ? OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                try {
                                  final f = await openFile();
                                  if (f != null && mounted) {
                                    setState(
                                      () => picked[field['name'] as String] = f,
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () =>
                                          error = 'Unable to open file picker.',
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          picked[field['name']]?.name ??
                              'Choose ${label(field['name'] as String)}',
                        ),
                      )
                    : SchemaField(
                        api: widget.api,
                        schema: Map<String, dynamic>.from(field as Map),
                        onChanged: (v) {
                          if (v != null) values[field['name'] as String] = v;
                        },
                      ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading || uncertain ? null : run,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(readonly ? Icons.refresh : Icons.check),
              label: Text(readonly ? 'Load records' : 'Continue'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFAE493B)),
                    ),
                  ),
                ),
              ),
            if (uncertain)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text(
                  'Return to the list and refresh before submitting another change.',
                ),
              ),
            if (result != null) ...[
              const SizedBox(height: 22),
              if (result!.bytes != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 38,
                          color: HospitalTheme.blue,
                        ),
                        const SizedBox(height: 12),
                        const Text('Your document is ready'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: share,
                          child: const Text('Save or share document'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                RecordView(
                  value: result!.data,
                  onRecord: (record) => openRecord(record),
                ),
              if (readonly &&
                  result!.data is Map &&
                  (result!.data as Map)['meta'] is Map)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: page <= 1 || loading
                          ? null
                          : () {
                              page--;
                              query['page'] = '$page';
                              run();
                            },
                      child: const Text('Previous'),
                    ),
                    Text('Page $page'),
                    TextButton(
                      onPressed:
                          (result!.data as Map)['meta']['has_next'] == true &&
                              !loading
                          ? () {
                              page++;
                              query['page'] = '$page';
                              run();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  void openRecord(Map<String, dynamic> record) {
    final id = record['id']?.toString();
    final related = recordActions(
      widget.operation,
      params,
      id ?? '',
      readonly: widget.api.session.role.toLowerCase() == 'patient',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              RecordView(value: record),
              if (id != null)
                for (final op in related)
                  ListTile(
                    title: Text((op['operation'] as Map)['title'] as String),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(c);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => HospitalOperationPage(
                            api: widget.api,
                            operation: Map<String, dynamic>.from(
                              op['operation'] as Map,
                            ),
                            initialParameters: Map<String, String>.from(
                              op['parameters'] as Map,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class SchemaField extends StatefulWidget {
  const SchemaField({
    super.key,
    required this.api,
    required this.schema,
    required this.onChanged,
    this.initial,
  });
  final HospitalApi api;
  final Map<String, dynamic> schema;
  final ValueChanged<Object?> onChanged;
  final Object? initial;
  @override
  State<SchemaField> createState() => _SchemaFieldState();
}

class _SchemaFieldState extends State<SchemaField> {
  late Object? value = widget.initial;
  final children = <Map<String, dynamic>>[];
  final childKeys = <UniqueKey>[];
  @override
  Widget build(BuildContext context) {
    final s = widget.schema,
        name = s['name'] as String? ?? 'Item',
        type = s['type'];
    if (type == 'boolean') {
      return DropdownButtonFormField<bool>(
        initialValue: value as bool?,
        decoration: InputDecoration(labelText: label(name)),
        items: const [
          DropdownMenuItem(value: true, child: Text('Yes')),
          DropdownMenuItem(value: false, child: Text('No')),
        ],
        onChanged: (v) {
          value = v;
          widget.onChanged(v);
        },
      );
    }
    if (type == 'object') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label(name),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final f in s['fields'] as List? ?? [])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SchemaField(
                    api: widget.api,
                    schema: Map<String, dynamic>.from(f as Map),
                    onChanged: (v) {
                      final map = value is Map
                          ? Map<String, dynamic>.from(value as Map)
                          : <String, dynamic>{};
                      if (v == null) {
                        map.remove(f['name']);
                      } else {
                        map[f['name'] as String] = v;
                      }
                      value = map;
                      widget.onChanged(map.isEmpty ? null : map);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (type == 'array') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label(name),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (var i = 0; i < children.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SchemaField(
                          key: childKeys[i],
                          api: widget.api,
                          schema: {
                            ...Map<String, dynamic>.from(s['item'] as Map),
                            'name': 'Item ${i + 1}',
                          },
                          onChanged: (v) {
                            children[i]['value'] = v;
                            widget.onChanged(
                              children
                                  .map((e) => e['value'])
                                  .where((x) => x != null)
                                  .toList(),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        onPressed: () {
                          setState(() {
                            children.removeAt(i);
                            childKeys.removeAt(i);
                          });
                          widget.onChanged(
                            children
                                .map((e) => e['value'])
                                .where((x) => x != null)
                                .toList(),
                          );
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  children.add({});
                  childKeys.add(UniqueKey());
                }),
                icon: const Icon(Icons.add),
                label: Text('Add ${label(name)}'),
              ),
            ],
          ),
        ),
      );
    }
    if (name.endsWith('_id') &&
        !RegExp('token|session|device').hasMatch(name)) {
      return EntityField(
        api: widget.api,
        name: name,
        initial: value?.toString(),
        onChanged: (v) => widget.onChanged(v.isEmpty ? null : v),
      );
    }
    final secret = s['secret'] == true;
    return TextFormField(
      initialValue: value?.toString(),
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      minLines: 1,
      maxLines: secret
          ? 1
          : (RegExp(
                  'notes|details|address|reason|description|body|instructions|diagnosis',
                ).hasMatch(name)
                ? 3
                : 1),
      keyboardType: type == 'number'
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : name.contains('email')
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label(name),
        helperText: name.contains('date') ? 'Date format: YYYY-MM-DD' : null,
      ),
      validator: (v) =>
          type == 'number' &&
              (v?.trim().isNotEmpty ?? false) &&
              num.tryParse(v!.trim()) == null
          ? 'Enter a valid number'
          : null,
      onChanged: (v) {
        value = v.trim().isEmpty
            ? null
            : type == 'number'
            ? num.tryParse(v.trim())
            : v;
        widget.onChanged(value);
      },
    );
  }
}

class EntityField extends StatefulWidget {
  const EntityField({
    super.key,
    required this.api,
    required this.name,
    required this.onChanged,
    this.initial,
    this.required = false,
  });
  final HospitalApi api;
  final String name;
  final ValueChanged<String> onChanged;
  final String? initial;
  final bool required;
  @override
  State<EntityField> createState() => _EntityFieldState();
}

class _EntityFieldState extends State<EntityField> {
  late final text = TextEditingController(text: widget.initial);
  bool loading = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String? get path => switch (widget.name) {
    'patient_id' => '/patients',
    'doctor_id' => '/doctors',
    'department_id' => '/departments',
    'medicine_id' => '/medicines',
    'hospital_id' => '/hospitals',
    'user_id' => '/users',
    'role_id' => '/roles',
    'admission_id' => '/admissions',
    'ward_id' => '/wards',
    'bed_id' => '/beds',
    'bill_id' => '/billing',
    'prescription_id' => '/prescriptions',
    'appointment_id' => '/appointments',
    'lab_order_id' => '/lab-tests',
    _ => null,
  };
  Future<void> choose() async {
    if (path == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = HospitalApi.rows(
        await widget.api.get(
          path!,
          query: {'search': text.text, 'page': '1', 'per_page': '50'},
        ),
      );
      if (!mounted) return;
      final record = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .65,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose ${label(widget.name.replaceFirst('_id', ''))}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Text('No matching records. Try another search.'),
                for (final row in rows)
                  ListTile(
                    title: Text(recordTitle(row)),
                    subtitle: Text(row['id']?.toString() ?? ''),
                    onTap: () => Navigator.pop(c, row),
                  ),
              ],
            ),
          ),
        ),
      );
      if (record != null) {
        text.text = record['id'].toString();
        widget.onChanged(text.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: text,
    decoration: InputDecoration(
      labelText: label(widget.name),
      helperText: path != null ? 'Search and choose a hospital record' : null,
      errorText: error,
      suffixIcon: path == null
          ? null
          : IconButton(
              tooltip: 'Find record',
              onPressed: loading ? null : choose,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
    ),
    validator: (v) => widget.required && (v?.trim().isEmpty ?? true)
        ? 'Choose ${label(widget.name)}'
        : null,
    onChanged: widget.onChanged,
    onSaved: (v) => widget.onChanged(v?.trim() ?? ''),
  );
}

String recordTitle(Map row) {
  for (final key in [
    'full_name',
    'name',
    'title',
    'description',
    'bill_number',
    'appointment_number',
    'code',
    'id',
  ]) {
    if (row[key] != null &&
        row[key] is! Map &&
        row[key] is! List &&
        row[key].toString().isNotEmpty) {
      return row[key].toString();
    }
  }
  return 'Hospital record';
}

class RecordView extends StatelessWidget {
  const RecordView({super.key, required this.value, this.onRecord});
  final Object? value;
  final ValueChanged<Map<String, dynamic>>? onRecord;
  @override
  Widget build(BuildContext context) {
    final data = value;
    if (data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Action completed. Refresh the record to see the latest information.',
          ),
        ),
      );
    }
    if (data is Map) {
      final items = data['items'] ?? data['results'] ?? data['records'];
      if (items is List) return RecordView(value: items, onRecord: onRecord);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in data.entries)
                if (!RegExp('password|token|secret|totp_uri|qr_code')
                    .hasMatch(e.key.toString()))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: e.value is List || e.value is Map
                        ? ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(label(e.key.toString())),
                            children: [
                              RecordView(value: e.value, onRecord: onRecord),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label(e.key.toString()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: HospitalTheme.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                e.value?.toString() ?? '—',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                  ),
            ],
          ),
        ),
      );
    }
    if (data is List) {
      return data.isEmpty
          ? const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No records found.'),
              ),
            )
          : Column(
              children: [
                for (final row in data)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: row is Map<String, dynamic> && onRecord != null
                        ? Card(
                            child: ListTile(
                              title: Text(recordTitle(row)),
                              subtitle: Text(
                                [
                                  row['status'],
                                  row['date'],
                                  row['phone'],
                                ].where((x) => x != null).join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => onRecord!(row),
                            ),
                          )
                        : RecordView(value: row, onRecord: onRecord),
                  ),
              ],
            );
    }
    return SelectableText(data.toString());
  }
}

Set<String> roleGroups(String role) {
  final groups = hospitalOperations.map((o) => o['group'] as String).toSet();
  final r = role.toLowerCase();
  if ([
    'superadmin',
    'super_admin',
    'hospital_admin',
    'admin',
    'organisation_admin',
    'organization_admin',
  ].contains(r)) {
    return groups;
  }
  final common = {
    'Auth',
    'Auth / 2FA — TOTP',
    'Auth / 2FA — Email',
    'Notifications',
    'Notification Preferences',
    'Devices (FCM)',
  };
  if (r == 'patient') {
    return {
      ...common,
      'Doctors',
      'Appointments',
      'Patients',
      'Prescriptions',
      'Lab Tests',
      'Billing',
      'Consents',
    };
  }
  if (r == 'doctor') {
    return {
      ...common,
      'Patients',
      'Doctors',
      'Appointments',
      'Doctor Dashboard',
      'Calendar',
      'Prescriptions',
      'Lab Tests',
      'IPD · Admission Requests',
      'IPD · Admissions',
      'IPD · Clinical Notes',
      'IPD · Care Plans',
      'IPD · Discharge',
      'Referrals',
      'Consents',
    };
  }
  if (r.contains('pharma')) {
    return {
      ...common,
      'Prescriptions',
      'Medicines',
      'Stock',
      'Patients',
      'Billing',
      'IPD · Ward Pharmacy',
    };
  }
  if (r.contains('lab')) return {...common, 'Patients', 'Lab Tests'};
  if (r.contains('nurs')) {
    return {
      ...common,
      'Patients',
      'IPD · Admissions',
      'IPD · Nursing & Medication',
      'IPD · Clinical Notes',
      'IPD · Wards & Beds',
    };
  }
  if (r.contains('bill') || r.contains('account')) {
    return {
      ...common,
      'Patients',
      'Billing',
      'IPD · Charges, Deposits & Bill',
      'IPD · Insurance & Packages',
    };
  }
  if (r.contains('recept')) {
    return {
      ...common,
      'Patients',
      'Doctors',
      'Appointments',
      'Calendar',
      'Billing',
      'IPD · Admission Requests',
    };
  }
  // Custom roles can still be constrained by allowedGroups; backend authorizes every request.
  return groups;
}

List<Map<String, dynamic>> recordActions(
  Map<String, dynamic> source,
  Map<String, String> context,
  String id, {
  bool readonly = false,
}) {
  if (id.isEmpty) return [];
  var root = (source['path'] as String).replaceFirst(RegExp(r'/$'), '');
  final nestedRoots = {
    'appointments': '/appointments',
    'prescriptions': '/prescriptions',
    'lab-orders': '/lab-tests',
    'bills': '/billing',
    'doctors': '/doctors',
    'hospitals': '/hospitals',
    'users': '/users',
  };
  if (root.contains('{{') && nestedRoots.containsKey(root.split('/').last))
    root = nestedRoots[root.split('/').last]!;
  final prefix = '$root/';
  final actions = <Map<String, dynamic>>[];
  for (final op in hospitalOperations) {
    final path = op['path'] as String;
    if (!path.startsWith(prefix) || readonly && op['method'] != 'GET') continue;
    final remaining = path.substring(prefix.length);
    final match = RegExp(r'^\{\{([^}]+)\}\}').firstMatch(remaining);
    if (match == null) continue;
    actions.add({
      'operation': op,
      'parameters': {...context, match.group(1)!: id},
    });
  }
  return actions;
}
