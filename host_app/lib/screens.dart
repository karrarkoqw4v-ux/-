import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'runner.dart';
import 'store.dart';
import 'ui.dart';

// ═════════════ الشروط ═════════════
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool agree = false;
  static const clauses = [
    'ممنوع رفع أي محتوى مخالف أو ضار أو مسروق.',
    'ممنوع استخدام الخادم للاختراق أو الهجمات أو الإساءة.',
    'أنت المسؤول الوحيد عن الكود والملفات التي ترفعها.',
    'الخطة المجانية تُعاد تشغيلها كل 24 ساعة.',
    'نحتفظ بحق إيقاف أي خادم مخالف دون إشعار.',
    'لا نشارك بياناتك مع أي طرف ثالث.',
  ];
  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(children: [
        const SizedBox(height: 6),
        const Logo(Icons.verified_user_outlined, size: 62),
        const SizedBox(height: 10),
        const Text('شروط الاستخدام',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        Text('اقرأها بتمعّن قبل المتابعة',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 14),
        Expanded(
          child: Glass(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: ListView(children: [
              for (var i = 0; i < clauses.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}',
                        style: const TextStyle(
                            color: Color(0xFF06B6D4),
                            fontWeight: FontWeight.w900,
                            fontSize: 17)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(clauses[i],
                            style: const TextStyle(fontSize: 16, height: 1.7))),
                  ]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => agree = !agree),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: agree
                    ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)])
                    : null,
                border: Border.all(color: Colors.white54),
              ),
              child: agree
                  ? const Icon(Icons.check_rounded, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('أوافق على الشروط وسياسة الخصوصية',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
        const SizedBox(height: 14),
        PressBtn(
            label: 'موافق ومتابعة',
            icon: Icons.arrow_back_rounded,
            onTap: agree ? app.acceptTerms : null),
      ]),
    );
  }
}

// ═════════════ تسجيل الدخول / إنشاء حساب ═════════════
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool register = false, loading = false;
  final u = TextEditingController(), p = TextEditingController(), p2 = TextEditingController();
  String? err;

  Future<void> submit() async {
    if (loading) return;
    setState(() {
      loading = true;
      err = null;
    });
    final e = register
        ? await app.register(u.text.trim(), p.text, p2.text)
        : await app.login(u.text.trim(), p.text);
    if (mounted) {
      setState(() {
        loading = false;
        err = e;
      });
    }
  }

  Future<void> serverDialog() async {
    final r = await askText(context, 'عنوان الخادم (مثال: https://my-host.com)',
        initial: app.base);
    if (r != null) {
      app.setBase(r);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Center(
        child: SingleChildScrollView(
          child: Column(children: [
            Logo(register ? Icons.auto_awesome : Icons.cloud_outlined),
            const SizedBox(height: 16),
            Text(register ? 'إنشاء حساب' : 'تسجيل الدخول',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            GField(controller: u, hint: 'اسم المستخدم', icon: Icons.person_outline),
            GField(controller: p, hint: 'كلمة السر', icon: Icons.lock_outline, obscure: true),
            if (register)
              GField(
                  controller: p2,
                  hint: 'تأكيد كلمة السر',
                  icon: Icons.lock_outline,
                  obscure: true),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(err!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFF6B88))),
              ),
            const SizedBox(height: 4),
            PressBtn(
                label: loading ? 'جاري الاتصال…' : (register ? 'التالي' : 'دخول'),
                icon: register && !loading ? Icons.arrow_back_rounded : null,
                onTap: loading ? null : submit),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() {
                register = !register;
                err = null;
              }),
              child: Text.rich(TextSpan(
                  text: register ? 'عندك حساب؟ ' : 'ما عندك حساب؟ ',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  children: [
                    TextSpan(
                        text: register ? 'تسجيل الدخول' : 'إنشاء حساب',
                        style: const TextStyle(
                            color: Color(0xFF06B6D4), fontWeight: FontWeight.w800))
                  ])),
            ),
            const SizedBox(height: 22),
            TextButton.icon(
              onPressed: serverDialog,
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(
                  app.base.isEmpty ? 'إعدادات الخادم (مطلوب)' : 'الخادم: ${app.base}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════ شاشة التحميل (تجهيز / إنشاء الخادم) ═════════════
class ProvisionScreen extends StatefulWidget {
  final String title, sub, hint;
  final int minSec, maxSec;
  final VoidCallback onDone;
  const ProvisionScreen(
      {super.key,
      required this.title,
      required this.sub,
      required this.hint,
      required this.minSec,
      required this.maxSec,
      required this.onDone});
  @override
  State<ProvisionScreen> createState() => _ProvisionScreenState();
}

class _ProvisionScreenState extends State<ProvisionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController c;
  @override
  void initState() {
    super.initState();
    final secs = widget.minSec + Random().nextInt(widget.maxSec - widget.minSec + 1);
    c = AnimationController(vsync: this, duration: Duration(seconds: secs))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Center(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                    strokeWidth: 7, color: Color(0xFF06B6D4), backgroundColor: Colors.white12)),
            const SizedBox(height: 28),
            Text(widget.title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(widget.sub, style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                  value: c.value,
                  minHeight: 9,
                  color: const Color(0xFF7C3AED),
                  backgroundColor: Colors.white12),
            ),
            const SizedBox(height: 10),
            Text('${(c.value * 100).round()}%  ·  ${widget.hint}',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════ الخطط ═════════════
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF7CFF9B);
    Widget f(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Icon(i, size: 20, color: green),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 15))),
          ]),
        );
    return AppPage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('اختر خطتك',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        Text('ابدأ مجاناً الآن', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          padding: const EdgeInsets.all(18),
          border: green.withOpacity(0.6),
          tint: const Color(0xFF11998E).withOpacity(0.22),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.star_outline_rounded, color: green),
              const SizedBox(width: 8),
              const Text('الخطة المجانية',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const Spacer(),
              const Pill('مجاناً', green),
            ]),
            const SizedBox(height: 10),
            f(Icons.bolt_rounded, 'سريعة (أخف من الخطة القصوى)'),
            f(Icons.dns_outlined, 'تجمع جميع الخوادم للمواقع والبوتات'),
            f(Icons.link_rounded, 'اتصال مستمر مع مراجعة وإعادة تشغيل'),
            f(Icons.schedule_rounded, 'تستمر 24 ساعة ثم تُعاد تلقائياً'),
            f(Icons.check_circle_outline_rounded, 'أداء سريع بدون تقطيع أو ضعف'),
          ]),
        ),
        const Spacer(),
        PressBtn(
            label: 'اضغط للخطة المجانية',
            colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
            onTap: () => app.setStage(Stage.creating)),
      ]),
    );
  }
}

// ═════════════ الأقسام ═════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      ('خوارزمية المواقع', 'استضافة مواقع الويب', Icons.public,
          const [Color(0xFF00C6FF), Color(0xFF0072FF)], false),
      ('بوتات تيليجرام', 'يعمل الآن', Icons.send_rounded,
          const [Color(0xFF29B6F6), Color(0xFF0288D1)], true),
      ('بوتات ديسكورد', 'استضافة بوتات ديسكورد', Icons.chat_bubble_outline,
          const [Color(0xFF5865F2), Color(0xFF404EED)], false),
      ('سيرفر ماين كرافت', 'سيرفرات اللعبة', Icons.view_in_ar_outlined,
          const [Color(0xFF43A047), Color(0xFF1B5E20)], false),
    ];
    return AppPage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('خادمي',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const Spacer(),
          const Pill('● متصل · مجاني', Color(0xFF7CFF9B)),
          IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: app.logout,
              icon: const Icon(Icons.logout_rounded)),
        ]),
        Text('مرحباً ${app.user ?? ''} — اختر نوع الخدمة',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 120),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Glass(
                radius: 22,
                border: items[i].$5 ? const Color(0xFF38EF7D).withOpacity(0.6) : null,
                onTap: () {
                  if (items[i].$5) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LanguagesScreen()));
                  } else {
                    toast(context, '${items[i].$1} — قريباً');
                  }
                },
                child: Row(children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: LinearGradient(colors: items[i].$4)),
                    child: Icon(items[i].$3, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(items[i].$1,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(items[i].$2,
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                  ])),
                  items[i].$5
                      ? const Pill('يعمل', Color(0xFF7CFF9B))
                      : Pill('قريباً', Colors.white70),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ═════════════ اختيار اللغة ═════════════
class LanguagesScreen extends StatelessWidget {
  const LanguagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cols = {
      'python': [const Color(0xFF3776AB), const Color(0xFF1f4e79)],
      'php': [const Color(0xFF777BB4), const Color(0xFF4F5B93)],
      'js': [const Color(0xFFF7DF1E), const Color(0xFFC9A800)],
    };
    return AppPage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward_rounded)),
          const Text('بوتات تيليجرام',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Text('اختر لغة البوت',
              style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ),
        for (final l in langs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Glass(
              radius: 22,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ProjectScreen(lang: l))),
              child: Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      gradient: LinearGradient(colors: cols[l.id]!)),
                  child: Text(l.badge,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: l.id == 'js' ? Colors.black : Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(l.depsHint,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                ])),
                const Icon(Icons.chevron_left_rounded),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ═════════════ المشروع: ملفات + لوحة تحكم ═════════════
class ProjectScreen extends StatefulWidget {
  final Lang lang;
  const ProjectScreen({super.key, required this.lang});
  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    Widget tabBtn(int i, IconData ic, String t) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => tab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: tab == i
                    ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899)])
                    : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(ic, size: 19),
                const SizedBox(width: 7),
                Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
    return AppPage(
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward_rounded)),
          Text('بوت ${widget.lang.title}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Glass(
          radius: 17,
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            tabBtn(0, Icons.folder_outlined, 'الملفات'),
            tabBtn(1, Icons.terminal_rounded, 'لوحة التحكم'),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(index: tab, children: [
            FilesTab(lang: widget.lang),
            ConsoleTab(lang: widget.lang),
          ]),
        ),
      ]),
    );
  }
}

// ───────── أدوات رفع الملفات ─────────
String _text(List<int> b) => utf8.decode(b, allowMalformed: true);

Future<Map<String, String>> pickFiles({bool zip = false}) async {
  final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: zip ? FileType.custom : FileType.any,
      allowedExtensions: zip ? ['zip'] : null);
  final out = <String, String>{};
  if (r == null) return out;
  for (final f in r.files) {
    final bytes = f.bytes;
    if (bytes == null) continue;
    if (zip || f.name.toLowerCase().endsWith('.zip')) {
      try {
        final a = ZipDecoder().decodeBytes(bytes);
        for (final e in a) {
          if (!e.isFile || e.name.startsWith('__MACOSX')) continue;
          out[e.name] = _text(e.content as List<int>);
        }
      } catch (_) {}
    } else {
      out[f.name] = _text(bytes);
    }
  }
  return out;
}

Future<void> fileActions(BuildContext c, String name,
    {VoidCallback? onRename, VoidCallback? onEdit, required VoidCallback onDelete}) {
  return showModalBottomSheet(
    context: c,
    backgroundColor: const Color(0xFF1d1745),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(name,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ),
        if (onRename != null)
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل الاسم'),
              onTap: () {
                Navigator.pop(c);
                onRename();
              }),
        if (onEdit != null)
          ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('تعديل الكود'),
              onTap: () {
                Navigator.pop(c);
                onEdit();
              }),
        ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B88)),
            title: const Text('حذف', style: TextStyle(color: Color(0xFFFF6B88))),
            onTap: () {
              Navigator.pop(c);
              onDelete();
            }),
      ]),
    ),
  );
}

// ───────── محرر الكود (إنشاء / تعديل ملف) ─────────
class EditorPage extends StatefulWidget {
  final String name, code;
  final bool isNew;
  final void Function(String name, String code) onSave;
  const EditorPage(
      {super.key,
      required this.name,
      required this.code,
      required this.isNew,
      required this.onSave});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final n = TextEditingController(text: widget.name);
  late final c = TextEditingController(text: widget.code);
  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward_rounded)),
          Text(widget.isNew ? 'إنشاء ملف' : 'تعديل الملف',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        GField(controller: n, hint: 'اسم الملف (مثال: main.py)', icon: Icons.insert_drive_file_outlined, mono: true),
        Expanded(
          child: Glass(
            radius: 18,
            tint: Colors.black.withOpacity(0.55),
            child: TextField(
              controller: c,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                  border: InputBorder.none, hintText: 'اكتب الكود هنا…'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PressBtn(
            label: 'حفظ',
            icon: Icons.save_outlined,
            onTap: () {
              final name = n.text.trim();
              if (name.isEmpty) {
                toast(context, 'اكتب اسم الملف');
                return;
              }
              widget.onSave(name, c.text);
              Navigator.pop(context);
            }),
      ]),
    );
  }
}

// ───────── صفحة الاستخراج ─────────
class ExtractPage extends StatefulWidget {
  final Lang lang;
  const ExtractPage({super.key, required this.lang});
  @override
  State<ExtractPage> createState() => _ExtractPageState();
}

class _ExtractPageState extends State<ExtractPage> {
  final staged = <String, String>{};

  Future<void> add(bool zip) async {
    final m = await pickFiles(zip: zip);
    if (m.isEmpty) {
      if (mounted) toast(context, 'لم يتم اختيار ملفات');
      return;
    }
    setState(() => staged.addAll(m));
  }

  @override
  Widget build(BuildContext context) {
    final names = staged.keys.toList()..sort();
    return AppPage(
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward_rounded)),
          const Text('استخراج',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        Row(children: [
          Expanded(
              child: Glass(
                  radius: 16,
                  onTap: () => add(false),
                  child: const Column(children: [
                    Icon(Icons.upload_file_rounded),
                    SizedBox(height: 4),
                    Text('رفع ملفات', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]))),
          const SizedBox(width: 10),
          Expanded(
              child: Glass(
                  radius: 16,
                  onTap: () => add(true),
                  child: const Column(children: [
                    Icon(Icons.folder_zip_outlined),
                    SizedBox(height: 4),
                    Text('رفع ملف ZIP', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]))),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: names.isEmpty
              ? Center(
                  child: Text('ارفع ملفات أو ZIP ليتم استخراجها هنا',
                      style: TextStyle(color: Colors.white.withOpacity(0.6))))
              : ListView(children: [
                  for (final n in names)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Glass(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        onTap: () => _edit(n),
                        onLongPress: () => fileActions(context, n,
                            onRename: () async {
                              final r = await askText(context, 'تعديل الاسم', initial: n);
                              if (r != null && r.isNotEmpty && r != n) {
                                setState(() => staged[r] = staged.remove(n)!);
                              }
                            },
                            onEdit: () => _edit(n),
                            onDelete: () => setState(() => staged.remove(n))),
                        child: Row(children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(n,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(fontFamily: 'monospace'))),
                        ]),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 8),
        Text('اضغط مطوّلاً على أي ملف للتعديل أو الحذف',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 8),
        PressBtn(
            label: 'حفظ في الملفات',
            icon: Icons.save_outlined,
            onTap: staged.isEmpty
                ? null
                : () async {
                    try {
                      final f = await app.files(widget.lang.id)
                        ..addAll(staged);
                      await app.saveFiles(widget.lang.id, f);
                      if (!mounted) return;
                      final n = staged.length;
                      Navigator.pop(context);
                      toast(context, 'تم حفظ $n ملف في قسم الملفات');
                    } on ApiError catch (e) {
                      if (mounted) toast(context, e.msg);
                    }
                  }),
      ]),
    );
  }

  void _edit(String n) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditorPage(
                  name: n,
                  code: staged[n] ?? '',
                  isNew: false,
                  onSave: (nn, code) => setState(() {
                    staged.remove(n);
                    staged[nn] = code;
                  }),
                )));
  }
}

// ───────── تبويب الملفات ─────────
class FilesTab extends StatefulWidget {
  final Lang lang;
  const FilesTab({super.key, required this.lang});
  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  String cwd = '';
  Map<String, String> files = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final f = await app.files(widget.lang.id);
      if (mounted) {
        setState(() {
          files = f;
          loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          error = e.msg;
          loading = false;
        });
      }
    }
  }

  Future<void> _commit(Map<String, String> nf) async {
    try {
      await app.saveFiles(widget.lang.id, nf);
      if (mounted) setState(() => files = nf);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.msg);
    }
  }

  String _p(String name) => cwd.isEmpty ? name : '$cwd/$name';

  Future<void> _newFolder() async {
    final name = await askText(context, 'اسم المجلد');
    if (name == null || name.isEmpty) return;
    final f = Map<String, String>.from(files);
    final picked = await pickFiles();
    if (picked.isEmpty) f['${_p(name)}/.keep'] = '';
    picked.forEach((k, v) => f['${_p(name)}/$k'] = v);
    await _commit(f);
    if (mounted) toast(context, 'تم إنشاء المجلد $name');
  }

  void _newFile() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditorPage(
                  name: cwd.isEmpty ? '' : '$cwd/',
                  code: '',
                  isNew: true,
                  onSave: (n, code) => _commit(Map<String, String>.from(files)..[n] = code),
                )));
  }

  void _editFile(String path) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditorPage(
                  name: path,
                  code: files[path] ?? '',
                  isNew: false,
                  onSave: (n, c) {
                    final f = Map<String, String>.from(files)..remove(path);
                    f[n] = c;
                    _commit(f);
                  },
                )));
  }

  Future<void> _renamePath(String path, bool dir) async {
    final r = await askText(context, 'تعديل الاسم', initial: path);
    if (r == null || r.isEmpty || r == path) return;
    final out = <String, String>{};
    files.forEach((k, v) {
      if (dir && k.startsWith('$path/')) {
        out['$r/${k.substring(path.length + 1)}'] = v;
      } else if (!dir && k == path) {
        out[r] = v;
      } else {
        out[k] = v;
      }
    });
    await _commit(out);
  }

  Future<void> _delete(String path, bool dir) async {
    final f = Map<String, String>.from(files)
      ..removeWhere((k, _) => dir ? k.startsWith('$path/') : k == path);
    await _commit(f);
  }

  @override
  Widget build(BuildContext context) {
    final f = files;
    final dirs = <String>{};
    final here = <String>[];
    for (final k in f.keys) {
      if (cwd.isNotEmpty && !k.startsWith('$cwd/')) continue;
      final rest = cwd.isEmpty ? k : k.substring(cwd.length + 1);
      if (rest.contains('/')) {
        dirs.add(rest.split('/').first);
      } else if (rest != '.keep') {
        here.add(rest);
      }
    }
    final dl = dirs.toList()..sort();
    here.sort();
    Widget big(IconData i, String t, VoidCallback on) => Expanded(
          child: Glass(
            radius: 16,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            onTap: on,
            child: Column(children: [
              Icon(i, size: 24),
              const SizedBox(height: 6),
              Text(t,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    Widget row(IconData i, String name, String path, bool dir) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Glass(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            onTap: () => dir ? setState(() => cwd = path) : _editFile(path),
            onLongPress: () => fileActions(context, path,
                onRename: () => _renamePath(path, dir),
                onEdit: dir ? null : () => _editFile(path),
                onDelete: () => _delete(path, dir)),
            child: Row(children: [
              Icon(i, size: 19),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(dir ? '$name/' : name,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'monospace'))),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        big(Icons.folder_zip_outlined, 'إنشاء مجلد (ZIP)', _newFolder),
        const SizedBox(width: 8),
        big(Icons.note_add_outlined, 'إنشاء ملف', _newFile),
        const SizedBox(width: 8),
        big(Icons.upload_file_rounded, 'استخراج', () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ExtractPage(lang: widget.lang)))
              .then((_) => _load());
        }),
      ]),
      if (cwd.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: () => setState(() {
                    final i = cwd.lastIndexOf('/');
                    cwd = i < 0 ? '' : cwd.substring(0, i);
                  }),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text('/$cwd', textDirection: TextDirection.ltr)),
        ),
      const SizedBox(height: 10),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF6B88))),
                    TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                  ]))
                : (dl.isEmpty && here.isEmpty)
                    ? Center(
                        child: Text('لا توجد ملفات بعد\nأنشئ ملفاً أو ارفع ملفاتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.6))))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(children: [
                          for (final d in dl) row(Icons.folder_outlined, d, _p(d), true),
                          for (final n in here)
                            row(Icons.insert_drive_file_outlined, n, _p(n), false),
                        ]),
                      ),
      ),
    ]);
  }
}

// ───────── لوحة التحكم (الكونسل) — تشغيل حقيقي على الخادم ─────────
class ConsoleTab extends StatefulWidget {
  final Lang lang;
  const ConsoleTab({super.key, required this.lang});
  @override
  State<ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<ConsoleTab> {
  final scroll = ScrollController();
  final lines = <Map>[];
  int next = 0;
  String state = 'idle';
  String? err;
  bool polling = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _poll();
    timer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (polling) return;
    polling = true;
    try {
      final j = await app.logs(widget.lang.id, next);
      final got = (j['lines'] as List).cast<Map>();
      final newNext = j['next'] as int;
      // إذا بدأ الخادم سجلاً جديداً (تشغيل جديد) نبدأ من الصفر
      if (newNext - got.length != next) lines.clear();
      lines.addAll(got);
      if (lines.length > 3000) lines.removeRange(0, lines.length - 3000);
      next = newNext;
      state = j['state'] as String;
      err = null;
      if (got.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
      }
    } on ApiError catch (e) {
      err = e.msg;
    } finally {
      polling = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _act(String a) async {
    try {
      state = await app.runAction(widget.lang.id, a);
      if (a != 'stop') {
        lines.clear();
        next = 0;
      }
      if (mounted) setState(() {});
      await _poll();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, col) = switch (state) {
      'running' => ('● يعمل', const Color(0xFF7CFF9B)),
      'installing' => ('… جاري التثبيت', const Color(0xFFFFD166)),
      'error' => ('● خطأ', const Color(0xFFFF6B88)),
      'stopped' => ('● متوقف', Colors.white60),
      _ => ('● جاهز', Colors.white60),
    };
    Color lc(String k) => switch (k) {
          'ok' => const Color(0xFF7CFF9B),
          'err' => const Color(0xFFFF5C7A),
          'warn' => const Color(0xFFFFD166),
          'info' => const Color(0xFF8AB4FF),
          _ => Colors.white70,
        };
    Widget ctl(String t, IconData i, Color c, String act) => Expanded(
          child: PressBtn(
              label: t,
              icon: i,
              height: 46,
              colors: [c, Color.lerp(c, Colors.black, 0.35)!],
              onTap: () => _act(act)),
        );
    return Column(children: [
      Row(children: [
        Pill(label, col),
        const SizedBox(width: 8),
        if (err != null)
          Expanded(
              child: Text(err!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFF6B88), fontSize: 11)))
        else
          Text('تشغيل حقيقي على الخادم',
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        ctl('تشغيل', Icons.play_arrow_rounded, const Color(0xFF22C55E), 'start'),
        const SizedBox(width: 8),
        ctl('إيقاف', Icons.stop_rounded, const Color(0xFFFF4D6D), 'stop'),
        const SizedBox(width: 8),
        ctl('إعادة', Icons.refresh_rounded, const Color(0xFFF59E0B), 'restart'),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12)),
          child: lines.isEmpty
              ? Text('اضغط «تشغيل» لتشغيل جميع الملفات…',
                  style: TextStyle(color: Colors.white.withOpacity(0.4)))
              : ListView.builder(
                  controller: scroll,
                  itemCount: lines.length,
                  itemBuilder: (_, i) => Text(lines[i]['t'] as String,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: lc(lines[i]['k'] as String),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.55)),
                ),
        ),
      ),
    ]);
  }
}
