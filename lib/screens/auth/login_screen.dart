import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        final userModel = await AuthService().getUserDetails(user.id);
        if (userModel != null) {
          await _redirectBasedOnRole(context);
        } else {
          throw 'User data not found in Supabase.';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _redirectBasedOnRole(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    final data = await Supabase.instance.client
        .from('users')
        .select('user_type')
        .eq('uid', user.id)
        .maybeSingle();

    final type = data?['user_type'];

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
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text("Login"),
                  ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
