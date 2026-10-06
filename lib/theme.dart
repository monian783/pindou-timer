import 'package:flutter/material.dart';

/// 全局配色：浅灰底 + 白卡片 + 蓝色主色，状态色只用于状态
class C {
  static const bg = Color(0xFFF4F5F7);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2B6DE5);
  static const primarySoft = Color(0xFFEAF1FE);
  static const text = Color(0xFF1F2329);
  static const sub = Color(0xFF8A9099);
  static const hint = Color(0xFFB4B9C0);
  static const line = Color(0xFFE9EBEF);

  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFEAF7EF);
  static const orange = Color(0xFFD97706);
  static const orangeSoft = Color(0xFFFDF4E7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFDECEC);
}

const double rCard = 14;
const double rBtn = 10;
const double rSheet = 20;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: C.primary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: C.primary,
      surface: C.card,
      onSurface: C.text,
    ),
    scaffoldBackgroundColor: C.bg,
  );
}

const kTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.text);
const kBody = TextStyle(fontSize: 14, color: C.text);
const kSub = TextStyle(fontSize: 12, color: C.sub);
const kNum = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: C.green,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// 统一卡片：白底 + 细边 + 小圆角，不用阴影
BoxDecoration cardDec({Color? color, Color? border, double r = rCard}) => BoxDecoration(
      color: color ?? C.card,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: border ?? C.line),
    );
