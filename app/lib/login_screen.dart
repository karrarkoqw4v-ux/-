import 'package:flutter/material.dart';
import 'api.dart';
import 'feed_screen.dart';
import 'forgot_screen.dart';
import 'register_screen.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Api.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FeedScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالسيرفر');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _form,
                child: Column(children: [
                  const AuthLogo(),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(hintText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'اكتب بريد إلكتروني صحيح',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'كلمة السر',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? 'اكتب كلمة السر' : null,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotScreen())),
                      child: const Text('نسيت كلمة السر؟'),
                    ),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB84D)))),
                  GradientButton(text: 'دخول ومتابعة', loading: _loading, onPressed: _submit),
                  const SizedBox(height: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('ما عندك حساب؟'),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('إنشاء حساب', style: TextStyle(fontWeight: FontWeight.bold, color: brand)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
