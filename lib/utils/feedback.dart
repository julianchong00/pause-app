import 'package:pause/constants.dart';

/// Pure helper that builds the `mailto:` URI for the Settings feedback button.
///
/// Kept pure (no platform calls) so it can be unit-tested without a Flutter
/// widget tree.
Uri buildFeedbackMailtoUri({
  required String version,
  required String buildNumber,
  required String platform,
}) {
  final stamp = 'v$version+$buildNumber';
  return Uri(
    scheme: 'mailto',
    path: kFeedbackEmail,
    queryParameters: {
      'subject': 'Pause feedback ($stamp)',
      'body': '\n\n---\nApp: Pause $stamp\nPlatform: $platform\n',
    },
  );
}
