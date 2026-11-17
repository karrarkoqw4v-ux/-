import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// كل شي بالتطبيق يروح مباشرة لفايربيس — بدون أي سيرفر وسيط.
/// تسجيل الدخول والحسابات: Firebase Authentication.
/// الملفات الشخصية والمحادثات والفيديوهات: Firebase Realtime Database.
/// صور البروفايل: Firebase Storage.
class ApiException implements Exception {
  final String? field;
  final String message;
  ApiException(this.message, [this.field]);
}

String _authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'هذا البريد مسجّل من قبل';
    case 'invalid-email':
      return 'البريد الإلكتروني غير صالح';
    case 'weak-password':
      return 'كلمة السر ضعيفة، جرّب كلمة أقوى';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'البريد أو كلمة السر غير صحيحة';
    case 'network-request-failed':
      return 'تعذر الاتصال، تأكد من الإنترنت';
    case 'too-many-requests':
      return 'محاولات كثيرة، جرّب بعد شوي';
    default:
      return e.message ?? 'صار خطأ';
  }
}

String _convKey(String a, String b) => a.compareTo(b) > 0 ? '${b}_$a' : '${a}_$b';

class Api {
  static String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw ApiException('سجّل الدخول أولاً');
    return u.uid;
  }

  static DatabaseReference get _root => FirebaseDatabase.instance.ref();
  static DatabaseReference get _convs => _root.child('conversations');

  // ---- الجلسة والحساب ----

  static Future<bool> hasSession() async => FirebaseAuth.instance.currentUser != null;

  static Future<void> logout() => FirebaseAuth.instance.signOut();

  static Future<Map<String, dynamic>?> currentUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    final snap = await _root.child('users/${u.uid}').get();
    final d = snap.exists ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
    return {'id': u.uid, 'email': u.email ?? '', 'name': d['name'] ?? '', 'username': d['username'] ?? '', 'avatar': d['avatar'] ?? ''};
  }

  static Future<void> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authErrorMessage(e));
    }
  }

  /// فايربيس يرسل بريد إعادة تعيين حقيقي — ما نكشف إذا البريد مسجّل أو لا.
  static Future<void> forgot(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (_) {
      // نتجاهل عمداً (user-not-found وغيره) حتى ما نكشف وجود الحساب
    }
  }

  /// null = متاح، غير ذلك سبب الرفض
  static Future<String?> usernameCheck(String u) async {
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(u)) return 'اسم المستخدم غير صالح';
    final snap = await _root.child('usernames/$u').get();
    return snap.exists ? 'اسم المستخدم مستخدم' : null;
  }

  static Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    File? avatar,
  }) async {
    final uRef = _root.child('usernames/$username');
    if ((await uRef.get()).exists) {
      throw ApiException('اسم المستخدم مستخدم، جرّب غيره', 'username');
    }
    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authErrorMessage(e), e.code == 'email-already-in-use' ? 'email' : (e.code == 'weak-password' ? 'password' : null));
    }
    final uid = cred.user!.uid;
    String avatarUrl = '';
    if (avatar != null) {
      try {
        final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
        await ref.putFile(avatar);
        avatarUrl = await ref.getDownloadURL();
      } catch (_) {
        // رفع الصورة فشل، نكمّل تسجيل الحساب بدونها بدل ما نوقف كل العملية
      }
    }
    await _root.child('users/$uid').set({'name': name, 'username': username, 'avatar': avatarUrl});
    await uRef.set(uid);
  }

  // ---- المحادثات ----

  static Future<List<dynamic>> conversations() async {
    final uid = _uid;
    final idxSnap = await _root.child('userConversations/$uid').get();
    final ids = <String>[];
    if (idxSnap.exists) {
      for (final e in Map<String, dynamic>.from(idxSnap.value as Map).entries) {
        if (e.value == true) ids.add(e.key);
      }
    }
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final snap = await _convs.child(id).get();
      if (!snap.exists) continue;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final participants = Map<String, dynamic>.from(data['participants'] ?? {});
      final otherId = participants.keys.firstWhere((k) => k != uid, orElse: () => '');
      Map<String, dynamic> otherData = {};
      if (otherId.isNotEmpty) {
        final oSnap = await _root.child('users/$otherId').get();
        if (oSnap.exists) otherData = Map<String, dynamic>.from(oSnap.value as Map);
      }
      final meta = Map<String, dynamic>.from(data['meta'] ?? {});
      final readCount = Map<String, dynamic>.from(data['readCount'] ?? {});
      final messageCount = meta['messageCount'] as int? ?? 0;
      final myRead = readCount[uid] as int? ?? 0;
      out.add({
        'id': id,
        'user': {'id': otherId, 'name': otherData['name'] ?? '', 'username': otherData['username'] ?? '', 'avatar': otherData['avatar'] ?? ''},
        'lastMessage': meta['lastMessage'] ?? '',
        'lastAt': meta['lastAt'] ?? '',
        'unreadCount': messageCount - myRead < 0 ? 0 : messageCount - myRead,
      });
    }
    out.sort((a, b) => (b['lastAt'] as String).compareTo(a['lastAt'] as String));
    return out;
  }

  static Future<Map<String, dynamic>> startConversation(String username) async {
    final uid = _uid;
    final uSnap = await _root.child('usernames/$username').get();
    if (!uSnap.exists) throw ApiException('ما لكينا هذا المستخدم', 'username');
    final otherId = uSnap.value as String;
    if (otherId == uid) throw ApiException('ما تقدر تراسل نفسك', 'username');

    final convId = _convKey(uid, otherId);
    await _convs.child(convId).child('participants').set({uid: true, otherId: true});
    await _root.child('userConversations/$uid/$convId').set(true);
    await _root.child('userConversations/$otherId/$convId').set(true);

    final oSnap = await _root.child('users/$otherId').get();
    final otherData = oSnap.exists ? Map<String, dynamic>.from(oSnap.value as Map) : <String, dynamic>{};
    return {
      'id': convId,
      'user': {'id': otherId, 'name': otherData['name'] ?? '', 'username': otherData['username'] ?? '', 'avatar': otherData['avatar'] ?? ''},
    };
  }

  static Future<List<dynamic>> messages(String convId) async {
    final uid = _uid;
    final snap = await _convs.child(convId).child('messages').get();
    final out = <Map<String, dynamic>>[];
    if (snap.exists) {
      for (final e in Map<String, dynamic>.from(snap.value as Map).entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        out.add({'id': e.key, 'senderId': m['senderId'], 'text': m['text'], 'at': m['at']});
      }
    }
    out.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));

    final metaSnap = await _convs.child(convId).child('meta').get();
    final count = metaSnap.exists ? (Map<String, dynamic>.from(metaSnap.value as Map)['messageCount'] as int? ?? 0) : 0;
    await _convs.child(convId).child('readCount/$uid').set(count);
    return out;
  }

  static Future<Map<String, dynamic>> sendMessage(String convId, String text) async {
    final uid = _uid;
    final at = DateTime.now().toUtc().toIso8601String();
    final msgRef = _convs.child(convId).child('messages').push();
    await msgRef.set({'senderId': uid, 'text': text, 'at': at});

    final metaRef = _convs.child(convId).child('meta');
    final result = await metaRef.runTransaction((value) {
      final data = value == null ? <String, dynamic>{} : Map<String, dynamic>.from(value as Map);
      final count = (data['messageCount'] as int? ?? 0) + 1;
      return Transaction.success({'lastMessage': text, 'lastAt': at, 'messageCount': count});
    });
    final count = result.snapshot.exists ? (Map<String, dynamic>.from(result.snapshot.value as Map)['messageCount'] as int? ?? 1) : 1;
    await _convs.child(convId).child('readCount/$uid').set(count);

    return {'id': msgRef.key, 'senderId': uid, 'text': text, 'at': at};
  }

  // ---- الفيديوهات ----

  static Future<List<dynamic>> videos() async {
    final ref = _root.child('videos');
    var snap = await ref.get();
    if (!snap.exists) {
      // أول مرة تفتح فيها قاعدة البيانات: نزرع فيديوهين افتراضيين
      await ref.set({
        '1': {'id': 1, 'title': 'أول فيديو', 'author': 'أحمد', 'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4', 'likes': 0},
        '2': {'id': 2, 'title': 'فيديو ثاني', 'author': 'سارة', 'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4', 'likes': 0},
      });
      snap = await ref.get();
    }
    final out = <Map<String, dynamic>>[];
    for (final v in Map<String, dynamic>.from(snap.value as Map).values) {
      out.add(Map<String, dynamic>.from(v as Map));
    }
    out.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return out;
  }

  static Future<int> likeVideo(int id) async {
    final ref = _root.child('videos/$id/likes');
    final result = await ref.runTransaction((value) => Transaction.success((value as int? ?? 0) + 1));
    return result.snapshot.value as int? ?? 0;
  }
}
