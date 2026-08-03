import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Etiket + deger satiri. Uzun basinca degeri panoya kopyalar.
class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.monospace = false,
    this.copyable = true,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Hex/UID gibi degerlerde tek aralikli yazi tipi kullan.
  final bool monospace;

  final bool copyable;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onLongPress: copyable
          ? () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$label kopyalandi')));
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SelectableText(
                    value,
                    style: monospace
                        ? AppTypography.monospace(context, fontSize: 14)
                        : theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Teknoloji ya da durum rozeti.
class TagBadge extends StatelessWidget {
  const TagBadge({
    required this.label,
    this.icon,
    this.risk,
    this.selected = false,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Verilirse rozet risk rengini alir.
  final RiskLevel? risk;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = risk == null
        ? (selected ? scheme.primary : scheme.onSurfaceVariant)
        : AppColors.forRisk(risk!, scheme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kullanilan / toplam kapasite gostergesi.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    required this.used,
    required this.total,
    this.label,
    super.key,
  });

  final int used;
  final int total;
  final String? label;

  bool get _overflows => used > total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final color = _overflows
        ? scheme.error
        : ratio > 0.85
        ? AppColors.forRisk(RiskLevel.warning, scheme.brightness)
        : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? 'Kapasite',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$used / $total byte',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        if (_overflows) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Icerik etikete sigmiyor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Arac izgarasindaki kart.
class ToolCard extends StatelessWidget {
  const ToolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.risk,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final RiskLevel risk;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final riskColor = AppColors.forRisk(risk, scheme.brightness);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(icon, size: 20, color: riskColor),
                    ),
                    const Spacer(),
                    if (risk == RiskLevel.danger)
                      Icon(risk.icon, size: 16, color: riskColor),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bos durum ekrani.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste bolum basligi.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
