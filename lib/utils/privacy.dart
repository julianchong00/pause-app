import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:pause/constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the hosted privacy policy in the system browser.
///
/// On failure (no browser, launch denied, or any thrown exception), copies
/// the URL to the clipboard and shows a snackbar so the user can paste it.
Future<void> openPrivacyPolicy(BuildContext context) async {
  try {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      await _showFallback(context);
    }
  } catch (error, stack) {
    debugPrint('openPrivacyPolicy failed: $error\n$stack');
    if (context.mounted) {
      await _showFallback(context);
    }
  }
}

Future<void> _showFallback(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: kPrivacyPolicyUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open browser. Link copied to clipboard.'),
    ),
  );
}
