import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glow_background.dart';
import 'theme.dart';

/// شاشة الشروط والأحكام — تطلع مرة وحدة أول ما يفتح التطبيق، وما يقدر
/// يكمّل إلا لو ضغط "موافق". خلفيتها متحركة دايماً (نفس GlowBackground).
class TermsScreen extends StatelessWidget {
  final VoidCallback onAccepted;
  const TermsScreen({super.key, required this.onAccepted});

  static const _prefKey = 'acceptedTerms';

  static Future<bool> isAccepted() async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

  Future<void> _accept() async {
    await (await SharedPreferences.getInstance()).setBool(_prefKey, true);
    onAccepted();
  }

  static const _rules = [
    'ممنوع نشر أي محتوى تجريبي أو تجارب غير جادة — جماعتكم للمحتوى الحقيقي بس.',
    'احترم بقية الأعضاء، وما تنشر أي محتوى مسيء أو مخالف.',
    'حسابك مسؤوليتك، حافظ على كلمة السر وما تشاركها حد.',
    'إدارة التطبيق تقدر تحذف أي محتوى أو حساب يخالف هالشروط بدون إشعار.',
  ];

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false, // ما يرجع بالضغط على رجوع قبل ما يوافق أو يرفض
        child: Scaffold(
          body: GlowBackground(
            active: true, // متحركة دايماً بهالشاشة
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(children: [
                  const Icon(Icons.gavel_rounded, size: 46, color: brand),
                  const SizedBox(height: 14),
                  const Text('الشروط والأحكام', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('اقرأ ووافق عشان تكمّل استخدام جماعتكم', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 22),
                  Expanded(
                    child: GlassCard(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final r in _rules)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.circle, size: 7, color: brand)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(r, style: const TextStyle(fontSize: 14.5, height: 1.6))),
                              ]),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: PressScale(
                        onTap: () => SystemNavigator.pop(), // إلغاء = ما يدخل التطبيق
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: outline, width: 1.5)),
                          child: const Text('إلغاء', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFC9C5E6))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: GradientButton(text: 'موافق', onPressed: _accept)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
