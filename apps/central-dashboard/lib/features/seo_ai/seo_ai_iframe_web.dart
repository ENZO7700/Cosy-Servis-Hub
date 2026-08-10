import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const String _seoIframeViewType = 'iframe-seo-ai';
bool _seoIframeFactoryRegistered = false;

Widget createIFrameWidget(String url) {
  if (!_seoIframeFactoryRegistered) {
    ui_web.platformViewRegistry.registerViewFactory(_seoIframeViewType, (
      int viewId,
    ) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement
            ..src = url
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.backgroundColor = 'transparent';
      return iframe;
    });
    _seoIframeFactoryRegistered = true;
  }

  return const HtmlElementView(viewType: _seoIframeViewType);
}
