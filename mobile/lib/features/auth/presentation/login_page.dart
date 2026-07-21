import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auth_controller.dart';

/// Màn Login (Figma "01 Login default"). UC10 — MSG09 khi sai thông tin.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

<<<<<<< Updated upstream
  Future<void> _submit() async {
    if (_submitting) return;
=======
  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required.';
    if (v.contains(' ')) return 'Username must not contain spaces.';
    if (v.length > 20) return 'Username must not exceed 20 characters.';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    if (v.length > 20) return 'Password must not exceed 20 characters.';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) return;

>>>>>>> Stashed changes
    final username = _user.text.trim();
    final password = _pass.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your user name and password.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    await ref.read(authControllerProvider.notifier).login(username, password);
    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    setState(() {
      _submitting = false;
      if (state.hasError) {
        _error = apiErrorMessage(
          state.error!,
          fallback: 'Incorrect user name or password. Please check again.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
<<<<<<< Updated upstream
      body: Column(
        children: [
          _BrandHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Username'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'cashier.linh',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(_error!),
=======
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _BrandHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: _validateUsername,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'cashier.linh',
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 22),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      validator: _validatePassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 22),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(_error!),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.terracotta.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.terracotta,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Trouble signing in? Ask your manager.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 60),
                    const Center(
                      child: Text(
                        '${AppConstants.appVersionLabel} · ${AppConstants.storeLabel}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5),
                      ),
                    ),
>>>>>>> Stashed changes
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Trouble signing in? Ask your manager.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Center(
                    child: Text(
                      '${AppConstants.appVersionLabel} · ${AppConstants.storeLabel}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: const Color(0xFF382B24),
      padding: EdgeInsets.fromLTRB(24, topPadding + 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A3B33),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Brew & Co.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'COUNTER POS',
                  style: TextStyle(
                    color: Color(0xFFAD9C92),
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Username',
            style: TextStyle(
              color: Color(0xFF9E8E84),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

