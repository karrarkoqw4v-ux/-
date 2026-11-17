import 'dart:ui';
import 'package:flutter/material.dart';

const brand = Color(0xFFB9B3D9); // لافندر هادئ (نمط 6)
const onBrand = Color(0xFF1F1E26); // نص/أيقونات فوق اللون الأساسي
const likeColor = Color(0xFFE59AAE); // لون اللايك (وردي هادئ)
const outline = Color(0xFF6A6685); // حدود الأزرار الثانوية
const cyan = Color(0xFF25F4EE); // سماوي تيك توك
const brandDark = Color(0xFF9C95C4);
const bgDark = Color(0xFF000000);
const fieldFill = Color(0xFF1F1E26);

ThemeData buildTheme() => ThemeData(
      // بدون fontFamily = خط النظام الأصلي (Roboto + خط العربي الافتراضي بأندرويد)
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark),
      scaffoldBackgroundColor: bgDark,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
        prefixIconColor: const Color(0xB3FFFFFF),
        suffixIconColor: const Color(0xB3FFFFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brand, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFFB84D))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFFB84D), width: 1.6)),
      ),
    );

/// يصغّر أي ويدجت شوي لما تنضغط ويرجعها بحركة ناعمة — إحساس "زر حقيقي"
/// بدل اللمعة الافتراضية فقط.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double downScale;
  const PressScale({super.key, required this.child, this.onTap, this.downScale = 0.96});
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.downScale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(opacity: _down ? .88 : 1, duration: const Duration(milliseconds: 110), child: widget.child),
        ),
      );
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final bool pill; // زر دائري بالكامل
  const GradientButton({super.key, required this.text, this.onPressed, this.loading = false, this.pill = false});
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: loading ? null : onPressed,
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: brand,
            borderRadius: BorderRadius.circular(pill ? 30 : 14),
            boxShadow: [BoxShadow(color: brand.withOpacity(.28), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: loading
                ? const SizedBox(key: ValueKey('spin'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: onBrand))
                : Text(text, key: const ValueKey('txt'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onBrand)),
          ),
        ),
      );
}

/// بطاقة زجاجية: شفافة وضبابية، الخلفية المتحركة خلفها تبان بوضوح خفيف.
class GlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  const GlassCard({super.key, required this.child, this.borderRadius = const BorderRadius.vertical(top: Radius.circular(30)), this.padding = const EdgeInsets.all(24)});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.07),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: child,
          ),
        ),
      );
}

/// تنقّل بحركة تلاشي وانزلاق خفيف بدل القفزة المفاجئة بين الشاشات.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(curved), child: child),
        );
      },
    );

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Transform(transform: Matrix4Translate.shift(-2.5, -2.5), child: const Icon(Icons.groups_rounded, size: 34, color: cyan)),
            Transform(transform: Matrix4Translate.shift(2.5, 2.5), child: const Icon(Icons.groups_rounded, size: 34, color: brand)),
            Icon(Icons.groups_rounded, size: 34, color: Colors.white),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('جماعتكم', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ]);
}

class Matrix4Translate {
  static Matrix4 shift(double x, double y) => Matrix4.translationValues(x, y, 0);
}
