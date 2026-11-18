import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';

const _green = Color(0xFF207361),
    _ink = Color(0xFF20312D),
    _muted = Color(0xFF566963),
    _cream = Color(0xFFF7F3EA);
Widget _card(String title, List<Widget> children, {String? description}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE1E6DC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );

class AccountSecurityPanel extends StatefulWidget {
  const AccountSecurityPanel({
    super.key,
    required this.session,
    required this.service,
    required this.account,
    required this.onPasswordChanged,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final Map<String, dynamic> account;
  final VoidCallback onPasswordChanged;
  @override
  State<AccountSecurityPanel> createState() => _AccountSecurityPanelState();
}

class _AccountSecurityPanelState extends State<AccountSecurityPanel> {
  List<Map<String, dynamic>>? sessions, activity;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.service.fetchAccountSessions(widget.session),
        widget.service.fetchSecurityActivity(widget.session),
      ]);
      if (result[0]['sessions'] is! List || result[1]['logs'] is! List) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() {
          sessions = (result[0]['sessions'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          activity = (result[1]['logs'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to load sessions and security activity.';
        });
      }
    }
  }

  Future<void> changePassword() async {
    final current = TextEditingController(),
        next = TextEditingController(),
        confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: _cream,
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You will be signed out and need to sign in with your new password.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: current,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: next,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 8 ||
                          !RegExp(r'[A-Z]').hasMatch(text) ||
                          !RegExp(r'[a-z]').hasMatch(text) ||
                          !RegExp(r'\d').hasMatch(text) ||
                          !RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
                        return 'Use 8+ characters, uppercase, lowercase, number and symbol';
                      }
                      if (text == current.text) {
                        return 'Choose a different password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirm,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (value) =>
                        value != next.text ? 'Passwords do not match' : null,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(form.currentState?.validate() ?? false)) return;
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await widget.service.changeAccountPassword(
                          widget.session,
                          current.text,
                          next.text,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) widget.onPasswordChanged();
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() {
                            error = e is AppointmentDetailException
                                ? e.message
                                : 'Unable to change password.';
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
              child: Text(busy ? 'Changing…' : 'Change password'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      current.dispose();
      next.dispose();
      confirm.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _card('Password', [
        Text(
          widget.account['password_changed_at'] == null
              ? 'Password change date is unavailable.'
              : 'Last changed: ${widget.account['password_changed_at']}',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: changePassword,
            child: const Text('Change password'),
          ),
        ),
      ], description: 'Changing your password signs you out on every device.'),
      _card('Two-step sign-in', [
        Text(
          widget.account['is_2fa_enabled'] == true
              ? 'On · ${widget.account['tfa_method'] == 'totp' ? 'Authenticator app' : 'Email code'}'
              : widget.account['is_2fa_enabled'] == false
              ? 'Off · Password sign-in'
              : 'Status unavailable',
          style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
        ),
      ]),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      if (error != null)
        _card('Sessions & activity', [
          Text(error!),
          TextButton(onPressed: load, child: const Text('Retry')),
        ]),
      if (!loading && error == null) ...[
        _card('Signed-in devices', [
          if (sessions?.isEmpty == true)
            const Text('No active sessions returned.'),
          for (final session in sessions ?? <Map<String, dynamic>>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_outlined, color: _green),
              title: Text(
                (session['device_name'] ??
                        session['user_agent'] ??
                        'Signed-in device')
                    .toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                (session['last_active_at'] ?? session['created_at'] ?? '')
                    .toString(),
              ),
              trailing: session['is_current'] == true
                  ? const Text('This device', style: TextStyle(color: _green))
                  : null,
            ),
        ]),
        _card('Recent security activity', [
          if (activity?.isEmpty == true) const Text('No activity returned.'),
          for (final event in activity ?? <Map<String, dynamic>>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined, color: _green),
              title: Text(
                (event['action'] ?? 'Security event').toString().replaceAll(
                  '_',
                  ' ',
                ),
              ),
              subtitle: Text((event['created_at'] ?? '').toString()),
            ),
        ]),
      ],
    ],
  );
}

class AccountNotificationsPanel extends StatefulWidget {
  const AccountNotificationsPanel({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<AccountNotificationsPanel> createState() =>
      _AccountNotificationsPanelState();
}

class _AccountNotificationsPanelState extends State<AccountNotificationsPanel> {
  Map<String, dynamic>? data, original;
  String? error;
  bool loading = true, saving = false;
  bool get changed =>
      data != null &&
      original != null &&
      data!.keys.any((key) => data![key] != original![key]);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.service.fetchNotificationPreferences(
        widget.session,
      );
      const required = [
        'email_notifications',
        'sms_notifications',
        'push_notifications',
        'appointment_alerts',
        'prescription_alerts',
        'lab_alerts',
        'billing_alerts',
      ];
      if (required.any((key) => result[key] is! bool)) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(result);
          original = Map<String, dynamic>.from(result);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to load notification settings. Please retry.';
        });
      }
    }
  }

  Future<void> save() async {
    if (saving || data == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.saveNotificationPreferences(widget.session, data!);
      if (!mounted) return;
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to save notification settings.';
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

  Future<void> pickTime(String key) async {
    final raw = data?[key]?.toString();
    final parts = raw?.split(':');
    final initial = parts != null && parts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 22, minute: 0);
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time != null && mounted) {
      setState(() {
        data![key] =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Widget toggle(String key, String title, String description) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      title,
      style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      description,
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    value: data![key] == true,
    onChanged: saving
        ? null
        : (value) => setState(() {
            data![key] = value;
          }),
  );
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (data == null) {
      return _card('Notifications', [
        Text(error ?? 'Settings unavailable'),
        TextButton(onPressed: load, child: const Text('Retry')),
      ]);
    }
    return Column(
      children: [
        _card(
          'How to reach you',
          [
            toggle(
              'email_notifications',
              'Email',
              'Summaries and alerts to your inbox',
            ),
            toggle(
              'sms_notifications',
              'Text message',
              'Urgent alerts to your mobile',
            ),
            toggle(
              'push_notifications',
              'Push',
              'Allow alerts on registered devices',
            ),
          ],
          description: 'In-app notifications always appear. These are extra ways to reach you.',
        ),
        _card('What about', [
          toggle(
            'appointment_alerts',
            'Appointments',
            'Bookings, changes and cancellations',
          ),
          toggle(
            'prescription_alerts',
            'Prescriptions',
            'Issued, dispensed and ready to collect',
          ),
          toggle(
            'lab_alerts',
            'Lab results',
            'Results reported and abnormal values',
          ),
          toggle(
            'billing_alerts',
            'Billing',
            'Bills issued and payments received',
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Security'),
            subtitle: Text(
              'Sign-ins, password and account changes are always sent.',
            ),
            trailing: Icon(Icons.lock_outline, color: _green),
          ),
        ]),
        _card(
          'Quiet hours',
          [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => pickTime('quiet_hours_start'),
                  child: Text(
                    'From: ${data!['quiet_hours_start'] ?? 'Not set'}',
                  ),
                ),
                OutlinedButton(
                  onPressed: saving ? null : () => pickTime('quiet_hours_end'),
                  child: Text(
                    'Until: ${data!['quiet_hours_end'] ?? 'Not set'}',
                  ),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          data!['quiet_hours_start'] = null;
                          data!['quiet_hours_end'] = null;
                        }),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
          description: 'Hold non-urgent push, email and texts overnight. Set both times, or leave both empty.',
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: saving || !changed
                  ? null
                  : () => setState(() {
                      data = Map<String, dynamic>.from(original!);
                      error = null;
                    }),
              child: const Text('Undo'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: saving || !changed ? null : save,
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: Text(saving ? 'Saving…' : 'Save settings'),
            ),
          ],
        ),
      ],
    );
  }
}
