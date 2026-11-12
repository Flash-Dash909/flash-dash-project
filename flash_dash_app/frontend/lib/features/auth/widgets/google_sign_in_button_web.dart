import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

Widget buildGoogleSignInButton({
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: 54,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(120, 400).toDouble()
            : 400.0;
        final plugin = GoogleSignInPlatform.instance;
        if (plugin is! web.GoogleSignInPlugin) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: IgnorePointer(
            ignoring: isLoading,
            child: Opacity(
              opacity: isLoading ? 0.55 : 1,
              child: plugin.renderButton(
                configuration: web.GSIButtonConfiguration(
                  type: web.GSIButtonType.standard,
                  theme: web.GSIButtonTheme.outline,
                  size: web.GSIButtonSize.large,
                  text: web.GSIButtonText.continueWith,
                  shape: web.GSIButtonShape.rectangular,
                  minimumWidth: width,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
