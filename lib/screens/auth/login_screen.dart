import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true; // UI only: toggle password visibility

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Identify this device with OneSignal using Supabase uid
        OneSignal.login(user.id);

        final userModel = await AuthService().getUserDetails(user.id);
        if (userModel != null) {
          if (!mounted) return;
          await _redirectBasedOnRole(context);
        } else {
          throw 'User data not found in Supabase.';
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _redirectBasedOnRole(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    final data = await Supabase.instance.client
        .from('users')
        .select('user_type')
        .eq('uid', user.id)
        .maybeSingle();

    final type = data?['user_type'];

    if (!mounted) return;
    if (type == 'owner') {
      Navigator.pushNamedAndRemoveUntil(
          context, '/owner/dashboard', (r) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, '/customer/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Nice, subtle gradient background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withOpacity(0.35),
              cs.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // App mark / header
                    const SizedBox(height: 12),
                    Icon(Icons.restaurant_menu_rounded,
                        size: 48, color: cs.primary),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome back',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to continue',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Card with fields
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: "Email",
                                prefixIcon: const Icon(Icons.alternate_email),
                                filled: true,
                                fillColor: cs.surfaceVariant.withOpacity(0.18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: cs.primary, width: 1.5),
                                ),
                              ),
                              onSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(), // convenience
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor: cs.surfaceVariant.withOpacity(0.18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: cs.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: cs.primary, width: 1.5),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _login,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                      _isLoading ? 'Signing in…' : 'Login'),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Centered "Don't have an account? Register"
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/register'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text(
                                    "Don't have an account? Register"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Small footnote / tips
                    Text(
                      'Tip: Use the same device for quick push pairing via OneSignal.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
