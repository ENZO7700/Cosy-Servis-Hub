// ignore_for_file: avoid_print
import 'package:isar/isar.dart';

void main() async {
  print('Downloading Isar core...');
  try {
    await Isar.initializeIsarCore(download: true);
    print('Isar core downloaded successfully.');
  } catch (e) {
    print('Failed to download Isar core: $e');
  }
}
