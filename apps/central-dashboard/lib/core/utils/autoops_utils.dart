/// Dart port of `src/lib/utils.ts`.
library;

import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String formatCurrency(num value, {String currency = 'EUR'}) {
  final formatter = NumberFormat.currency(
    locale: 'sk_SK',
    name: currency,
    decimalDigits: 0,
  );
  return formatter.format(value);
}

String formatNumber(num value) {
  return NumberFormat.decimalPattern('sk_SK').format(value);
}

/// Mirrors `formatRelativeTime` (Intl.RelativeTimeFormat 'sk-SK', numeric: 'auto').
String formatRelativeTime(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diffSeconds = value.difference(reference).inSeconds;
  final abs = diffSeconds.abs();

  if (abs < 60) return _relative(diffSeconds, 'sekundou', 'sekundami', 'o sekundu');
  if (abs < 3600) {
    final minutes = (diffSeconds / 60).round();
    return _relative(minutes, 'minútou', 'minútami', 'o minútu');
  }
  if (abs < 86400) {
    final hours = (diffSeconds / 3600).round();
    return _relative(hours, 'hodinou', 'hodinami', 'o hodinu');
  }
  final days = (diffSeconds / 86400).round();
  return _relative(days, 'dňom', 'dňami', 'o deň');
}

String _relative(int amount, String pastSuffix, String pastSuffixPlural, String future) {
  if (amount == 0) return 'teraz';
  if (amount < 0) {
    final n = amount.abs();
    return 'pred $n ${n == 1 ? pastSuffix : pastSuffixPlural}';
  }
  return future;
}

num clamp(num value, num min, num max) {
  return value < min ? min : (value > max ? max : value);
}

String uid([String prefix = 'id']) {
  return '${prefix}_${_uuid.v4()}';
}

T safeJsonParse<T>(String? value, T fallback) {
  if (value == null) return fallback;
  try {
    return jsonDecode(value) as T;
  } catch (_) {
    return fallback;
  }
}

String randomToken([int length = 8]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}
