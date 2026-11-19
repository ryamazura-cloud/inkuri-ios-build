import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phrase_flow/speech.dart';
import 'package:phrase_flow/voice_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Apple premium and enhanced voices rank above basic voices', () {
    final voices = rankEnglishVoices([
      {'name': 'Basic', 'locale': 'en-US', 'quality': 'default'},
      {'name': 'Enhanced', 'locale': 'en-US', 'quality': 'enhanced'},
      {
        'name': 'Premium',
        'locale': 'en-US',
        'quality': 'premium',
        'identifier': 'voice-premium',
      },
    ]);
    expect(voices.map((v) => v.name), ['Premium', 'Enhanced', 'Basic']);
    expect(voices.first.parameters['identifier'], 'voice-premium');
  });
  test('American English stays preferred and other English is a fallback', () {
    final us = {'name': 'US', 'locale': 'en_US', 'quality': 'normal'};
    final uk = {'name': 'UK', 'locale': 'en-GB', 'quality': 'premium'};
    expect(rankEnglishVoices([uk, us]).single.name, 'US');
    expect(rankEnglishVoices([uk]).single.name, 'UK');
  });
  test(
    'Android quality is primary and local voice breaks equal-quality ties',
    () {
      final voices = rankEnglishVoices([
        {
          'name': 'Online',
          'locale': 'en-US',
          'quality': 'high',
          'network_required': '1',
        },
        {
          'name': 'Local',
          'locale': 'en-US',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'Basic',
          'locale': 'en-US',
          'quality': 'normal',
          'network_required': '0',
        },
      ]);
      expect(voices.map((v) => v.name), ['Local', 'Online', 'Basic']);
    },
  );
  test('browser natural or neural names rank before basic names', () {
    final voices = rankEnglishVoices([
      {'name': 'Basic', 'locale': 'en-US'},
      {'name': 'Google US English', 'locale': 'en-US'},
      {'name': 'Example English Natural', 'locale': 'en-US'},
    ]);
    expect(voices.map((v) => v.name), [
      'Example English Natural',
      'Google US English',
      'Basic',
    ]);
  });
  test('invalid non-English and uninstalled voices are skipped', () {
    expect(
      rankEnglishVoices([
        null,
        42,
        {},
        {'name': 'Japanese', 'locale': 'ja-JP'},
        {'name': '', 'locale': 'en-US'},
        {'name': 'Missing', 'locale': 'en-US', 'features': 'notInstalled'},
      ]),
      isEmpty,
    );
    expect(rankEnglishVoices(null), isEmpty);
  });
  test(
    'normal rate uses Apple native scale and multiplier scale elsewhere',
    () {
      expect(naturalSpeechRate(TargetPlatform.iOS, web: false), 0.5);
      expect(naturalSpeechRate(TargetPlatform.macOS, web: false), 0.5);
      expect(naturalSpeechRate(TargetPlatform.android, web: false), 1.0);
      expect(naturalSpeechRate(TargetPlatform.iOS, web: true), 1.0);
    },
  );

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('adapter applies best installed voice and Apple normal rate', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getVoices') {
        return [
          {'name': 'Basic', 'locale': 'en-US', 'quality': 'default'},
          {
            'name': 'Enhanced',
            'locale': 'en-US',
            'quality': 'enhanced',
            'identifier': 'enhanced-id',
          },
        ];
      }
      return 1;
    });
    await DeviceSpeechEngine(
      platform: TargetPlatform.iOS,
      web: false,
    ).prepare();
    expect(
      (calls.singleWhere((c) => c.method == 'setVoice').arguments
          as Map)['identifier'],
      'enhanced-id',
    );
    expect(
      calls.singleWhere((c) => c.method == 'setSpeechRate').arguments,
      0.5,
    );
  });
  test(
    'voice query failure falls back to default English at normal speed',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getVoices') {
          throw PlatformException(code: 'unsupported');
        }
        return 1;
      });
      await DeviceSpeechEngine(
        platform: TargetPlatform.android,
        web: false,
      ).prepare();
      expect(calls.where((c) => c.method == 'setVoice'), isEmpty);
      expect(
        calls.lastWhere((c) => c.method == 'setLanguage').arguments,
        'en-US',
      );
      expect(
        calls.singleWhere((c) => c.method == 'setSpeechRate').arguments,
        1.0,
      );
    },
  );
  test(
    'an installed English locale works even when en-US is unavailable',
    () async {
      final languages = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getVoices') {
          return [
            {'name': 'British', 'locale': 'en-GB'},
          ];
        }
        if (call.method == 'setLanguage') {
          languages.add(call.arguments as String);
          return call.arguments == 'en-GB' ? 1 : 0;
        }
        return 1;
      });
      await DeviceSpeechEngine(web: false).prepare();
      expect(languages, ['en-US', 'en-GB']);
    },
  );
  test(
    'voice rejection tries the next voice without preventing playback setup',
    () async {
      final names = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getVoices') {
          return [
            {'name': 'Unavailable', 'locale': 'en-US', 'quality': 'premium'},
            {'name': 'Working', 'locale': 'en-US', 'quality': 'enhanced'},
          ];
        }
        if (call.method == 'setVoice') {
          final name = (call.arguments as Map)['name'] as String;
          names.add(name);
          return name == 'Working' ? 1 : 0;
        }
        return 1;
      });
      await DeviceSpeechEngine(web: false).prepare();
      expect(names, ['Unavailable', 'Working']);
    },
  );
}
