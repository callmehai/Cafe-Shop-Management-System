import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../data/tables_repository.dart';
import '../domain/table_model.dart';

/// Thêm/sửa bàn (Figma "29 Add / Edit Table"). Có nút Remove (mở confirm "30").
class TableFormPage extends ConsumerStatefulWidget {
  const TableFormPage({super.key, this.table});
  final TableModel? table;

  @override
  ConsumerState<TableFormPage> createState() => _TableFormPageState();
}

class _TableFormPageState extends ConsumerState<TableFormPage> {
  static const _zones = ['Main floor', 'Terrace'];
  static const _shapes = ['Square', 'Round', 'Booth', 'Bar'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _capacity;
  late String _zone;
  String? _shape;
  late TableStatus _status;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.table != null;

  @override
  void initState() {
    super.initState();
    final t = widget.table;
    _number = TextEditingController(text: t != null ? t.number.toString() : '');
    _capacity = TextEditingController(text: t != null ? t.capacity.toString() : '4');
    _zone = t?.floor ?? _zones.first;
    _shape = t?.shape;
    _status = t?.status ?? TableStatus.free;
  }

  @override
  void dispose() {
    _number.dispose();
    _capacity.dispose();
    super.dispose();
  }

  List<String> get _zoneOptions => {..._zones, _zone}.toList();

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final body = <String, dynamic>{
      'number': int.parse(_number.text.trim()),
      'capacity': int.parse(_capacity.text.trim()),
      'floor': _zone,
      'shape': _shape,
      if (_isEdit) 'occupancyStatus': _status.api,
    };
    setState(() => _saving = true);
    final repo = ref.read(tablesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(widget.table!.id, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(tablesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final t = widget.table!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove table'),
        content: Text(
          'Remove ${t.code}? It will no longer appear when assigning tables. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(tablesRepositoryProvider).remove(t.id);
      ref.invalidate(tablesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // 409 khi bàn đang bận/đặt trước.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManageAll = user?.role == UserRole.manager || user?.role == UserRole.administrator;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? (canManageAll ? 'Edit Table' : 'Change Table Status') : 'Add Table'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _Label('Table number'),
            TextFormField(
              controller: _number,
              enabled: canManageAll,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '5'),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Enter a valid table number.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Zone'),
            _ChipRow(
              options: _zoneOptions,
              selected: {_zone},
              onTap: canManageAll ? (z) => setState(() => _zone = z) : (_) {},
            ),
            const SizedBox(height: 16),
            const _Label('Capacity'),
            TextFormField(
              controller: _capacity,
              enabled: canManageAll,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '4', suffixText: 'seats'),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Capacity must be at least 1.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Shape'),
            _ChipRow(
              options: _shapes,
              selected: _shape == null ? {} : {_shape!},
              onTap: canManageAll ? (s) => setState(() => _shape = s) : (_) {},
            ),
            if (_isEdit) ...[
              const SizedBox(height: 16),
              const _Label('Status'),
              _ChipRow(
                options: TableStatus.values.map((s) => s.shortLabel).toList(),
                selected: {_status.shortLabel},
                onTap: (label) => setState(() {
                  _status = TableStatus.values.firstWhere((s) => s.shortLabel == label);
                }),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save table'),
            ),
            if (_isEdit && canManageAll) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text('Remove table', style: TextStyle(color: AppColors.danger)),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.options, required this.selected, required this.onTap});
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        final on = selected.contains(o);
        return ChoiceChip(
          label: Text(o),
          selected: on,
          onSelected: (_) => onTap(o),
          selectedColor: AppColors.terracotta.withValues(alpha: 0.18),
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: on ? AppColors.terracottaDark : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: on ? AppColors.terracotta : AppColors.border),
          ),
        );
      }).toList(),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}
