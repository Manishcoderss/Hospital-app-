import 'patient_home.dart';
import 'patient_mock_data.dart';
import 'patient_registration_demo.dart';
export 'patient_mock_data.dart';
export 'patient_home.dart' show PatientDashboard;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Standalone demo entry point.
// Run with:
// flutter run -t lib/patient/patient_login.dart
void main() {
  runApp(const PatientDemoApp());
}

class PatientDemoApp extends StatelessWidget {
  const PatientDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00B4C5);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Samagati Patient',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: const Color(0xFFF6F9FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E8EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: teal, width: 1.5),
          ),
        ),
      ),
      home: const PatientLoginPage(),
    );
  }
}

class PatientLoginPage extends StatefulWidget {
  const PatientLoginPage({super.key});

  @override
  State<PatientLoginPage> createState() => _PatientLoginPageState();
}

class _PatientLoginPageState extends State<PatientLoginPage> {
  static const teal = Color(0xFF008779);
  static const dark = Color(0xFF0B1529);

  final _formKey = GlobalKey<FormState>();
  final _otpFieldKey = GlobalKey<FormFieldState<String>>();

  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool _otpMode = true;
  bool _otpSent = false;
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  MockPatient? _findPatient(String value) {
    final input = value.trim().toLowerCase();

    for (final patient in mockPatients) {
      if (patient.phone == input || patient.email.toLowerCase() == input) {
        return patient;
      }
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAccount() async {
    final patient = await Navigator.of(context).push<MockPatient>(
      MaterialPageRoute(builder: (_) => const PatientRegistrationDemo()),
    );
    if (patient == null || !mounted) return;
    setState(() {
      _mobile.text = patient.phone;
      _otpMode = true;
      _otpSent = false;
      _otp.clear();
    });
    _showMessage('Demo account created. Send OTP to sign in.');
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    // Simulate an API request.
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final patient = _findPatient(_mobile.text);

    if (patient == null) {
      setState(() => _loading = false);
      _showMessage(
        'Demo account not found. Use 9876543210 or tap Create Account to register your number.',
      );
      return;
    }

    if (_otpMode && !_otpSent) {
      setState(() {
        _otpSent = true;
        _loading = false;
      });

      _showMessage('Demo OTP: 123456');
      return;
    }

    final valid = _otpMode
        ? _otp.text.trim() == '123456'
        : _password.text == 'Patient@123';

    setState(() => _loading = false);

    if (!valid) {
      _showMessage(
        _otpMode ? 'Invalid OTP. Use 123456.' : 'Incorrect password.',
      );
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PatientDashboard(patient: patient)),
    );
  }

  Widget _tab(String label, bool otp) {
    final selected = _otpMode == otp;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _loading || selected
            ? null
            : () => setState(() {
                _otpMode = otp;
                _otpSent = false;
                _otp.clear();
                _password.clear();
                _hidePassword = true;
                if (otp && !RegExp(r'^\d{10}$').hasMatch(_mobile.text.trim())) {
                  _mobile.clear();
                }
              }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0FBF7) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFB0E8DB) : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color(0x16249E8B),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                otp ? Icons.phone_iphone_rounded : Icons.lock_outline_rounded,
                color: selected ? teal : const Color(0xFF596A83),
                size: 19,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? teal : const Color(0xFF596A83),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      text,
      style: const TextStyle(
        color: dark,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _accountLink() => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFFDFE3E9))),
      const SizedBox(width: 10),
      Flexible(
        flex: 7,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(color: Color(0xFF71829B), fontSize: 12),
            ),
            TextButton(
              onPressed: _loading ? null : _createAccount,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  color: teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: Color(0xFFDFE3E9))),
    ],
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: teal),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFEFEFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFD4DAE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF20AE9B), width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF8A9BB3), fontSize: 14),
        errorMaxLines: 2,
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFFFFCF5),
      body: CustomPaint(
        painter: const _PatientLoginBackdrop(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    minHeight: (bounds.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        const Center(
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: CustomPaint(painter: _PatientMedicalLogo()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Welcome back to',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: dark,
                            fontSize: 19,
                            height: 1.3,
                          ),
                        ),
                        const Text(
                          'Samagati',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF003F3B),
                            fontSize: 40,
                            height: 1.1,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your health, simplified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF71829B),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFCFFFFFF),
                            borderRadius: BorderRadius.circular(27),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x173F5030),
                                blurRadius: 34,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Patient Login',
                                  style: TextStyle(
                                    color: dark,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Access your care securely.',
                                  style: TextStyle(
                                    color: Color(0xFF687B96),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F6),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFEAEBED),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _tab('Mobile OTP', true),
                                      _tab('Password', false),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 21),
                                _label(
                                  _otpMode
                                      ? 'Mobile Number'
                                      : 'Email or Mobile Number',
                                ),
                                TextFormField(
                                  key: ValueKey('patient-identifier-$_otpMode'),
                                  controller: _mobile,
                                  enabled: !_loading,
                                  keyboardType: _otpMode
                                      ? TextInputType.phone
                                      : TextInputType.emailAddress,
                                  inputFormatters: _otpMode
                                      ? [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ]
                                      : null,
                                  style: const TextStyle(
                                    color: dark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _otpMode
                                        ? 'Enter mobile number'
                                        : 'Email or mobile',
                                    prefixIcon: _otpMode
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                              right: 10,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.phone_iphone_rounded,
                                                  color: Color(0xFF596A83),
                                                  size: 21,
                                                ),
                                                Container(
                                                  width: 1,
                                                  height: 21,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                  color: const Color(
                                                    0xFFD4DAE5,
                                                  ),
                                                ),
                                                const Text(
                                                  '+91',
                                                  style: TextStyle(
                                                    color: dark,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 18,
                                                  color: Color(0xFF596A83),
                                                ),
                                                Container(
                                                  width: 1,
                                                  height: 24,
                                                  margin: const EdgeInsets.only(
                                                    left: 10,
                                                  ),
                                                  color: const Color(
                                                    0xFFD4DAE5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_outline,
                                            color: Color(0xFF596A83),
                                          ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0,
                                      minHeight: 0,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {
                                    if (_otpSent) {
                                      _otpSent = false;
                                      _otp.clear();
                                    }
                                  }),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'This field is required';
                                    }
                                    if (_otpMode &&
                                        !RegExp(r'^\d{10}$')
                                            .hasMatch(value.trim())) {
                                      return 'Enter a valid 10-digit mobile number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _otpMode
                                      ? "We'll send a 6-digit verification code."
                                      : 'Use your patient account password.',
                                  style: const TextStyle(
                                    color: Color(0xFF71829B),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                if (_otpMode && _otpSent) ...[
                                  const SizedBox(height: 20),
                                  _label('Verification Code'),
                                  TextFormField(
                                    key: _otpFieldKey,
                                    controller: _otp,
                                    enabled: !_loading,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 22,
                                      letterSpacing: 5,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '6-digit OTP',
                                    ),
                                    validator: (v) => (v ?? '').length == 6
                                        ? null
                                        : 'Enter 6-digit OTP',
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              _otpFieldKey.currentState
                                                  ?.reset();
                                              _otp.clear();
                                              _showMessage('Demo OTP: 123456');
                                            },
                                      child: const Text('Resend OTP'),
                                    ),
                                  ),
                                ],
                                if (!_otpMode) ...[
                                  const SizedBox(height: 20),
                                  _label('Password'),
                                  TextFormField(
                                    key: const ValueKey('patient-password'),
                                    controller: _password,
                                    enabled: !_loading,
                                    obscureText: _hidePassword,
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 18,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your password',
                                      suffixIcon: IconButton(
                                        tooltip: _hidePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setState(
                                          () => _hidePassword = !_hidePassword,
                                        ),
                                        icon: Icon(
                                          _hidePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Enter your password'
                                        : null,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _showMessage(
                                        'Demo password: Patient@123. You can also sign in with OTP 123456.',
                                      ),
                                      child: const Text('Forgot Password?'),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x29239D86),
                                        blurRadius: 20,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(17),
                                    child: CustomPaint(
                                      painter: const _PatientLoginButtonPaint(),
                                      child: SizedBox(
                                        height: 56,
                                        width: double.infinity,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(17),
                                            ),
                                          ),
                                          onPressed: _loading ? null : _submit,
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        _otpMode
                                                            ? (_otpSent
                                                                  ? 'Verify & Login'
                                                                  : 'Send OTP')
                                                            : 'Login',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _accountLink(),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEEF7F2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_user_outlined,
                                        color: teal,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    const Flexible(
                                      child: Text(
                                        'Secure & private sign in',
                                        style: TextStyle(
                                          color: Color(0xFF596A83),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: const Color(0x99F8F0DE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                color: Color(0xFF20A48F),
                                size: 30,
                              ),
                              Container(
                                height: 48,
                                width: 1,
                                color: const Color(0xFFD8D8D3),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                ),
                              ),
                              const Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            'Demo Credentials (for testing)\n',
                                      ),
                                      TextSpan(
                                        text: 'OTP: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: '9876543210 / 123456\n'),
                                      TextSpan(
                                        text: 'Password: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: 'Patient@123'),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: Color(0xFF687B96),
                                    fontSize: 11,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PatientLoginButtonPaint extends CustomPainter {
  const _PatientLoginButtonPaint();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2CC3AE), Color(0xFF008575)],
        ).createShader(rect),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * .24, 0)
        ..quadraticBezierTo(
          size.width * .08,
          size.height * .55,
          size.width * .03,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = const Color(0x16FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatientMedicalLogo extends CustomPainter {
  const _PatientMedicalLogo();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final cross = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(31, 1, 37, 91),
          const Radius.circular(13),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 31, 91, 37),
          const Radius.circular(13),
        ),
      );
    canvas.drawPath(
      cross,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF48C5A0), Color(0xFF00899C)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    final leaf = Path()
      ..moveTo(36, 99)
      ..cubicTo(31, 49, 55, 34, 96, 30)
      ..cubicTo(100, 58, 89, 67, 68, 71)
      ..cubicTo(56, 74, 61, 94, 36, 99)
      ..close();
    canvas.drawPath(
      leaf,
      Paint()
        ..color = const Color(0xFFFFFCF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFADD889), Color(0xFF008C9E)],
        ).createShader(const Rect.fromLTWH(30, 30, 70, 70)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatientLoginBackdrop extends CustomPainter {
  const _PatientLoginBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFCF5),
    );
    final wash = Paint()..color = const Color(0x66F5E6C3);
    canvas.drawOval(Rect.fromLTWH(-w * .44, -h * .18, w * 1.02, h * .34), wash);
    canvas.drawOval(
      Rect.fromLTWH(-w * .46, h * .09, w * .98, h * .25),
      Paint()..color = const Color(0x44F3E3BF),
    );
    canvas.drawOval(Rect.fromLTWH(w * .74, -h * .10, w * .8, h * .23), wash);
    canvas.drawPath(
      Path()
        ..moveTo(w, h * .75)
        ..quadraticBezierTo(w * .75, h * .92, w * .5, h)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = const Color(0x44F5E6C3),
    );
    canvas.drawCircle(
      Offset(w * .1, h * .195),
      w * .019,
      Paint()..color = const Color(0x99EDD29F),
    );
    canvas.drawCircle(
      Offset(w * .75, h * .085),
      w * .01,
      Paint()..color = const Color(0x99EDD29F),
    );
    final stem = Path()
      ..moveTo(w * 1.03, h * .30)
      ..quadraticBezierTo(w * .90, h * .21, w * .92, h * .08);
    canvas.drawPath(
      stem,
      Paint()
        ..color = const Color(0x99898E58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    void leaf(Offset base, Offset tip, double width) {
      final center = Offset((base.dx + tip.dx) / 2, (base.dy + tip.dy) / 2);
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(center.dx - width, center.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(center.dx + width, center.dy, base.dx, base.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x448A925E), Color(0x889AA36C)],
          ).createShader(Rect.fromPoints(base, tip).inflate(width)),
      );
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0x33898E58)
          ..strokeWidth = .7,
      );
    }

    leaf(Offset(w * .925, h * .16), Offset(w * .95, h * .075), w * .045);
    leaf(Offset(w * .955, h * .22), Offset(w * .81, h * .135), w * .045);
    leaf(Offset(w * .995, h * .275), Offset(w * .78, h * .225), w * .055);
    leaf(Offset(w * .995, h * .26), Offset(w * 1.04, h * .17), w * .045);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
