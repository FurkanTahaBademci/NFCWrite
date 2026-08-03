import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Tarama alt sayfasinin durumu.
enum NfcScanPhase {
  /// Henuz baslamadi.
  idle,

  /// Etiket bekleniyor.
  scanning,

  /// Etiket bulundu, islem basliyor.
  tagFound,

  /// Islem suruyor.
  working,

  /// Basarili.
  success,

  /// Basarisiz.
  failure,
}

/// Uygulamadaki **her** NFC isleminin kullandigi tarama alt sayfasi.
///
/// Tek sorumlulugu durum gostermektir; NFC ile ilgili hicbir sey bilmez.
/// Cagiran taraf durumu gunceller.
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isDismissible: false,
///   builder: (_) => NfcScanSheet(
///     phase: phase,
///     title: 'Etiketi okutun',
///     onCancel: controller.cancel,
///   ),
/// );
/// ```
class NfcScanSheet extends StatefulWidget {
  const NfcScanSheet({
    required this.phase,
    required this.title,
    this.message,
    this.progress,
    this.onCancel,
    this.onDone,
    this.hapticFeedback = true,
    super.key,
  });

  final NfcScanPhase phase;

  /// Buyuk baslik, orn. "Etiketi okutun".
  final String title;

  /// Aciklayici alt metin.
  final String? message;

  /// 0..1 arasi ilerleme. Belirsizse null.
  final double? progress;

  /// Iptal dugmesine basildiginda. null ise dugme gizlenir.
  final VoidCallback? onCancel;

  /// Sonuc ekraninda "Tamam" dugmesi.
  final VoidCallback? onDone;

  final bool hapticFeedback;

  @override
  State<NfcScanSheet> createState() => _NfcScanSheetState();
}

class _NfcScanSheetState extends State<NfcScanSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(NfcScanSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _syncAnimation();
      _fireHaptic();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.phase == NfcScanPhase.scanning ||
        widget.phase == NfcScanPhase.working;
    if (shouldAnimate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!shouldAnimate && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _fireHaptic() {
    if (!widget.hapticFeedback) return;
    switch (widget.phase) {
      case NfcScanPhase.tagFound:
        HapticFeedback.mediumImpact();
      case NfcScanPhase.success:
        HapticFeedback.lightImpact();
      case NfcScanPhase.failure:
        HapticFeedback.heavyImpact();
      case NfcScanPhase.idle:
      case NfcScanPhase.scanning:
      case NfcScanPhase.working:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = _iconAndColor(scheme);
    final isTerminal =
        widget.phase == NfcScanPhase.success ||
        widget.phase == NfcScanPhase.failure;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => CustomPaint(
                    painter: _PulsePainter(
                      progress: _pulse.value,
                      color: color,
                      active: _pulse.isAnimating,
                    ),
                    child: child,
                  ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, size: 44, color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.progress != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (isTerminal && widget.onDone != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDone,
                  child: const Text('Tamam'),
                ),
              )
            else if (widget.onCancel != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Iptal'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconAndColor(ColorScheme scheme) => switch (widget.phase) {
    NfcScanPhase.idle => (Icons.nfc_outlined, scheme.onSurfaceVariant),
    NfcScanPhase.scanning => (Icons.nfc, scheme.primary),
    NfcScanPhase.tagFound => (Icons.contactless, scheme.primary),
    NfcScanPhase.working => (Icons.sync, scheme.primary),
    NfcScanPhase.success => (
      Icons.check_circle,
      AppColors.forRisk(RiskLevel.safe, scheme.brightness),
    ),
    NfcScanPhase.failure => (Icons.error, scheme.error),
  };
}

/// Tarama sirasinda disari dogru genisleyen nabiz halkalari.
class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.progress,
    required this.color,
    required this.active,
  });

  final double progress;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = Offset(size.width / 2, size.height / 2);
    const ringCount = 3;

    for (var i = 0; i < ringCount; i++) {
      // Halkalari zamana yay ki dalga etkisi olussun.
      final phase = (progress + i / ringCount) % 1.0;
      final radius = 44 + phase * 44;
      final opacity = (1.0 - phase) * 0.35;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.active != active;
}
