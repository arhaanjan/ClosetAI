import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/firebase_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _service = FirebaseService();
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _service.resetPassword(email: _emailCtrl.text.trim());
      setState(() {
        _isError = false;
        _message = 'Password reset link sent! Check your email.';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _message = e.toString().contains('user-not-found')
            ? 'No account found with this email.'
            : 'Failed to send reset link. Try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Form(key: _formKey, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text('Forgot your\npassword?',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 30,
                    fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 12),
            const Text('Enter your email address and we will send you instructions to reset your password.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 36),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 20)),
              validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 20),
            if (_message != null) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: (_isError ? Colors.red : AppColors.available).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (_isError ? Colors.red : AppColors.available).withOpacity(0.3))),
              child: Text(_message!,
                  style: TextStyle(color: _isError ? Colors.redAccent : AppColors.available, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Reset Link'),
            ),
          ],
        )),
      )),
    );
  }
}