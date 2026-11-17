import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ToolBoxApp());

class Section {
  final String title, desc;
  final IconData icon;
  final List<Color> colors;
  const Section(this.title, this.desc, this.icon, this.colors);
}

const sections = <Section>[
  Section('رسل ومشاركة', 'أرسل ملفاتك وروابطك وشاركها بسرعة', Icons.send_rounded,
      [Color(0xFF00C6FF), Color(0xFF0072FF)]),
  Section('أدوات تطوير', 'أدوات المبرمجين والمطورين في مكان واحد', Icons.terminal_rounded,
      [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
  Section('تحميل وسيفر', 'حمّل واحفظ ملفاتك بأمان', Icons.cloud_download_rounded,
      [Color(0xFF11998E), Color(0xFF38EF7D)]),
  Section('بحث تحميل', 'ابحث عن أي شيء وحمّله مباشرة', Icons.travel_explore_rounded,
      [Color(0xFFFF512F), Color(0xFFF09819)]),
  Section('المتجر', 'تطبيقات وأدوات جاهزة للتنزيل', Icons.storefront_rounded,
      [Color(0xFFEC008C), Color(0xFFFC6767)]),
];

class ToolBoxApp extends StatelessWidget {
  const ToolBoxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صندوق الأدوات',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0B1E),
      ),
      builder: (c, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const IntroScreen(),
    );
  }
}

/// خلفية بكرات ضوئية ملوّنة تتحرك باستمرار
class MovingBackground extends StatefulWidget {
  final Widget child;
  const MovingBackground({super.key, required this.child});
  @override
  State<MovingBackground> createState() => _MovingBackgroundState();
}

class _MovingBackgroundState extends State<MovingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: c,
        builder: (_, __) => CustomPaint(painter: _BlobPainter(c.value)),
      ),
      widget.child,
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  _BlobPainter(this.t);
  static const blobs = [
    [Color(0xFF7C3AED), 1, 0.0, 0.55],
    [Color(0xFF06B6D4), 2, 0.25, 0.5],
    [Color(0xFFEC4899), 1, 0.5, 0.6],
    [Color(0xFFF59E0B), 2, 0.75, 0.45],
  ];

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0B1E), Color(0xFF120A2E)],
          ).createShader(Offset.zero & s));
    for (final b in blobs) {
      final color = b[0] as Color;
      final k = (b[1] as num).toDouble();
      final ph = b[2] as double;
      final r = (b[3] as double) * s.width;
      final a = 2 * math.pi * (t * k + ph);
      final center = Offset(s.width * (0.5 + 0.45 * math.sin(a)),
          s.height * (0.5 + 0.4 * math.cos(a * 0.9 + ph * 6)));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(
                    colors: [color.withOpacity(0.55), color.withOpacity(0)])
                .createShader(Rect.fromCircle(center: center, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_BlobPainter o) => o.t != t;
}

// ───────────────── شاشة الدخول ─────────────────
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void _start() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
              scale: Tween(begin: 1.08, end: 1.0)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
              child: child)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MovingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Spacer(flex: 3),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.6),
                          blurRadius: 50,
                          spreadRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.widgets_rounded, size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 34),
              const Text('صندوق الأدوات',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('كل ما تحتاجه في تطبيق واحد',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
              const Spacer(flex: 4),
              AnimatedBuilder(
                animation: pulse,
                builder: (_, child) => Transform.scale(
                    scale: 1 + 0.04 * pulse.value, child: child),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFEC4899).withOpacity(0.5),
                            blurRadius: 28,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: _start,
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('تريد نبدأ الآن؟',
                                  style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.w800)),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_back_rounded),
                            ]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────── الأقسام ─────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MovingBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            children: [
              const Text('الأقسام',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('اختر القسم اللي تريده',
                  style: TextStyle(color: Colors.white.withOpacity(0.65))),
              const SizedBox(height: 22),
              for (var i = 0; i < sections.length; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 450 + i * 120),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                          offset: Offset(0, 30 * (1 - v)), child: child)),
                  child: _SectionCard(sections[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Section s;
  const _SectionCard(this.s);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ComingSoonScreen(s))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Row(children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: s.colors),
                  boxShadow: [
                    BoxShadow(
                        color: s.colors.first.withOpacity(0.5), blurRadius: 18)
                  ],
                ),
                child: Icon(s.icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.desc,
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withOpacity(0.65))),
                ]),
              ),
              Icon(Icons.chevron_left_rounded, color: Colors.white.withOpacity(0.6)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────── قيد التطوير ─────────────────
class ComingSoonScreen extends StatelessWidget {
  final Section s;
  const ComingSoonScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MovingBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                  padding: const EdgeInsets.all(16),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_rounded)),
            ),
            const Spacer(),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(colors: s.colors),
                boxShadow: [
                  BoxShadow(color: s.colors.first.withOpacity(0.6), blurRadius: 40)
                ],
              ),
              child: Icon(s.icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Text(s.title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.construction_rounded, size: 18, color: Color(0xFFFACC15)),
                SizedBox(width: 8),
                Text('قيد التطوير', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('نشتغل عليه، ويجيك قريباً',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}
