import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Yikici islem onayinin sonucu.
typedef DangerConfirmation = ({bool confirmed, bool takeBackup});

/// Geri alinamaz islemler icin onay diyalogu.
///
/// ADR-0005'in 3. kapisi. Dort sey yapar:
///   1. Ne olacagini duz Turkce anlatir
///   2. Risk seviyesini gorsel olarak belirtir
///   3. Hedef etiketi gosterir (kullanici yanlis etikete islem yapmasin)
///   4. Kaydirarak onay ister (kazara dokunmayi engeller)
///
/// ```dart
/// final result = await DangerDialog.show(
///   context,
///   title: 'Etiketi salt-okunur yap',
///   description: 'Bu etikete bir daha yazi yazilamayacak.',
///   risk: RiskLevel.danger,
///   targetUid: '04:A1:B2:C3',
/// );
/// if (result?.confirmed ?? false) { ... }
/// ```
class DangerDialog extends StatefulWidget {
  const DangerDialog({
    required this.title,
    required this.description,
    required this.risk,
    this.targetUid,
    this.warning,
    this.offerBackup = true,
    this.simplified = false,
    super.key,
  });

  /// Diyalogu acar. Kullanici vazgecerse null doner.
  static Future<DangerConfirmation?> show(
    BuildContext context, {
    required String title,
    required String description,
    required RiskLevel risk,
    String? targetUid,
    String? warning,
    bool offerBackup = true,
    bool simplified = false,
  }) => showDialog<DangerConfirmation>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DangerDialog(
      title: title,
      description: description,
      risk: risk,
      targetUid: targetUid,
      warning: warning,
      offerBackup: offerBackup,
      simplified: simplified,
    ),
  );

  final String title;
  final String description;
  final RiskLevel risk;

  /// Islemin uygulanacagi etiketin UID'si.
  final String? targetUid;

  /// Ek uyari — ne ters gidebilir.
  final String? warning;

  /// "Once yedek al" secenegi gosterilsin mi?
  final bool offerBackup;

  /// Uzman modunda kaydirma yerine tek dokunus.
  ///
  /// Uyari metni ve hedef UID **her durumda** gosterilir; yalnizca onay
  /// hareketi sadelesir.
  final bool simplified;

  @override
  State<DangerDialog> createState() => _DangerDialogState();
}

class _DangerDialogState extends State<DangerDialog> {
  bool _takeBackup = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final riskColor = AppColors.forRisk(widget.risk, scheme.brightness);
    final irreversible = widget.risk == RiskLevel.danger;

    return AlertDialog(
      icon: Icon(widget.risk.icon, color: riskColor, size: 32),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (irreversible) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: riskColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: riskColor),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'BU ISLEM GERI ALINAMAZ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          Text(widget.description, style: theme.textTheme.bodyMedium),

          if (widget.warning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.warning!,
              style: theme.textTheme.bodySmall?.copyWith(color: riskColor),
            ),
          ],

          if (widget.targetUid != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.nfc, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.targetUid!,
                      style: AppTypography.monospace(context, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.offerBackup) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              value: _takeBackup,
              onChanged: (value) => setState(() => _takeBackup = value),
              contentPadding: EdgeInsets.zero,
              title: Text('Once yedek al', style: theme.textTheme.bodyMedium),
              subtitle: Text(
                'Bellek dokumu gecmise kaydedilir',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          if (widget.simplified)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: riskColor),
              onPressed: _confirm,
              child: const Text('Onayla'),
            )
          else
            SlideToConfirm(color: riskColor, onConfirmed: _confirm),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
      ],
    );
  }

  void _confirm() =>
      Navigator.of(context).pop((confirmed: true, takeBackup: _takeBackup));
}

/// Kaydirarak onay bileseni — kazara dokunmayi engeller.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    required this.onConfirmed,
    required this.color,
    this.label = 'Onaylamak icin kaydirin',
    super.key,
  });

  final VoidCallback onConfirmed;
  final Color color;
  final String label;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  static const double _trackHeight = 52;
  static const double _thumbSize = 44;

  double _dragPosition = 0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _thumbSize - 8;

        return Semantics(
          button: true,
          label: widget.label,
          onTap: _complete,
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - (_dragPosition / maxDrag)).clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: widget.color,
                    ),
                  ),
                ),
                Positioned(
                  left: 4 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_confirmed) return;
                      setState(() {
                        _dragPosition = (_dragPosition + details.delta.dx)
                            .clamp(0.0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      if (_confirmed) return;
                      // Yolun %90'i asilirsa onay sayilir.
                      if (_dragPosition >= maxDrag * 0.9) {
                        _complete();
                      } else {
                        setState(() => _dragPosition = 0);
                      }
                    },
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _complete() {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    unawaited(HapticFeedback.heavyImpact());
    widget.onConfirmed();
  }
}
