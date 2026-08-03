import 'dart:convert';

/// Uzaktaki surum bilgisini temsil eder.
final class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.forceUpdate,
    required this.sha256,
    required this.releaseNotes,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final buildNumber = json['buildNumber'];
    final apkUrl = json['apkUrl'];
    final forceUpdate = json['forceUpdate'];
    final sha256 = json['sha256'];
    final releaseNotes = json['releaseNotes'];

    if (version is! String || version.trim().isEmpty) {
      throw const FormatException('version zorunludur');
    }
    if (buildNumber is! int || buildNumber < 1) {
      throw const FormatException('buildNumber pozitif int olmalidir');
    }
    if (apkUrl is! String || apkUrl.trim().isEmpty) {
      throw const FormatException('apkUrl zorunludur');
    }
    if (forceUpdate is! bool) {
      throw const FormatException('forceUpdate bool olmalidir');
    }
    if (sha256 is! String || sha256.trim().isEmpty) {
      throw const FormatException('sha256 zorunludur');
    }
    if (releaseNotes is! String) {
      throw const FormatException('releaseNotes string olmalidir');
    }

    final parsedUri = Uri.tryParse(apkUrl);
    if (parsedUri == null || !parsedUri.hasScheme) {
      throw const FormatException('apkUrl gecerli bir URI olmali');
    }

    return VersionInfo(
      version: version,
      buildNumber: buildNumber,
      apkUrl: parsedUri,
      forceUpdate: forceUpdate,
      sha256: sha256.toLowerCase(),
      releaseNotes: releaseNotes,
    );
  }

  final String version;
  final int buildNumber;
  final Uri apkUrl;
  final bool forceUpdate;
  final String sha256;
  final String releaseNotes;

  /// Uzak surumun mevcut surumden yeni olup olmadigini hesaplar.
  bool isNewerThan({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    final semanticCompare = _compareSemanticVersions(version, currentVersion);
    if (semanticCompare > 0) {
      return true;
    }
    if (semanticCompare < 0) {
      return false;
    }

    return buildNumber > currentBuildNumber;
  }
}

Map<String, dynamic> decodeVersionJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('version.json nesne olmali');
  }
  return decoded;
}

int _compareSemanticVersions(String a, String b) {
  final aParts = _normalizeVersion(a);
  final bParts = _normalizeVersion(b);

  final length = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var index = 0; index < length; index += 1) {
    final left = index < aParts.length ? aParts[index] : 0;
    final right = index < bParts.length ? bParts[index] : 0;

    if (left > right) {
      return 1;
    }
    if (left < right) {
      return -1;
    }
  }

  return 0;
}

List<int> _normalizeVersion(String raw) {
  return raw
      .trim()
      .split('.')
      .map((segment) {
        final clean = segment.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.isEmpty) {
          return 0;
        }
        return int.tryParse(clean) ?? 0;
      })
      .toList(growable: false);
}
