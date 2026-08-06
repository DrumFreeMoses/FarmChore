/// Builds relay URLs with optional API key authentication.
class RelayUrl {
  /// Appends the API key as a query parameter to the relay URL.
  /// If no API key is provided, the URL is returned as-is.
  static String withKey(String relayUrl, {String? apiKey}) {
    if (apiKey == null || apiKey.isEmpty) return relayUrl;
    final uri = Uri.parse(relayUrl);
    final withKey = uri.replace(
      queryParameters: {...uri.queryParameters, 'key': apiKey},
    );
    return withKey.toString();
  }
}
