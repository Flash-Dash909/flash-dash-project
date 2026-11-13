// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class PresentationFullscreen {
  static Future<void> enter() async {
    if (html.document.fullscreenElement != null) return;
    await html.document.documentElement?.requestFullscreen();
  }

  static Future<void> exit() async {
    if (html.document.fullscreenElement == null) return;
    html.document.exitFullscreen();
  }
}
