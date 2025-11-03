import 'dart:math';

int compareVersions(String a, String b) {
  final aParts = a.split('.');
  final bParts = b.split('.');
  final length = max(aParts.length, bParts.length);

  for (var i = 0; i < length; i++) {
    final aValue = i < aParts.length ? int.tryParse(aParts[i]) ?? 0 : 0;
    final bValue = i < bParts.length ? int.tryParse(bParts[i]) ?? 0 : 0;
    if (aValue != bValue) {
      return aValue.compareTo(bValue);
    }
  }
  return 0;
}

bool isVersionGreater(String a, String b) => compareVersions(a, b) > 0;
