import 'dart:ui';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_home.dart';
import 'remembered_session_store.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app_update_service.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService, this.sessionStore});
  final AuthService? authService;
  final RememberedSessionStore? sessionStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Hospital Login',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B6BA)),
      scaffoldBackgroundColor: const Color(0xFFF5F8F7),
    ),
    home: LoginPage(authService: authService, sessionStore: sessionStore),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authService, this.sessionStore});
  final AuthService? authService;
  final RememberedSessionStore? sessionStore;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _loading = false;
  bool _rememberMe = false;
  bool _retrySavedSignIn = false;
  late final AuthService _auth = widget.authService ?? AuthService();
  late final RememberedSessionStore _sessionStore =
      widget.sessionStore ?? RememberedSessionStore();

  @override
  void initState() {
    super.initState();
    _restoreSavedSignIn();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdate();
    });
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openHome(AuthSession session) {
    _password.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            DoctorHome(session: session, sessionStore: _sessionStore),
      ),
    );
  }

  Future<void> _restoreSavedSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _retrySavedSignIn = false;
    });
    try {
      final saved = await _sessionStore.read();
      if (saved == null || !mounted) return;
      setState(() {
        _username.text = saved.email;
        _rememberMe = true;
      });
      final session = await _auth.restoreSession(saved.refreshToken);
      if (session.role == 'patient') {
        throw const SessionRestoreException(
          'Please use patient sign-in. This login is for hospital staff.',
          invalidSession: true,
        );
      }
      try {
        await _sessionStore.save(session);
      } catch (_) {
        _message('Saved sign-in could not be updated on this device.');
      }
      if (mounted) _openHome(session);
    } on SessionRestoreException catch (error) {
      if (error.invalidSession) {
        try {
          await _sessionStore.clear();
        } catch (_) {
          /* Manual sign-in retries clearing the saved record. */
        }
      }
      if (mounted) {
        setState(() {
          _retrySavedSignIn = !error.invalidSession;
        });
        _message(error.message);
      }
    } catch (_) {
      // Storage can be unavailable on an unsupported/locked device. Manual
      // sign-in stays available; no cached session is trusted without the API.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _setRememberMe(bool value) async {
    if (_loading) return;
    setState(() {
      _rememberMe = value;
    });
    if (value) return;
    setState(() {
      _loading = true;
    });
    try {
      await _sessionStore.clear();
      if (mounted) {
        setState(() {
          _retrySavedSignIn = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rememberMe = true;
        });
      }
      _message('Unable to clear saved sign-in. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    final info = await AppUpdateService.checkForUpdate();

    if (!mounted || info == null || !info.updateAvailable) {
      return;
    }

    final storeUrl = FirebaseRemoteConfig.instance.getString(
      'android_store_url',
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (dialogContext) => PopScope(
        canPop: !info.forceUpdate,
        child: AlertDialog(
          title: Text(
            info.forceUpdate ? 'Update Required' : 'Update Available',
          ),
          content: Text(
            info.message.isNotEmpty
                ? info.message
                : 'A new version of Hospital App is available.',
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: storeUrl.isEmpty
                  ? null
                  : () async {
                      final uri = Uri.tryParse(storeUrl);
                      if (uri == null) return;

                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.authService == null) _auth.close();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      try {
        await _sessionStore.clear();
      } catch (_) {
        throw const LoginException(
          'Unable to clear the previous saved sign-in. Please try again.',
        );
      }
      final session = await _auth.login(_username.text, _password.text);
      if (!mounted) return;
      if (session.role == 'patient') {
        throw const LoginException(
          'Please use patient sign-in. This login is for hospital staff.',
        );
      }
      if (_rememberMe) {
        try {
          await _sessionStore.save(session);
        } catch (_) {
          _message(
            'Signed in, but Remember me could not be saved on this device.',
          );
        }
      }
      if (mounted) _openHome(session);
    } on LoginException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to sign in. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/doctor_tablet_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (bounds.maxHeight - 24).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _loginCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _loginCard() => Theme(
    data: ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008EAD)),
      inputDecorationTheme: InputDecorationTheme(
        prefixIconColor: const Color(0xFF52758C),
        suffixIconColor: const Color(0xFF52758C),
        filled: true,
        fillColor: const Color(0xBFFFFFFF),
        hintStyle: const TextStyle(color: Color(0xFF7C8FA2), fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6E4ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF009FB1), width: 2),
        ),
        errorMaxLines: 2,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xCFFFFFFF)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xDCFFFFFF), Color(0xBDE2F3FC)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20142327),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD5F3F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_hospital_outlined,
                        color: Color(0xFF00849D),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hospital Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF203D5B),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in securely to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF77899B), fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _username,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: Color(0xFF203D5B),
                      fontSize: 16,
                    ),
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Enter email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_loading,
                    style: const TextStyle(
                      color: Color(0xFF203D5B),
                      fontSize: 16,
                    ),
                    obscureText: _hidden,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    enableSuggestions: false,
                    autocorrect: false,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidden ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter your password'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Reset password'),
                                content: const Text(
                                  'Please contact your hospital administrator to reset your password.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Color(0xFF006D92)),
                      ),
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text('Remember me'),
                      subtitle: const Text('Keep me signed in on this device'),
                      value: _rememberMe,
                      onChanged: _loading
                          ? null
                          : (value) => _setRememberMe(value ?? false),
                    ),
                  ),
                  if (_retrySavedSignIn)
                    TextButton(
                      onPressed: _loading ? null : _restoreSavedSignIn,
                      child: const Text('Retry saved sign-in'),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [Color(0xFF003366), Color(0xFF286CAF)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33216DA7),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded, size: 22),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
