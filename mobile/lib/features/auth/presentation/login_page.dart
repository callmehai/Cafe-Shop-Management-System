import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Mẫu màn Login theo SRS §3.2 (username/password). MSG09 khi sai.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    // TODO: gọi AuthRepository.login(...) qua provider; nếu lỗi -> MSG09.
    // Tạm thời điều hướng thẳng để demo flow.
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CSMS', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(controller: _user, decoration: const InputDecoration(labelText: 'User Name')),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _submit, child: const Text('Login')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
