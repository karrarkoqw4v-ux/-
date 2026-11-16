import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// عنوان السيرفر: يتغيّر وقت البناء  --dart-define=API_HOST=http://IP:8080
// الافتراضي 10.0.2.2 = localhost من محاكي أندرويد فقط.
const host = String.fromEnvironment('API_HOST', defaultValue: 'http://10.0.2.2:8080');
const apiBase = '$host/api';

class ApiException implements Exception {
  final String? field;
  final String message;
  ApiException(this.message, [this.field]);
}

class Api {
  static Future<Map<String, dynamic>> _handle(http.Response r) async {
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw ApiException(body['error'] ?? 'صار خطأ', body['field'] == '' ? null : body['field']);
    }
    return body;
  }

  static Future<void> _saveSession(Map<String, dynamic> b) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', b['token']);
    await p.setString('user', jsonEncode(b['user']));
  }

  static Future<bool> hasSession() async =>
      (await SharedPreferences.getInstance()).getString('token') != null;

  static Future<Map<String, dynamic>?> currentUser() async {
    final s = (await SharedPreferences.getInstance()).getString('user');
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
  }

  static Future<void> login(String email, String password) async {
    final r = await http.post(Uri.parse('$apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));
    await _saveSession(await _handle(r));
  }

  static Future<void> forgot(String email) async {
    await _handle(await http.post(Uri.parse('$apiBase/auth/forgot'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email})));
  }

  /// null = متاح، غير ذلك سبب الرفض
  static Future<String?> usernameCheck(String u) async {
    final r = await http.get(Uri.parse('$apiBase/auth/username-available').replace(queryParameters: {'username': u}));
    final b = await _handle(r);
    return b['available'] == true ? null : (b['reason'] == 'taken' ? 'اسم المستخدم مستخدم' : 'اسم المستخدم غير صالح');
  }

  static Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    File? avatar,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/auth/register'))
      ..fields.addAll({'name': name, 'username': username, 'email': email, 'password': password});
    if (avatar != null) req.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
    await _saveSession(await _handle(await http.Response.fromStream(await req.send())));
  }
}
