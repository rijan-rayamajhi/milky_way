import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global sound + haptics. Used as a singleton (`sound`) so any widget can
/// trigger a cue without plumbing it through constructors. Every call is
/// guarded by [enabled] and wrapped so a missing/failed asset never throws.
class SoundService extends ChangeNotifier {
  static const _kEnabled = 'sound_enabled';

  final AudioPlayer _sfx = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _loop = AudioPlayer(playerId: 'loop');
  SharedPreferences? _prefs;
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_kEnabled) ?? true;
    await _loop.setReleaseMode(ReleaseMode.loop);
    notifyListeners();
  }

  void setEnabled(bool v) {
    _enabled = v;
    _prefs?.setBool(_kEnabled, v);
    if (!v) _loop.stop();
    notifyListeners();
  }

  void toggle() => setEnabled(!_enabled);

  void _play(AudioPlayer p, String file) {
    if (!_enabled) return;
    p.play(AssetSource('sounds/$file')).catchError((_) {});
  }

  // ---- cues ----
  void tap() {
    _play(_sfx, 'tap.wav');
    HapticFeedback.selectionClick();
  }

  void spinStart() {
    _play(_loop, 'spin_loop.wav');
    HapticFeedback.mediumImpact();
  }

  void spinStop() {
    if (_enabled) _loop.stop();
  }

  void reelStop() {
    _play(_sfx, 'reel_stop.wav');
    HapticFeedback.selectionClick();
  }

  void win() {
    _play(_sfx, 'win.wav');
    HapticFeedback.lightImpact();
  }

  void bigWin() {
    _play(_sfx, 'bigwin.wav');
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _sfx.dispose();
    _loop.dispose();
    super.dispose();
  }
}

/// App-wide instance; initialized in main().
final sound = SoundService();
