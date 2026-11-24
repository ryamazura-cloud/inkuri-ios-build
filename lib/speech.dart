import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_selection.dart';

abstract class SpeechEngine {
  Future<void> prepare();

  /// Completes when the utterance finishes, rather than when it starts.
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class PlaybackControls {
  Future<void> pause();
  Future<void> resume();
  Future<void> setRate(double rate);
  Stream<Duration> get position;
  Stream<Duration> get duration;
}

class DeviceSpeechEngine implements SpeechEngine {
  DeviceSpeechEngine({TargetPlatform? platform, bool? web})
    : platform = platform ?? defaultTargetPlatform,
      web = web ?? kIsWeb;
  final TargetPlatform platform;
  final bool web;
  final FlutterTts _tts = FlutterTts();
  Future<void>? _preparation;
  Completer<void>? _failure;

  @override
  Future<void> prepare() => _preparation ??= _configure();

  Future<void> _configure() async {
    try {
      _tts.setErrorHandler((message) {
        final failure = _failure;
        if (failure != null && !failure.isCompleted) {
          failure.completeError(StateError('Speech engine: $message'));
        }
      });
      // A device may only have a different English locale installed. Selection
      // below validates the chosen locale before falling back to en-US.
      await _tts.setLanguage('en-US');
      await _chooseVoice();
      await _tts.setSpeechRate(naturalSpeechRate(platform, web: web));
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      final supported = await _tts.awaitSpeakCompletion(true);
      if (supported != 1) throw StateError('Speech synthesis unavailable');
    } catch (_) {
      _preparation = null;
      rethrow;
    }
  }

  Future<void> _chooseVoice() async {
    // Browsers can publish their voice list shortly after first access.
    // Voice discovery must never make the existing default unusable.
    for (var attempt = 0; attempt < (web ? 3 : 1); attempt++) {
      try {
        final voices = rankEnglishVoices(
          await _tts.getVoices.timeout(const Duration(seconds: 2)),
        );
        if (voices.isEmpty && web && attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        for (final voice in voices.take(5)) {
          try {
            if (await _tts.setLanguage(voice.locale) != 1) continue;
            final result = await _tts.setVoice(voice.parameters);
            // flutter_tts Web setVoice returns null on success.
            if (result == 1 || (web && result == null)) return;
          } catch (_) {
            /* Try the next installed English voice. */
          }
        }
        break;
      } catch (_) {
        break;
      }
    }
    final language = await _tts.setLanguage('en-US');
    if (language != 1) throw StateError('English speech unavailable');
  }

  @override
  Future<void> speak(String text) async {
    final failure = Completer<void>();
    _failure = failure;
    try {
      await Future.any<void>([
        _tts.speak(text).then((result) {
          // flutter_tts Web completes successfully with null; native targets use 1.
          if (result != 1 && !(kIsWeb && result == null)) {
            throw StateError('Speech was not completed');
          }
        }),
        failure.future,
      ]).timeout(const Duration(seconds: 45));
    } finally {
      if (identical(_failure, failure)) _failure = null;
    }
  }

  @override
  Future<void> stop() async {
    // No platform calls for sessions where the learner never requested audio.
    if (_preparation == null) return;
    final interrupted = _failure;
    _failure = null;
    try {
      await _tts.stop();
    } finally {
      // Some platform engines never settle the speak future after cancellation.
      if (interrupted != null && !interrupted.isCompleted) {
        interrupted.complete();
      }
    }
  }
}

/// Each request owns a generation: completion of an interrupted utterance must
/// never clear the playback state for a newer request.
class SpeechController extends ChangeNotifier {
  SpeechController(this.engine) {
    final controls = playback;
    if (controls != null) {
      _positionSubscription = controls.position.listen((value) {
        position = value;
        if (!_disposed) notifyListeners();
      });
      _durationSubscription = controls.duration.listen((value) {
        duration = value;
        if (!_disposed) notifyListeners();
      });
    }
  }
  final SpeechEngine engine;
  PlaybackControls? get playback =>
      engine is PlaybackControls ? engine as PlaybackControls : null;
  StreamSubscription<Duration>? _positionSubscription, _durationSubscription;
  Duration position = Duration.zero, duration = Duration.zero;
  bool paused = false, preparing = false, _changingPlayback = false;
  double rate = 1;
  String? activeText;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  bool _current(int generation) => !_disposed && _generation == generation;

  Future<void> toggle(String text) async {
    if (_disposed || _changingPlayback) return;
    if (activeText != text) return _play(text);
    final controls = playback;
    if (controls == null) return stop();
    await _adjust(() async {
      if (paused) {
        await controls.resume();
      } else {
        await controls.pause();
      }
      if (activeText == text) paused = !paused;
    });
  }

  Future<void> restart(String text) async {
    if (!_disposed && !preparing && !_changingPlayback) await _play(text);
  }

  Future<void> setRate(double value) async {
    final controls = playback;
    if (_disposed || controls == null || preparing || _changingPlayback) return;
    await _adjust(() async {
      await controls.setRate(value);
      rate = value;
    });
  }

  Future<void> _adjust(Future<void> Function() change) async {
    final generation = _generation;
    _changingPlayback = true;
    try {
      await change();
    } catch (_) {
      if (_current(generation)) {
        error = '音声の設定を変更できませんでした。もう一度お試しください。';
      }
    } finally {
      _changingPlayback = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _play(String text) async {
    final generation = ++_generation;
    activeText = text;
    paused = false;
    preparing = true;
    position = duration = Duration.zero;
    error = null;
    notifyListeners();
    try {
      await engine.prepare();
      if (!_current(generation)) return;
      await engine.stop();
      if (!_current(generation)) return;
      final playbackFuture = engine.speak(text);
      preparing = false;
      notifyListeners();
      await playbackFuture;
      if (!_current(generation)) return;
      activeText = null;
      notifyListeners();
    } catch (_) {
      if (!_current(generation)) return;
      try {
        await engine.stop();
      } catch (_) {
        /* Playback may already be unavailable. */
      }
      if (!_current(generation)) return;
      activeText = null;
      preparing = paused = false;
      error = '音声を再生できませんでした。音量をご確認のうえ、もう一度お試しください。学習はそのまま続けられます。';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    ++_generation;
    activeText = null;
    preparing = paused = false;
    position = duration = Duration.zero;
    error = null;
    notifyListeners();
    try {
      await engine.stop();
    } catch (_) {
      /* Keep study navigation available. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(engine.stop().catchError((Object _) {}));
    super.dispose();
  }
}
