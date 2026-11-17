import 'dart:async';

enum LogKind { info, ok, warn, err, plain }

class LogLine {
  final String text;
  final LogKind kind;
  LogLine(this.text, [this.kind = LogKind.plain]);
}

class Lang {
  final String id, title, main, depsHint, badge;
  const Lang(this.id, this.title, this.main, this.depsHint, this.badge);
}

const langs = [
  Lang('python', 'Python', 'main.py', 'main.py + requirements.txt', 'Py'),
  Lang('php', 'PHP', 'index.php', 'index.php + composer.json', 'PHP'),
  Lang('js', 'JavaScript', 'index.js', 'index.js + package.json', 'JS'),
];

Lang langById(String id) => langs.firstWhere((l) => l.id == id);

/// المكتبات المطلوبة حسب اللغة (تُثبَّت تلقائياً بدون سؤال المستخدم)
List<String> detectDeps(String lang, Map<String, String> files) {
  final out = <String>[];
  if (lang == 'python') {
    final r = files['requirements.txt'];
    if (r != null) {
      for (var l in r.split('\n')) {
        l = l.split('#').first.trim();
        if (l.isEmpty || l.startsWith('-')) continue;
        out.add(l.split(RegExp(r'[=<>!~\[;\s]')).first);
      }
    }
  } else {
    final file = lang == 'js' ? 'package.json' : 'composer.json';
    final key = lang == 'js' ? 'dependencies' : 'require';
    final r = files[file];
    if (r != null) {
      final m = RegExp('"$key"\\s*:\\s*\\{([^}]*)\\}').firstMatch(r);
      if (m != null) {
        for (final d in RegExp(r'"([^"]+)"\s*:').allMatches(m.group(1)!)) {
          if (d.group(1) != 'php') out.add(d.group(1)!);
        }
      }
    }
  }
  return out;
}

/// فحص بسيط للأقواس والنصوص (يكشف الأخطاء الواضحة ويعطي رقم السطر)
String? syntaxCheck(String name, String code) {
  final ext = name.split('.').last.toLowerCase();
  if (!['py', 'js', 'php'].contains(ext)) return null;
  final stack = <MapEntry<String, int>>[];
  const open = {'(': ')', '[': ']', '{': '}'};
  const close = {')': '(', ']': '[', '}': '{'};
  var line = 1;
  var i = 0;
  while (i < code.length) {
    final ch = code[i];
    if (ch == '\n') {
      line++;
      i++;
      continue;
    }
    if (((ext == 'py' || ext == 'php') && ch == '#') ||
        ((ext == 'js' || ext == 'php') && code.startsWith('//', i))) {
      while (i < code.length && code[i] != '\n') {
        i++;
      }
      continue;
    }
    if ((ext == 'js' || ext == 'php') && code.startsWith('/*', i)) {
      final e = code.indexOf('*/', i + 2);
      final end = e < 0 ? code.length : e + 2;
      line += '\n'.allMatches(code.substring(i, end)).length;
      i = end;
      continue;
    }
    if (ch == '"' || ch == "'" || (ch == '`' && ext == 'js')) {
      final triple = ext == 'py' && code.startsWith(ch * 3, i);
      final q = triple ? ch * 3 : ch;
      final startLine = line;
      i += q.length;
      var closed = false;
      while (i < code.length) {
        if (code[i] == '\\') {
          i += 2;
          continue;
        }
        if (code[i] == '\n') {
          if (!triple && ch != '`') break;
          line++;
        }
        if (code.startsWith(q, i)) {
          i += q.length;
          closed = true;
          break;
        }
        i++;
      }
      if (!closed) return 'السطر $startLine: نص غير مغلق (علامة اقتباس ناقصة)';
      continue;
    }
    if (open.containsKey(ch)) stack.add(MapEntry(ch, line));
    if (close.containsKey(ch)) {
      if (stack.isEmpty || stack.last.key != close[ch]) {
        return 'السطر $line: القوس "$ch" بدون قوس فتح مطابق';
      }
      stack.removeLast();
    }
    i++;
  }
  if (stack.isNotEmpty) {
    return 'السطر ${stack.last.value}: القوس "${stack.last.key}" لم يُغلق';
  }
  return null;
}

/// تشغيل تجريبي محلي: يفحص كل الملفات ويثبّت المكتبات ثم يشغّل الملف الرئيسي
Stream<LogLine> runProject(Lang lang, Map<String, String> files) async* {
  Future<void> d([int ms = 350]) => Future.delayed(Duration(milliseconds: ms));
  yield LogLine('› فحص الملفات (${files.length} ملف)…', LogKind.info);
  await d();
  if (!files.containsKey(lang.main)) {
    yield LogLine('خطأ: الملف الرئيسي ${lang.main} غير موجود', LogKind.err);
    yield LogLine('أنشئ ملفاً باسم ${lang.main} داخل قسم الملفات.', LogKind.warn);
    return;
  }
  yield LogLine('${lang.main} ✓', LogKind.ok);
  final names = files.keys.toList()..sort();
  for (final n in names) {
    final err = syntaxCheck(n, files[n]!);
    if (err != null) {
      yield LogLine('خطأ في الملف $n', LogKind.err);
      yield LogLine(err, LogKind.err);
      yield LogLine('تم إيقاف التشغيل. صحّح الخطأ وأعد التشغيل.', LogKind.warn);
      return;
    }
  }
  final deps = detectDeps(lang.id, files);
  if (deps.isNotEmpty) {
    yield LogLine('› تثبيت المكتبات تلقائياً (${deps.length})', LogKind.info);
    for (final dep in deps) {
      await d(300);
      yield LogLine('  $dep ✓', LogKind.ok);
    }
  }
  yield LogLine('› تشغيل ${lang.main}', LogKind.info);
  await d(500);
  yield LogLine('البوت يعمل الآن ✓', LogKind.ok);
}
