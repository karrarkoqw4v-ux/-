import 'package:flutter/material.dart';

const brand = Color(0xFFFE2C55); // أحمر تيك توك
const cyan = Color(0xFF25F4EE); // سماوي تيك توك
const brandDark = Color(0xFFD91E46);
const bgDark = Color(0xFF000000);
const fieldFill = Color(0xFF1F1F23);

ThemeData buildTheme() => ThemeData(
      // بدون fontFamily = خط النظام الأصلي (Roboto + خط العربي الافتراضي بأندرويد)
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark),
      scaffoldBackgroundColor: bgDark,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: brand, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFB84D))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFB84D), width: 1.6)),
      ),
    );

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({super.key, required this.text, this.onPressed, this.loading = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [brand, brand]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: brand.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      );
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Transform(transform: Matrix4Translate.shift(-2.5, -2.5), child: const Icon(Icons.groups_rounded, size: 42, color: cyan)),
            Transform(transform: Matrix4Translate.shift(2.5, 2.5), child: const Icon(Icons.groups_rounded, size: 42, color: brand)),
            Icon(Icons.groups_rounded, size: 42, color: Colors.white),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('جماعتكم', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      ]);
}

class Matrix4Translate {
  static Matrix4 shift(double x, double y) => Matrix4.translationValues(x, y, 0);
}
