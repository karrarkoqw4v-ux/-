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
