import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'feed_screen.dart';
import 'login_screen.dart';
import 'notifications.dart';
import 'terms_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // يقرأ إعداداته من google-services.json تلقائياً
  Notifications.init(); // يطلب إذن الإشعارات أول ما يفتح التطبيق
  runApp(const JamaatkumApp());
}

class JamaatkumApp extends StatelessWidget {
  const JamaatkumApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'جماعتكم',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const AppGate(),
      );
}

/// أول شاشة تفتح: تتأكد إن المستخدم وافق على الشروط قبل أي شي، وبعدها
/// توديه لتسجيل الدخول أو مباشرة للفيديوهات لو عنده جلسة شغّالة.
class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    TermsScreen.isAccepted().then((v) => setState(() => _accepted = v));
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_accepted == false) return TermsScreen(onAccepted: () => setState(() => _accepted = true));
    return FutureBuilder<bool>(
      future: Api.hasSession(),
      builder: (c, s) => s.connectionState != ConnectionState.done
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (s.data! ? const FeedScreen() : const LoginScreen()),
    );
  }
}
