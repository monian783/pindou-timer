import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/blur.dart';
import '../widgets/dialogs.dart';
import '../widgets/open_dialog.dart';
import '../widgets/session_sheet.dart';
import 'packages_page.dart';
import 'records_page.dart';
import 'settings_page.dart';
import 'zones_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _Group {
  final String id;
  final String name;
  final List<Seat> seats;
  const _Group(this.id, this.name, this.seats);
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _collapsed = {};
  Timer? _ticker;
  String _q = '';
  String _zone = 'all';
  int _sort = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    store.removeListener(_onStore);
    _search.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  // ---------------- 顶部 ----------------

  Widget _header() {
    final total = store.s.seats.length;
    final busy = store.occupiedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              const Text('我勒个豆计时器',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
              const Spacer(),
              _menuBtn(),
            ],
          ),
          const SizedBox(height: 12),
          _searchBar(),
          const SizedBox(height: 10),
          Row(
            children: [
              _zonePicker(),
              const SizedBox(width: 8),
              _sortPicker(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('开台：$busy/$total',
                  style: TextStyle(
                    fontSize: 13,
                    color: busy > 0 ? C.primary : C.sub,
                    fontWeight: busy > 0 ? FontWeight.w600 : FontWeight.w400,
                  )),
              const Spacer(),
              const Text('长按桌台可改名/换分区', style: kSub),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuBtn() {
    return PopupMenuButton<String>(
      tooltip: '管理',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: C.card,
      onSelected: (v) {
        if (v == 'zones') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZonesPage()));
        } else if (v == 'pkgs') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackagesPage()));
        } else if (v == 'settings') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
        } else if (v == 'records') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordsPage()));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'zones', height: 44, child: Text('分区与桌位', style: kBody)),
        PopupMenuItem(value: 'pkgs', height: 44, child: Text('套餐管理', style: kBody)),
        PopupMenuItem(value: 'settings', height: 44, child: Text('计费设置', style: kBody)),
        PopupMenuItem(value: 'records', height: 44, child: Text('结账记录', style: kBody)),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: cardDec(),
        child: const Icon(Icons.more_horiz_rounded, size: 20, color: C.text),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: cardDec(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: C.sub),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v.trim()),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: C.text),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '查桌号（如：1）',
                hintStyle: TextStyle(fontSize: 14, color: C.hint),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_q.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                setState(() => _q = '');
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.cancel_rounded, size: 17, color: C.hint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _zonePicker() {
    final label = _zone == 'all' ? '全部' : store.zoneName(_zone);
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: C.card,
      onSelected: (v) => setState(() => _zone = v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', height: 44, child: Text('全部分区', style: kBody)),
        ...store.s.zones.map(
          (z) => PopupMenuItem(value: z.id, height: 44, child: Text(z.name, style: kBody)),
        ),
      ],
      child: pill(text: '分区：$label', icon: Icons.keyboard_arrow_down_rounded),
    );
  }

  Widget _sortPicker() {
    const labels = ['自定义顺序', '按桌号', '使用中优先', '空闲优先'];
    return PopupMenuButton<int>(
      tooltip: '',
      offset: const Offset(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: C.card,
      onSelected: (v) => setState(() => _sort = v),
      itemBuilder: (_) => List<PopupMenuEntry<int>>.generate(
        labels.length,
        (i) => PopupMenuItem(value: i, height: 44, child: Text(labels[i], style: kBody)),
      ),
      child: pill(text: '排序：${labels[_sort]}', icon: Icons.keyboard_arrow_down_rounded),
    );
  }

  // ---------------- 列表 ----------------

  List<_Group> _groups() {
    final searching = _q.isNotEmpty;
    final seats = store.s.seats.where((s) {
      if (searching) return s.name.contains(_q);
      if (_zone != 'all' && s.zoneId != _zone) return false;
      return true;
    }).toList();

    final ids = store.s.zones.map((z) => z.id).toList();
    final groups = <_Group>[];
    for (final z in store.s.zones) {
      final list = seats.where((s) => s.zoneId == z.id).toList();
      if (list.isEmpty && (searching || _zone != 'all')) continue;
      groups.add(_Group(z.id, z.name, _sorted(list)));
    }
    final orphan = _sorted(seats.where((s) => !ids.contains(s.zoneId)).toList());
    if (orphan.isNotEmpty) groups.add(_Group('', '未分区', orphan));
    return groups;
  }

  List<Seat> _sorted(List<Seat> list) {
    // 0 = 自定义顺序：保持「分区与桌位」里拖出来的顺序，不做排序
    if (_sort == 0) return [...list];
    final l = [...list];
    int byName(Seat a, Seat b) => seatCompare(a.name, b.name);
    l.sort((a, b) {
      if (_sort == 2 || _sort == 3) {
        final oa = store.sessionOf(a.id) != null ? 0 : 1;
        final ob = store.sessionOf(b.id) != null ? 0 : 1;
        final r = _sort == 2 ? oa.compareTo(ob) : ob.compareTo(oa);
        if (r != 0) return r;
      }
      return byName(a, b);
    });
    return l;
  }

  Widget _list() {
    if (store.s.seats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chair_outlined, size: 46, color: C.hint),
              const SizedBox(height: 14),
              const Text('还没有桌位', style: TextStyle(fontSize: 15, color: C.text)),
              const SizedBox(height: 6),
              const Text('先去「分区与桌位」建几个分区和桌位', style: kSub, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              primaryBtn('去添加桌位', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZonesPage()));
              }),
            ],
          ),
        ),
      );
    }

    final groups = _groups();
    if (groups.isEmpty) {
      return const Center(child: Text('没有找到这个桌号', style: kSub));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: groups.map(_zoneBlock).toList(),
    );
  }

  Widget _zoneBlock(_Group g) {
    final collapsed = _q.isEmpty && _collapsed.contains(g.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: cardDec(),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              if (collapsed) {
                _collapsed.remove(g.id);
              } else {
                _collapsed.add(g.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: C.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(g.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
                  const SizedBox(width: 6),
                  Text('${g.seats.length}个', style: kSub),
                  const Spacer(),
                  if (!collapsed)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => showAddSeatDialog(context, g.id),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.add_circle_outline_rounded, size: 19, color: C.sub),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(collapsed ? '展开' : '收起', style: kSub),
                  Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                      size: 17, color: C.sub),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (ctx, c) {
                const gap = 8.0;
                final w = ((c.maxWidth - gap * 2) / 3).clamp(72.0, 160.0);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: g.seats
                      .map((s) => SizedBox(width: w, child: _seatCard(s)))
                      .toList(),
                );
              },
            ),
            if (g.seats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('这个分区还没有桌位，点上面的 + 加一个', style: kSub),
              ),
          ],
        ],
      ),
    );
  }

  Widget _seatCard(Seat seat) {
    final se = store.sessionOf(seat.id);
    final now = DateTime.now();

    Color border = C.line;
    Color bg = C.card;
    String? tag;
    String? time;
    Color tc = C.sub;

    if (se != null) {
      final isCount = se.mode == PkgMode.countdown;
      if (se.paused) {
        border = C.orange.withValues(alpha: 0.55);
        bg = C.orangeSoft;
        tag = '已暂停';
        time = fmtHms(isCount ? (se.remainMs(now) > 0 ? se.remainMs(now) : 0) : se.elapsedMs(now));
        tc = C.orange;
      } else if (se.isOut(now)) {
        border = C.red.withValues(alpha: 0.55);
        bg = C.redSoft;
        tag = '已到点';
        time = '00:00:00';
        tc = C.red;
      } else {
        border = C.green.withValues(alpha: 0.5);
        bg = C.greenSoft;
        tag = isCount ? '倒计时' : '正计时';
        time = fmtHms(isCount ? se.remainMs(now) : se.elapsedMs(now));
        tc = C.green;
      }
    }

    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(rCard),
          onTap: () {
            if (se == null) {
              showOpenDialog(context, seat);
            } else {
              showSessionSheet(context, seat);
            }
          },
          onLongPress: () => _seatMenu(seat),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: C.text),
                ),
              ),
              const SizedBox(height: 5),
              if (se == null)
                const Text('空闲', style: kSub)
              else ...[
                Text(tag!, style: TextStyle(fontSize: 11, color: tc)),
                const SizedBox(height: 1),
                Text(
                  time!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tc,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _seatMenu(Seat seat) => showSeatActions(context, seat);
}
