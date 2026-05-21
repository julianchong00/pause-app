import 'package:pause/constants.dart';

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
