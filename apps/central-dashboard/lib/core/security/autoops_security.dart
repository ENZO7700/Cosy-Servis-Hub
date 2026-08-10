/// Dart port of `src/lib/security.ts`.
///
/// The TS version uses `zod` for schema validation; Flutter forms typically
/// validate with a plain `String? Function(String?)` validator instead, so
/// [validateEmail] follows that convention rather than pulling in a schema
/// library for a single field.
library;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const String emailErrorMessage =
    'Zadaj platný email. Robot má síce trpezlivosť, SMTP server už menej.';

/// Returns null when valid, otherwise the sk-SK error message — drop this
/// straight into a `TextFormField(validator: validateEmail)`.
String? validateEmail(String? value) {
  if (value == null || !_emailPattern.hasMatch(value)) {
    return emailErrorMessage;
  }
  return null;
}

final RegExp _dangerousTagChars = RegExp('[<>]');
final RegExp _secretWords =
    RegExp(r'\b(api[_-]?key|secret|token|password)\b', caseSensitive: false);

String sanitizePrompt(String prompt) {
  var cleaned = prompt.replaceAll(_dangerousTagChars, '');
  cleaned = cleaned.replaceAll(_secretWords, '[redacted]');
  cleaned = cleaned.trim();
  return cleaned.length > 2000 ? cleaned.substring(0, 2000) : cleaned;
}

final RegExp _riskyIntent = RegExp(
  r'refund|vrát|vrat|dobropis|zľava|zlava|delete|vymaž|storno|cancel|angry|nahnevan',
  caseSensitive: false,
);

bool requiresHumanApproval(String prompt) => _riskyIntent.hasMatch(prompt);
