import 'package:flutter/material.dart';

import '../models.dart';
import '../pages/packages_page.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'blur.dart';

/// 点空闲桌位 -> 开台操作弹窗
Future<void> showOpenDialog(BuildContext context, Seat seat) async {
  await showBlurDialog<void>(context, _OpenDialog(seat: seat));
}

class _OpenDialog extends StatefulWidget {
  final Seat seat;
  const _OpenDialog({required this.seat});

  @override
  State<_OpenDialog> createState() => _OpenDialogState();
}

class _OpenDialogState extends State<_OpenDialog> {
  PkgGroup tab = PkgGroup.general;

  @override
  Widget build(BuildContext context) {
    final pkgs = store.s.packages.where((p) => p.group == tab).toList();
    return dialogBox(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '开台操作'),
          const SizedBox(height: 2),
          Text('${store.zoneName(widget.seat.zoneId)} · ${widget.seat.name}', style: kSub),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _tabBtn(PkgGroup.manager)),
              const SizedBox(width: 8),
              Expanded(child: _tabBtn(PkgGroup.general)),
            ],
          ),
          const SizedBox(height: 12),
          if (pkgs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text('这个分类下还没有套餐\n可以点下面「去配置套餐」加一个', textAlign: TextAlign.center, style: kSub),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(children: pkgs.map(_pkgRow).toList()),
              ),
            ),
          const SizedBox(height: 12),
          const SheetDivider(),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('自定义与预定', style: kSub),
          ),
          const SizedBox(height: 4),
          sheetItem(
            icon: Icons.timer_outlined,
            text: '自定义倒计时',
            onTap: _customCountdown,
          ),
          const Divider(height: 1, color: C.line),
          sheetItem(
            icon: Icons.play_circle_outline,
            text: '开始正计时（不限时）',
            onTap: _startCountUp,
          ),
          const Divider(height: 1, color: C.line),
          sheetItem(
            icon: Icons.tune_rounded,
            text: '去配置套餐',
            trailing: '>',
            color: C.sub,
            onTap: _gotoPackages,
          ),
          const SizedBox(height: 6),
          ghostBtn('关闭', () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _tabBtn(PkgGroup g) {
    final active = tab == g;
    return InkWell(
      borderRadius: BorderRadius.circular(rBtn),
      onTap: () => setState(() => tab = g),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? C.primarySoft : C.bg,
          borderRadius: BorderRadius.circular(rBtn),
        ),
        child: Text(
          g.label,
          style: TextStyle(
            fontSize: 14,
            color: active ? C.primary : C.sub,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _pkgRow(Pkg p) {
    final isCount = p.mode == PkgMode.countdown;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(rBtn),
        onTap: () {
          store.openSeat(
            widget.seat,
            pkgId: p.id,
            pkgName: p.name,
            mode: p.mode,
            minutes: p.minutes,
            price: p.price,
            hourlyRate: p.hourlyRate,
          );
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: cardDec(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('开台：${p.name}', style: kBody),
                    const SizedBox(height: 3),
                    Text(
                      isCount ? '${p.minutes}分钟 · 到点自动停' : '不限时 · 按小时结账',
                      style: kSub,
                    ),
                  ],
                ),
              ),
              Text(
                isCount ? fmtMoneyShort(p.price) : '${fmtMoneyShort(p.hourlyRate)}/时',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startCountUp() {
    store.openSeat(
      widget.seat,
      pkgName: '正计时（不限时）',
      mode: PkgMode.countup,
      hourlyRate: store.s.hourlyRate,
    );
    Navigator.of(context).pop();
  }

  void _customCountdown() {
    showBlurDialog<void>(context, _CustomCountdown(seat: widget.seat));
  }

  void _gotoPackages() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => const PackagesPage()));
  }
}

/// 自定义倒计时：自己填时长和单价
class _CustomCountdown extends StatefulWidget {
  final Seat seat;
  const _CustomCountdown({required this.seat});

  @override
  State<_CustomCountdown> createState() => _CustomCountdownState();
}

class _CustomCountdownState extends State<_CustomCountdown> {
  late final TextEditingController _h =
      TextEditingController(text: '1');
  late final TextEditingController _m = TextEditingController(text: '0');
  late final TextEditingController _rate =
      TextEditingController(text: _rateText(store.s.hourlyRate));

  static String _rateText(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    _rate.dispose();
    super.dispose();
  }

  int get _minutes {
    final h = int.tryParse(_h.text.trim()) ?? 0;
    final m = int.tryParse(_m.text.trim()) ?? 0;
    return h * 60 + m;
  }

  double get _hourly {
    final v = double.tryParse(_rate.text.trim()) ?? store.s.hourlyRate;
    return v < 0 ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final mm = _minutes;
    final price = round2(mm / 60 * _hourly);
    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, '自定义倒计时'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _h,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: inputDec('0', label: '小时'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _m,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: inputDec('30', label: '分钟'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: inputDec('10', label: '每小时单价（元）'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: cardDec(color: C.bg, border: C.line),
            child: Row(
              children: [
                const Text('预计收费', style: kSub),
                const Spacer(),
                Text(
                  mm <= 0 ? '—' : fmtMoneyShort(price),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ghostBtn('取消', () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(
                child: primaryBtn('开始计时', mm <= 0 ? null : _start, enabled: mm > 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _start() {
    final nav = Navigator.of(context);
    store.openSeat(
      widget.seat,
      pkgName: '自定义 ${_minutes}分钟',
      mode: PkgMode.countdown,
      minutes: _minutes,
      price: round2(_minutes / 60 * _hourly),
      hourlyRate: _hourly,
    );
    nav.pop(); // 关掉自定义弹窗
    nav.pop(); // 关掉开台弹窗
  }
}
