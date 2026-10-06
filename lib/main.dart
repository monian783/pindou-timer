import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notify.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我勒个豆计时器',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_syncNotify);
    // 启动时先同步一次（上次退出时可能还有桌位在计中）
    WidgetsBinding.instance.addPostFrameCallback((_) => TimerNotify.sync(force: true));
    // 定时校准：万一系统时间被改过，重推一次
    _beat = Timer.periodic(const Duration(seconds: 60), (_) => TimerNotify.sync(force: true));
  }

  @override
  void dispose() {
    _beat?.cancel();
    store.removeListener(_syncNotify);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncNotify() {
    TimerNotify.sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TimerNotify.sync(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(
        index: _index,
        children: const [HomePage(), MinePage()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.card,
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (v) => setState(() => _index = v),
            backgroundColor: C.card,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: C.primary,
            unselectedItemColor: C.sub,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded, size: 22),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 22),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
