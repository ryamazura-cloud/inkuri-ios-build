import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/speech.dart';

class FakeSpeechEngine implements SpeechEngine {
  final spoken = <String>[];
  final completions = <Completer<void>>[];
  int stops = 0;
  bool fail = false;
  Completer<void>? preparation;
  @override
  Future<void> prepare() async {
    if (preparation != null) await preparation!.future;
  }

  @override
  Future<void> speak(String text) async {
    if (fail) throw StateError('No English voice');
    spoken.add(text);
    final completer = Completer<void>();
    completions.add(completer);
    await completer.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('playback returns to idle on completion', () async {
    final engine = FakeSpeechEngine();
    final controller = SpeechController(engine);
    final play = controller.toggle('I have a question.');
    await flush();
    expect(engine.spoken, ['I have a question.']);
    expect(controller.activeText, 'I have a question.');
    engine.completions.single.complete();
    await play;
    expect(controller.activeText, isNull);
    controller.dispose();
  });
  test(
    'switching utterances ignores completion of previous playback',
    () async {
      final engine = FakeSpeechEngine();
      final controller = SpeechController(engine);
      final first = controller.toggle('First.');
      await flush();
      final second = controller.toggle('Second.');
      await flush();
      engine.completions.first.complete();
      await first;
      expect(controller.activeText, 'Second.');
      expect(engine.stops, 2);
      engine.completions.last.complete();
      await second;
      expect(controller.activeText, isNull);
      controller.dispose();
    },
  );
  test('stop during voice setup prevents later playback', () async {
    final engine = FakeSpeechEngine()..preparation = Completer<void>();
    final controller = SpeechController(engine);
    final play = controller.toggle('Do not start.');
    await controller.stop();
    engine.preparation!.complete();
    await play;
    expect(engine.spoken, isEmpty);
    expect(controller.activeText, isNull);
    controller.dispose();
  });
  test('same sentence toggles stop', () async {
    final engine = FakeSpeechEngine();
    final controller = SpeechController(engine);
    final play = controller.toggle('Hello.');
    await flush();
    await controller.toggle('Hello.');
    expect(controller.activeText, isNull);
    expect(engine.spoken, ['Hello.']);
    engine.completions.single.complete();
    await play;
    controller.dispose();
  });
  test('voice failure is recoverable and never changes study data', () async {
    final engine = FakeSpeechEngine()..fail = true;
    final controller = SpeechController(engine);
    await controller.toggle('Hello.');
    expect(controller.error, isNotNull);
    expect(controller.activeText, isNull);
    engine.fail = false;
    final retry = controller.toggle('Hello.');
    await flush();
    expect(controller.error, isNull);
    engine.completions.single.complete();
    await retry;
    controller.dispose();
  });
  test('disposal stops speech and ignores late failures', () async {
    final engine = FakeSpeechEngine();
    final controller = SpeechController(engine);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final play = controller.toggle('Hello.');
    await flush();
    controller.dispose();
    final count = notifications;
    engine.completions.single.completeError(StateError('interrupted'));
    await play;
    expect(notifications, count);
    expect(engine.stops, 2);
  });

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('device adapter configures English and waits for completion', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 1;
    });
    final engine = DeviceSpeechEngine();
    await engine.prepare();
    await engine.prepare();
    await engine.speak('Hello.');
    await engine.stop();
    expect(calls.map((c) => c.method), [
      'setLanguage',
      'getVoices',
      'setLanguage',
      'setSpeechRate',
      'setPitch',
      'setVolume',
      'awaitSpeakCompletion',
      'speak',
      'stop',
    ]);
    expect(calls.first.arguments, 'en-US');
    expect(calls.firstWhere((c) => c.method == 'setSpeechRate').arguments, 1.0);
    expect(calls.firstWhere((c) => c.method == 'setPitch').arguments, 1.0);
    expect(
      calls.firstWhere((c) => c.method == 'awaitSpeakCompletion').arguments,
      true,
    );
    expect(calls.firstWhere((c) => c.method == 'speak').arguments, 'Hello.');
  });
  test(
    'stop settles playback even when the platform leaves speak pending',
    () async {
      final nativeSpeech = Completer<dynamic>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') return await nativeSpeech.future;
        return 1;
      });
      final engine = DeviceSpeechEngine();
      await engine.prepare();
      final play = engine.speak('Hello.');
      await flush();
      await engine.stop();
      await play;
      nativeSpeech.complete(0);
      await flush();
    },
  );
  test(
    'unavailable English voice fails instead of falling back silently',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'setLanguage' ? 0 : 1,
      );
      await expectLater(DeviceSpeechEngine().prepare(), throwsStateError);
    },
  );
}
