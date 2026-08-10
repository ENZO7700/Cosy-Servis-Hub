import 'package:flutter/material.dart';

void openExternalUrl(String url) {}

Widget createAnythingLLMIFrameWidget(String url, {Key? key}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'AnythingLLM Frame ($url) je dostupný vo Flutter Web.',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    ),
  );
}
