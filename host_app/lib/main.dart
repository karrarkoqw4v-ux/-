import 'package:flutter/material.dart';
import 'screens.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const HostApp());
}

class HostApp extends StatelessWidget {
  const HostApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'استضافة',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFF0A0B1E),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C3AED), brightness: Brightness.dark),
      ),
      builder: (c, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const Root(),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (_, __) {
        final s = app.stage;
        final Widget w;
        switch (s) {
          case Stage.terms:
            w = const TermsScreen();
          case Stage.auth:
            w = const AuthScreen();
          case Stage.provision:
            w = ProvisionScreen(
              key: const ValueKey('prov1'),
              title: 'جاري تجهيز حسابك',
              sub: 'يتم إنشاء الخادم تلقائياً، انتظر قليلاً…',
              hint: 'قد يستغرق من 10 إلى 20 ثانية',
              minSec: 10,
              maxSec: 20,
              onDone: () => app.setStage(Stage.plans),
            );
          case Stage.plans:
            w = const PlansScreen();
          case Stage.creating:
            w = ProvisionScreen(
              key: const ValueKey('prov2'),
              title: 'جاري إنشاء الخادم…',
              sub: 'نجهّز خادمك على الخطة المجانية',
              hint: 'يستغرق من ثانية إلى 5 ثواني',
              minSec: 1,
              maxSec: 5,
              onDone: () => app.setStage(Stage.ready),
            );
          case Stage.ready:
            w = const HomeScreen();
        }
        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(key: ValueKey(s), child: w));
      },
    );
  }
}
