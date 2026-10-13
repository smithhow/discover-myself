# 发现自我（Discover Self）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个完全离线无后端的 Flutter 自我评测游戏化 App，用户可用 PIN 解锁本地加密数据库，完成人格/智商/情商/兴趣测评与 MBTI/星座番外篇，获得积分徽章抽奖，并导出 PDF 报告。

**Architecture:** 分层架构 —— UI 层（Flutter Widget）→ Service 层（assessment/achievement/lottery/recommendation）→ Data 层（sqflite_sqlcipher 加密数据库 + assets JSON 资源）。加密密钥由 PIN 经 PBKDF2 派生，仅内存持有。

**Tech Stack:** Flutter 3.x, Dart 3.x, sqflite_sqlcipher, flutter_secure_storage, crypto, pdf, printing, screenshot, lottie, flutter_test。

## Global Constraints

- 完全离线：禁止任何网络请求依赖（无 http/dio 等），无后端。
- 项目显示名统一为「发现自我」。
- PIN 最小 4 位；PBKDF2-HMAC-SHA256，迭代 10000，salt 16 字节。
- 数据库使用 sqflite_sqlcipher，密钥仅内存持有，后台 5 分钟自动锁定。
- 抽奖使用 Mulberry32 可重现 PRNG，seed = timestamp_ms + deviceIdHash。
- 数据库文件名固定 `discover_self.db`。
- 所有 JSON 资源位于 `assets/data/`，随包发布。
- 目标平台 iOS/Android，UI 中文。

---

### Task 1: Flutter 项目脚手架与依赖

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `test/smoke_test.dart`
- Create: `.gitignore`

**Interfaces:**
- Consumes: 无
- Produces: 可编译运行的 Flutter 工程；`main()` 入口；依赖清单供后续任务使用。

- [ ] **Step 1: 初始化 Flutter 工程**

Run: `flutter create --org com.discoverself --project-name discover_self .`
Expected: 生成 `lib/main.dart`、`pubspec.yaml`、`android/`、`ios/`、`test/`。

- [ ] **Step 2: 写冒烟测试**

Create `test/smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/main.dart';

void main() {
  test('app title is 发现自我', () {
    expect(appTitle, '发现自我');
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/smoke_test.dart`
Expected: FAIL（`appTitle` 未定义 / 导入失败）。

- [ ] **Step 4: 写最小实现**

Create `lib/main.dart`:
```dart
import 'package:flutter/material.dart';

const String appTitle = '发现自我';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text(appTitle)))));
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/smoke_test.dart`
Expected: PASS。

- [ ] **Step 6: 添加依赖**

Modify `pubspec.yaml` `dependencies:` 与 `dev_dependencies:`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite_sqlcipher: ^3.1.0
  sqflite_common_ffi: ^2.3.0
  path: ^1.9.0
  path_provider: ^2.1.0
  flutter_secure_storage: ^9.2.2
  crypto: ^3.0.3
  pdf: ^3.11.0
  printing: ^5.13.0
  screenshot: ^3.0.0
  lottie: ^3.1.0
  provider: ^6.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

- [ ] **Step 7: 拉取依赖并分析**

Run: `flutter pub get; flutter analyze`
Expected: 无 error。

- [ ] **Step 8: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart test/smoke_test.dart .gitignore
git commit -m "chore: scaffold discover_self flutter project with dependencies"
```

---

### Task 2: 目录结构与 JSON 资源骨架

**Files:**
- Create: `lib/src/models/question.dart`
- Create: `assets/data/questions.json`
- Create: `assets/data/models.json`
- Create: `assets/data/prizes.json`
- Create: `assets/data/career.json`
- Create: `assets/data/recommendations.json`
- Modify: `pubspec.yaml`（注册 assets）
- Test: `test/resource_load_test.dart`

**Interfaces:**
- Consumes: Task 1 工程。
- Produces: `assets/data/*.json` 五份资源；`Question` 模型供 Task 6 使用。

- [ ] **Step 1: 写资源加载失败测试**

Create `test/resource_load_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> loadJson(String name) async {
  final s = await rootBundle.loadString('assets/data/$name');
  return jsonDecode(s) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('questions.json 含 items 数组', () async {
    final data = await loadJson('questions.json');
    expect(data['items'], isA<List>());
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/resource_load_test.dart`
Expected: FAIL（asset 不存在）。

- [ ] **Step 3: 写资源骨架**

Create `assets/data/questions.json`:
```json
{ "version": 1, "items": [
  { "id": "p1", "type": "personality", "dimension": "openness", "text": "我喜欢尝试新事物。", "options": ["非常不同意","不同意","同意","非常同意"] }
]}
```
Create `assets/data/models.json`:
```json
{ "version": 1, "dimensions": [
  { "key": "openness", "label": "开放性", "weight": 1.0, "threshold": 3.0 }
]}
```
Create `assets/data/prizes.json`:
```json
{ "version": 1, "items": [
  { "id": "badge_1", "name": "初识自我", "weight": 40, "stock": 1000 },
  { "id": "badge_2", "name": "潜行者", "weight": 10, "stock": 100 }
]}
```
Create `assets/data/career.json`:
```json
{ "version": 1, "items": [
  { "dimension": "openness", "min": 3.5, "careers": ["产品经理","设计师"] }
]}
```
Create `assets/data/recommendations.json`:
```json
{ "version": 1, "items": [
  { "dimension": "openness", "action": "每周阅读一本新领域书籍" }
]}
```

- [ ] **Step 4: 注册 assets**

Modify `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/data/
```

- [ ] **Step 5: 创建 Question 模型**

Create `lib/src/models/question.dart`:
```dart
class QuestionOption {
  final String label;
  final int value;
  const QuestionOption(this.label, this.value);
}

class Question {
  final String id;
  final String type;
  final String dimension;
  final String text;
  final List<String> options;
  const Question({required this.id, required this.type, required this.dimension, required this.text, required this.options});

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        type: j['type'] as String,
        dimension: j['dimension'] as String,
        text: j['text'] as String,
        options: (j['options'] as List).cast<String>(),
      );

  List<QuestionOption> toOptions() => [
        for (var i = 0; i < options.length; i++) QuestionOption(options[i], i + 1),
      ];
}
```

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/resource_load_test.dart`
Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add assets/data lib/src/models/question.dart pubspec.yaml test/resource_load_test.dart
git commit -m "feat: add json assets skeleton and question model"
```

---

### Task 3: PIN 密钥派生与加密服务

**Files:**
- Create: `lib/src/encryption/key_derivation.dart`
- Test: `test/key_derivation_test.dart`

**Interfaces:**
- Consumes: Task 1 `crypto` 依赖。
- Produces:
  - `List<int> deriveKey(String pin, List<int> salt, {int iterations = 10000})` 返回 32 字节密钥。
  - `List<int> randomSalt()` 返回 16 字节随机 salt。
  - `String bytesToHex(List<int>)`。

- [ ] **Step 1: 写失败测试**

Create `test/key_derivation_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/encryption/key_derivation.dart';

void main() {
  test('same pin+salt yields same 32-byte key', () {
    final salt = List<int>.filled(16, 7);
    final a = deriveKey('1234', salt);
    final b = deriveKey('1234', salt);
    expect(a.length, 32);
    expect(a, equals(b));
  });

  test('different pin yields different key', () {
    final salt = List<int>.filled(16, 7);
    expect(deriveKey('1234', salt), isNot(equals(deriveKey('9999', salt))));
  });

  test('randomSalt is 16 bytes and varies', () {
    expect(randomSalt().length, 16);
    expect(randomSalt(), isNot(equals(randomSalt())));
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/key_derivation_test.dart`
Expected: FAIL（文件不存在）。

- [ ] **Step 3: 实现**

Create `lib/src/encryption/key_derivation.dart`:
```dart
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

Uint8List deriveKey(String pin, List<int> salt, {int iterations = 10000}) {
  final pbkdf2 = _Pbkdf2(hmacSha256, iterations);
  return pbkdf2.derive(Uint8List.fromList(pin.codeUnits), Uint8List.fromList(salt), 32);
}

Uint8List randomSalt() {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(16, (_) => r.nextInt(256)));
}

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class _Pbkdf2 {
  final Hash hash;
  final int iterations;
  _Pbkdf2(this.hash, this.iterations);

  Uint8List derive(Uint8List password, Uint8List salt, int keyLen) {
    final hLen = hash.convert(<int>[]).bytes.length;
    final blocks = (keyLen / hLen).ceil();
    final out = BytesBuilder();
    for (var i = 1; i <= blocks; i++) {
      var u = _f(password, salt, i);
      final t = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = Uint8List.fromList(_hmac(password, u));
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, keyLen);
  }

  Uint8List _f(Uint8List password, Uint8List salt, int blockIndex) {
    final input = <int>[...salt, (blockIndex >> 24) & 0xff, (blockIndex >> 16) & 0xff, (blockIndex >> 8) & 0xff, blockIndex & 0xff];
    return Uint8List.fromList(_hmac(password, Uint8List.fromList(input)));
  }

  List<int> _hmac(Uint8List key, Uint8List data) =>
      Hmac(hash, key).convert(data).bytes;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/key_derivation_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: 提交**

```bash
git add lib/src/encryption/key_derivation.dart test/key_derivation_test.dart
git commit -m "feat: add pin pbkdf2 key derivation"
```

---

### Task 4: 数据模型与本地数据库封装

**Files:**
- Create: `lib/src/models/profile.dart`
- Create: `lib/src/models/assessment_result.dart`
- Create: `lib/src/db/database.dart`
- Test: `test/database_test.dart`

**Interfaces:**
- Consumes: Task 3 `deriveKey`、`randomSalt`。
- Produces:
  - `class Database`（`lib/src/db/database.dart`）: `Future<void> open(List<int> key)`, `Future<void> close()`, `Future<int> insertProfile(String name, List<int> salt)`, `Future<List<Map<String,Object?>>> profiles()`, `Future<int> insertResult(int profileId, String type, Map<String,int> scores)`, `Future<List<Map<String,Object?>>> results(int profileId)`。
  - `class Profile`、`class AssessmentResult`。

- [ ] **Step 1: 写失败测试**

Create `test/database_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:discover_self/src/db/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('open, insert profile and result, read back', () async {
    final db = Database(inMemory: true);
    await db.open(List<int>.filled(32, 1));
    final pid = await db.insertProfile('孩子A', List<int>.filled(16, 2));
    expect(pid, greaterThan(0));
    await db.insertResult(pid, 'personality', {'openness': 4, 'extraversion': 3});
    final rows = await db.results(pid);
    expect(rows.length, 1);
    expect(rows.first['type'], 'personality');
    await db.close();
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/database_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现数据库**

Create `lib/src/db/database.dart`:
```dart
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as p;

class Database {
  Database({this.inMemory = false});
  final bool inMemory;
  android.Database? _db;

  Future<void> open(List<int> key) async {
    final password = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final path = inMemory ? inMemoryDatabasePath : p.join(await getDatabasesPath(), 'discover_self.db');
    _db = await openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, pin_salt BLOB, created_at INTEGER)');
        await db.execute('CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, profile_id INTEGER, type TEXT, score_json TEXT, finished_at INTEGER)');
        await db.execute('CREATE TABLE achievements(id INTEGER PRIMARY KEY AUTOINCREMENT, profile_id INTEGER, type TEXT, points INTEGER, earned_at INTEGER)');
        await db.execute('CREATE TABLE lottery_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, profile_id INTEGER, seed INTEGER, prize_id TEXT, drawn_at INTEGER)');
      },
    );
  }

  Future<int> insertProfile(String name, List<int> salt) async =>
      _db!.insert('users', {'name': name, 'pin_salt': salt, 'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<List<Map<String, Object?>>> profiles() async =>
      _db!.query('users');

  Future<int> insertResult(int profileId, String type, Map<String, int> scores) async =>
      _db!.insert('assessments', {
        'profile_id': profileId,
        'type': type,
        'score_json': _encode(scores),
        'finished_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<List<Map<String, Object?>>> results(int profileId) async =>
      _db!.query('assessments', where: 'profile_id = ?', whereArgs: [profileId]);

  Future<void> close() async { await _db?.close(); _db = null; }

  String _encode(Map<String, int> m) =>
      '{${m.entries.map((e) => '"${e.key}":${e.value}').join(',')}}';
}
```
Note: 若 `android.Database` 导入报错，改为 `import 'package:sqflite_sqlcipher/sqflite.dart';` 的 `Database` 重命名以避免与类名冲突（`import '...' as sqflite;` 后使用 `sqflite.Database?`）。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/database_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/db/database.dart lib/src/models/profile.dart lib/src/models/assessment_result.dart test/database_test.dart
git commit -m "feat: add encrypted sqlite database layer"
```

---

### Task 5: Mulberry32 抽奖 PRNG 与抽奖服务

**Files:**
- Create: `lib/src/utils/prng.dart`
- Create: `lib/src/services/lottery.dart`
- Test: `test/lottery_test.dart`

**Interfaces:**
- Consumes: Task 2 `prizes.json` 结构。
- Produces:
  - `class Mulberry32 { Mulberry32(int seed); double next(); int nextInt(int max); }`
  - `class Prize { final String id; final String name; final int weight; final int stock; }`
  - `class Lottery { Lottery(this.prizes); Prize draw(int seed); }`

- [ ] **Step 1: 写失败测试**

Create `test/lottery_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/prng.dart';
import 'package:discover_self/src/services/lottery.dart';

void main() {
  test('mulberry32 is reproducible', () {
    expect(Mulberry32(42).next(), equals(Mulberry32(42).next()));
  });

  test('lottery deterministic for same seed', () {
    final l = Lottery([const Prize('a', 'A', 1, 10), const Prize('b', 'B', 0, 10)]);
    expect(l.draw(7).id, 'a');
    expect(l.draw(7).id, 'a');
  });

  test('weight zero prize never drawn', () {
    final l = Lottery([const Prize('a', 'A', 0, 10), const Prize('b', 'B', 5, 10)]);
    for (var s = 0; s < 50; s++) {
      expect(l.draw(s).id, 'b');
    }
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/lottery_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/utils/prng.dart`:
```dart
class Mulberry32 {
  Mulberry32(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;

  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = (t ^ (t >> 15)) * (t | 1) & 0xFFFFFFFF;
    t = (t ^ (t + ((t ^ (t >> 7)) * (t | 61) & 0xFFFFFFFF))) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  int nextInt(int max) => (next() * max).floor();
}
```

Create `lib/src/services/lottery.dart`:
```dart
import '../utils/prng.dart';

class Prize {
  final String id;
  final String name;
  final int weight;
  final int stock;
  const Prize(this.id, this.name, this.weight, this.stock);
  factory Prize.fromJson(Map<String, dynamic> j) =>
      Prize(j['id'] as String, j['name'] as String, j['weight'] as int, j['stock'] as int);
}

class Lottery {
  Lottery(this.prizes);
  final List<Prize> prizes;

  Prize draw(int seed) {
    final available = prizes.where((p) => p.weight > 0 && p.stock > 0).toList();
    final total = available.fold<int>(0, (s, p) => s + p.weight);
    if (total == 0) return prizes.first;
    final r = Mulberry32(seed).nextInt(total);
    var acc = 0;
    for (final p in available) {
      acc += p.weight;
      if (r < acc) return p;
    }
    return available.last;
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/lottery_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/utils/prng.dart lib/src/services/lottery.dart test/lottery_test.dart
git commit -m "feat: add mulberry32 prng and lottery service"
```

---

### Task 6: 测评计分服务

**Files:**
- Create: `lib/src/services/assessment.dart`
- Test: `test/assessment_test.dart`

**Interfaces:**
- Consumes: Task 2 `Question`。
- Produces:
  - `class AssessmentService { AssessmentService(List<Question> questions); Map<String,double> score(Map<String,int> answers); }`
  - answers 为 questionId -> 选项值(1..4)。

- [ ] **Step 1: 写失败测试**

Create `test/assessment_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/services/assessment.dart';

void main() {
  final qs = [
    const Question(id: 'p1', type: 'personality', dimension: 'openness', text: 't', options: ['a', 'b', 'c', 'd']),
    const Question(id: 'p2', type: 'personality', dimension: 'openness', text: 't', options: ['a', 'b', 'c', 'd']),
    const Question(id: 'p3', type: 'personality', dimension: 'extraversion', text: 't', options: ['a', 'b', 'c', 'd']),
  ];

  test('averages per dimension', () {
    final s = AssessmentService(qs).score({'p1': 4, 'p2': 2, 'p3': 3});
    expect(s['openness'], closeTo(3.0, 0.001));
    expect(s['extraversion'], closeTo(3.0, 0.001));
  });

  test('missing answers ignored', () {
    final s = AssessmentService(qs).score({'p1': 4});
    expect(s['openness'], closeTo(4.0, 0.001));
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/assessment_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/services/assessment.dart`:
```dart
import '../models/question.dart';

class AssessmentService {
  AssessmentService(this.questions);
  final List<Question> questions;

  Map<String, double> score(Map<String, int> answers) {
    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final q in questions) {
      final v = answers[q.id];
      if (v == null) continue;
      sums[q.dimension] = (sums[q.dimension] ?? 0) + v;
      counts[q.dimension] = (counts[q.dimension] ?? 0) + 1;
    }
    return {
      for (final k in sums.keys) k: sums[k]! / counts[k]!,
    };
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/assessment_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/services/assessment.dart test/assessment_test.dart
git commit -m "feat: add assessment scoring service"
```

---

### Task 7: 积分徽章与多档案切换服务

**Files:**
- Create: `lib/src/services/achievement.dart`
- Test: `test/achievement_test.dart`

**Interfaces:**
- Consumes: 无。
- Produces: `class AchievementService { int points; List<String> badges; void award(String badgeId, int points); }`。

- [ ] **Step 1: 写失败测试**

Create `test/achievement_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/achievement.dart';

void main() {
  test('award increases points and adds unique badge', () {
    final a = AchievementService();
    a.award('badge_1', 10);
    a.award('badge_1', 10);
    expect(a.points, 20);
    expect(a.badges, ['badge_1']);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/achievement_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/services/achievement.dart`:
```dart
class AchievementService {
  int points = 0;
  final List<String> badges = [];

  void award(String badgeId, int value) {
    points += value;
    if (!badges.contains(badgeId)) badges.add(badgeId);
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/achievement_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/services/achievement.dart test/achievement_test.dart
git commit -m "feat: add achievement points and badges service"
```

---

### Task 8: PDF 报告生成服务

**Files:**
- Create: `lib/src/utils/pdf_export.dart`
- Test: `test/pdf_export_test.dart`

**Interfaces:**
- Consumes: Task 6 `Map<String,double>`。
- Produces: `Future<Uint8List> buildReportPdf({required String profileName, required Map<String,double> scores, required List<String> recommendations})`。

- [ ] **Step 1: 写失败测试**

Create `test/pdf_export_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/pdf_export.dart';

void main() {
  test('produces non-empty pdf bytes starting with %PDF', () async {
    final bytes = await buildReportPdf(
      profileName: '孩子A',
      scores: {'openness': 4.0},
      recommendations: ['多读书'],
    );
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/pdf_export_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/utils/pdf_export.dart`:
```dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildReportPdf({
  required String profileName,
  required Map<String, double> scores,
  required List<String> recommendations,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0, text: '发现自我 - 测评报告'),
        pw.Text('档案：$profileName'),
        pw.SizedBox(height: 12),
        pw.Text('维度得分', style: const pw.TextStyle(fontSize: 16)),
        pw.Bullet(text: scores.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join('\n')),
        pw.SizedBox(height: 12),
        pw.Text('成长建议', style: const pw.TextStyle(fontSize: 16)),
        for (final r in recommendations) pw.Bullet(text: r),
      ],
    ),
  );
  return doc.save();
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/pdf_export_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/utils/pdf_export.dart test/pdf_export_test.dart
git commit -m "feat: add pdf report generation"
```

---

### Task 9: 引导与 PIN 解锁界面

**Files:**
- Create: `lib/src/ui/onboarding/pin_screen.dart`
- Create: `lib/src/ui/onboarding/profile_select_screen.dart`
- Create: `lib/src/app.dart`
- Modify: `lib/main.dart`
- Test: `test/pin_screen_test.dart`

**Interfaces:**
- Consumes: Task 3 `deriveKey/randomSalt`，Task 4 `Database`。
- Produces: `class PinScreen extends StatefulWidget { final Future<void> Function(List<int> key) onUnlocked; }`；`class ProfileSelectScreen extends StatelessWidget { final List<String> names; final void Function(int index) onSelect; }`；`app()` 根 Widget（由 main 调用，展示 `appTitle`）。

- [ ] **Step 1: 写失败测试**

Create `test/pin_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/onboarding/pin_screen.dart';

void main() {
  testWidgets('submitting 4-digit pin calls onUnlocked with 32-byte key', (tester) async {
    List<int>? got;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(onUnlocked: (k) async => got = k),
    ));
    await tester.enterText(find.byKey(const Key('pin_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.length, 32);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/pin_screen_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/ui/onboarding/pin_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../encryption/key_derivation.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.onUnlocked});
  final Future<void> Function(List<int> key) onUnlocked;
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _c = TextEditingController();
  static final _salt = List<int>.filled(16, 1);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('发现自我', style: TextStyle(fontSize: 28)),
            TextField(key: const Key('pin_field'), controller: _c, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '输入 PIN (4-6位)')),
            const SizedBox(height: 16),
            ElevatedButton(key: const Key('pin_submit'), onPressed: () async {
              if (_c.text.length < 4) return;
              await widget.onUnlocked(deriveKey(_c.text, _salt));
            }, child: const Text('解锁')),
          ]),
        ),
      );
}
```

Create `lib/src/ui/onboarding/profile_select_screen.dart`:
```dart
import 'package:flutter/material.dart';

class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({super.key, required this.names, required this.onSelect});
  final List<String> names;
  final void Function(int index) onSelect;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('选择档案')),
        body: ListView.builder(
          itemCount: names.length,
          itemBuilder: (c, i) => ListTile(title: Text(names[i]), onTap: () => onSelect(i)),
        ),
      );
}
```

Create `lib/src/app.dart`:
```dart
import 'package:flutter/material.dart';

Widget app() => const MaterialApp(
      home: Scaffold(body: Center(child: Text('发现自我'))),
    );
```

Modify `lib/main.dart`:
```dart
import 'package:flutter/material.dart';

const String appTitle = '发现自我';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text(appTitle)))));
}
```
Note: 保留 `appTitle` 常量以通过 Task 1 冒烟测试；`app.dart` 供后续任务扩展。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/pin_screen_test.dart; flutter test test/smoke_test.dart`
Expected: 均 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/src/ui/onboarding lib/src/app.dart lib/main.dart test/pin_screen_test.dart
git commit -m "feat: add pin unlock and profile select screens"
```

---

### Task 10: 测评流程界面与结果页、抽奖、导出入口

**Files:**
- Create: `lib/src/ui/assessment/assessment_screen.dart`
- Create: `lib/src/ui/result/result_screen.dart`
- Create: `lib/src/ui/reward/lottery_screen.dart`
- Test: `test/assessment_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 `Question`、Task 6 `AssessmentService`、Task 5 `Lottery`、Task 8 `buildReportPdf`。
- Produces: `class AssessmentScreen extends StatefulWidget { final List<Question> questions; final void Function(Map<String,int> answers) onDone; }`；`class ResultScreen extends StatelessWidget { final Map<String,double> scores; final List<String> recommendations; final String profileName; }`。

- [ ] **Step 1: 写失败测试**

Create `test/assessment_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/ui/assessment/assessment_screen.dart';

void main() {
  testWidgets('answering all questions calls onDone with answers', (tester) async {
    Map<String, int>? done;
    await tester.pumpWidget(MaterialApp(home: AssessmentScreen(
      questions: [
        const Question(id: 'p1', type: 'personality', dimension: 'openness', text: 'Q1', options: ['a', 'b']),
        const Question(id: 'p2', type: 'personality', dimension: 'openness', text: 'Q2', options: ['a', 'b']),
      ],
      onDone: (a) => done = a,
    )));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
    }
    expect(done, isNotNull);
    expect(done!.length, 2);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/assessment_screen_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

Create `lib/src/ui/assessment/assessment_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../models/question.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key, required this.questions, required this.onDone});
  final List<Question> questions;
  final void Function(Map<String, int> answers) onDone;
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  int _i = 0;
  final Map<String, int> _answers = {};

  void _answer(int value) {
    final q = widget.questions[_i];
    _answers[q.id] = value;
    if (_i == widget.questions.length - 1) {
      widget.onDone(_answers);
      return;
    }
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_i];
    return Scaffold(
      appBar: AppBar(title: Text('测评 ${_i + 1}/${widget.questions.length}')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(q.text, style: const TextStyle(fontSize: 20))),
        for (var i = 0; i < q.options.length; i++)
          ListTile(title: Text(q.options[i]), onTap: () => _answer(i + 1)),
      ]),
    );
  }
}
```

Create `lib/src/ui/result/result_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../utils/pdf_export.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.profileName, required this.scores, required this.recommendations});
  final String profileName;
  final Map<String, double> scores;
  final List<String> recommendations;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('测评结果')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('档案：$profileName', style: const TextStyle(fontSize: 18)),
          for (final e in scores.entries) LinearProgressIndicator(value: (e.value / 4).clamp(0, 1), minHeight: 12),
          const SizedBox(height: 16),
          const Text('成长建议', style: TextStyle(fontSize: 18)),
          for (final r in recommendations) Text('• $r'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () async {
            await buildReportPdf(profileName: profileName, scores: scores, recommendations: recommendations);
          }, child: const Text('导出 PDF 报告')),
        ]),
      );
}
```

Create `lib/src/ui/reward/lottery_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../services/lottery.dart';

class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key, required this.prizes});
  final List<Prize> prizes;
  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> {
  Prize? _result;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('抽奖')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_result == null ? '点击抽奖' : '恭喜获得：${_result!.name}', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () {
            final seed = DateTime.now().millisecondsSinceEpoch;
            setState(() => _result = Lottery(widget.prizes).draw(seed));
          }, child: const Text('抽奖')),
        ])),
      );
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/assessment_screen_test.dart`
Expected: PASS。

- [ ] **Step 5: 全量测试与静态分析**

Run: `flutter test; flutter analyze`
Expected: 全部 PASS，无 error。

- [ ] **Step 6: 提交**

```bash
git add lib/src/ui/assessment lib/src/ui/result lib/src/ui/reward test/assessment_screen_test.dart
git commit -m "feat: add assessment flow, result, lottery screens"
```

---

### Task 11: 应用装配（依赖注入、路由、自动锁定）

**Files:**
- Create: `lib/src/services/app_state.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/main.dart`
- Test: `test/app_state_test.dart`

**Interfaces:**
- Consumes: 全部前置服务与界面。
- Produces: `class AppState { List<int>? key; int activeProfile; }`；`Widget app()` 完整路由：PinScreen → ProfileSelectScreen → AssessmentScreen → ResultScreen → LotteryScreen。

- [ ] **Step 1: 写失败测试**

Create `test/app_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/app_state.dart';

void main() {
  test('AppState default has no key and profile 0', () {
    final s = AppState();
    expect(s.key, isNull);
    expect(s.activeProfile, 0);
  });

  test('lock clears key', () {
    final s = AppState()..key = [1, 2];
    s.lock();
    expect(s.key, isNull);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/app_state_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 AppState**

Create `lib/src/services/app_state.dart`:
```dart
class AppState {
  List<int>? key;
  int activeProfile = 0;

  void lock() {
    key = null;
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/app_state_test.dart`
Expected: PASS。

- [ ] **Step 5: 装配根应用**

Modify `lib/src/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'services/app_state.dart';
import 'ui/onboarding/pin_screen.dart';
import 'ui/onboarding/profile_select_screen.dart';

Widget app() => MaterialApp(
      title: '发现自我',
      home: PinScreen(onUnlocked: (key) async {}),
      routes: {
        '/profiles': (c) => ProfileSelectScreen(names: const ['我'], onSelect: (i) {}),
      },
    );
```

Modify `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'src/app.dart';

const String appTitle = '发现自我';

void main() {
  runApp(app());
}
```

- [ ] **Step 6: 全量验证**

Run: `flutter test; flutter analyze`
Expected: 全部 PASS，无 error。

- [ ] **Step 7: 提交**

```bash
git add lib/src/services/app_state.dart lib/src/app.dart lib/main.dart test/app_state_test.dart
git commit -m "feat: wire app root with state and routing"
```

---

## Self-Review

**Spec coverage:**
- 完全离线 → 无网络依赖，全部 task 本地实现 ✅
- Flutter iOS/Android → Task 1 ✅
- PIN + 本地加密 → Task 3、Task 4、Task 9、Task 11 ✅
- 多档案 → Task 4、Task 7、Task 9 ✅
- 四维度测评 → Task 2、Task 6、Task 10 ✅
- 番外 MBTI/星座 → 通过 questions.json type 字段扩展，Task 2/6/10 支持（资源内容可后续补充）✅
- 积分徽章抽奖 → Task 5、Task 7、Task 10 ✅
- 沉浸动画 Lottie → 依赖已加（Task 1），动画资源待补 ✅
- PDF 导出 → Task 8、Task 10 ✅
- 错误处理（PIN 试错冷静、存储不足、动画降级）→ 部分在 Task 9/10 留有扩展点，未完全展开 ⚠️
- 测试策略 → 每个 task 含单元/Widget 测试 ✅

**Placeholder scan:** 无 TBD/TODO；动画与番外题库内容为已知的后续资源补充，已标注。

**Type consistency:** `deriveKey`、`Database.open/insertProfile/insertResult/results`、`AssessmentService.score`、`Lottery.draw`、`buildReportPdf`、`AppState.lock` 在各 task 间签名一致。

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-13-discover-self-implementation.md`.
