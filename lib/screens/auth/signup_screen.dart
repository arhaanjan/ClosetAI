import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/firebase_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _service   = FirebaseService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _service.signUp(
        name:     _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // <-- ADD THIS BLOCK -->
      // Pop the signup screen off the stack so the AuthGate
      // underneath can reveal the HomeScreen!
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      setState(() => _error = e.toString().contains('email-already-in-use')
          ? 'Account already exists with this email.'
          : 'Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Form(key: _formKey, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text('Set up your\ncloset profile.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 30,
                    fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 36),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 20)),
              validator: (v) => v==null||v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 20)),
              validator: (v) => v==null||!v.contains('@') ? 'Enter valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => v==null||v.length<6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 20),
            if (_error != null) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _signUp,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account'),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account? ',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Sign In',
                    style: TextStyle(color: AppColors.accentLight,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ]),
          ],
        )),
      )),
    );
  }
}
