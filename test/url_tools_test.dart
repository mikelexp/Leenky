import 'package:flutter_test/flutter_test.dart';
import 'package:leenky/url_tools.dart';

void main() {
  group('extractUrls', () {
    test('extracts unique URLs in source order and strips punctuation', () {
      expect(
        extractUrls(
          'Open https://example.com/a, then file:///tmp/report.txt and custom:item.',
        ),
        ['https://example.com/a', 'file:///tmp/report.txt', 'custom:item'],
      );
    });

    test('ignores text and removes repeated URLs', () {
      expect(extractUrls('No URL here'), isEmpty);
      expect(extractUrls('https://a.test https://a.test'), ['https://a.test']);
    });

    test('preserves balanced URL punctuation', () {
      expect(extractUrls('See https://example.com/a_(b).'), [
        'https://example.com/a_(b)',
      ]);
    });
  });
}
