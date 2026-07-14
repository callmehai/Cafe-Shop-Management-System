import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../auth/domain/app_user.dart';
import '../data/users_repository.dart';
import '../domain/managed_user.dart';

/// Quản lý người dùng (Figma "23 User Management"). Admin only.
class UsersManagementPage extends ConsumerWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'users-fab',
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserFormPage()));
          ref.invalidate(usersProvider);
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add user'),
      ),
      body: SafeArea(
        bottom: false,
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
          error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
          data: (list) {
            final active = list.where((u) => u.isActive).length;
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(usersProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  PageHeader(title: 'Users', subtitle: '${list.length} users · $active active'),
                  ...list.map((u) => _UserRow(
                        user: u,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserFormPage(user: u)));
                          ref.invalidate(usersProvider);
                        },
                      )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});
  final ManagedUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
          child: Text(user.initials, style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
        ),
        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('@${user.username} · ${user.role.label}', style: const TextStyle(fontSize: 13)),
        trailing: user.isActive
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('Inactive', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
      ),
    );
  }
}

/// Thêm/sửa user (Figma "24 User Details").
class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({super.key, this.user});
  final ManagedUser? user;

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  static const _roles = [UserRole.administrator, UserRole.manager, UserRole.cashier, UserRole.barista];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  final _password = TextEditingController();
  late UserRole _role;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.user?.fullName ?? '');
    _username = TextEditingController(text: widget.user?.username ?? '');
    _role = widget.user?.role ?? UserRole.cashier;
    _active = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'fullName': _fullName.text.trim(),
      'username': _username.text.trim(),
      'role': _role.api,
      'isActive': _active,
      if (_password.text.isNotEmpty) 'password': _password.text,
    };
    setState(() => _saving = true);
    try {
      final repo = ref.read(usersRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.user!.id, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(usersProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Deactivate user'),
        content: Text('Deactivate ${widget.user!.fullName}? They will no longer be able to sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(usersRepositoryProvider).deactivate(widget.user!.id);
      ref.invalidate(usersProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'Edit User' : 'Add User'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: _isEdit ? 'New password (leave blank to keep)' : 'Password'),
              validator: (v) {
                if (_isEdit) return null;
                if (v == null || v.length < 6) return 'Password must be at least 6 characters.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                activeColor: AppColors.terracotta,
                title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save user'),
            ),
            if (_isEdit && widget.user!.isActive) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deactivate,
                icon: const Icon(Icons.block, color: AppColors.danger),
                label: const Text('Deactivate user', style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
