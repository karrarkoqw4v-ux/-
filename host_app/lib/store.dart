import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum Stage { terms, auth, provision, plans, creating, ready }

/// عنوان الخادم الافتراضي (يُحقن وقت البناء: --dart-define=API_BASE=https://...)
const String kDefaultBase = String.fromEnvironment('API_BASE', defaultValue: '');

class ApiError implements Exception {
  final String msg;
  ApiError(this.msg);
  @override
  String toString() => msg;
}

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool loaded = false;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    loaded = true;
    notifyListeners();
  }

  // ───── الإعدادات والجلسة ─────
  String get base {
    final b = (_p.getString('base') ?? kDefaultBase).trim();
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  void setBase(String v) {
    _p.setString('base', v.trim());
    notifyListeners();
  }

  bool get terms => _p.getBool('terms') ?? false;
  String? get token => _p.getString('token');
  String? get user => _p.getString('user');

  Stage get stage {
    if (!terms) return Stage.terms;
    if (token == null) return Stage.auth;
    final s = _p.getString('stage') ?? 'provision';
    return Stage.values.firstWhere((e) => e.name == s, orElse: () => Stage.provision);
  }

  void acceptTerms() {
    _p.setBool('terms', true);
    notifyListeners();
  }

  void _saveSession(Map j) {
    _p.setString('token', j['token'] as String);
    _p.setString('user', j['username'] as String);
    _p.setString('stage', j['stage'] as String);
    notifyListeners();
  }

  void logout() {
    _p.remove('token');
    _p.remove('user');
    _p.remove('stage');
    notifyListeners();
  }

  // ───── طلبات الخادم ─────
  Future<dynamic> _req(String method, String path, [Object? body]) async {
    if (base.isEmpty) {
      throw ApiError('اكتب عنوان الخادم أولاً (إعدادات الخادم)');
    }
    final uri = Uri.parse('$base$path');
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final enc = body == null ? null : utf8.encode(jsonEncode(body));
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));
        case 'PUT':
          r = await http.put(uri, headers: headers, body: enc).timeout(const Duration(seconds: 40));
        default:
          r = await http.post(uri, headers: headers, body: enc ?? utf8.encode('{}'))
              .timeout(const Duration(seconds: 40));
      }
    } on TimeoutException {
      throw ApiError('انتهت مهلة الاتصال بالخادم');
    } on SocketException {
      throw ApiError('تعذّر الاتصال بالخادم — تأكد من العنوان والإنترنت');
    } on http.ClientException {
      throw ApiError('تعذّر الاتصال بالخادم — تأكد من العنوان والإنترنت');
    } on FormatException {
      throw ApiError('عنوان الخادم غير صالح');
    }
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiError('رد غير متوقع من الخادم (${r.statusCode})');
    }
    if (r.statusCode == 401 && token != null) logout();
    if (r.statusCode >= 400) {
      throw ApiError((j is Map ? j['error'] : null)?.toString() ?? 'خطأ ${r.statusCode}');
    }
    return j;
  }

  /// يرجع نص الخطأ أو null عند النجاح
  Future<String?> register(String u, String pw, String pw2) async {
    if (pw != pw2) return 'كلمتا السر غير متطابقتين';
    try {
      _saveSession(await _req('POST', '/api/register', {'username': u, 'password': pw}) as Map);
      return null;
    } on ApiError catch (e) {
      return e.msg;
    }
  }

  Future<String?> login(String u, String pw) async {
    try {
      _saveSession(await _req('POST', '/api/login', {'username': u, 'password': pw}) as Map);
      return null;
    } on ApiError catch (e) {
      return e.msg;
    }
  }

  void setStage(Stage s) {
    _p.setString('stage', s.name);
    notifyListeners();
    _req('POST', '/api/stage', {'stage': s.name}).catchError((_) {});
  }

  // ───── الملفات (محفوظة في قاعدة بيانات الخادم لحسابك) ─────
  Future<Map<String, String>> files(String lang) async {
    final j = await _req('GET', '/api/files/$lang') as Map;
    return (j['files'] as Map).map((k, v) => MapEntry(k as String, v as String));
  }

  Future<void> saveFiles(String lang, Map<String, String> f) async {
    await _req('PUT', '/api/files/$lang', {'files': f});
  }

  // ───── التشغيل الحقيقي ─────
  Future<String> runAction(String lang, String act) async {
    final j = await _req('POST', '/api/run/$lang/$act') as Map;
    return j['state'] as String;
  }

  Future<Map> logs(String lang, int since) async {
    return await _req('GET', '/api/run/$lang/logs?since=$since') as Map;
  }
}

final app = AppState();
