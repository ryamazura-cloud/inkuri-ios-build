import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'speech.dart';

class AudioCatalog {
  AudioCatalog._(this.clips);
  final Map<String, String> clips;
  static AudioCatalog decode(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    if (root['schemaVersion'] != 1 || root['clips'] is! List) {
      throw const FormatException('Invalid bundled audio catalog');
    }
    final clips = <String, String>{};
    for (final raw in root['clips'] as List) {
      if (raw is! Map || raw['text'] is! String || raw['asset'] is! String) {
        throw const FormatException('Invalid audio entry');
      }
      final text = raw['text'] as String;
      final asset = raw['asset'] as String;
      if (text.trim().isEmpty ||
          clips.containsKey(text) ||
          !RegExp(r'^assets/audio/[a-f0-9]{20}\.m4a$').hasMatch(asset)) {
        throw const FormatException('Invalid audio mapping');
      }
      clips[text] = asset;
    }
    if (clips.isEmpty) throw const FormatException('Empty audio catalog');
    return AudioCatalog._(Map.unmodifiable(clips));
  }
}

abstract class ClipPlayback {
  Future<void> play(String asset);
  Future<void> stop();
  Future<void> dispose();
}

class AssetClipPlayback implements ClipPlayback, PlaybackControls {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  Future<void>? _resume;
  final _done = Completer<void>();
  bool _stopped = false;
  double _rate = 1;
  bool _paused = false;
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  StreamSubscription<Duration>? _positionSubscription, _durationSubscription;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Future<void> pause() async {
    _paused = true;
    await _resume;
    if (!_stopped) await _player?.pause();
  }

  @override
  Future<void> resume() async {
    _paused = false;
    if (!_stopped && _resume != null) await _player?.resume();
  }

  @override
  Future<void> setRate(double rate) async {
    if (!_stopped && _resume != null) await _player?.setPlaybackRate(rate);
    _rate = rate;
  }

  @override
  Future<void> play(String asset) async {
    final player = _player = AudioPlayer();
    _positionSubscription = player.onPositionChanged.listen(_position.add);
    _durationSubscription = player.onDurationChanged.listen(_duration.add);
    _completion = player.onPlayerComplete.listen(
      (_) {
        if (!_done.isCompleted) _done.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!_done.isCompleted) _done.completeError(error, stack);
      },
    );
    // Subscribe before native preparation so errors have a listener immediately.
    final completion = _done.future;
    unawaited(completion.catchError((Object _) {}));
    await player.setReleaseMode(ReleaseMode.stop);
    if (_stopped) return;
    await player
        .setSource(AssetSource(asset.substring('assets/'.length)))
        .timeout(const Duration(seconds: 15));
    if (_stopped) return;
    _resume = player.resume();
    await _resume;
    if (_stopped) await player.stop();
    if (!_stopped) await player.setPlaybackRate(_rate);
    if (_paused && !_stopped) await player.pause();
    await completion;
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    try {
      // Stop after an already-issued resume, avoiding delayed playback after exit.
      await _resume;
      await _player?.stop();
    } finally {
      if (!_done.isCompleted) _done.complete();
    }
  }

  @override
  Future<void> dispose() async {
    _stopped = true;
    await _completion?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _position.close();
    await _duration.close();
    await _player?.dispose();
  }
}

class BundledSpeechEngine implements SpeechEngine, PlaybackControls {
  BundledSpeechEngine({
    Future<String> Function()? loadManifest,
    ClipPlayback Function()? createPlayback,
  }) : _loadManifest =
           loadManifest ??
           (() => rootBundle.loadString('assets/audio/manifest.json')),
       _createPlayback = createPlayback ?? AssetClipPlayback.new;
  final Future<String> Function() _loadManifest;
  final ClipPlayback Function() _createPlayback;
  Future<void>? _preparation;
  AudioCatalog? _catalog;
  ClipPlayback? _active;
  double _rate = 1;
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;

  PlaybackControls? get _controls =>
      _active is PlaybackControls ? _active as PlaybackControls : null;

  @override
  Future<void> pause() async => _controls?.pause();
  @override
  Future<void> resume() async => _controls?.resume();
  @override
  Future<void> setRate(double rate) async {
    await _controls?.setRate(rate);
    _rate = rate;
  }

  @override
  Future<void> prepare() => _preparation ??= _load();
  Future<void> _load() async {
    try {
      _catalog = AudioCatalog.decode(await _loadManifest());
    } catch (_) {
      _preparation = null;
      rethrow;
    }
  }

  @override
  Future<void> speak(String text) async {
    final asset = _catalog?.clips[text];
    if (asset == null) {
      throw StateError('No bundled audio for this exact English text');
    }
    final playback = _createPlayback();
    _active = playback;
    final controls = _controls;
    final positionSubscription = controls?.position.listen((value) {
      if (identical(_active, playback)) _position.add(value);
    });
    final durationSubscription = controls?.duration.listen((value) {
      if (identical(_active, playback)) _duration.add(value);
    });
    try {
      if (controls != null) await controls.setRate(_rate);
      if (identical(_active, playback)) await playback.play(asset);
    } finally {
      await positionSubscription?.cancel();
      await durationSubscription?.cancel();
      if (identical(_active, playback)) _active = null;
      await playback.dispose();
    }
  }

  @override
  Future<void> stop() async {
    final playback = _active;
    _active = null;
    await playback?.stop();
  }
}
