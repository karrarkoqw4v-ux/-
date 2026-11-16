import 'package:flutter/material.dart';

const brand = Color(0xFF7C4DFF);
const brandDark = Color(0xFF5B2EE6);
const bgDark = Color(0xFF0E0B1F);
const fieldFill = Color(0xFF1A1633);

ThemeData buildTheme() => ThemeData(
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
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5C7A))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5C7A), width: 1.6)),
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
            gradient: const LinearGradient(colors: [brand, Color(0xFFB388FF)]),
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
            gradient: const LinearGradient(colors: [brand, Color(0xFFFF6FB5)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.groups_rounded, size: 42, color: Colors.white),
        ),
        const SizedBox(height: 14),
        const Text('جماعتكم', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      ]);
}
