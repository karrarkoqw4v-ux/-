import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'feed_screen.dart';
import 'theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  File? _avatar;
  bool _hide = true, _loading = false, _checking = false;
  String? _userError; // null + _userOk = متاح
  bool _userOk = false;
  String? _serverError;
  Timer? _debounce;
  final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // الصورة: المعرض (يطلب الصلاحية تلقائياً) ثم قص مربع ثابت 1:1 وتصغير لـ 512
  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 90);
    if (x == null) return;
    final c = await ImageCropper().cropImage(
      sourcePath: x.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'حدد الصورة', toolbarColor: bgDark, toolbarWidgetColor: Colors.white, activeControlsWidgetColor: brand, lockAspectRatio: true, hideBottomControls: true),
      ],
    );
    if (c != null) setState(() => _avatar = File(c.path));
  }

  void _onUserChanged(String v) {
    _debounce?.cancel();
    final u = v.trim().toLowerCase();
    setState(() { _userOk = false; _userError = null; });
    if (u.isEmpty) return;
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(u)) {
      setState(() => _userError = '3-20 حرف إنجليزي أو أرقام أو _ .');
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final r = await Api.usernameCheck(u);
        if (!mounted) return;
        setState(() { _checking = false; _userError = r; _userOk = r == null; });
      } catch (_) {
        if (mounted) setState(() => _checking = false);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_form.currentState!.validate() || _userError != null || _checking) return;
    setState(() => _loading = true);
    try {
      await Api.register(name: _name.text.trim(), username: _user.text.trim().toLowerCase(), email: _email.text.trim(), password: _pass.text, avatar: _avatar);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const FeedScreen()), (_) => false);
    } on ApiException catch (e) {
      setState(() {
        if (e.field == 'username') _userError = e.message; else _serverError = e.message;
      });
    } catch (_) {
      setState(() => _serverError = 'تعذر الاتصال بالسيرفر');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Form(
              key: _form,
              child: Column(children: [
                const Text('إنشاء حساب', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(children: [
                    CircleAvatar(radius: 56, backgroundColor: fieldFill, backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                        child: _avatar == null ? const Icon(Icons.person_rounded, size: 56, color: Colors.white38) : null),
                    Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: brand, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white))),
                  ]),
                ),
                const SizedBox(height: 6),
                const Text('اضغط لاختيار صورتك', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(hintText: 'الاسم الثلاثي', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: (v) => (v ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 3 ? null : 'الاسم لازم يكون ثلاثي أو أكثر',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _user,
                  textDirection: TextDirection.ltr,
                  onChanged: _onUserChanged,
                  decoration: InputDecoration(
                    hintText: 'اسم المستخدم (اليوزر)',
                    prefixIcon: const Icon(Icons.alternate_email),
                    errorText: _userError,
                    helperText: _userOk ? 'اسم المستخدم متاح ✓' : null,
                    helperStyle: const TextStyle(color: Colors.greenAccent),
                    suffixIcon: _checking
                        ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        : _userOk ? const Icon(Icons.check_circle, color: Colors.greenAccent) : (_userError != null ? const Icon(Icons.cancel, color: Color(0xFFFF5C7A)) : null),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم المستخدم' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(hintText: 'بريدك الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => _emailRe.hasMatch(v?.trim() ?? '') ? null : 'اكتب بريد إلكتروني صحيح',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: _hide,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'كلمة السر (8 أحرف على الأقل)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                  validator: (v) => (v ?? '').length >= 8 ? null : 'كلمة السر 8 أحرف على الأقل',
                ),
                const SizedBox(height: 22),
                if (_serverError != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_serverError!, style: const TextStyle(color: Color(0xFFFF5C7A)))),
                GradientButton(text: 'إنشاء ومتابعة', loading: _loading, onPressed: _submit),
                const SizedBox(height: 14),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع لتسجيل الدخول', style: TextStyle(color: brand))),
              ]),
            ),
          ),
        ),
      );
}
