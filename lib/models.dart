// 数据模型：分区 / 桌位 / 套餐 / 开台会话 / 账单
// 全部可 JSON 序列化，存本地

int _i(dynamic v, [int d = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

double _d(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

String _s(dynamic v, [String d = '']) => v is String ? v : d;

bool _b(dynamic v, [bool d = false]) => v is bool ? v : d;

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

List<dynamic> _l(dynamic v) => v is List ? v : const [];

T _e<T>(List<T> values, dynamic v, T fallback) {
  final i = _i(v, -1);
  return (i >= 0 && i < values.length) ? values[i] : fallback;
}

/// 分区（店里的区域，比如：大厅、包间、二楼）
class Zone {
  String id;
  String name;
  Zone({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Zone.fromJson(Map<String, dynamic> j) =>
      Zone(id: _s(j['id']), name: _s(j['name'], '未命名'));
}

/// 桌位（座位，比如：1号桌、散座）
class Seat {
  String id;
  String zoneId; // 空字符串代表「未分区」
  String name;
  Seat({required this.id, this.zoneId = '', required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'zoneId': zoneId, 'name': name};

  factory Seat.fromJson(Map<String, dynamic> j) =>
      Seat(id: _s(j['id']), zoneId: _s(j['zoneId']), name: _s(j['name'], '未命名'));
}

enum PkgGroup { manager, general }

extension PkgGroupX on PkgGroup {
  String get label => this == PkgGroup.manager ? '店长专属' : '通用套餐';
}

enum PkgMode { countdown, countup }

extension PkgModeX on PkgMode {
  String get label => this == PkgMode.countdown ? '倒计时' : '正计时';
}

/// 套餐
class Pkg {
  String id;
  String name;
  PkgGroup group;
  PkgMode mode;
  int minutes; // 倒计时时长（分钟）
  double price; // 套餐价（倒计时按这个价收）
  double hourlyRate; // 每小时单价（正计时用；倒计时提前结账折算也用）

  Pkg({
    required this.id,
    required this.name,
    this.group = PkgGroup.general,
    this.mode = PkgMode.countdown,
    this.minutes = 120,
    this.price = 0,
    this.hourlyRate = 10,
  });

  Pkg clone() => Pkg.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group.index,
        'mode': mode.index,
        'minutes': minutes,
        'price': price,
        'hourlyRate': hourlyRate,
      };

  factory Pkg.fromJson(Map<String, dynamic> j) => Pkg(
        id: _s(j['id']),
        name: _s(j['name'], '未命名套餐'),
        group: _e(PkgGroup.values, j['group'], PkgGroup.general),
        mode: _e(PkgMode.values, j['mode'], PkgMode.countdown),
        minutes: _i(j['minutes'], 120),
        price: _d(j['price']),
        hourlyRate: _d(j['hourlyRate'], 10),
      );
}

/// 一次开台（客人坐下到清台）
class Session {
  String seatId;
  String? pkgId;
  String pkgName;
  PkgMode mode;
  DateTime startAt; // 实际开台时间（可手动改）
  int minutes; // 倒计时总时长
  double price; // 套餐价
  double hourlyRate; // 时价
  int extraMinutes; // 加钟时长
  double extraFee; // 加钟费用
  int pausedMs; // 累计已暂停毫秒
  DateTime? pausedAt; // 当前暂停起点，null = 没暂停

  Session({
    required this.seatId,
    this.pkgId,
    required this.pkgName,
    required this.mode,
    required this.startAt,
    this.minutes = 0,
    this.price = 0,
    this.hourlyRate = 10,
    this.extraMinutes = 0,
    this.extraFee = 0,
    this.pausedMs = 0,
    this.pausedAt,
  });

  bool get paused => pausedAt != null;

  int get totalMinutes => minutes + extraMinutes;

  /// 已计时长（毫秒），不含暂停
  int elapsedMs(DateTime now) {
    var ms = now.difference(startAt).inMilliseconds - pausedMs;
    if (pausedAt != null) ms -= now.difference(pausedAt!).inMilliseconds;
    return ms < 0 ? 0 : ms;
  }

  /// 剩余（倒计时）
  int remainMs(DateTime now) => totalMinutes * 60000 - elapsedMs(now);

  /// 倒计时到点（自动停）
  bool isOut(DateTime now) => mode == PkgMode.countdown && remainMs(now) <= 0;

  Map<String, dynamic> toJson() => {
        'seatId': seatId,
        'pkgId': pkgId,
        'pkgName': pkgName,
        'mode': mode.index,
        'startAt': startAt.millisecondsSinceEpoch,
        'minutes': minutes,
        'price': price,
        'hourlyRate': hourlyRate,
        'extraMinutes': extraMinutes,
        'extraFee': extraFee,
        'pausedMs': pausedMs,
        'pausedAt': pausedAt?.millisecondsSinceEpoch,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        seatId: _s(j['seatId']),
        pkgId: j['pkgId'] == null ? null : _s(j['pkgId']),
        pkgName: _s(j['pkgName'], '自定义'),
        mode: _e(PkgMode.values, j['mode'], PkgMode.countup),
        startAt: DateTime.fromMillisecondsSinceEpoch(_i(j['startAt'], DateTime.now().millisecondsSinceEpoch)),
        minutes: _i(j['minutes']),
        price: _d(j['price']),
        hourlyRate: _d(j['hourlyRate'], 10),
        extraMinutes: _i(j['extraMinutes']),
        extraFee: _d(j['extraFee']),
        pausedMs: _i(j['pausedMs']),
        pausedAt: j['pausedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(_i(j['pausedAt'])),
      );
}

/// 结账记录
class BillRecord {
  String id;
  String seatName;
  String zoneName;
  String pkgName;
  PkgMode mode;
  DateTime startAt;
  DateTime endAt;
  int usedMs;
  double amount;
  bool settled; // true = 入账并清台

  BillRecord({
    required this.id,
    required this.seatName,
    required this.zoneName,
    required this.pkgName,
    required this.mode,
    required this.startAt,
    required this.endAt,
    required this.usedMs,
    required this.amount,
    required this.settled,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'seatName': seatName,
        'zoneName': zoneName,
        'pkgName': pkgName,
        'mode': mode.index,
        'startAt': startAt.millisecondsSinceEpoch,
        'endAt': endAt.millisecondsSinceEpoch,
        'usedMs': usedMs,
        'amount': amount,
        'settled': settled,
      };

  factory BillRecord.fromJson(Map<String, dynamic> j) => BillRecord(
        id: _s(j['id']),
        seatName: _s(j['seatName']),
        zoneName: _s(j['zoneName']),
        pkgName: _s(j['pkgName']),
        mode: _e(PkgMode.values, j['mode'], PkgMode.countup),
        startAt: DateTime.fromMillisecondsSinceEpoch(_i(j['startAt'], DateTime.now().millisecondsSinceEpoch)),
        endAt: DateTime.fromMillisecondsSinceEpoch(_i(j['endAt'], DateTime.now().millisecondsSinceEpoch)),
        usedMs: _i(j['usedMs']),
        amount: _d(j['amount']),
        settled: _b(j['settled']),
      );
}

/// 全部本地数据
class AppState {
  String shopName;
  double hourlyRate; // 默认每小时单价（自定义/正计时用）
  int rounding; // 0 按分钟；30 不足半小时按半小时；60 不足1小时按1小时
  bool earlyFull; // 倒计时套餐提前结账是否按套餐价全额收
  double balance; // 虚拟余额
  List<Zone> zones;
  List<Seat> seats;
  List<Pkg> packages;
  Map<String, Session> sessions; // seatId -> 会话
  List<BillRecord> records;

  AppState({
    this.shopName = '我勒个豆',
    this.hourlyRate = 10,
    this.rounding = 0,
    this.earlyFull = false,
    this.balance = 0,
    List<Zone>? zones,
    List<Seat>? seats,
    List<Pkg>? packages,
    Map<String, Session>? sessions,
    List<BillRecord>? records,
  })  : zones = zones ?? [],
        seats = seats ?? [],
        packages = packages ?? [],
        sessions = sessions ?? {},
        records = records ?? [];

  /// 首次安装的默认数据
  static AppState initial() {
    return AppState(
      zones: [Zone(id: 'z_hall', name: '大厅')],
      seats: [
        Seat(id: 'st_1', zoneId: 'z_hall', name: '1号桌'),
        Seat(id: 'st_2', zoneId: 'z_hall', name: '2号桌'),
        Seat(id: 'st_3', zoneId: 'z_hall', name: '3号桌'),
        Seat(id: 'st_4', zoneId: '', name: '散座'),
      ],
      packages: [
        Pkg(
            id: 'pk_hour',
            name: '按小时计费',
            group: PkgGroup.general,
            mode: PkgMode.countup,
            hourlyRate: 10),
        Pkg(
            id: 'pk_2h',
            name: '2小时体验',
            group: PkgGroup.general,
            mode: PkgMode.countdown,
            minutes: 120,
            price: 20,
            hourlyRate: 10),
        Pkg(
            id: 'pk_half',
            name: '包半天（4小时）',
            group: PkgGroup.general,
            mode: PkgMode.countdown,
            minutes: 240,
            price: 38,
            hourlyRate: 10),
        Pkg(
            id: 'pk_boss',
            name: '店长特惠',
            group: PkgGroup.manager,
            mode: PkgMode.countdown,
            minutes: 60,
            price: 5,
            hourlyRate: 5),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'hourlyRate': hourlyRate,
        'rounding': rounding,
        'earlyFull': earlyFull,
        'balance': balance,
        'zones': zones.map((e) => e.toJson()).toList(),
        'seats': seats.map((e) => e.toJson()).toList(),
        'packages': packages.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((k, v) => MapEntry(k, v.toJson())),
        'records': records.map((e) => e.toJson()).toList(),
      };

  factory AppState.fromJson(Map<String, dynamic> j) {
    final sessions = <String, Session>{};
    _m(j['sessions']).forEach((k, v) {
      final se = Session.fromJson(_m(v));
      sessions[k] = se;
    });
    return AppState(
      shopName: _s(j['shopName'], '我勒个豆'),
      hourlyRate: _d(j['hourlyRate'], 10),
      rounding: _i(j['rounding']),
      earlyFull: _b(j['earlyFull']),
      balance: _d(j['balance']),
      zones: _l(j['zones']).map((e) => Zone.fromJson(_m(e))).toList(),
      seats: _l(j['seats']).map((e) => Seat.fromJson(_m(e))).toList(),
      packages: _l(j['packages']).map((e) => Pkg.fromJson(_m(e))).toList(),
      sessions: sessions,
      records: _l(j['records']).map((e) => BillRecord.fromJson(_m(e))).toList(),
    );
  }
}

/// 结账明细
class BillResult {
  final int usedMs;
  final int billableMinutes;
  final double amount;
  const BillResult({required this.usedMs, required this.billableMinutes, required this.amount});
}
