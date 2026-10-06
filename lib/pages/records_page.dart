import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/header.dart';

/// 结账记录
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
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
              '结账记录',
              actions: [
                if (store.s.records.isNotEmpty)
                  TextButton(
                    onPressed: _clear,
                    child: const Text('清空', style: TextStyle(fontSize: 13, color: C.sub)),
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
    final rs = store.s.records;
    if (rs.isEmpty) {
      return const Center(
        child: Text('还没有结账记录\n客人结账清台后会记在这里', textAlign: TextAlign.center, style: kSub),
      );
    }
    final settled = rs.where((r) => r.settled).toList();
    final sum = settled.fold<double>(0, (a, b) => a + b.amount);

    final today = DateTime.now();
    final todaySum = settled
        .where((r) =>
            r.endAt.year == today.year &&
            r.endAt.month == today.month &&
            r.endAt.day == today.day)
        .fold<double>(0, (a, b) => a + b.amount);

    // 按天分组（记录本身是新到旧，所以天也是新到旧）
    final days = <String, List<BillRecord>>{};
    for (final r in rs) {
      final k = '${r.endAt.year}/${r.endAt.month}/${r.endAt.day}';
      days.putIfAbsent(k, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDec(),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今日入账', style: kSub),
                  const SizedBox(height: 4),
                  Text(fmtMoney(todaySum),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: C.primary)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('累计 ${fmtMoney(sum)}', style: kSub),
                  const SizedBox(height: 4),
                  Text('共 ${rs.length} 笔 · 已入账 ${settled.length} 笔', style: kSub),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...days.entries.map(_dayBlock),
      ],
    );
  }

  /// 一天的记录：日期 + 当天合计，下面跟当天的明细
  Widget _dayBlock(MapEntry<String, List<BillRecord>> e) {
    final list = e.value;
    final daySum = list.where((r) => r.settled).fold<double>(0, (a, b) => a + b.amount);
    final d = list.first.endAt;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    final tag = diff == 0
        ? '今天'
        : diff == 1
            ? '昨天'
            : '${d.month}月${d.day}日';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          child: Row(
            children: [
              Text(tag,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(width: 8),
              Text('${list.length} 笔', style: kSub),
              const Spacer(),
              Text('入账 ${fmtMoney(daySum)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: C.primary)),
            ],
          ),
        ),
        ...list.map(_row),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _row(BillRecord r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(rCard),
        onLongPress: () => _delete(r),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDec(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.seatName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
                        const SizedBox(width: 6),
                        Text(r.zoneName, style: kSub),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: r.settled ? C.greenSoft : C.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.settled ? '已入账' : '未入账',
                            style: TextStyle(
                                fontSize: 10, color: r.settled ? C.green : C.sub),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.pkgName} · ${fmtSpan(r.usedMs)} · ${fmtClock(r.startAt)}-${fmtClock(r.endAt)}',
                      style: kSub,
                    ),
                  ],
                ),
              ),
              Text(
                fmtMoney(r.amount),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: C.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BillRecord r) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除记录',
      message: '删除这条记录不会改余额，只是把记录去掉',
      okText: '删除',
      danger: true,
    );
    if (ok) store.deleteRecord(r.id);
  }

  Future<void> _clear() async {
    final ok = await showConfirmDialog(
      context,
      title: '清空记录',
      message: '记录会全部清掉，余额不变',
      okText: '清空',
      danger: true,
    );
    if (ok) store.clearRecords();
  }
}
