import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/blur.dart';
import '../widgets/dialogs.dart';
import '../widgets/header.dart';

/// 套餐管理：随时加、改、删
class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  @override
  void initState() {
    super.initState();
    store.addListener(_on);
  }

  @override
  void dispose() {
    store.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(
              '套餐管理',
              actions: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showPkgEditor(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: C.primary,
                      borderRadius: BorderRadius.circular(rBtn),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 3),
                        Text('新增', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final pkgs = store.s.packages;
    if (pkgs.isEmpty) {
      return const Center(child: Text('还没有套餐，点右上角「新增」加一个', style: kSub));
    }
    final manager = pkgs.where((p) => p.group == PkgGroup.manager).toList();
    final general = pkgs.where((p) => p.group == PkgGroup.general).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text('店长专属：只有店长用的特殊套餐；通用套餐：平时给客人开台用的', style: kSub),
        ),
        if (manager.isNotEmpty) _section('店长专属', manager),
        if (general.isNotEmpty) _section('通用套餐', general),
      ],
    );
  }

  Widget _section(String title, List<Pkg> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(width: 6),
              Text('${list.length}个', style: kSub),
            ],
          ),
        ),
        ...list.map(_row),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _row(Pkg p) {
    final isCount = p.mode == PkgMode.countdown;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: cardDec(),
      child: InkWell(
        borderRadius: BorderRadius.circular(rCard),
        onTap: () => showPkgEditor(context, pkg: p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
                    const SizedBox(height: 4),
                    Text(
                      isCount
                          ? '${p.mode.label} · ${p.minutes}分钟 · 套餐价${fmtMoneyShort(p.price)}'
                          : '${p.mode.label} · ${fmtMoneyShort(p.hourlyRate)}/小时',
                      style: kSub,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: () => showPkgEditor(context, pkg: p),
                icon: const Icon(Icons.edit_outlined, size: 18, color: C.sub),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _delete(p),
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: C.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Pkg p) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除套餐',
      message: '确定删除「${p.name}」吗？',
      okText: '删除',
      danger: true,
    );
    if (ok) store.deletePkg(p.id);
  }
}

/// 新增/编辑套餐
Future<void> showPkgEditor(BuildContext context, {Pkg? pkg}) async {
  await showBlurDialog<void>(context, _PkgEditor(origin: pkg));
}

class _PkgEditor extends StatefulWidget {
  final Pkg? origin;
  const _PkgEditor({this.origin});

  @override
  State<_PkgEditor> createState() => _PkgEditorState();
}

class _PkgEditorState extends State<_PkgEditor> {
  late final TextEditingController _name;
  late final TextEditingController _h;
  late final TextEditingController _m;
  late final TextEditingController _price;
  late final TextEditingController _rate;
  late PkgGroup _group;
  late PkgMode _mode;

  @override
  void initState() {
    super.initState();
    final p = widget.origin;
    _name = TextEditingController(text: p?.name ?? '');
    final mins = p?.minutes ?? 120;
    _h = TextEditingController(text: '${mins ~/ 60}');
    _m = TextEditingController(text: '${mins % 60}');
    _price = TextEditingController(
        text: p == null ? '' : _num(p.price));
    _rate = TextEditingController(
        text: _num(p?.hourlyRate ?? store.s.hourlyRate));
    _group = p?.group ?? PkgGroup.general;
    _mode = p?.mode ?? PkgMode.countdown;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _h.dispose();
    _m.dispose();
    _price.dispose();
    _rate.dispose();
    super.dispose();
  }

  int get _minutes {
    final h = int.tryParse(_h.text.trim()) ?? 0;
    final m = int.tryParse(_m.text.trim()) ?? 0;
    return h * 60 + m;
  }

  double get _rateV => double.tryParse(_rate.text.trim()) ?? 0;
  double get _priceV => double.tryParse(_price.text.trim()) ?? 0;

  bool get _valid => _name.text.trim().isNotEmpty && (_mode == PkgMode.countdown ? _minutes > 0 : true);

  @override
  Widget build(BuildContext context) {
    return dialogBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogHeader(context, widget.origin == null ? '新增套餐' : '编辑套餐'),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: inputDec('例如：2小时体验', label: '套餐名称'),
          ),
          const SizedBox(height: 12),
          _label('分类'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _seg('店长专属', _group == PkgGroup.manager,
                    () => setState(() => _group = PkgGroup.manager)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _seg('通用套餐', _group == PkgGroup.general,
                    () => setState(() => _group = PkgGroup.general)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('计时方式'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _seg('倒计时', _mode == PkgMode.countdown,
                    () => setState(() => _mode = PkgMode.countdown)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _seg('正计时', _mode == PkgMode.countup,
                    () => setState(() => _mode = PkgMode.countup)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_mode == PkgMode.countdown) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _h,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: inputDec('2', label: '时长 小时'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _m,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: inputDec('0', label: '时长 分钟'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: inputDec('20', label: '套餐价（元）'),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: inputDec('10', label: '每小时单价（元）'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _mode == PkgMode.countdown
                  ? '正常坐到点收套餐价；提前结账按每小时单价折算，不会超过套餐价'
                  : '按实际用时 × 每小时单价结账',
              style: kSub,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ghostBtn('取消', () => Navigator.of(context).pop())),
              const SizedBox(width: 10),
              Expanded(
                child: primaryBtn('保存', _valid ? _save : null, enabled: _valid),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String s) =>
      Align(alignment: Alignment.centerLeft, child: Text(s, style: kSub));

  /// 整行可选按钮
  Widget _seg(String text, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(rBtn),
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? C.primarySoft : C.bg,
          borderRadius: BorderRadius.circular(rBtn),
          border: Border.all(color: active ? C.primary.withValues(alpha: 0.35) : C.line),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: active ? C.primary : C.text,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _save() {
    final p = Pkg(
      id: widget.origin?.id ?? newId(),
      name: _name.text.trim(),
      group: _group,
      mode: _mode,
      minutes: _mode == PkgMode.countdown ? _minutes : 0,
      price: _mode == PkgMode.countdown ? round2(_priceV) : 0,
      hourlyRate: _rateV < 0 ? 0 : _rateV,
    );
    store.savePkg(p);
    Navigator.of(context).pop();
  }
}
