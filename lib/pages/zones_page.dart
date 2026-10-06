import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/header.dart';

/// 分区与桌位管理：增删分区/桌位，长按拖动排序
class ZonesPage extends StatefulWidget {
  const ZonesPage({super.key});

  @override
  State<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends State<ZonesPage> {
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

  List<Seat> _seatsOf(String zoneId) =>
      store.s.seats.where((s) => s.zoneId == zoneId).toList();

  @override
  Widget build(BuildContext context) {
    final ids = store.s.zones.map((z) => z.id).toList();
    final orphan = store.s.seats.where((s) => !ids.contains(s.zoneId)).toList();

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(
              '分区与桌位',
              actions: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _addZone,
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
                        Text('新增分区', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) {
                  if (oldIndex < 0 || oldIndex >= store.s.zones.length) return;
                  store.reorderZone(store.s.zones[oldIndex].id, newIndex);
                },
                header: const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: Text(
                    '分区就是店里的区域，比如「大厅」「包间」；每个分区下面再放桌位。\n'
                    '· 长按桌位拖动，可以在分区内排序\n'
                    '· 按住分区左边的 ⠿ 可以调整分区顺序',
                    style: kSub,
                  ),
                ),
                footer: _orphanCard(orphan),
                children: [
                  for (var i = 0; i < store.s.zones.length; i++)
                    _zoneCard(store.s.zones[i], i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 分区 ----------------

  Widget _zoneCard(Zone z, int index) {
    final seats = _seatsOf(z.id);
    return Container(
      key: ValueKey('zone_${z.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 12),
      decoration: cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.drag_indicator_rounded, size: 20, color: C.hint),
                ),
              ),
              Container(
                width: 3.5,
                height: 15,
                decoration: BoxDecoration(
                  color: C.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  z.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: C.text),
                ),
              ),
              const SizedBox(width: 6),
              Text('${seats.length}个桌位', style: kSub),
              const Spacer(),
              IconButton(
                tooltip: '改名',
                visualDensity: VisualDensity.compact,
                onPressed: () => _renameZone(z),
                icon: const Icon(Icons.edit_outlined, size: 17, color: C.sub),
              ),
              IconButton(
                tooltip: '删除分区',
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteZone(z),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: C.sub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...seats.map(_seatChip),
                _addChip(() => showAddSeatDialog(context, z.id)),
              ],
            ),
          ),
          if (seats.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 8),
              child: Text('点右边的「加桌位」加几个', style: kSub),
            ),
        ],
      ),
    );
  }

  Widget _orphanCard(List<Seat> seats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 15,
                decoration:
                    BoxDecoration(color: C.sub, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('未分区',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(width: 6),
              Text('${seats.length}个桌位', style: kSub),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...seats.map(_seatChip),
              _addChip(() => showAddSeatDialog(context, '')),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 桌位 ----------------

  /// 桌位标签：点一下改名字/换分区，长按拖动能排序
  Widget _seatChip(Seat s) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != s.id && _sameZone(d.data, s),
      onAcceptWithDetails: (d) => store.reorderSeat(d.data, s.id),
      builder: (ctx, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        return LongPressDraggable<String>(
          data: s.id,
          feedback: Material(
            color: Colors.transparent,
            child: _chipView(s, hot: true, floating: true),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: _chipView(s)),
          child: GestureDetector(
            onTap: () => showSeatActions(context, s),
            child: _chipView(s, hot: hot),
          ),
        );
      },
    );
  }

  bool _sameZone(String seatId, Seat target) {
    for (final x in store.s.seats) {
      if (x.id == seatId) return x.zoneId == target.zoneId;
    }
    return false;
  }

  Widget _chipView(Seat s, {bool hot = false, bool floating = false}) {
    final busy = store.sessionOf(s.id) != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: hot ? C.primarySoft : (busy ? C.greenSoft : C.bg),
        borderRadius: BorderRadius.circular(rBtn),
        border: Border.all(
          color: hot ? C.primary : (busy ? C.green.withValues(alpha: 0.45) : C.line),
          width: hot ? 1.5 : 1,
        ),
        boxShadow: floating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.name, style: TextStyle(fontSize: 13, color: busy ? C.green : C.text)),
          if (busy) ...[
            const SizedBox(width: 5),
            const Text('计时中', style: TextStyle(fontSize: 10, color: C.green)),
          ],
        ],
      ),
    );
  }

  Widget _addChip(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(rBtn),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rBtn),
          border: Border.all(color: C.primary.withValues(alpha: 0.4)),
          color: C.primarySoft,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: C.primary),
            SizedBox(width: 3),
            Text('加桌位', style: TextStyle(fontSize: 13, color: C.primary)),
          ],
        ),
      ),
    );
  }

  // ---------------- 分区操作 ----------------

  Future<void> _addZone() async {
    final v = await showInputDialog(
      context,
      title: '新增分区',
      hint: '例如：大厅、包间、二楼',
      label: '分区名称',
      okText: '创建',
    );
    if (v == null) return;
    if (store.s.zones.any((z) => z.name == v)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已经有同名的分区了')));
      }
      return;
    }
    store.addZone(v);
  }

  Future<void> _renameZone(Zone z) async {
    final v = await showInputDialog(
      context,
      title: '分区改名',
      initial: z.name,
      label: '分区名称',
      okText: '保存',
    );
    if (v == null) return;
    store.renameZone(z.id, v);
  }

  Future<void> _deleteZone(Zone z) async {
    final n = _seatsOf(z.id).length;
    final ok = await showConfirmDialog(
      context,
      title: '删除分区',
      message: n > 0
          ? '「${z.name}」里有 $n 个桌位，删掉分区后它们会变成「未分区」，桌位本身不会丢'
          : '确定删除分区「${z.name}」吗？',
      okText: '删除',
      danger: true,
    );
    if (!ok) return;
    final busy = _seatsOf(z.id).where((s) => store.sessionOf(s.id) != null).length;
    if (busy > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有 $busy 个桌位正在计时，分区已删除，桌位归到「未分区」')),
      );
    }
    store.deleteZone(z.id);
  }
}
