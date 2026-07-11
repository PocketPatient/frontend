import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(authNotifierProvider, (_, next) {
      if (next.hasError && mounted) {
        final msg = _friendlyError(next.error!);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }
    final msg = error.toString();
    if (msg.contains('Sign-in cancelled')) return 'Sign-in cancelled.';
    if (msg.contains('403') || msg.contains('rutgers')) {
      return 'Only @rutgers.edu or @scarletmail.rutgers.edu emails are allowed.';
    }
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Cannot reach server. Is the backend running?';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    if (_isRegistering) {
      await notifier.register(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _displayNameCtrl.text.trim(),
      );
    } else {
      await notifier.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    final inputCtrl = TextEditingController(text: email);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: inputCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send reset link')),
        ],
      ),
    );
    if (confirmed == true && inputCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await ref
            .read(authNotifierProvider.notifier)
            .sendPasswordReset(inputCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send reset email.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo & title
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFCC0033),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Image.asset('assets/icon/icon_foreground.png'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pocket Patient v2',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCC0033),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rutgers University Clinical Simulation',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Google sign-in
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref
                        .read(authNotifierProvider.notifier)
                        .signInWithGoogle(),
                icon: const _GoogleLogo(),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.grey),
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 24),

              // Email / password form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Display name — registration only
                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _displayNameCtrl,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'e.g. Jane Smith',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Rutgers email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: _isRegistering
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted:
                          _isRegistering ? null : (_) => _submitEmailForm(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (_isRegistering && v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    // Confirm password — registration only
                    if (_isRegistering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitEmailForm(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Forgot password (sign-in mode only)
                    if (!_isRegistering)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Submit button
                    FilledButton(
                      onPressed: isLoading ? null : _submitEmailForm,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isRegistering ? 'Create account' : 'Sign in',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle register / sign-in
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegistering
                              ? 'Already have an account?'
                              : "Don't have an account?",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() {
                                    _isRegistering = !_isRegistering;
                                    _displayNameCtrl.clear();
                                    _confirmPasswordCtrl.clear();
                                    _formKey.currentState?.reset();
                                  }),
                          child: Text(_isRegistering ? 'Sign in' : 'Register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple coloured "G" that approximates Google branding without an SVG package.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
