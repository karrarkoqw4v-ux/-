import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Stage { terms, auth, provision, plans, creating, ready }

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool loaded = false;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    loaded = true;
    notifyListeners();
  }

  bool get terms => _p.getBool('terms') ?? false;
  String? get user => _p.getString('session');

  Map<String, dynamic> get _users =>
      jsonDecode(_p.getString('users') ?? '{}') as Map<String, dynamic>;

  String _hash(String u, String pw) =>
      sha256.convert(utf8.encode('$u::$pw::host-app')).toString();

  Stage get stage {
    if (!terms) return Stage.terms;
    final u = user;
    if (u == null) return Stage.auth;
    final s = (_users[u]?['stage'] as String?) ?? 'provision';
    return Stage.values.firstWhere((e) => e.name == s, orElse: () => Stage.provision);
  }

  void acceptTerms() {
    _p.setBool('terms', true);
    notifyListeners();
  }

  /// يرجع نص الخطأ أو null عند النجاح
  String? register(String u, String pw, String pw2) {
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(u)) {
      return 'اسم المستخدم: 3 إلى 20 حرف إنكليزي أو رقم أو _';
    }
    if (pw.length < 6) return 'كلمة السر لازم 6 أحرف على الأقل';
    if (pw != pw2) return 'كلمتا السر غير متطابقتين';
    final users = _users;
    if (users.containsKey(u.toLowerCase())) return 'اسم المستخدم مستخدم مسبقاً';
    users[u.toLowerCase()] = {'hash': _hash(u.toLowerCase(), pw), 'stage': 'provision'};
    _p.setString('users', jsonEncode(users));
    _p.setString('session', u.toLowerCase());
    notifyListeners();
    return null;
  }

  String? login(String u, String pw) {
    final k = u.trim().toLowerCase();
    final rec = _users[k];
    if (rec == null || rec['hash'] != _hash(k, pw)) {
      return 'اسم المستخدم أو كلمة السر غير صحيحة';
    }
    _p.setString('session', k);
    notifyListeners();
    return null;
  }

  void logout() {
    _p.remove('session');
    notifyListeners();
  }

  void setStage(Stage s) {
    final users = _users;
    final u = user;
    if (u == null) return;
    users[u]['stage'] = s.name;
    _p.setString('users', jsonEncode(users));
    notifyListeners();
  }

  // ───── ملفات المشروع (لكل مستخدم ولكل لغة) ─────
  String _fk(String lang) => 'files:$user:$lang';

  Map<String, String> files(String lang) {
    final raw = _p.getString(_fk(lang));
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
  }

  void saveFiles(String lang, Map<String, String> f) {
    _p.setString(_fk(lang), jsonEncode(f));
    notifyListeners();
  }
}

final app = AppState();
