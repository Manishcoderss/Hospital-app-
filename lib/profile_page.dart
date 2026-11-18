import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'account_settings_panels.dart';

const _cream = Color(0xFFF7F3EA),
    _green = Color(0xFF207361),
    _ink = Color(0xFF20312D),
    _muted = Color(0xFF566963);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.service,
    required this.onSignOut,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final VoidCallback onSignOut;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final first = TextEditingController(),
      last = TextEditingController(),
      address = TextEditingController();
  Map<String, dynamic>? account;
  bool loading = true, saving = false;
  String? error, saveError;
  int tab = 0;
  bool get changed =>
      account != null &&
      (first.text != (account!['first_name'] ?? '') ||
          last.text != (account!['last_name'] ?? '') ||
          address.text != (account!['address'] ?? ''));
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.service.fetchAccount(widget.session);
      if (mounted) {
        setState(() {
          account = data;
          first.text = (data['first_name'] ?? '').toString();
          last.text = (data['last_name'] ?? '').toString();
          address.text = (data['address'] ?? '').toString();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          account = null;
          loading = false;
          error = 'Unable to load your profile. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> save() async {
    if (saving || !changed || first.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.service.saveAccountDetails(
        widget.session,
        firstName: first.text,
        lastName: last.text,
        address: address.text,
      );
      if (!mounted) return;
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your details are saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saveError = e is AppointmentDetailException
              ? e.message
              : 'Unable to save your details.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void undo() {
    setState(() {
      first.text = (account?['first_name'] ?? '').toString();
      last.text = (account?['last_name'] ?? '').toString();
      address.text = (account?['address'] ?? '').toString();
      saveError = null;
    });
  }

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          changed
              ? 'Unsaved profile changes will be lost. You will need to sign in again.'
              : 'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) widget.onSignOut();
  }

  Future<void> verifyEmail() async {
    final code = TextEditingController();
    bool sent = false, busy = false;
    String? failure;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: _cream,
          title: const Text('Verify your email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((account?['email'] ?? '').toString()),
              const SizedBox(height: 12),
              Text(
                sent
                    ? 'Enter the six-digit code sent to your email.'
                    : 'Send a verification code to your account email.',
              ),
              if (sent)
                TextField(
                  controller: code,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                ),
              if (failure != null)
                Text(failure!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialog(() {
                        busy = true;
                        failure = null;
                      });
                      try {
                        await widget.service.sendAccountEmailCode(
                          widget.session,
                        );
                        if (context.mounted) {
                          setDialog(() {
                            sent = true;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() {
                            failure = e is AppointmentDetailException
                                ? e.message
                                : 'Unable to send verification code.';
                          });
                        }
                      } finally {
                        if (context.mounted) {
                          setDialog(() {
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(sent ? 'Resend code' : 'Send code'),
            ),
            if (sent)
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setDialog(() {
                          busy = true;
                          failure = null;
                        });
                        try {
                          await widget.service.verifyAccountEmail(
                            widget.session,
                            code.text.trim(),
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          final fresh = await widget.service.fetchAccount(
                            widget.session,
                          );
                          if (mounted) {
                            setState(() {
                              account = fresh;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setDialog(() {
                              failure = e is AppointmentDetailException
                                  ? e.message
                                  : 'Verification failed.';
                            });
                          }
                        } finally {
                          if (context.mounted) {
                            setDialog(() {
                              busy = false;
                            });
                          }
                        }
                      },
                child: const Text('Verify'),
              ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      code.dispose();
    });
  }

  String roleLabel(String value) => switch (value.toLowerCase()) {
    'doctor' => 'Doctor',
    'hospital_admin' => 'Hospital administrator',
    'pharmacist' => 'Pharmacist',
    'lab_technician' => 'Laboratory technician',
    'patient' => 'Patient',
    _ =>
      value.isEmpty ? 'Account role unavailable' : value.replaceAll('_', ' '),
  };
  String dateLabel(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not available';
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

  Widget panel(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE1E6DC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  Widget editor() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_outline, color: _green, size: 25),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your details',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Shown to colleagues on records you create, and on printed letters.',
                      style: TextStyle(color: _muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE1E6DC)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final inputs = [
                    TextField(
                      controller: first,
                      enabled: !saving,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'First name *',
                      ),
                    ),
                    TextField(
                      controller: last,
                      enabled: !saving,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ];
                  return constraints.maxWidth >= 500
                      ? Row(
                          children: [
                            Expanded(child: inputs[0]),
                            const SizedBox(width: 14),
                            Expanded(child: inputs[1]),
                          ],
                        )
                      : Column(
                          children: [
                            inputs[0],
                            const SizedBox(height: 14),
                            inputs[1],
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: address,
                enabled: !saving,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        if (saveError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(saveError!, style: const TextStyle(color: Colors.red)),
          ),
        const Divider(height: 1, color: Color(0xFFE1E6DC)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: saving || !changed ? null : undo,
                child: const Text('Undo'),
              ),
              FilledButton(
                onPressed: saving || !changed || first.text.trim().isEmpty
                    ? null
                    : save,
                style: FilledButton.styleFrom(backgroundColor: _green),
                child: Text(saving ? 'Saving…' : 'Save details'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget summary() {
    final data = account!;
    final name = (data['full_name'] ?? widget.session.name).toString();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    final hospital = data['hospital'];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFFD9F3E7),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7ED),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBBDDCB)),
                  ),
                  child: Text(
                    roleLabel((data['role'] ?? '').toString()),
                    style: const TextStyle(color: _green),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hospital is Map
                      ? (hospital['name'] ?? 'Hospital unavailable').toString()
                      : 'Hospital unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE1E6DC)),
          info(
            'Email',
            (data['email'] ?? widget.session.email).toString(),
            action: data['is_email_verified'] == false
                ? TextButton(
                    onPressed: saving ? null : verifyEmail,
                    child: const Text('Verify'),
                  )
                : null,
          ),
          info('Mobile', data['phone']?.toString() ?? 'Not available'),
          info('Member since', dateLabel(data['created_at'])),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your email and mobile are how you sign in, so an administrator changes them.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget info(String label, String value, {Widget? action}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E6DC))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: _ink, fontSize: 13),
              ),
            ),
            ?action,
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: _green, surface: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
    ),
    child: ColoredBox(
      color: _cream,
      child: RefreshIndicator(
        color: _green,
        onRefresh: saving ? () async {} : load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [
                    (0, 'Profile'),
                    (1, 'Sign-in & security'),
                    (2, 'Notifications'),
                  ])
                    InkWell(
                      onTap: saving
                          ? null
                          : () => setState(() {
                              tab = item.$1;
                            }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tab == item.$1
                                  ? _green
                                  : const Color(0xFFE1E6DC),
                              width: tab == item.$1 ? 2 : 1,
                            ),
                          ),
                        ),
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            color: tab == item.$1 ? _green : _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null)
              panel(
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(onPressed: load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            if (!loading && account != null)
              if (tab == 0)
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 850
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: editor()),
                            const SizedBox(width: 20),
                            Expanded(child: summary()),
                          ],
                        )
                      : Column(
                          children: [
                            editor(),
                            const SizedBox(height: 18),
                            summary(),
                          ],
                        ),
                )
              else if (tab == 1)
                AccountSecurityPanel(
                  session: widget.session,
                  service: widget.service,
                  account: account!,
                  onPasswordChanged: widget.onSignOut,
                )
              else
                AccountNotificationsPanel(
                  session: widget.session,
                  service: widget.service,
                ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: saving ? null : signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
