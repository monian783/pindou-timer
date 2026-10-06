import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';
import 'store.dart';
import 'utils.dart';

/// 通知栏常驻计时（安卓侧 TimerService）。
///
/// 这里只负责把「每桌的目标时间 / 起始时间」推过去，秒级刷新由安卓那边自己算，
/// 所以不用每秒过一次通道。
class TimerNotify {
  static const MethodChannel _channel = MethodChannel('wlgd/timer_notify');

  static String _lastSig = '';

  /// 状态没变就不重复推。[force] 用于定时校准和回到前台时重推一次。
  static Future<void> sync({bool force = false}) async {
    final payload = buildPayload();
    final items = payload['items'] as List;
    final sig = items
        .map((e) => '${e['name']}|${e['kind']}|${e['frozen'] ?? ''}')
        .join(',');

    if (!force && sig == _lastSig) return;
    _lastSig = sig;

    try {
      if (items.isEmpty) {
        await _channel.invokeMethod<void>('stop');
      } else {
        await _channel.invokeMethod<void>('update', {'payload': jsonEncode(payload)});
      }
    } catch (_) {
      // 非安卓环境（比如跑测试）没有这个通道，忽略
    }
  }

  static Map<String, dynamic> buildPayload() {
    final now = DateTime.now();
    final items = <Map<String, dynamic>>[];

    // 按桌位本身的顺序排，跟首页看到的顺序一致
    for (final seat in store.s.seats) {
      final se = store.s.sessions[seat.id];
      if (se == null) continue;
      final name = '${store.zoneName(seat.zoneId)}·${seat.name}';

      if (se.paused) {
        final frozen = _frozenMs(se);
        final show = se.mode == PkgMode.countdown ? se.totalMinutes * 60000 - frozen : frozen;
        items.add({'name': name, 'kind': 'paused', 'frozen': fmtHms(show)});
      } else if (se.mode == PkgMode.countdown) {
        final remain = se.remainMs(now);
        if (remain <= 0) {
          items.add({'name': name, 'kind': 'out'});
        } else {
          items.add({
            'name': name,
            'kind': 'down',
            'target': now.millisecondsSinceEpoch + remain,
          });
        }
      } else {
        items.add({
          'name': name,
          'kind': 'up',
          'base': now.millisecondsSinceEpoch - se.elapsedMs(now),
        });
      }
    }

    return {'shop': store.s.shopName, 'items': items};
  }

  /// 暂停那一刻已经走了多久（不含当前这次暂停）
  static int _frozenMs(Session se) {
    final pausedAt = se.pausedAt;
    if (pausedAt == null) return se.elapsedMs(DateTime.now());
    final ms = pausedAt.difference(se.startAt).inMilliseconds - se.pausedMs;
    return ms < 0 ? 0 : ms;
  }
}
