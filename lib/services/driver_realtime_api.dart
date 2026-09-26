import 'dart:convert';

import 'package:driver/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Authenticated client for Tangzo realtime Cloud Functions (Redis-backed).
/// Never talks to Redis directly.
class DriverRealtimeApi {
  DriverRealtimeApi._();

  static Uri _callableUri(String functionName) {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );
  }

  static Future<bool> _callOk(String functionName, [Map<String, dynamic>? data]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      final idToken = await user.getIdToken();
      final response = await http
          .post(
            _callableUri(functionName),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'data': data ?? <String, dynamic>{}}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        print('$functionName HTTP ${response.statusCode}: ${response.body}');
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        print('$functionName callable error: ${decoded['error']}');
        return false;
      }
      final result = decoded is Map ? decoded['result'] : null;
      return result is Map && result['ok'] == true;
    } catch (e) {
      print('$functionName failed: $e');
      return false;
    }
  }

  /// Publishes this driver's live GPS to Redis via Cloud Function.
  /// Also refreshes Redis presence TTL (Phase 3).
  static Future<bool> updateDriverLocation({
    required double latitude,
    required double longitude,
    double? heading,
  }) {
    return _callOk('updateDriverLocation', {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading ?? 0.0,
    });
  }

  /// Mark driver online in Redis (TTL ~90s). Firestore isActive remains separate.
  static Future<bool> setDriverPresence() => _callOk('setDriverPresence');

  /// Mark driver offline in Redis and clear live location keys.
  static Future<bool> clearDriverPresence() => _callOk('clearDriverPresence');
}
