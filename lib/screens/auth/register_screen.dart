import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedUserType = 'customer';

  bool _isLoading = false;
  bool _obscure = true; // UI only: toggle password visibility

  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      await AuthService().registerUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedUserType,
      );

      // If register signs the user in (usual flow), log them into OneSignal
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        OneSignal.login(uid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      await _redirectBasedOnRole(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
                    const SizedBox(height: 12),
                    Icon(Icons.app_registration_rounded,
                        size: 48, color: cs.primary),
                    const SizedBox(height: 10),
                    Text(
                      'Create your account',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign up to get started',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
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
                              textInputAction: TextInputAction.next,
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
                            const SizedBox(height: 12),

                            // Styled Dropdown
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'User Type',
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
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedUserType,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'customer',
                                        child: Text('Customer')),
                                    DropdownMenuItem(
                                        value: 'owner',
                                        child: Text('Restaurant Owner')),
                                  ],
                                  onChanged: (value) => setState(() =>
                                      _selectedUserType = value ?? 'customer'),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _register,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.app_registration_rounded),
                                label: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                      _isLoading ? 'Registering…' : 'Register'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text("Already have an account? Login"),
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
}
