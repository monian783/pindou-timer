import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 弹窗：底层页面做模糊处理
Future<T?> showBlurDialog<T>(BuildContext context, Widget child) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (ctx, _, _) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, c) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: c,
    ),
  );
}

/// 底部操作面板：底层页面同样模糊
Future<T?> showBlurSheet<T>(BuildContext context, Widget child) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: child,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, c) {
      final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(a),
          child: c,
        ),
      );
    },
  );
}

/// 弹窗白底容器（用 Material 当底，弹窗里的 InkWell 才有水波）
Widget dialogBox({required Widget child, double width = 322, EdgeInsets? padding}) {
  return Material(
    color: C.card,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Container(
      width: width,
      padding: padding ?? const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: child,
    ),
  );
}

/// 底部面板白底容器
Widget sheetBox({required Widget child}) {
  return SafeArea(
    top: false,
    child: Material(
      color: C.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: child,
      ),
    ),
  );
}

/// 标题栏（关闭叉 + 标题）
Widget dialogHeader(BuildContext context, String title) {
  return Row(
    children: [
      const SizedBox(width: 32),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.text),
        ),
      ),
      SizedBox(
        width: 32,
        height: 32,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.close_rounded, size: 19, color: C.sub),
        ),
      ),
    ],
  );
}

/// 小圆角按钮（筛选用）
Widget pill({
  required String text,
  bool active = false,
  VoidCallback? onTap,
  IconData? icon,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(rBtn),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? C.primarySoft : C.card,
        borderRadius: BorderRadius.circular(rBtn),
        border: Border.all(color: active ? C.primary.withValues(alpha: 0.35) : C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: active ? C.primary : C.text,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 2),
            Icon(icon, size: 16, color: active ? C.primary : C.sub),
          ],
        ],
      ),
    ),
  );
}

/// 主按钮
Widget primaryBtn(String text, VoidCallback? onTap, {bool danger = false, bool enabled = true}) {
  final color = danger ? C.red : C.primary;
  return SizedBox(
    height: 44,
    child: Material(
      color: enabled ? color : C.line,
      borderRadius: BorderRadius.circular(rBtn),
      child: InkWell(
        borderRadius: BorderRadius.circular(rBtn),
        onTap: enabled ? onTap : null,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

/// 次要按钮
Widget ghostBtn(String text, VoidCallback? onTap, {Color? color}) {
  return SizedBox(
    height: 44,
    child: Material(
      color: C.card,
      borderRadius: BorderRadius.circular(rBtn),
      child: InkWell(
        borderRadius: BorderRadius.circular(rBtn),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(rBtn),
            border: Border.all(color: C.line),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: color ?? C.text),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 底部面板里的一行操作
Widget sheetItem({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
  Color? color,
  String? trailing,
  bool bold = false,
}) {
  final c = color ?? C.text;
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 19, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: c,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (trailing != null) Text(trailing, style: TextStyle(fontSize: 14, color: c)),
        ],
      ),
    ),
  );
}

class SheetDivider extends StatelessWidget {
  const SheetDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: C.line);
}

/// 输入框统一样式
InputDecoration inputDec(String hint, {String? label}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: C.bg,
      hintStyle: const TextStyle(fontSize: 14, color: C.hint),
      labelStyle: const TextStyle(fontSize: 13, color: C.sub),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rBtn),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rBtn),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rBtn),
        borderSide: const BorderSide(color: C.primary),
      ),
    );
