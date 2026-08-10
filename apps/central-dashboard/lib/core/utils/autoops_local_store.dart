/// Dart port of the caching half of `src/api/client.ts`
/// (`sleep`, `isOffline`, `saveSnapshot`, `readSnapshot`, `cachedMock`).
///
/// `localStorage` -> `SharedPreferences`; `navigator.onLine` -> `connectivity_plus`
/// is intentionally NOT added as a dependency here to keep this file
/// drop-in-able — inject an `isOffline` check from whatever connectivity
/// package the app already uses, or leave the default (always online).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const Duration snapshotTtl = Duration(days: 7);

Future<void> sleep([Duration duration = const Duration(milliseconds: 420)]) {
  return Future.delayed(duration);
}

/// Wire up to your connectivity solution of choice; defaults to "always
/// online" so `cachedMock` behaves like a pure remote-refresh cache until
/// you plug in real detection (e.g. `connectivity_plus`).
bool Function() isOffline = () => false;

class _Snapshot<T> {
  _Snapshot(this.value, this.savedAtMs);

  final T value;
  final int savedAtMs;

  Map<String, dynamic> toJson(Object? Function(T) encode) => {
        'value': encode(value),
        'savedAt': savedAtMs,
      };
}

Future<void> saveSnapshot<T>(
  String key,
  T value, {
  required Object? Function(T value) encode,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final snapshot = _Snapshot<T>(value, DateTime.now().millisecondsSinceEpoch);
  await prefs.setString(key, jsonEncode(snapshot.toJson(encode)));
}

Future<T> readSnapshot<T>(
  String key,
  T fallback, {
  required T Function(Object? json) decode,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(key);
  if (raw == null) return fallback;

  try {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final savedAt = parsed['savedAt'] as int;
    if (DateTime.now().millisecondsSinceEpoch - savedAt > snapshotTtl.inMilliseconds) {
      return fallback;
    }
    return decode(parsed['value']);
  } catch (_) {
    return fallback;
  }
}

/// Direct port of `cachedMock<T>(key, producer, delay)`: serves the cached
/// snapshot when offline, otherwise "calls the backend" (here: runs
/// [producer], same as the web app's mock data functions) and refreshes
/// the snapshot.
Future<T> cachedMock<T>(
  String key,
  Future<T> Function() producer, {
  required Object? Function(T value) encode,
  required T Function(Object? json) decode,
  required T fallback,
  Duration delay = const Duration(milliseconds: 420),
}) async {
  final cached = await readSnapshot<T?>(key, null, decode: (json) => json == null ? null : decode(json));
  if (isOffline() && cached != null) return cached;

  await sleep(delay);
  final value = await producer();
  await saveSnapshot(key, value, encode: encode);
  return value;
}
