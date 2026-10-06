import 'package:flutter/material.dart';

import '../theme.dart';

/// 二级页面的顶部标题栏
class SubHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const SubHeader(this.title, {super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: C.text),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.text),
            ),
          ),
          ...actions,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
