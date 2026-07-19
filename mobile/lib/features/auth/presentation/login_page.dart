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
  final _formKey = GlobalKey<FormState>();
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

  /// Validate username theo business rules:
  /// - Không được để trống
  /// - Không chứa khoảng trắng (username là định danh, không nên có space)
  /// - Tối đa 20 ký tự (khớp backend LoginDto @MaxLength(20))
  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username is required.';
    if (v.contains(' ')) return 'Username must not contain spaces.';
    if (v.length > 20) return 'Username must not exceed 20 characters.';
    return null;
  }

  /// Validate password theo business rules:
  /// - Không được để trống
  /// - Tối thiểu 6 ký tự (best-practice bảo mật)
  /// - Tối đa 20 ký tự (khớp backend LoginDto @MaxLength(20))
  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    if (v.length > 20) return 'Password must not exceed 20 characters.';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    // Chạy validate form trước khi gọi API.
    if (!_formKey.currentState!.validate()) return;

    final username = _user.text.trim();
    final password = _pass.text;

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
      // Thành công: router redirect tự đưa sang /home.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          _BrandHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel('Username'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: _validateUsername,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: 'cashier.linh',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      validator: _validatePassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 36, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Brew & Co.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'COUNTER POS',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 3),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
