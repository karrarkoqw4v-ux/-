import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// خلفية بقع ضوئية ملوّنة متحركة
class MovingBackground extends StatefulWidget {
  final Widget child;
  const MovingBackground({super.key, required this.child});
  @override
  State<MovingBackground> createState() => _MovingBackgroundState();
}

class _MovingBackgroundState extends State<MovingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => CustomPaint(painter: _Blobs(c.value))),
      ),
      widget.child,
    ]);
  }
}

class _Blobs extends CustomPainter {
  final double t;
  _Blobs(this.t);
  static const blobs = [
    [Color(0xFF7C3AED), 1, 0.0, 0.75],
    [Color(0xFF06B6D4), 2, 0.25, 0.65],
    [Color(0xFFEC4899), 1, 0.5, 0.75],
    [Color(0xFFF59E0B), 2, 0.75, 0.5],
  ];
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0A0B1E));
    for (final b in blobs) {
      final color = b[0] as Color;
      final k = (b[1] as num).toDouble();
      final ph = b[2] as double;
      final r = (b[3] as double) * s.width;
      final a = 2 * math.pi * (t * k + ph);
      final c = Offset(s.width * (0.5 + 0.45 * math.sin(a)),
          s.height * (0.5 + 0.4 * math.cos(a * 0.9 + ph * 6)));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
                    colors: [color.withOpacity(0.6), color.withOpacity(0)])
                .createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_Blobs o) => o.t != t;
}

/// صفحة بخلفية متحركة
class AppPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppPage(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20)});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: MovingBackground(
          child: SafeArea(child: Padding(padding: padding, child: child))),
    );
  }
}

/// مربع زجاجي مغوّش
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? border;
  final Color? tint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Glass(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.radius = 20,
      this.border,
      this.tint,
      this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: tint ?? Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border ?? Colors.white.withOpacity(0.22)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// زر بتأثيرات: لمعة متحركة + تصغير عند الضغط + ظل متوهج
class PressBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final List<Color> colors;
  final double height;
  const PressBtn(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.colors = const [Color(0xFF7C3AED), Color(0xFFEC4899)],
      this.height = 54});
  @override
  State<PressBtn> createState() => _PressBtnState();
}

class _PressBtnState extends State<PressBtn> with SingleTickerProviderStateMixin {
  late final AnimationController shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
        ..repeat();
  bool down = false;
  @override
  void dispose() {
    shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => down = true) : null,
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: down ? 0.95 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(colors: widget.colors),
              boxShadow: [
                BoxShadow(
                    color: widget.colors.last.withOpacity(down ? 0.2 : 0.5),
                    blurRadius: down ? 8 : 24,
                    offset: Offset(0, down ? 3 : 10))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(alignment: Alignment.center, children: [
                if (enabled)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (_, c) => AnimatedBuilder(
                        animation: shine,
                        builder: (_, __) => Stack(children: [
                          Positioned(
                            left: -80 + shine.value * (c.maxWidth + 160),
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: Transform(
                              transform: Matrix4.skewX(-0.35),
                              child: Container(
                                  decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                Color(0x00FFFFFF),
                                Color(0x55FFFFFF),
                                Color(0x00FFFFFF)
                              ]))),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  color: down ? Colors.black.withOpacity(0.12) : Colors.transparent,
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 22),
                    const SizedBox(width: 8)
                  ],
                  Text(widget.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// حقل إدخال زجاجي بتوهج عند التركيز
class GField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final int maxLines;
  final bool mono;
  const GField(
      {super.key,
      required this.controller,
      required this.hint,
      required this.icon,
      this.obscure = false,
      this.maxLines = 1,
      this.mono = false});
  @override
  State<GField> createState() => _GFieldState();
}

class _GFieldState extends State<GField> {
  bool focus = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: focus
              ? [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.4), blurRadius: 12)]
              : [],
        ),
        child: Glass(
          radius: 16,
          border: focus ? const Color(0xFF06B6D4) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Focus(
            onFocusChange: (f) => setState(() => focus = f),
            child: TextField(
              controller: widget.controller,
              obscureText: widget.obscure,
              maxLines: widget.maxLines,
              style: TextStyle(
                  fontFamily: widget.mono ? 'monospace' : null,
                  fontSize: widget.mono ? 13 : 15),
              textDirection: widget.mono ? TextDirection.ltr : null,
              decoration: InputDecoration(
                border: InputBorder.none,
                icon: Icon(widget.icon, size: 20),
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  final IconData icon;
  final double size;
  const Logo(this.icon, {super.key, this.size = 84});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.6),
              blurRadius: 40,
              spreadRadius: 2)
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

Future<String?> askText(BuildContext c, String title, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1d1745),
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, textDirection: TextDirection.ltr),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        TextButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('موافق')),
      ],
    ),
  );
}
