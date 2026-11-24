import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/bundled_speech.dart';
import 'package:phrase_flow/domain.dart';
import 'package:phrase_flow/speech.dart';

const asset = 'assets/audio/01234567890123456789.m4a';
String fixture() => jsonEncode({
  'schemaVersion': 1,
  'clips': [
    {'text': 'I have a question.', 'asset': asset},
  ],
});

class FakeClip implements ClipPlayback {
  String? played;
  int stops = 0, disposals = 0;
  final done = Completer<void>();
  @override
  Future<void> play(String asset) async {
    played = asset;
    await done.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (!done.isCompleted) done.complete();
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class ControllableClip extends FakeClip implements PlaybackControls {
  final changes = <String>[];
  final positions = StreamController<Duration>();
  final durations = StreamController<Duration>();

  @override
  Stream<Duration> get position => positions.stream;
  @override
  Stream<Duration> get duration => durations.stream;
  @override
  Future<void> pause() async => changes.add('pause');
  @override
  Future<void> resume() async => changes.add('resume');
  @override
  Future<void> setRate(double rate) async => changes.add('rate=$rate');

  @override
  Future<void> dispose() async {
    await positions.close();
    await durations.close();
    await super.dispose();
  }
}

void main() {
  test(
    'bundled audio resumes the same clip and retains the selected rate',
    () async {
      const text = 'I have a question.';
      final clip = ControllableClip();
      final controller = SpeechController(
        BundledSpeechEngine(
          loadManifest: () async => fixture(),
          createPlayback: () => clip,
        ),
      );
      await controller.setRate(.75);
      final playing = controller.toggle(text);
      await Future<void>.delayed(Duration.zero);
      clip.positions.add(const Duration(seconds: 2));
      clip.durations.add(const Duration(seconds: 8));
      await Future<void>.delayed(Duration.zero);
      expect(controller.position, const Duration(seconds: 2));
      expect(controller.duration, const Duration(seconds: 8));
      await controller.toggle(text);
      expect(controller.paused, isTrue);
      await controller.setRate(1.25);
      await controller.toggle(text);
      expect(controller.paused, isFalse);
      expect(clip.changes, ['rate=0.75', 'pause', 'rate=1.25', 'resume']);
      expect(clip.stops, 0);
      clip.done.complete();
      await playing;
      expect(controller.activeText, isNull);
      expect(controller.rate, 1.25);
      controller.dispose();
    },
  );

  test(
    'all adventure and grammar English texts have valid bundled audio and hashes',
    () {
      final raw =
          jsonDecode(File('assets/audio/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final catalog = AudioCatalog.decode(jsonEncode(raw));
      final questions = [
        ...Question.decode(File('assets/questions.json').readAsStringSync()),
        ...Question.decode(File('assets/grammar.json').readAsStringSync()),
      ];
      final texts = questions
          .expand((q) => q.answers.map((a) => a.text))
          .toSet();
      expect(texts.length, 3836);
      expect(catalog.clips.keys.toSet(), texts);
      expect(catalog.clips.values.toSet().length, 3836);
      expect(raw['audioFormat'], 'AAC-LC mono 24000 Hz M4A 48 kbps');
      expect(
        Directory(
          'assets/audio',
        ).listSync().where((f) => f.path.endsWith('.wav')),
        isEmpty,
      );
      for (final clip in raw['clips'] as List) {
        final text = clip['text'] as String;
        final textHash = sha256.convert(utf8.encode(text)).toString();
        expect(clip['textSha256'], textHash);
        expect(clip['asset'], 'assets/audio/${textHash.substring(0, 20)}.m4a');
        final bytes = File(clip['asset'] as String).readAsBytesSync();
        expect(sha256.convert(bytes).toString(), clip['fileSha256']);
        expect(bytes.length, clip['bytes']);
        expect(ascii.decode(bytes.sublist(4, 8)), 'ftyp');
        final container = latin1.decode(bytes);
        expect(container, contains('moov'));
        expect(container, contains('mdat'));
        expect(clip['sourceFileSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        final seconds = (clip['durationSeconds'] as num).toDouble();
        expect(seconds, inInclusiveRange(0.4, 30));
        expect((clip['rms'] as num).toDouble(), greaterThan(0.001));
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test('manifest rejects unknown schemas duplicate text and remote paths', () {
    expect(
      () => AudioCatalog.decode('{"schemaVersion":2,"clips":[]}'),
      throwsFormatException,
    );
    for (final clips in [
      [],
      [
        {'text': 'Hello', 'asset': 'https://example.com/audio.wav'},
      ],
      [
        {'text': 'Hello', 'asset': asset},
        {'text': 'Hello', 'asset': asset},
      ],
    ]) {
      expect(
        () => AudioCatalog.decode(
          jsonEncode({'schemaVersion': 1, 'clips': clips}),
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'bundled engine plays the exact mapped local clip and disposes after completion',
    () async {
      final clip = FakeClip();
      final engine = BundledSpeechEngine(
        loadManifest: () async => fixture(),
        createPlayback: () => clip,
      );
      await engine.prepare();
      final play = engine.speak('I have a question.');
      await Future<void>.delayed(Duration.zero);
      expect(clip.played, asset);
      clip.done.complete();
      await play;
      expect(clip.disposals, 1);
    },
  );
  test(
    'stop ends playback and missing audio never triggers device synthesis',
    () async {
      final clip = FakeClip();
      final engine = BundledSpeechEngine(
        loadManifest: () async => fixture(),
        createPlayback: () => clip,
      );
      await engine.prepare();
      final play = engine.speak('I have a question.');
      await Future<void>.delayed(Duration.zero);
      await engine.stop();
      await play;
      expect(clip.stops, 1);
      expect(clip.disposals, 1);
      await expectLater(
        engine.speak('Changed English text.'),
        throwsStateError,
      );
    },
  );
  test('asset loading errors do not turn into successful playback', () async {
    final clip = FakeClip();
    final engine = BundledSpeechEngine(
      loadManifest: () async => fixture(),
      createPlayback: () => clip,
    );
    await engine.prepare();
    final play = engine.speak('I have a question.');
    clip.done.completeError(StateError('Cannot decode file'));
    await expectLater(play, throwsStateError);
    expect(clip.disposals, 1);
  });
}
