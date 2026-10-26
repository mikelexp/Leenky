final _urlPattern = RegExp(
  r'''(?<![\w@])([A-Za-z][A-Za-z0-9+.-]*:(?://)?[^\s<>"'`]+)''',
);

String _stripTrailingPunctuation(String value) {
  while (value.isNotEmpty && '.,;:!?'.contains(value[value.length - 1])) {
    value = value.substring(0, value.length - 1);
  }
  for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
    while (value.endsWith(pair.$2) &&
        pair.$1.allMatches(value).length < pair.$2.allMatches(value).length) {
      value = value.substring(0, value.length - 1);
    }
  }
  return value;
}

/// Extracts unique absolute URLs in source order, excluding malformed URIs.
List<String> extractUrls(String text) {
  final urls = <String>[];
  for (final match in _urlPattern.allMatches(text)) {
    final value = _stripTrailingPunctuation(match.group(1)!);
    final uri = Uri.tryParse(value);
    if (value.isNotEmpty &&
        uri != null &&
        uri.hasScheme &&
        !urls.contains(value)) {
      urls.add(value);
    }
  }
  return urls;
}
