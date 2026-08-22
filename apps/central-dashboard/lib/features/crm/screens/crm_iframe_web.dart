import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const String _crmIframeViewType = 'iframe-nexify-crm';
bool _crmIframeFactoryRegistered = false;

Widget createCrmIFrameWidget(String url) {
  if (!_crmIframeFactoryRegistered) {
    ui_web.platformViewRegistry.registerViewFactory(_crmIframeViewType, (
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
    _crmIframeFactoryRegistered = true;
  }

  return const HtmlElementView(viewType: _crmIframeViewType);
}
