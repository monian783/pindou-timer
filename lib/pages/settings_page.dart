import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/blur.dart';
import '../widgets/dialogs.dart';
import '../widgets/header.dart';

/// 计费设置
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _shop =
      TextEditingController(text: store.s.shopName);
  late final TextEditingController _rate = TextEditingController(
      text: store.s.hourlyRate == store.s.hourlyRate.roundToDouble()
          ? store.s.hourlyRate.toInt().toString()
          : store.s.hourlyRate.toString());

  @override
  void initState() {
    super.initState();
    store.addListener(_on);
  }

  @override
  void dispose() {
    store.removeListener(_on);
    _shop.dispose();
    _rate.dispose();
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
            const SubHeader('计费设置'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _card('店铺', [
                    TextField(
                      controller: _shop,
                      onChanged: store.setShopName,
                      decoration: inputDec('店名', label: '店名（只显示用）'),
                    ),
                  ]),
                  _card('收费', [
                    TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final d = double.tryParse(v.trim());
                        if (d != null) store.setHourlyRate(d);
                      },
                      decoration: inputDec('10', label: '默认每小时单价（元）'),
                    ),
                    const SizedBox(height: 8),
                    const Text('「自定义倒计时」和「正计时」默认用这个价；套餐可以单独定价',
                        style: kSub),
                    const SizedBox(height: 16),
                    const Text('计费怎么取整', style: kBody),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _seg('按分钟', store.s.rounding == 0, () => store.setRounding(0))),
                        const SizedBox(width: 6),
                        Expanded(child: _seg('半小时', store.s.rounding == 30, () => store.setRounding(30))),
                        const SizedBox(width: 6),
                        Expanded(child: _seg('一小时', store.s.rounding == 60, () => store.setRounding(60))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      store.s.rounding == 0
                          ? '用多少分钟就算多少分钟'
                          : store.s.rounding == 30
                              ? '超过半小时不到一小时，按一小时算'
                              : '不满一小时也算一小时',
                      style: kSub,
                    ),
                    const SizedBox(height: 16),
                    const Text('倒计时套餐提前结账', style: kBody),
                    const SizedBox(height: 8),
                    _segFull('按已用时长折算（不会超过套餐价）', !store.s.earlyFull,
                        () => store.setEarlyFull(false)),
                    const SizedBox(height: 6),
                    _segFull('一律按套餐价收', store.s.earlyFull, () => store.setEarlyFull(true)),
                  ]),
                  _card('数据', [
                    const Text('数据只保存在这台手机上，不会上传到任何地方', style: kSub),
                    const SizedBox(height: 12),
                    ghostBtn('恢复默认数据（清空全部）', _reset, color: C.red),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

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
        child: Text(text,
            style: TextStyle(
              fontSize: 13,
              color: active ? C.primary : C.text,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }

  Widget _segFull(String text, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(rBtn),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? C.primarySoft : C.bg,
          borderRadius: BorderRadius.circular(rBtn),
          border: Border.all(color: active ? C.primary.withValues(alpha: 0.35) : C.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? C.primary : C.text,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  )),
            ),
            if (active) const Icon(Icons.check_rounded, size: 17, color: C.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _reset() async {
    final ok = await showConfirmDialog(
      context,
      title: '恢复默认数据',
      message: '分区、桌位、套餐、余额、记录都会清空，恢复成刚装好的样子',
      okText: '确定清空',
      danger: true,
    );
    if (!ok) return;
    store.resetAll();
    if (!mounted) return;
    _shop.text = store.s.shopName;
    _rate.text = store.s.hourlyRate.toInt().toString();
  }
}
