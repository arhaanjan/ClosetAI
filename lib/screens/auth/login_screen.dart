import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/firebase_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart'; // <-- Add this


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _service = FirebaseService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _loginWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _service.signInWithGoogle();
      // Navigation is handled by authStateChanges in main.dart
    } catch (e) {
      setState(() => _error = 'Google login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    }

  String _friendly(String e) {
    if (e.contains('user-not-found')) return 'No account with this email.';
    if (e.contains('wrong-password')) return 'Incorrect password.';
    if (e.contains('invalid-email')) return 'Enter a valid email.';
    if (e.contains('too-many-requests')) return 'Too many attempts. Try later.';
    return 'Login failed. Please try again.';
  }

  @override void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Form(key: _formKey, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),

            Image.asset(
                'assets/images/inside.png',
                width: 250, // Optional: Set width
                height: 250, // Optional: Set height
                fit: BoxFit.contain,),

            const SizedBox(height: 6),
            const Text('Your smart wardrobe, organized.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 52),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Email',
                  prefixIcon: Icon(
                      Icons.mail_outline, color: AppColors.textMuted,
                      size: 20)),
              validator: (v) =>
              v == null || !v.contains('@')
                  ? 'Enter valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(
                    Icons.lock_outline, color: AppColors.textMuted, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons
                      .visibility_outlined,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
              v == null || v.length < 6
                  ? 'Min 6 characters'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentLight,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                ),
                child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Don\'t have an account? ',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: () =>
                    Navigator.push(context,
                        MaterialPageRoute(builder: (
                            _) => const SignupScreen())),
                child: const Text('Sign Up',
                    style: TextStyle(color: AppColors.accentLight,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.2))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.2))),
            ]),

            const SizedBox(height: 40),

            OutlinedButton(
              onPressed: _loading ? null : _loginWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.deepPurple.withOpacity(0.7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png' , height: 28),
                  const SizedBox(width: 12),
                  const Text('Continue with Google',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),

          ],
        )),
      )),
    );
  }
}