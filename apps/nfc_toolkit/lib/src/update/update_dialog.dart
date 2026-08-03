import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'update_service.dart';
import 'version_info.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required VersionInfo info,
  required String currentVersion,
  required int currentBuildNumber,
  required UpdateService service,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (dialogContext) {
      return PopScope(
        canPop: !info.forceUpdate,
        child: UpdateDialog(
          info: info,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          service: service,
        ),
      );
    },
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    required this.info,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.service,
    super.key,
  });

  final VersionInfo info;
  final String currentVersion;
  final int currentBuildNumber;
  final UpdateService service;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isBusy = false;
  double _progress = 0;
  String? _error;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.info.forceUpdate
                      ? 'Zorunlu Güncelleme'
                      : 'Güncelleme Hazır',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Mevcut: ${widget.currentVersion}+${widget.currentBuildNumber}\n'
                  'Yeni: ${widget.info.version}+${widget.info.buildNumber}',
                ),
                const SizedBox(height: 12),
                if (widget.info.releaseNotes.trim().isNotEmpty) ...[
                  const Text('Yenilikler:'),
                  const SizedBox(height: 4),
                  Text(widget.info.releaseNotes),
                  const SizedBox(height: 12),
                ],
                if (_isBusy) ...[
                  LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                  const SizedBox(height: 8),
                  Text(_status ?? 'İndiriliyor...'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.info.forceUpdate) ...[
                      TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Daha Sonra'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: _isBusy ? null : _handleUpdate,
                      child: Text(_isBusy ? 'Bekleyin...' : 'Şimdi Güncelle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isBusy = true;
      _progress = 0;
      _error = null;
        _status = 'APK indiriliyor...';
    });

    try {
      final apkFile = await widget.service.downloadAndVerifyApk(
        versionInfo: widget.info,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress;
            final ratio = (progress * 100).clamp(0, 100).round();
            _status = 'APK indiriliyor... %$ratio';
          });
        },
      );

      await _ensureInstallPermission();
      await _openInstaller(apkFile);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on UpdateException catch (error) {
      _showError(error.message);
    } on DioException {
      _showError('APK indirilemedi. Bağlantıyı kontrol edip tekrar deneyin.');
    } on FileSystemException {
      _showError('APK dosyası kaydedilemedi. Depolama alanını kontrol edin.');
    } catch (_) {
      _showError('Güncelleme sırasında beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> _ensureInstallPermission() async {
    final canInstall = await widget.service.canInstallUnknownApps();
    if (canInstall) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Kurulum izni bekleniyor...';
    });

    await widget.service.openUnknownAppsSettings();

    throw const UpdateException(
      'Bu kaynaktan kurulum izni verip tekrar Güncelle butonuna basın.',
    );
  }

  Future<void> _openInstaller(File apkFile) async {
    final result = await widget.service.openApkInstaller(apkFile);
    if (result.type != ResultType.done) {
      throw const UpdateException(
        'Android yükleyicisi açılamadı. Tekrar deneyin.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      _status = null;
      _error = message;
    });
  }
}
