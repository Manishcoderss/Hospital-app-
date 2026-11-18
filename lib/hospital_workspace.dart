import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_home.dart';
import 'remembered_session_store.dart';
import 'hospital_theme.dart';
import 'hospital_api.dart';
import 'hospital_modules.dart';
import 'patient_portal.dart';
import 'main.dart' show LoginPage;

class HospitalWorkspace extends StatefulWidget {
  const HospitalWorkspace({
    super.key,
    required this.session,
    this.sessionStore,
  });
  final AuthSession session;
  final RememberedSessionStore? sessionStore;
  @override
  State<HospitalWorkspace> createState() => _HospitalWorkspaceState();
}

class _HospitalWorkspaceState extends State<HospitalWorkspace> {
  late final api = HospitalApi(widget.session);
  bool signingOut = false;
  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> signOut() async {
    if (signingOut) return;
    signingOut = true;
    try {
      await api.execute({'method': 'POST', 'path': '/auth/logout'});
    } catch (_) {
      /* Always clear local access even if remote revocation is unavailable. */
    }
    try {
      await (widget.sessionStore ?? RememberedSessionStore()).clear();
    } catch (_) {
      signingOut = false;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to clear saved sign-in. Please retry sign out.',
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(sessionStore: widget.sessionStore),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.session.role.toLowerCase();
    return Theme(
      data: HospitalTheme.data,
      child: role == 'patient'
          ? PatientPortal(session: widget.session, api: api, onSignOut: signOut)
          : ['doctor', 'hospital_admin'].contains(role)
          ? DoctorHome(
              session: widget.session,
              sessionStore: widget.sessionStore,
            )
          : Scaffold(
              appBar: AppBar(
                title: const Text('Samagati'),
                actions: [
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: signOut,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              body: HospitalModulesPage(api: api),
            ),
    );
  }
}

class HospitalServicesHost extends StatefulWidget {
  const HospitalServicesHost({super.key, required this.session});
  final AuthSession session;
  @override
  State<HospitalServicesHost> createState() => _HospitalServicesHostState();
}

class _HospitalServicesHostState extends State<HospitalServicesHost> {
  late final api = HospitalApi(widget.session);
  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: HospitalTheme.data,
    child: HospitalModulesPage(api: api),
  );
}
