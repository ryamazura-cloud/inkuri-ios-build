import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final output = Platform.environment['INKURI_DEVICE_PROOF'];
    if (output == null) throw StateError('Set INKURI_DEVICE_PROOF');
    await File('$output/$name.png').writeAsBytes(bytes);
    return true;
  },
);
