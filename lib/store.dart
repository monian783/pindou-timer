import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'utils.dart';

/// 结账算钱：
/// - 正计时：用多久算多久（按设置的取整方式）* 每小时单价
/// - 倒计时：用到时间就按套餐价；提前结账默认按已用时长折算（不超过套餐价），
///   也可以在「计费设置」里改成一律按套餐价收
/// - 加钟费用单独加上
BillResult calcBill(Session se, AppState st, DateTime now) {
  final usedMs = se.elapsedMs(now);
  var usedMin = (usedMs / 60000).ceil();
  if (usedMin < 0) usedMin = 0;

  int billable;
  if (st.rounding == 30) {
    billable = ((usedMin + 29) ~/ 30) * 30;
  } else if (st.rounding == 60) {
    billable = ((usedMin + 59) ~/ 60) * 60;
  } else {
    billable = usedMin;
  }

  final pro = round2(billable / 60 * se.hourlyRate);
  double amount;
  if (se.mode == PkgMode.countdown) {
    final done = usedMin >= se.totalMinutes;
    if (done || st.earlyFull) {
      amount = se.price;
    } else {
      amount = pro < se.price ? pro : se.price;
    }
  } else {
    amount = pro;
  }
  return BillResult(
    usedMs: usedMs,
    billableMinutes: billable,
    amount: round2(amount + se.extraFee),
  );
}

class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore I = AppStore._();

  static const _key = 'wlgd_timer_state_v1';

  AppState s = AppState.initial();
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      s = AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 数据坏了就用默认数据，不让app起不来
      s = AppState.initial();
    }
  }

  void _save() {
    try {
      _prefs?.setString(_key, jsonEncode(s.toJson()));
    } catch (_) {}
  }

  void _touch([void Function()? fn]) {
    fn?.call();
    _save();
    notifyListeners();
  }

  // ---------- 查询 ----------

  String zoneName(String zoneId) {
    for (final z in s.zones) {
      if (z.id == zoneId) return z.name;
    }
    return '未分区';
  }

  Session? sessionOf(String seatId) => s.sessions[seatId];

  int get occupiedCount => s.sessions.length;

  // ---------- 分区 ----------

  void addZone(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _touch(() => s.zones.add(Zone(id: newId(), name: n)));
  }

  void renameZone(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _touch(() {
      for (final z in s.zones) {
        if (z.id == id) z.name = n;
      }
    });
  }

  /// 删除分区：里面的桌位回到「未分区」，不会丢
  void deleteZone(String id) {
    _touch(() {
      s.zones.removeWhere((z) => z.id == id);
      for (final st in s.seats) {
        if (st.zoneId == id) st.zoneId = '';
      }
    });
  }

  // ---------- 桌位 ----------

  /// 桌位重名只在同一个分区内算冲突：大厅可以有1号桌，包间也可以有1号桌。
  /// [zoneId] 传 null 表示全店查重。
  bool seatNameExists(String name, {String? exceptId, String? zoneId}) {
    for (final st in s.seats) {
      if (st.id == exceptId) continue;
      if (zoneId != null && st.zoneId != zoneId) continue;
      if (st.name == name) return true;
    }
    return false;
  }

  void addSeat(String zoneId, String name) {
    addSeats(zoneId, [name]);
  }

  /// 返回真正加进去的数量（重名的会被跳过）
  int addSeats(String zoneId, List<String> names) {
    var added = 0;
    _touch(() {
      for (final n in names) {
        final nm = n.trim();
        if (nm.isEmpty) continue;
        if (seatNameExists(nm, zoneId: zoneId)) continue;
        s.seats.add(Seat(id: newId(), zoneId: zoneId, name: nm));
        added++;
      }
    });
    return added;
  }

  void renameSeat(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _touch(() {
      for (final st in s.seats) {
        if (st.id == id) st.name = n;
      }
    });
  }

  void moveSeat(String id, String zoneId) {
    _touch(() {
      for (final st in s.seats) {
        if (st.id == id) st.zoneId = zoneId;
      }
    });
  }

  /// 桌位拖动排序：把 [movingId] 放到 [targetId] 原来的位置。
  /// 只允许在同一个分区内挪动。
  void reorderSeat(String movingId, String targetId) {
    if (movingId == targetId) return;
    final from = s.seats.indexWhere((x) => x.id == movingId);
    final targetIdx = s.seats.indexWhere((x) => x.id == targetId);
    if (from < 0 || targetIdx < 0) return;
    if (s.seats[from].zoneId != s.seats[targetIdx].zoneId) return;
    _touch(() {
      final moving = s.seats.removeAt(from);
      final at = s.seats.indexWhere((x) => x.id == targetId);
      s.seats.insert(at < 0 ? s.seats.length : at, moving);
    });
  }

  /// 分区排序：[newIndex] 是「把这一项拿出去之后」要插入的下标
  void reorderZone(String movingId, int newIndex) {
    final from = s.zones.indexWhere((z) => z.id == movingId);
    if (from < 0 || s.zones.length < 2) return;
    _touch(() {
      final z = s.zones.removeAt(from);
      var to = newIndex;
      if (to < 0) to = 0;
      if (to > s.zones.length) to = s.zones.length;
      s.zones.insert(to, z);
    });
  }

  void deleteSeat(String id) {
    _touch(() {
      s.seats.removeWhere((st) => st.id == id);
      s.sessions.remove(id);
    });
  }

  // ---------- 套餐 ----------

  void savePkg(Pkg p) {
    _touch(() {
      final i = s.packages.indexWhere((e) => e.id == p.id);
      if (i >= 0) {
        s.packages[i] = p;
      } else {
        s.packages.add(p);
      }
    });
  }

  void deletePkg(String id) {
    _touch(() => s.packages.removeWhere((e) => e.id == id));
  }

  // ---------- 开台 / 计时 ----------

  void openSeat(
    Seat seat, {
    String? pkgId,
    required String pkgName,
    required PkgMode mode,
    int minutes = 0,
    double price = 0,
    double hourlyRate = 10,
  }) {
    _touch(() {
      s.sessions[seat.id] = Session(
        seatId: seat.id,
        pkgId: pkgId,
        pkgName: pkgName,
        mode: mode,
        startAt: DateTime.now(),
        minutes: mode == PkgMode.countdown ? minutes : 0,
        price: price,
        hourlyRate: hourlyRate,
      );
    });
  }

  void changePackage(Seat seat, Pkg p) {
    final se = s.sessions[seat.id];
    if (se == null) return;
    _touch(() {
      se.pkgId = p.id;
      se.pkgName = p.name;
      se.mode = p.mode;
      se.minutes = p.mode == PkgMode.countdown ? p.minutes : 0;
      se.price = p.price;
      se.hourlyRate = p.hourlyRate;
      se.extraMinutes = 0;
      se.extraFee = 0;
    });
  }

  void togglePause(Seat seat) {
    final se = s.sessions[seat.id];
    if (se == null) return;
    _touch(() {
      final now = DateTime.now();
      if (se.pausedAt == null) {
        se.pausedAt = now;
      } else {
        se.pausedMs += now.difference(se.pausedAt!).inMilliseconds;
        se.pausedAt = null;
      }
    });
  }

  void addTime(Seat seat, int minutes, double fee) {
    final se = s.sessions[seat.id];
    if (se == null) return;
    _touch(() {
      if (se.mode == PkgMode.countdown) {
        se.extraMinutes += minutes;
      }
      se.extraFee = round2(se.extraFee + fee);
    });
  }

  void setStartAt(Seat seat, DateTime t) {
    final se = s.sessions[seat.id];
    if (se == null) return;
    _touch(() => se.startAt = t);
  }

  /// 结账清台。[settle] true = 入账并清台（余额增加），false = 清台不入账
  double checkout(Seat seat, {required bool settle}) {
    final se = s.sessions[seat.id];
    if (se == null) return 0;
    final now = DateTime.now();
    final bill = calcBill(se, s, now);
    _touch(() {
      s.sessions.remove(seat.id);
      s.records.insert(
        0,
        BillRecord(
          id: newId(),
          seatName: seat.name,
          zoneName: zoneName(seat.zoneId),
          pkgName: se.pkgName,
          mode: se.mode,
          startAt: se.startAt,
          endAt: now,
          usedMs: bill.usedMs,
          amount: bill.amount,
          settled: settle,
        ),
      );
      if (settle) s.balance = round2(s.balance + bill.amount);
    });
    return bill.amount;
  }

  // ---------- 记录 / 设置 ----------

  void deleteRecord(String id) {
    _touch(() => s.records.removeWhere((r) => r.id == id));
  }

  void clearRecords() {
    _touch(() => s.records.clear());
  }

  void setShopName(String v) => _touch(() => s.shopName = v.trim().isEmpty ? '我勒个豆' : v.trim());

  void setHourlyRate(double v) => _touch(() => s.hourlyRate = v < 0 ? 0 : v);

  void setRounding(int v) => _touch(() => s.rounding = v);

  void setEarlyFull(bool v) => _touch(() => s.earlyFull = v);

  void setBalance(double v) => _touch(() => s.balance = round2(v));

  void resetAll() => _touch(() => s = AppState.initial());
}

final AppStore store = AppStore.I;
