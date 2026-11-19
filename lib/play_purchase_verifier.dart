import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;

class PlayPurchaseVerifier {
  PlayPurchaseVerifier(this.endpoint);

  final Uri endpoint;

  Future<String> appCheckToken() async {
    final appCheckToken = await FirebaseAppCheck.instance.getToken().timeout(
      const Duration(seconds: 10),
    );
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw StateError('App Check token is unavailable');
    }
    return appCheckToken;
  }

  Future<bool> verify(String purchaseToken) async {
    final token = await appCheckToken();
    final response = await http
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'X-Firebase-AppCheck': token,
          },
          body: jsonEncode({'purchaseToken': purchaseToken}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Purchase verification unavailable');
    }
    final result = jsonDecode(response.body);
    if (result is! Map || result['entitled'] is! bool) {
      throw const FormatException('Invalid purchase verification response');
    }
    return result['entitled'] as bool;
  }
}
