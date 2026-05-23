import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';
import 'package:pause/utils/feedback.dart';

void main() {
  group('buildFeedbackMailtoUri', () {
    test('uses mailto scheme and feedback email as recipient', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, kFeedbackEmail);
    });

    test('subject includes version and build number', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      expect(uri.queryParameters['subject'], 'Pause feedback (v1.0.0+5)');
    });

    test('body includes app version and platform identifiers', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      final body = uri.queryParameters['body']!;
      expect(body, contains('App: Pause v1.0.0+5'));
      expect(body, contains('Platform: iOS'));
    });

    test('different platform string is reflected in the body', () {
      final uri = buildFeedbackMailtoUri(
        version: '2.1.0',
        buildNumber: '42',
        platform: 'android',
      );
      expect(uri.queryParameters['subject'], 'Pause feedback (v2.1.0+42)');
      expect(uri.queryParameters['body'], contains('Platform: android'));
    });
  });
}
