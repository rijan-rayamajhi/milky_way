import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global audio + haptics. Used as a singleton (`sound`) so any widget can
/// trigger a cue without plumbing it through constructors. Three independent,
/// persisted switches — [musicEnabled], [sfxEnabled], [hapticsEnabled] — each
/// guarding its own output. Every play is wrapped so a missing/failed asset
/// never throws.
class SoundService extends ChangeNotifier {
  static const _kMusic = 'music_enabled';
  static const _kSfx = 'sfx_enabled';
  static const _kHaptics = 'haptics_enabled';
  static const _kLegacy = 'sound_enabled'; // old single flag (pre-split)

  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _loop = AudioPlayer(playerId: 'loop');
  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  SharedPreferences? _prefs;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _hapticsEnabled = true;
  bool _musicStarted = false;

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  /// True while any audio channel is on (for a single header mute button).
  bool get anyAudioOn => _musicEnabled || _sfxEnabled;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    // Migrate the old single flag: if present, seed all three from it.
    final legacy = _prefs?.getBool(_kLegacy);
    _musicEnabled = _prefs?.getBool(_kMusic) ?? legacy ?? true;
    _sfxEnabled = _prefs?.getBool(_kSfx) ?? legacy ?? true;
    _hapticsEnabled = _prefs?.getBool(_kHaptics) ?? legacy ?? true;
    await _loop.setReleaseMode(ReleaseMode.loop);
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35); // sits under the SFX
    notifyListeners();
  }

  /// Start the looping background track. Safe to call repeatedly.
  Future<void> startMusic() async {
    _musicStarted = true;
    if (!_musicEnabled) return;
    try {
      await _music.play(AssetSource('sounds/bg_music.mp3'), volume: 0.35);
    } catch (_) {}
  }

  // ---- switches ----
  void setMusicEnabled(bool v) {
    _musicEnabled = v;
    _prefs?.setBool(_kMusic, v);
    if (!v) {
      _music.stop();
    } else if (_musicStarted) {
      startMusic();
    }
    notifyListeners();
  }

  void setSfxEnabled(bool v) {
    _sfxEnabled = v;
    _prefs?.setBool(_kSfx, v);
    if (!v) _loop.stop();
    notifyListeners();
  }

  void setHapticsEnabled(bool v) {
    _hapticsEnabled = v;
    _prefs?.setBool(_kHaptics, v);
    notifyListeners();
  }

  void toggleMusic() => setMusicEnabled(!_musicEnabled);
  void toggleSfx() => setSfxEnabled(!_sfxEnabled);
  void toggleHaptics() => setHapticsEnabled(!_hapticsEnabled);

  /// Mute/unmute all audio at once (music + SFX), for a single header button.
  void setAllAudio(bool v) {
    setMusicEnabled(v);
    setSfxEnabled(v);
  }

  void _play(AudioPlayer p, String file) {
    if (!_sfxEnabled) return;
    p.play(AssetSource('sounds/$file')).catchError((_) {});
  }

  // ---- haptics (gated by [hapticsEnabled]) ----
  void hapticSelection() {
    if (_hapticsEnabled) HapticFeedback.selectionClick();
  }

  void hapticLight() {
    if (_hapticsEnabled) HapticFeedback.lightImpact();
  }

  void hapticMedium() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
  }

  void hapticHeavy() {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
  }

  // ---- cues ----
  void tap() {
    _play(_sfxPlayer, 'tap.wav');
    hapticSelection();
  }

  void spinStart() {
    _play(_loop, 'spin_loop.wav');
    hapticMedium();
  }

  void spinStop() {
    if (_sfxEnabled) _loop.stop();
  }

  void reelStop() {
    _play(_sfxPlayer, 'reel_stop.wav');
    hapticSelection();
  }

  /// Coins landing in the balance (coin-increase chime).
  void coin() {
    _play(_sfxPlayer, 'coin.wav');
    hapticSelection();
  }

  void win() {
    _play(_sfxPlayer, 'win.wav');
    hapticLight();
  }

  void bigWin() {
    _play(_sfxPlayer, 'bigwin.wav');
    hapticHeavy();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _loop.dispose();
    _music.dispose();
    super.dispose();
  }
}

/// App-wide instance; initialized in main().
final sound = SoundService();
