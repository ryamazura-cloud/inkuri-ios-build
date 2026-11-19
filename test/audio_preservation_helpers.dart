import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compression intentionally changes file bytes and extension, while retaining
/// the exact text, original audio provenance, duration and stable filename stem.
void expectCompressedOriginal(Map? current, Map original) {
  expect(current, isNotNull, reason: original['text'] as String);
  final clip = current!;
  expect(clip['text'], original['text']);
  expect(clip['textSha256'], original['textSha256']);
  expect(
    clip['asset'],
    (original['asset'] as String).replaceFirst(RegExp(r'\.wav$'), '.m4a'),
  );
  expect(clip['sourceFileSha256'], original['fileSha256']);
  expect(clip['durationSeconds'], original['durationSeconds']);
  final bytes = File(clip['asset'] as String).readAsBytesSync();
  expect(sha256.convert(bytes).toString(), clip['fileSha256']);
  expect(bytes.length, clip['bytes']);
}
