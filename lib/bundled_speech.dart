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

class AssetClipPlayback implements ClipPlayback {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  Future<void>? _resume;
  final _done = Completer<void>();
  bool _stopped = false;

  @override
  Future<void> play(String asset) async {
    final player = _player = AudioPlayer();
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
    await player.setSource(AssetSource(asset.substring('assets/'.length)));
    if (_stopped) return;
    _resume = player.resume();
    await _resume;
    if (_stopped) await player.stop();
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
    await _player?.dispose();
  }
}

class BundledSpeechEngine implements SpeechEngine {
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
    try {
      await playback.play(asset).timeout(const Duration(seconds: 45));
    } finally {
      if (identical(_active, playback)) _active = null;
      await playback.dispose();
    }
  }

  @override
  Future<void> stop() async {
    await _active?.stop();
  }
}
