import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';
import 'packages_page.dart';
import 'records_page.dart';
import 'settings_page.dart';
import 'zones_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
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

  void _go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final settled = store.s.records.where((r) => r.settled).length;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 12),
              child: Text('我的',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: C.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('余额（虚拟）',
                          style: TextStyle(fontSize: 13, color: Colors.white70)),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _editBalance,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Text('手动调整',
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fmtMoney(store.s.balance),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('结账时选「入账并清台」才会加到这里，一共 $settled 笔',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: cardDec(),
              child: Column(
                children: [
                  _item(Icons.inventory_2_outlined, '套餐管理', '加套餐、改价格、改时长',
                      () => _go(const PackagesPage())),
                  const Divider(height: 1, color: C.line, indent: 52),
                  _item(Icons.grid_view_rounded, '分区与桌位', '增删分区和桌位',
                      () => _go(const ZonesPage())),
                  const Divider(height: 1, color: C.line, indent: 52),
                  _item(Icons.tune_rounded, '计费设置', '每小时单价、结账怎么算',
                      () => _go(const SettingsPage())),
                  const Divider(height: 1, color: C.line, indent: 52),
                  _item(Icons.receipt_long_outlined, '结账记录', '${store.s.records.length} 条',
                      () => _go(const RecordsPage())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('我勒个豆计时器 v1.0.0',
                  style: TextStyle(fontSize: 12, color: C.hint)),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('数据存在本机，换手机不会自动同步',
                  style: TextStyle(fontSize: 12, color: C.hint)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: C.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: C.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15, color: C.text)),
                  const SizedBox(height: 2),
                  Text(sub, style: kSub),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.hint),
          ],
        ),
      ),
    );
  }

  Future<void> _editBalance() async {
    final v = await showInputDialog(
      context,
      title: '手动调整余额',
      initial: store.s.balance.toStringAsFixed(2),
      label: '余额（元）',
      hint: '0',
      okText: '保存',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
    if (v == null) return;
    final d = double.tryParse(v);
    if (d == null) return;
    store.setBalance(d);
  }
}
