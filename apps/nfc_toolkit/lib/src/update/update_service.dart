import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'version_info.dart';

const String _defaultVersionInfoUrl = '';
const _platform = MethodChannel('nfc_toolkit/system');

final class UpdateService {
  UpdateService({http.Client? httpClient, Dio? dio, Duration? requestTimeout})
    : _httpClient = httpClient ?? http.Client(),
      _dio = dio ?? Dio(),
      _requestTimeout = requestTimeout ?? const Duration(seconds: 8);

  final http.Client _httpClient;
  final Dio _dio;
  final Duration _requestTimeout;

  void dispose() {
    _httpClient.close();
  }

  static String get versionInfoUrl => const String.fromEnvironment(
    'OTA_VERSION_URL',
    defaultValue: _defaultVersionInfoUrl,
  );

  Future<UpdateCheckResult> checkForUpdate() async {
    if (versionInfoUrl.trim().isEmpty) {
      return const UpdateCheckResult.noUpdate();
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    try {
      final response = await _httpClient
          .get(Uri.parse(versionInfoUrl))
          .timeout(_requestTimeout);

      if (response.statusCode != HttpStatus.ok) {
        return const UpdateCheckResult.noUpdate();
      }

      final versionInfo = VersionInfo.fromJson(
        decodeVersionJson(utf8.decode(response.bodyBytes)),
      );

      final hasUpdate = versionInfo.isNewerThan(
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
      );

      if (!hasUpdate) {
        return const UpdateCheckResult.noUpdate();
      }

      return UpdateCheckResult.available(
        info: versionInfo,
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
      );
    } on TimeoutException {
      return const UpdateCheckResult.noUpdate();
    } on FormatException {
      return const UpdateCheckResult.noUpdate();
    } on SocketException {
      return const UpdateCheckResult.noUpdate();
    } on http.ClientException {
      return const UpdateCheckResult.noUpdate();
    }
  }

  Future<File> downloadAndVerifyApk({
    required VersionInfo versionInfo,
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/nfc_toolkit_${versionInfo.version}_${versionInfo.buildNumber}.apk';
    final target = File(filePath);

    if (target.existsSync()) {
      target.deleteSync();
    }

    await _dio.download(
      versionInfo.apkUrl.toString(),
      filePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          onProgress(0);
          return;
        }
        onProgress(received / total);
      },
      options: Options(followRedirects: true, receiveTimeout: _requestTimeout),
    );

    final actualHash = await _computeSha256(target);
    if (actualHash != versionInfo.sha256.toLowerCase()) {
      if (target.existsSync()) {
        target.deleteSync();
      }
      throw const UpdateException(
        'Indirilen APK hash dogrulamasi basarisiz oldu.',
      );
    }

    return target;
  }

  Future<bool> canInstallUnknownApps() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final result = await _platform.invokeMethod<bool>('canInstallUnknownApps');
    return result ?? false;
  }

  Future<void> openUnknownAppsSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _platform.invokeMethod<void>('openInstallUnknownAppsSettings');
  }

  Future<OpenResult> openApkInstaller(File apkFile) {
    return OpenFilex.open(apkFile.path);
  }

  Future<String> _computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }
}

final class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.info,
    required this.currentVersion,
    required this.currentBuildNumber,
  });

  const UpdateCheckResult.noUpdate()
    : this._(info: null, currentVersion: null, currentBuildNumber: null);

  const UpdateCheckResult.available({
    required VersionInfo info,
    required String currentVersion,
    required int currentBuildNumber,
  }) : this._(
         info: info,
         currentVersion: currentVersion,
         currentBuildNumber: currentBuildNumber,
       );

  final VersionInfo? info;
  final String? currentVersion;
  final int? currentBuildNumber;

  bool get hasUpdate => info != null;
}

final class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
