int _seq = 0;

String newId() {
  _seq++;
  return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_seq.toRadixString(36)}';
}

String two(int n) => n.toString().padLeft(2, '0');

/// 毫秒 -> 01:23:45
String fmtHms(int ms) {
  var t = ms ~/ 1000;
  if (t < 0) t = 0;
  return '${two(t ~/ 3600)}:${two((t % 3600) ~/ 60)}:${two(t % 60)}';
}

/// 时长口语化：1小时23分
String fmtSpan(int ms) {
  var m = ms ~/ 60000;
  if (m < 0) m = 0;
  final h = m ~/ 60;
  final mm = m % 60;
  if (h > 0 && mm > 0) return '$h小时$mm分';
  if (h > 0) return '$h小时';
  return '$mm分';
}

double round2(double v) => (v * 100).roundToDouble() / 100;

String fmtMoney(double v) => '¥${round2(v).toStringAsFixed(2)}';

/// 金额显示去掉无意义的 .00
String fmtMoneyShort(double v) {
  final r = round2(v);
  if (r == r.roundToDouble()) return '¥${r.toInt()}';
  return '¥${r.toStringAsFixed(2)}';
}

String fmtClock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDay(DateTime d) => '${d.month}月${d.day}日';

String fmtFull(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';

/// 桌号排序：1号桌 < 2号桌 < 10号桌，非数字的排后面
int seatCompare(String a, String b) {
  final na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
  final nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
  if (na != null && nb != null) {
    if (na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }
  if (na != null) return -1;
  if (nb != null) return 1;
  return a.compareTo(b);
}

/// 解析批量添加：支持 "1-10" / "1,2,3" / "A1-A5"
List<String> parseBulkNames(String input, String suffix) {
  final out = <String>[];
  for (var part in input.split(RegExp(r'[,，、\s]+'))) {
    part = part.trim();
    if (part.isEmpty) continue;
    final m = RegExp(r'^(\D*)(\d+)\s*[-~至]\s*(\D*)(\d+)$').firstMatch(part);
    if (m != null) {
      final p1 = m.group(1)!;
      final n1 = int.parse(m.group(2)!);
      final p2 = m.group(3)!;
      final n2 = int.parse(m.group(4)!);
      final pre = p1.isNotEmpty ? p1 : p2;
      final from = n1 <= n2 ? n1 : n2;
      final to = n1 <= n2 ? n2 : n1;
      if (to - from > 200) continue;
      for (var i = from; i <= to; i++) {
        out.add('$pre$i$suffix');
      }
    } else {
      final hasDigit = RegExp(r'\d').hasMatch(part);
      if (hasDigit && suffix.isNotEmpty && !part.endsWith(suffix)) {
        out.add('$part$suffix');
      } else {
        out.add(part);
      }
    }
  }
  return out;
}
