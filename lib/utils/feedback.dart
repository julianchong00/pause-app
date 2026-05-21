import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pause/constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pure helper that builds the `mailto:` URI for the Settings feedback button.
///
/// Kept pure (no platform calls) so it can be unit-tested without a Flutter
/// widget tree.
///
/// Uses `Uri.encodeComponent` (which encodes space as `%20`) rather than
/// `Uri.queryParameters` (which encodes space as `+`). Per RFC 6068, mail
/// clients treat `+` literally in subject/body, so form-style encoding would
/// cause subjects to render as `Pause+feedback` instead of `Pause feedback`.
Uri buildFeedbackMailtoUri({
  required String version,
  required String buildNumber,
  required String platform,
}) {
  final stamp = 'v$version+$buildNumber';
  final subject = Uri.encodeComponent('Pause feedback ($stamp)');
  final body = Uri.encodeComponent(
    '\n\n---\nApp: Pause $stamp\nPlatform: $platform\n',
  );
  return Uri.parse('mailto:$kFeedbackEmail?subject=$subject&body=$body');
}

/// Launches the user's email client with a pre-filled feedback message.
///
/// On failure (no email app installed, launch denied, or any thrown
/// exception), copies the feedback address to the clipboard and shows a
/// snackbar so the user can fall back to webmail.
Future<void> sendFeedback(BuildContext context) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final uri = buildFeedbackMailtoUri(
      version: info.version,
      buildNumber: info.buildNumber,
      platform: defaultTargetPlatform.name,
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      await _showFallback(context);
    }
  } catch (error, stack) {
    debugPrint('sendFeedback failed: $error\n$stack');
    if (context.mounted) {
      await _showFallback(context);
    }
  }
}

Future<void> _showFallback(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: kFeedbackEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No email app found. Address copied to clipboard.'),
    ),
  );
}
