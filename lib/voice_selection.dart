import 'package:flutter/foundation.dart';

/// Native Apple rate values use a different scale from Android / Web.
double naturalSpeechRate(TargetPlatform platform, {required bool web}) =>
    !web && (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)
    ? 0.5
    : 1.0;

class EnglishVoice {
  EnglishVoice(
    this.name,
    this.locale,
    this.quality,
    this.identifier,
    this.networkRequired,
  );
  final String name, locale, quality, identifier;
  final bool networkRequired;
  Map<String, String> get parameters => {
    'name': name,
    'locale': locale,
    if (identifier.isNotEmpty) 'identifier': identifier,
  };

  static EnglishVoice? parse(dynamic raw) {
    if (raw is! Map || raw['name'] is! String || raw['locale'] is! String) {
      return null;
    }
    final name = raw['name'] as String;
    final locale = raw['locale'] as String;
    final normalized = locale.replaceAll('_', '-').toLowerCase();
    if (name.trim().isEmpty ||
        !(normalized == 'en' || normalized.startsWith('en-')) ||
        raw['features'].toString().contains('notInstalled')) {
      return null;
    }
    return EnglishVoice(
      name,
      locale,
      (raw['quality'] ?? '').toString().toLowerCase(),
      raw['identifier'] is String ? raw['identifier'] as String : '',
      [
        '1',
        'true',
      ].contains((raw['network_required'] ?? '').toString().toLowerCase()),
    );
  }

  int get qualityScore {
    // Browser voice listings have no quality field. Names are a hint, not a
    // guarantee of naturalness; explicit platform quality takes precedence.
    const ranks = {
      'premium': 600,
      'enhanced': 500,
      'very high': 500,
      'high': 400,
      'normal': 300,
      'default': 300,
      'low': 200,
      'very low': 100,
    };
    final explicit = ranks[quality];
    if (explicit != null) return explicit;
    final label = name.toLowerCase();
    if (label.contains('natural') || label.contains('neural')) return 450;
    if (label.startsWith('google ')) return 350;
    return 250;
  }
}

List<EnglishVoice> rankEnglishVoices(dynamic raw) {
  if (raw is! List) return [];
  final voices = raw.map(EnglishVoice.parse).whereType<EnglishVoice>().toList();
  final american = voices
      .where((v) => v.locale.replaceAll('_', '-').toLowerCase() == 'en-us')
      .toList();
  final candidates = american.isNotEmpty ? american : voices;
  candidates.sort((a, b) {
    final quality = b.qualityScore.compareTo(a.qualityScore);
    if (quality != 0) return quality;
    // Equal quality: prefer an explicitly local voice on Android.
    final network = (a.networkRequired ? 1 : 0).compareTo(
      b.networkRequired ? 1 : 0,
    );
    return network != 0 ? network : a.name.compareTo(b.name);
  });
  return candidates;
}
