import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'blur.dart';

/// 点使用中的桌位 -> 操作面板
Future<void> showSessionSheet(BuildContext context, Seat seat) async {
  await showBlurSheet<void>(context, _SessionSheet(seat: seat));
}

class _SessionSheet extends StatelessWidget {
  final Seat seat;
  const _SessionSheet({required this.seat});

  @override
  Widget build(BuildContext context) {
    final se = store.sessionOf(seat.id);
    if (se == null) {
      return sheetBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('这个桌位已经清台了', style: kSub),
              const SizedBox(height: 12),
              ghostBtn('关闭', () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final used = se.elapsedMs(now);
    final isCount = se.mode == PkgMode.countdown;
    final status = se.paused
        ? '已暂停'
        : (se.isOut(now) ? '已到点' : (isCount ? '剩余 ${fmtHms(se.remainMs(now))}' : '已用 ${fmtHms(used)}'));

    return sheetBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: cardDec(color: C.bg, border: C.line),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(seat.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
                    const SizedBox(width: 8),
                    Text(store.zoneName(seat.zoneId), style: kSub),
                    const Spacer(),
                    Text(status, style: kNum.copyWith(color: se.paused ? C.orange : C.green)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${se.pkgName} · ${fmtClock(se.startAt)}开台', style: kSub),
              ],
            ),
          ),
          const SizedBox(height: 6),
          sheetItem(
            icon: Icons.receipt_long_outlined,
            text: '结账清台',
            bold: true,
            color: C.primary,
            onTap: () => _checkout(context),
          ),
          const SheetDivider(),
          sheetItem(
            icon: Icons.inventory_2_outlined,
            text: '更换套餐',
            onTap: () => _changePackage(context),
          ),
          const SheetDivider(),
          sheetItem(
            icon: se.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            text: se.paused ? '继续计时' : '暂停计时',
            onTap: () {
              final nav = Navigator.of(context);
              store.togglePause(seat);
              nav.pop();
            },
          ),
          const SheetDivider(),
          sheetItem(
            icon: Icons.hourglass_bottom_rounded,
            text: '增加时长（加钟）',
            onTap: () => _addTime(context),
          ),
          const SheetDivider(),
          sheetItem(
            icon: Icons.schedule_rounded,
            text: '修改实际开台时间',
            onTap: () => _editStart(context),
          ),
          const SizedBox(height: 6),
          ghostBtn('取消', () => Navigator.of(context).pop(), color: C.sub),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _checkout(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    showBlurDialog<void>(nav.context, _CheckoutDialog(seat: seat));
  }

  void _changePackage(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    showBlurDialog<void>(nav.context, _ChangePackage(seat: seat));
  }

  void _addTime(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    showBlurDialog<void>(nav.context, _AddTime(seat: seat));
  }

  Future<void> _editStart(BuildContext context) async {
    final nav = Navigator.of(context);
    // 先把 context / messenger 取出来，await 之后就不能再碰原来的 context 了
    final ctx = nav.context;
    final messenger = ScaffoldMessenger.of(context);
    final se = store.sessionOf(seat.id);
    if (se == null) return;
    nav.pop();

    final now = DateTime.now();
    final d = await showDatePicker(
      context: ctx,
      initialDate: se.startAt,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: '选择开台日期',
    );
    if (d == null) return;
    if (!ctx.mounted) return;
    final t = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(se.startAt),
      helpText: '选择开台时间',
    );
    if (t == null) return;
    store.setStartAt(seat, DateTime(d.year, d.month, d.day, t.hour, t.minute));
    messenger.showSnackBar(
      const SnackBar(content: Text('已修改开台时间'), duration: Duration(seconds: 2)),
    );
  }
}

/// 结账清台
class _CheckoutDialog extends StatelessWidget {
  final Seat seat;
  const _CheckoutDialog({required this.seat});

  @override
  Widget build(BuildContext context) {
    final se = store.sessionOf(seat.id);
    if (se == null) {
      return dialogBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('这个桌位已经清台了', style: kSub),
            const SizedBox(height: 14),
            ghostBtn('关闭', () => Navigator.of(context).pop()),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final bill = calcBill(se, store.s, now);
    final before = store.s.balance;
    final after = round2(before + bill.amount);

    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '结账清台'),
          const SizedBox(height: 12),
          _kv('桌位', '${store.zoneName(seat.zoneId)} · ${seat.name}'),
          _kv('套餐', se.pkgName),
          _kv('开台时间', fmtClock(se.startAt)),
          _kv('已用时长', fmtSpan(bill.usedMs)),
          if (bill.billableMinutes > 0) _kv('计费时长', '${bill.billableMinutes}分钟'),
          if (se.extraFee > 0) _kv('加钟费用', fmtMoney(se.extraFee)),
          const SizedBox(height: 8),
          Container(height: 1, color: C.line),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('应收金额', style: kBody),
              const Spacer(),
              Text(
                fmtMoney(bill.amount),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('余额', style: kSub),
              const Spacer(),
              Text('${fmtMoney(before)} → ${fmtMoney(after)}', style: kSub),
            ],
          ),
          const SizedBox(height: 16),
          primaryBtn('入账并清台  +${fmtMoney(bill.amount)}', () => _do(context, true)),
          const SizedBox(height: 8),
          ghostBtn('清台不入账', () => _do(context, false)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('再想想', style: TextStyle(fontSize: 14, color: C.sub)),
          ),
        ],
      ),
    );
  }

  void _do(BuildContext context, bool settle) {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = store.checkout(seat, settle: settle);
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(settle ? '已入账 ${fmtMoney(amount)}，桌位已清台' : '已清台（未入账）'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(k, style: kSub),
          const Spacer(),
          Text(v, style: const TextStyle(fontSize: 13, color: C.text)),
        ],
      ),
    );
  }
}

/// 更换套餐
class _ChangePackage extends StatelessWidget {
  final Seat seat;
  const _ChangePackage({required this.seat});

  @override
  Widget build(BuildContext context) {
    final list = store.s.packages;
    return dialogBox(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '更换套餐'),
          const SizedBox(height: 6),
          const Text('换套餐不会重置开台时间，已计时的时长保留', style: kSub, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('还没有套餐', style: kSub))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(children: list.map((p) => _row(context, p)).toList()),
              ),
            ),
          const SizedBox(height: 8),
          ghostBtn('关闭', () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Pkg p) {
    final isCount = p.mode == PkgMode.countdown;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(rBtn),
        onTap: () {
          final nav = Navigator.of(context);
          store.changePackage(seat, p);
          nav.pop();
          ScaffoldMessenger.of(nav.context).showSnackBar(
            SnackBar(content: Text('已换成「${p.name}」'), duration: const Duration(seconds: 2)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: cardDec(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: p.group == PkgGroup.manager ? C.orangeSoft : C.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.group.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: p.group == PkgGroup.manager ? C.orange : C.primary,
                  ),
                ),
              ),
              Expanded(child: Text(p.name, style: kBody)),
              Text(
                isCount ? fmtMoneyShort(p.price) : '${fmtMoneyShort(p.hourlyRate)}/时',
                style: const TextStyle(fontSize: 13, color: C.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 加钟
class _AddTime extends StatefulWidget {
  final Seat seat;
  const _AddTime({required this.seat});

  @override
  State<_AddTime> createState() => _AddTimeState();
}

class _AddTimeState extends State<_AddTime> {
  final TextEditingController _min = TextEditingController(text: '30');
  final TextEditingController _fee = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _fee.text = _suggest();
  }

  @override
  void dispose() {
    _min.dispose();
    _fee.dispose();
    super.dispose();
  }

  int get _minutes => int.tryParse(_min.text.trim()) ?? 0;

  String _suggest() {
    final se = store.sessionOf(widget.seat.id);
    final rate = se?.hourlyRate ?? store.s.hourlyRate;
    final m = int.tryParse(_min.text.trim()) ?? 0;
    if (m <= 0) return '0';
    return fmtMoneyShort(round2(m / 60 * rate)).replaceAll('¥', '');
  }

  void _set(int minutes) {
    setState(() {
      _min.text = '$minutes';
      _fee.text = _suggest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '增加时长（加钟）'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('+15分钟', 15),
              _chip('+30分钟', 30),
              _chip('+1小时', 60),
              _chip('+2小时', 120),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _min,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _fee.text = _suggest()),
            decoration: inputDec('30', label: '加多少分钟'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: inputDec('0', label: '加收金额（元）'),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('加收金额会加在结账金额里，不想加钱就填 0', style: kSub),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ghostBtn('取消', () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(
                child: primaryBtn(
                  '确定加钟',
                  _minutes <= 0 ? null : _do,
                  enabled: _minutes > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int minutes) {
    return InkWell(
      borderRadius: BorderRadius.circular(rBtn),
      onTap: () => _set(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: cardDec(color: C.bg),
        child: Text(label, style: const TextStyle(fontSize: 13, color: C.text)),
      ),
    );
  }

  void _do() {
    final nav = Navigator.of(context);
    final fee = double.tryParse(_fee.text.trim()) ?? 0;
    store.addTime(widget.seat, _minutes, fee < 0 ? 0 : fee);
    nav.pop();
    ScaffoldMessenger.of(nav.context).showSnackBar(
      SnackBar(content: Text('已加 $_minutes 分钟'), duration: const Duration(seconds: 2)),
    );
  }
}
