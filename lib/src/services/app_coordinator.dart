import '../db/database.dart';
import '../models/assessment_record.dart';
import '../models/career.dart';
import '../models/dimension.dart';
import '../models/question.dart';
import 'assessment.dart';
import 'asset_loader.dart';
import 'lottery.dart';

/// Drives the end-to-end user flow: unlock the encrypted store, load the
/// question bank and prize table, manage profiles, score assessments and
/// persist results.
///
/// This replaces the old [AppState] value holder so the UI has a single source
/// of truth that owns the [Database] handle.
class AppCoordinator {
  AppCoordinator({Database? database, AssetLoader? loader})
    : _db = database ?? Database(),
      _loader = loader ?? AssetLoader();

  final Database _db;
  final AssetLoader _loader;

  /// Derived encryption key while unlocked, `null` when locked.
  List<int>? key;

  /// Index into [profileNames] of the currently selected profile.
  int activeProfile = 0;

  /// Human-readable profile names in display order.
  List<String> profileNames = const ['我'];

  /// Profile row ids parallel to [profileNames] (`0` for the in-memory default).
  List<int> profileIds = const [0];

  /// Assessment questions loaded on unlock.
  List<Question> questions = const [];

  /// Dimension metadata loaded on unlock.
  List<DimensionInfo> dimensions = const [];

  /// Career suggestions loaded on unlock.
  List<CareerItem> careers = const [];

  /// Lottery prizes loaded on unlock.
  List<Prize> prizes = const [];

  /// Unlocks the store with [key], opens the database and loads local data.
  ///
  /// The key is published only after the database and all local data load
  /// successfully, and any failure resets the coordinator to a clean locked
  /// state, so a wrong PIN can never leave [key] set with empty questions.
  Future<void> unlock(List<int> key) async {
    _reset();

    try {
      await _db.open(key);
      final loadedQuestions = await _loader.questions();
      final loadedDimensions = await _loader.dimensions();
      final loadedCareers = await _loader.careers();
      final loadedPrizes = await _loader.prizes();
      final rows = await _db.profiles();

      final names = rows.isEmpty
          ? const ['我']
          : rows.map((r) => r['name'] as String).toList(growable: false);
      final ids = rows.isEmpty
          ? const [0]
          : rows.map((r) => r['id'] as int).toList(growable: false);

      questions = loadedQuestions;
      dimensions = loadedDimensions;
      careers = loadedCareers;
      prizes = loadedPrizes;
      profileNames = names;
      profileIds = ids;
      activeProfile = 0;
      this.key = key;
    } catch (_) {
      try {
        await _db.close();
      } catch (_) {
        // Ignore; preserving the original failure below.
      }
      _reset();
      rethrow;
    }
  }

  void _reset() {
    key = null;
    questions = const [];
    dimensions = const [];
    careers = const [];
    prizes = const [];
    profileNames = const ['我'];
    profileIds = const [0];
    activeProfile = 0;
  }

  /// Creates a profile and selects it.
  Future<void> createProfile(String name, List<int> salt) async {
    final id = await _db.insertProfile(name, salt);
    final rows = await _db.profiles();
    profileNames = rows.map((r) => r['name'] as String).toList(growable: false);
    profileIds = rows.map((r) => r['id'] as int).toList(growable: false);
    activeProfile = profileIds.lastIndexOf(id);
    if (activeProfile < 0) activeProfile = profileIds.length - 1;
  }

  /// Scores [answers], persists the raw per-dimension result and answer sheet,
  /// and returns the averaged scores keyed by dimension.
  Future<Map<String, double>> submitAnswers(Map<String, int> answers) async {
    final scores = AssessmentService(questions).score(answers);
    final type = questions.isNotEmpty ? questions.first.type : 'personality';
    await _db.saveResult(_activeProfileId, type, scores, answers: answers);
    return scores;
  }

  int get _activeProfileId =>
      profileIds.isNotEmpty ? profileIds[activeProfile] : activeProfile;

  /// The newest persisted attempt for the active profile, if any.
  Future<AssessmentRecord?> latestResult() =>
      _db.latestResult(_activeProfileId);

  /// All persisted attempts for the active profile, newest first.
  Future<List<AssessmentRecord>> resultHistory() =>
      _db.resultHistory(_activeProfileId);

  /// Growth tips relevant to [scores].
  Future<List<String>> recommendations(Map<String, double> scores) =>
      _loader.recommendations(scores);

  /// Clears the in-memory key/data and closes the database.
  Future<void> lock() async {
    key = null;
    questions = const [];
    dimensions = const [];
    careers = const [];
    prizes = const [];
    await _db.close();
  }
}
