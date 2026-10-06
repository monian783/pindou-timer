import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pindou_timer/main.dart';
import 'package:pindou_timer/store.dart';
import 'package:pindou_timer/utils.dart';

/// 首页有个每秒刷新的计时器，不能用 pumpAndSettle（会一直等下去）
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() {
    store.resetAll();
  });

  test('桌位重名只在同一个分区内拦', () {
    // 大厅里已经有 1号桌
    expect(store.addSeats('z_hall', ['1号桌']), 0);
    expect(store.s.seats.where((s) => s.name == '1号桌').length, 1);

    // 换个分区就能叫一样的名字
    store.addZone('包间');
    final pid = store.s.zones.last.id;
    expect(store.addSeats(pid, ['1号桌']), 1);
    expect(store.s.seats.where((s) => s.name == '1号桌').length, 2);

    // 但同一个分区里还是不行
    expect(store.addSeats(pid, ['1号桌', '2号桌']), 1);
    expect(store.s.seats.where((s) => s.zoneId == pid).length, 2);

    // 批量加的时候重名的自动跳过
    expect(store.addSeats(pid, parseBulkNames('2-4', '号桌')), 2);
    expect(store.s.seats.where((s) => s.zoneId == pid).map((s) => s.name).toList(),
        ['1号桌', '2号桌', '3号桌', '4号桌']);
  });

  test('桌位拖动排序（只在分区内生效）', () {
    List<String> hall() => store.s.seats
        .where((s) => s.zoneId == 'z_hall')
        .map((s) => s.name)
        .toList();

    expect(hall(), ['1号桌', '2号桌', '3号桌']);

    final s1 = store.s.seats.firstWhere((s) => s.name == '1号桌');
    final s3 = store.s.seats.firstWhere((s) => s.name == '3号桌');
    // 把 1号桌 拖到 3号桌 的位置上
    store.reorderSeat(s1.id, s3.id);
    expect(hall(), ['2号桌', '1号桌', '3号桌']);

    // 不能拖到别的分区去
    final loose = store.s.seats.firstWhere((s) => s.name == '散座');
    store.reorderSeat(s1.id, loose.id);
    expect(hall(), ['2号桌', '1号桌', '3号桌']);
  });

  test('分区拖动排序', () {
    store.addZone('包间');
    expect(store.s.zones.map((z) => z.name).toList(), ['大厅', '包间']);

    // ReorderableListView 语义：把第二个拖到最前面
    store.reorderZone(store.s.zones[1].id, 0);
    expect(store.s.zones.map((z) => z.name).toList(), ['包间', '大厅']);

    // 拖到最后
    store.reorderZone(store.s.zones[0].id, 2);
    expect(store.s.zones.map((z) => z.name).toList(), ['大厅', '包间']);
  });

  testWidgets('首页正常渲染', (tester) async {
    await tester.pumpWidget(const App());
    await settle(tester, 3);

    expect(find.text('我勒个豆计时器'), findsOneWidget);
    expect(find.text('1号桌'), findsOneWidget);
    expect(find.text('散座'), findsOneWidget);
    expect(find.text('开台：0/4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('开台 -> 操作面板 -> 结账清台', (tester) async {
    await tester.pumpWidget(const App());
    await settle(tester, 3);

    // 点空闲桌位 -> 开台操作弹窗
    await tester.tap(find.text('1号桌'));
    await settle(tester);
    expect(find.text('开台操作'), findsOneWidget);
    expect(find.text('店长专属'), findsOneWidget);
    expect(find.text('通用套餐'), findsOneWidget);
    expect(find.text('自定义倒计时'), findsOneWidget);
    expect(find.text('开始正计时（不限时）'), findsOneWidget);

    // 选一个套餐开始计时
    await tester.tap(find.text('开台：按小时计费'));
    await settle(tester);
    expect(find.text('开台操作'), findsNothing);
    expect(find.text('正计时'), findsOneWidget);
    expect(find.text('开台：1/4'), findsOneWidget);

    // 再点 -> 开台中操作面板
    await tester.tap(find.text('1号桌'));
    await settle(tester);
    expect(find.text('结账清台'), findsOneWidget);
    expect(find.text('更换套餐'), findsOneWidget);
    expect(find.text('暂停计时'), findsOneWidget);
    expect(find.text('增加时长（加钟）'), findsOneWidget);
    expect(find.text('修改实际开台时间'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 结账清台
    await tester.tap(find.text('结账清台'));
    await settle(tester);
    expect(find.textContaining('入账并清台'), findsOneWidget);
    expect(find.text('清台不入账'), findsOneWidget);

    await tester.tap(find.text('清台不入账'));
    await settle(tester);
    expect(find.text('开台：0/4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('我的页 + 套餐管理 + 分区管理能打开', (tester) async {
    await tester.pumpWidget(const App());
    await settle(tester, 3);

    await tester.tap(find.text('我的'));
    await settle(tester);
    expect(find.text('余额（虚拟）'), findsOneWidget);
    expect(find.text('套餐管理'), findsOneWidget);

    await tester.tap(find.text('套餐管理'));
    await settle(tester);
    expect(find.text('2小时体验'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await settle(tester);

    await tester.tap(find.text('分区与桌位'));
    await settle(tester);
    expect(find.text('未分区'), findsOneWidget);
    expect(find.text('新增分区'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('入账清台后，记录页按天汇总', (tester) async {
    await tester.pumpWidget(const App());
    await settle(tester, 3);

    // 开台 -> 结账 -> 入账并清台
    await tester.tap(find.text('1号桌'));
    await settle(tester);
    await tester.tap(find.text('开台：按小时计费'));
    await settle(tester);
    await tester.tap(find.text('1号桌'));
    await settle(tester);
    await tester.tap(find.text('结账清台'));
    await settle(tester);
    await tester.tap(find.textContaining('入账并清台'));
    await settle(tester);

    // 我的 -> 结账记录
    await tester.tap(find.text('我的'));
    await settle(tester);
    await tester.tap(find.text('结账记录'));
    await settle(tester);

    expect(find.text('今日入账'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.textContaining('入账 ¥'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
