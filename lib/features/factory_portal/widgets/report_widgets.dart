import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../admin/models/sales_report.dart';

/// A titled card that groups one part of a report.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// A small card with one number and an optional note below it.
class ReportMetricCard extends StatelessWidget {
  const ReportMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? noteText = note;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (noteText != null)
              Text(
                noteText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label and a value with a progress bar underneath.
class ReportBarRow extends StatelessWidget {
  const ReportBarRow({
    super.key,
    required this.label,
    required this.trailing,
    required this.fraction,
    this.color = AppColors.primary,
  });

  final String label;
  final String trailing;

  /// Bar fill, from 0 to 1.
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                trailing,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppColors.border,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// A label on the left and its value on the right.
class ReportInfoRow extends StatelessWidget {
  const ReportInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Simple bar chart of orders over time, drawn with widgets.
class OrdersBarChart extends StatelessWidget {
  const OrdersBarChart({super.key, required this.buckets});

  final List<TimelineBucket> buckets;

  static const double _barAreaHeight = 120;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? labelStyle =
        textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    final int maxOrders = buckets.fold<int>(
      0,
      (int best, TimelineBucket bucket) => math.max(best, bucket.orders),
    );
    if (maxOrders == 0) {
      return Text('No orders in this period', style: labelStyle);
    }
    final double gap = buckets.length > 14 ? 1 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _barAreaHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final TimelineBucket bucket in buckets)
                Expanded(
                  child: Tooltip(
                    message: '${bucket.label}: ${bucket.orders} order(s)',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: bucket.orders == 0
                            ? const SizedBox(
                                width: double.infinity,
                                height: 2,
                                child: ColoredBox(color: AppColors.border),
                              )
                            : FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: bucket.orders / maxOrders,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildLabels(labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text('Highest: $maxOrders order(s)', style: labelStyle),
      ],
    );
  }

  Widget _buildLabels(TextStyle? style) {
    if (buckets.length <= 8) {
      return Row(
        children: <Widget>[
          for (final TimelineBucket bucket in buckets)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(bucket.label, style: style),
              ),
            ),
        ],
      );
    }
    final TimelineBucket middle = buckets[buckets.length ~/ 2];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(buckets.first.label, style: style),
        Text(middle.label, style: style),
        Text(buckets.last.label, style: style),
      ],
    );
  }
}
