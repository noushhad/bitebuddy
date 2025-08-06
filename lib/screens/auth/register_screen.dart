import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  void _register() async {
    setState(() => _isLoading = true);

    try {
      await AuthService().registerUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedUserType,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      if (context.mounted) await _redirectBasedOnRole(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
      appBar: AppBar(title: const Text("Register")),
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
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _selectedUserType,
              onChanged: (value) =>
                  setState(() => _selectedUserType = value ?? 'customer'),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
                DropdownMenuItem(
                    value: 'owner', child: Text('Restaurant Owner')),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register, child: const Text("Register")),
          ],
        ),
      ),
    );
  }
}
