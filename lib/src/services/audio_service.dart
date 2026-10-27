import 'package:audioplayers/audioplayers.dart';

/// Plays bundled sound effects and an optional looping background track.
///
/// Every call is a no-op when [silent] is true or when the audio platform is
/// unavailable, so widget tests and unusual devices never crash. Sound assets
/// are CC0 (Kenney); see `assets/sounds/LICENSE-*`.
class AudioService {
  AudioService({this.silent = false});

  /// Disables all playback. Tests use `AudioService(silent: true)`.
  bool silent;

  /// Whether sound effects are enabled (user toggle).
  bool sfxOn = true;

  /// Whether background music is enabled (user toggle).
  bool musicOn = true;

  final Map<String, AudioPlayer> _sfx = {};
  AudioPlayer? _bgm;

  Future<void> tap() => _play('sounds/tap.ogg', 'tap');

  Future<void> back() => _play('sounds/back.ogg', 'back');

  Future<void> stageComplete() => _play('sounds/stage.ogg', 'stage');

  Future<void> result() => _play('sounds/result.ogg', 'result');

  Future<void> win() => _play('sounds/win.ogg', 'win');

  Future<void> _play(String asset, String key) async {
    if (silent || !sfxOn) return;
    try {
      final player = _sfx.putIfAbsent(key, AudioPlayer.new);
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (_) {
      // Audio is best-effort; never let it break the flow.
    }
  }

  /// Starts or stops the looping background music.
  Future<void> setMusic(bool on) async {
    musicOn = on;
    if (silent) return;
    try {
      final player = _bgm ??= AudioPlayer();
      if (on) {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0.25);
        await player.play(AssetSource('sounds/bgm.wav'));
      } else {
        await player.stop();
      }
    } catch (_) {
      // Ignore: music is optional.
    }
  }

  Future<void> dispose() async {
    for (final player in _sfx.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    try {
      await _bgm?.dispose();
    } catch (_) {}
  }
}
