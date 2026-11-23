/// True when [input] is a single http(s) URL with a host.
bool isProbablyUrl(String input) {
  final s = input.trim();
  if (s.isEmpty || RegExp(r'\s').hasMatch(s)) return false;
  final uri = Uri.tryParse(s);
  if (uri == null) return false;
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}
