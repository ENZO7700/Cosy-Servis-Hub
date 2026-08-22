// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File('lib/core/isar_models.g.dart');
  if (!await file.exists()) {
    print('Error: lib/core/isar_models.g.dart not found.');
    exit(1);
  }

  print(
    'Patching Isar generated code for Web JS integer precision compatibility dynamically...',
  );

  String content = await file.readAsString();

  // Find all integer literals with 16 or more digits
  final regExp = RegExp(r'-?\b\d{16,}\b');
  final matches = regExp.allMatches(content).map((m) => m.group(0)!).toSet();

  int count = 0;
  for (final literal in matches) {
    try {
      final val = BigInt.parse(literal);
      // Ensure it is indeed outside JS safe integer range
      final maxSafe = BigInt.from(9007199254740991);
      final minSafe = BigInt.from(-9007199254740991);
      if (val > maxSafe || val < minSafe) {
        final high = (val >> 32).toSigned(32).toInt();
        final low = (val & BigInt.from(0xFFFFFFFF)).toSigned(32).toInt();
        final replacement = '($high << 32) | ($low & 0xFFFFFFFF)';

        // Replace with digit lookarounds to avoid partial matches
        final escaped = RegExp.escape(literal);
        content = content.replaceAll(
          RegExp('(?<!\\d)$escaped(?!\\d)'),
          replacement,
        );
        print('Patched literal: $literal -> $replacement');
        count++;
      }
    } catch (e) {
      print('Failed to parse literal "$literal": $e');
    }
  }

  if (count > 0) {
    await file.writeAsString(content);
    print(
      'Successfully applied $count dynamic patches to lib/core/isar_models.g.dart.',
    );
  } else {
    print('No patches needed or code already patched.');
  }
}
