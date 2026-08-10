import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

void openExternalUrl(String url) {
  if (url.isNotEmpty) {
    web.window.open(url, '_blank');
  }
}

class AnythingLLMIFrameWidget extends StatefulWidget {
  final String url;
  const AnythingLLMIFrameWidget({super.key, required this.url});

  @override
  State<AnythingLLMIFrameWidget> createState() => _AnythingLLMIFrameWidgetState();
}

class _AnythingLLMIFrameWidgetState extends State<AnythingLLMIFrameWidget> {
  late String _viewType;
  web.HTMLIFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _registerFactory();
  }

  @override
  void didUpdateWidget(AnythingLLMIFrameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      if (_iframeElement != null) {
        _iframeElement!.src = widget.url;
      } else {
        _registerFactory();
      }
    }
  }

  void _registerFactory() {
    _viewType = 'iframe-anything-llm-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..allow = 'microphone; camera; clipboard-write; autoplay';
      _iframeElement = iframe;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

Widget createAnythingLLMIFrameWidget(String url, {Key? key}) {
  return AnythingLLMIFrameWidget(key: key, url: url);
}
