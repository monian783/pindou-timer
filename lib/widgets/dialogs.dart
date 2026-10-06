import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'blur.dart';

/// 简单的文本输入弹窗
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String? label,
  String okText = '确定',
  TextInputType? keyboard,
}) {
  return showBlurDialog<String>(
    context,
    _InputDialog(
      title: title,
      initial: initial,
      hint: hint,
      label: label,
      okText: okText,
      keyboard: keyboard,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String hint;
  final String? label;
  final String okText;
  final TextInputType? keyboard;

  const _InputDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.label,
    required this.okText,
    required this.keyboard,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _c.text.trim().isNotEmpty;
    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, widget.title),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: widget.keyboard,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _ok(),
            decoration: inputDec(widget.hint, label: widget.label),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ghostBtn('取消', () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(
                child: primaryBtn(
                  widget.okText,
                  ok ? _ok : null,
                  enabled: ok,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _ok() {
    if (_c.text.trim().isEmpty) return;
    Navigator.of(context).pop(_c.text.trim());
  }
}

/// 确认弹窗
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String message = '',
  String okText = '确定',
  bool danger = false,
}) async {
  final r = await showBlurDialog<bool>(
    context,
    Builder(
      builder: (ctx) => dialogBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            dialogHeader(ctx, title),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(message, style: kSub, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: ghostBtn('取消', () => Navigator.of(ctx).pop(false))),
                const SizedBox(width: 10),
                Expanded(
                  child: primaryBtn(okText, () => Navigator.of(ctx).pop(true), danger: danger),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}

/// 添加桌位（支持批量：1-10）
Future<void> showAddSeatDialog(BuildContext context, String zoneId) async {
  await showBlurDialog<void>(context, _AddSeatDialog(zoneId: zoneId));
}

class _AddSeatDialog extends StatefulWidget {
  final String zoneId;
  const _AddSeatDialog({required this.zoneId});

  @override
  State<_AddSeatDialog> createState() => _AddSeatDialogState();
}

class _AddSeatDialogState extends State<_AddSeatDialog> {
  final TextEditingController _c = TextEditingController();
  String _suffix = '号桌';

  static const _suffixes = ['号桌', '号位', '桌', ''];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<String> get _names => parseBulkNames(_c.text, _suffix);

  @override
  Widget build(BuildContext context) {
    final names = _names;
    // 重名只看同一个分区，所以这里按当前分区过滤一遍
    final fresh =
        names.where((n) => !store.seatNameExists(n, zoneId: widget.zoneId)).toList();
    final dup = names.length - fresh.length;
    final preview = fresh.isEmpty
        ? '这些名字这个分区里都已经有了'
        : '将创建 ${fresh.length} 个：${fresh.take(8).join('、')}'
            '${fresh.length > 8 ? ' …' : ''}'
            '${dup > 0 ? '（另有 $dup 个已存在，会跳过）' : ''}';
    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '添加桌位'),
          const SizedBox(height: 6),
          Text('${store.zoneName(widget.zoneId)} · 已有个 ${store.s.seats.where((s) => s.zoneId == widget.zoneId).length}',
              style: kSub),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: inputDec('例如：1-6 或 1,2,3 或 散座', label: '桌位名称'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('后缀', style: kSub),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: _suffixes
                      .map((s) => pill(
                            text: s.isEmpty ? '不加' : s,
                            active: _suffix == s,
                            onTap: () => setState(() => _suffix = s),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: cardDec(color: C.bg),
            child: Text(
              names.isEmpty ? '填 1-6 会一次建出 1号桌 ~ 6号桌' : preview,
              style: kSub,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ghostBtn('取消', () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(
                child: primaryBtn(
                  '添加',
                  fresh.isEmpty ? null : _ok,
                  enabled: fresh.isNotEmpty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _ok() {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final want = _names.length;
    final added = store.addSeats(widget.zoneId, _names);
    nav.pop();
    if (added < want) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('加了 $added 个，有 ${want - added} 个这个分区里已经有了'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 把桌位挪到别的分区
Future<void> showMoveSeatDialog(BuildContext context, Seat seat) async {
  await showBlurDialog<void>(context, _MoveSeatDialog(seat: seat));
}

/// 桌位操作面板：重命名 / 移动分区 / 删除
void showSeatActions(BuildContext context, Seat seat) {
  final busy = store.sessionOf(seat.id) != null;
  showBlurSheet<void>(
    context,
    sheetBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)),
          ),
          Text(
            '${store.zoneName(seat.zoneId)} · ${seat.name}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text),
          ),
          const SizedBox(height: 8),
          sheetItem(
            icon: Icons.edit_outlined,
            text: '重命名',
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              _renameSeat(nav.context, seat);
            },
          ),
          const SheetDivider(),
          sheetItem(
            icon: Icons.swap_horiz_rounded,
            text: '移动到其他分区',
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              showMoveSeatDialog(nav.context, seat);
            },
          ),
          const SheetDivider(),
          sheetItem(
            icon: Icons.delete_outline_rounded,
            text: '删除桌位',
            color: C.red,
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              _deleteSeat(nav.context, seat, busy);
            },
          ),
          const SizedBox(height: 6),
          ghostBtn('取消', () => Navigator.of(context).pop(), color: C.sub),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

Future<void> _renameSeat(BuildContext ctx, Seat seat) async {
  final v = await showInputDialog(
    ctx,
    title: '重命名桌位',
    initial: seat.name,
    label: '桌位名称',
    okText: '保存',
  );
  if (v == null) return;
  if (store.seatNameExists(v, exceptId: seat.id, zoneId: seat.zoneId)) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('「${store.zoneName(seat.zoneId)}」里已经有叫 $v 的桌位了')),
      );
    }
    return;
  }
  store.renameSeat(seat.id, v);
}

Future<void> _deleteSeat(BuildContext ctx, Seat seat, bool busy) async {
  if (busy) {
    ScaffoldMessenger.of(ctx)
        .showSnackBar(const SnackBar(content: Text('这个桌位还在计时，先结账清台再删')));
    return;
  }
  final ok = await showConfirmDialog(
    ctx,
    title: '删除桌位',
    message: '确定删除「${seat.name}」吗？删了就找不回来了',
    okText: '删除',
    danger: true,
  );
  if (!ok) return;
  store.deleteSeat(seat.id);
}

class _MoveSeatDialog extends StatelessWidget {
  final Seat seat;
  const _MoveSeatDialog({required this.seat});

  @override
  Widget build(BuildContext context) {
    final options = <MapEntry<String, String>>[
      ...store.s.zones.map((z) => MapEntry(z.id, z.name)),
      const MapEntry('', '未分区'),
    ];
    return dialogBox(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '移动到分区'),
          const SizedBox(height: 6),
          Text(seat.name, style: kSub),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: options.map((o) {
                  final active = o.key == seat.zoneId;
                  // 目标分区里已经有同名桌位就不让挪，免得两个「1号桌」挨在一起分不清
                  final clash = !active &&
                      store.seatNameExists(seat.name, exceptId: seat.id, zoneId: o.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(rBtn),
                      onTap: () {
                        if (clash) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('「${o.value}」里已经有 ${seat.name} 了')),
                          );
                          return;
                        }
                        store.moveSeat(seat.id, o.key);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: cardDec(color: active ? C.primarySoft : C.card),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.value,
                                style: clash ? kSub : kBody,
                              ),
                            ),
                            if (active)
                              const Icon(Icons.check_rounded, size: 18, color: C.primary),
                            if (clash)
                              const Text('重名', style: TextStyle(fontSize: 11, color: C.hint)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ghostBtn('取消', () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
