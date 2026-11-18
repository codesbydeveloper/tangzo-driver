import 'dart:convert';

import 'package:driver/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const bool kUseSettingsCache = true;
const Duration kSettingsCfTimeout = Duration(seconds: 20);
const Duration kSettingsCfRaceTimeout = Duration(milliseconds: 2500);

class SettingsApi {
  SettingsApi._();

  static const _prefsKey = 'settings_bundle_driver_v2';
  static const _prefsVersionKey = 'settings_bundle_driver_version_v2';

  static Future<SettingsBundleResult?>? _prefetchFuture;
  static int? _appliedVersion;

  static Uri _callableUri(String functionName) {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );
  }

  static void prefetch() {
    if (!kUseSettingsCache) return;
    _prefetchFuture ??= fetchFromCloudFunction().then((bundle) async {
      if (bundle != null) await writePrefs(bundle);
      return bundle;
    });
  }

  static Future<SettingsBundleResult?> getBundle({bool forceRefresh = false}) async {
    if (!kUseSettingsCache) return null;
    if (!forceRefresh) {
      final cached = await readPrefs();
      if (cached != null) return cached;
    }
    return null;
  }

  static Future<SettingsBundleResult?> raceBundle({
    required Future<Map<String, Map<String, dynamic>?>> Function()
        firestoreLoader,
  }) async {
    if (!kUseSettingsCache) {
      final docs = await firestoreLoader();
      return SettingsBundleResult(
        docs: docs,
        version: DateTime.now().millisecondsSinceEpoch,
        source: 'firestore',
      );
    }

    final prefs = await readPrefs();
    if (prefs != null && prefs.docs.isNotEmpty) return prefs;

    prefetch();
    final cfFuture = (_prefetchFuture ?? fetchFromCloudFunction()).timeout(
      kSettingsCfRaceTimeout,
      onTimeout: () => null,
    );
    final fsFuture = firestoreLoader().then(
      (docs) => SettingsBundleResult(
        docs: docs,
        version: DateTime.now().millisecondsSinceEpoch,
        source: 'firestore',
      ),
    );

    final first = await Future.any<SettingsBundleResult?>([cfFuture, fsFuture]);
    if (first != null && first.docs.isNotEmpty) {
      await writePrefs(first);
      // ignore: unawaited_futures
      cfFuture.then((cf) async {
        if (cf != null && cf.docs.isNotEmpty) await writePrefs(cf);
      });
      return first;
    }
    final fallback = await fsFuture;
    await writePrefs(fallback);
    return fallback;
  }

  static Future<void> refreshInBackground({
    void Function(SettingsBundleResult bundle)? onFresh,
  }) async {
    if (!kUseSettingsCache) return;
    try {
      final bundle = await fetchFromCloudFunction();
      if (bundle == null) return;
      await writePrefs(bundle);
      if (bundle.version > (_appliedVersion ?? 0)) {
        onFresh?.call(bundle);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SettingsApi] background refresh failed: $e');
    }
  }

  static void markApplied(SettingsBundleResult bundle) {
    _appliedVersion = bundle.version;
  }

  static Future<SettingsBundleResult?> fetchFromCloudFunction({
    bool forceRefresh = false,
  }) async {
    try {
      final response = await http
          .post(
            _callableUri('getSettingsBundle'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': {'app': 'driver', 'forceRefresh': forceRefresh},
            }),
          )
          .timeout(kSettingsCfTimeout);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['error'] != null ||
          response.statusCode != 200) {
        return null;
      }
      final result = decoded['result'];
      if (result is! Map || result['ok'] != true) return null;
      final docsRaw = result['docs'];
      final docs = <String, Map<String, dynamic>?>{};
      if (docsRaw is Map) {
        docsRaw.forEach((key, value) {
          docs[key.toString()] =
              value is Map ? Map<String, dynamic>.from(value) : null;
        });
      }
      return SettingsBundleResult(
        docs: docs,
        version: result['version'] is int
            ? result['version'] as int
            : DateTime.now().millisecondsSinceEpoch,
        source: result['source']?.toString() ?? 'unknown',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SettingsApi] CF fetch failed: $e');
      return null;
    }
  }

  static Future<SettingsBundleResult?> readPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final version = prefs.getInt(_prefsVersionKey);
      if (raw == null || version == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final docs = <String, Map<String, dynamic>?>{};
      decoded.forEach((key, value) {
        docs[key.toString()] =
            value is Map ? Map<String, dynamic>.from(value) : null;
      });
      return SettingsBundleResult(docs: docs, version: version, source: 'prefs');
    } catch (_) {
      return null;
    }
  }

  static Future<void> writePrefs(SettingsBundleResult bundle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(bundle.docs));
      await prefs.setInt(_prefsVersionKey, bundle.version);
    } catch (_) {}
  }
}

class SettingsBundleResult {
  final Map<String, Map<String, dynamic>?> docs;
  final int version;
  final String source;
  const SettingsBundleResult({
    required this.docs,
    required this.version,
    required this.source,
  });
  Map<String, dynamic>? doc(String id) => docs[id];
}
