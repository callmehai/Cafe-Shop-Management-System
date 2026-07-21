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
      floatingActionButton: FloatingActionButton(
        heroTag: 'users-fab',
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserFormPage()));
          ref.invalidate(usersProvider);
        },
        child: const Icon(Icons.add, size: 28),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildRoleCard(UserRole role) {
    final isSelected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAF0E6) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.terracotta : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                role.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isSelected ? AppColors.terracottaDark : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
<<<<<<< Updated upstream
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
=======
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.close, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit User' : 'Add User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isEdit && widget.user!.isActive)
                    IconButton(
                      onPressed: _deactivate,
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 24),
                      tooltip: 'Deactivate user',
                    )
                  else
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 24),
                    ),
                ],
>>>>>>> Stashed changes
              ),
            ),
            // Form body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _buildFieldLabel('Full name'),
                    TextFormField(
                      controller: _fullName,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Full name',
                        fillColor: AppColors.surfaceAlt,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Username'),
                    TextFormField(
                      controller: _username,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 20),
                        hintText: 'Username',
                        fillColor: AppColors.surfaceAlt,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required.' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel(_isEdit ? 'New password (optional)' : 'Password'),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                        hintText: _isEdit ? 'Leave blank to keep current' : 'Password',
                        fillColor: AppColors.surfaceAlt,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5)),
                      ),
                      validator: (v) {
                        if (_isEdit) return null;
                        if (v == null || v.length < 6) return 'Password must be at least 6 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Role'),
                    ..._roles.map((r) => _buildRoleCard(r)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account active',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Can sign in to CSMS',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _active,
                            onChanged: (v) => setState(() => _active = v),
                            activeTrackColor: AppColors.terracotta,
                            activeThumbColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Bottom Action Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: AppColors.cream,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(
                          _isEdit ? 'Save changes' : 'Add User',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

