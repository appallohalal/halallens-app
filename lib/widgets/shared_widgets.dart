import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../models/halal_result.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';

/// A reusable card widget for displaying halal status with gradient styling.
class StatusCard extends StatelessWidget {
  final HalalStatus status;
  final String? subtitle;
  final bool isCompact;

  const StatusCard({
    super.key,
    required this.status,
    this.subtitle,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (status == HalalStatus.halal ||
              status == HalalStatus.haram ||
              status == HalalStatus.doubtful)
            Container(
              height: isCompact ? 80 : 120,
              width: isCompact ? 80 : 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: status == HalalStatus.halal
                  ? Image.asset(
                      'assets/halal_logo.png',
                      errorBuilder: (context, error, stackTrace) => Text(
                        status.emoji,
                        style: AppFonts.primary(
                          context,
                          fontSize: isCompact ? 48 : 64,
                        ),
                      ),
                    )
                  : status == HalalStatus.haram
                  ? Image.asset(
                      'assets/haram_logo.png',
                      errorBuilder: (context, error, stackTrace) => Text(
                        status.emoji,
                        style: AppFonts.primary(
                          context,
                          fontSize: isCompact ? 48 : 64,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/doubtful_logo.png',
                      errorBuilder: (context, error, stackTrace) => Text(
                        status.emoji,
                        style: AppFonts.primary(
                          context,
                          fontSize: isCompact ? 48 : 64,
                        ),
                      ),
                    ),
            )
          else
            Text(
              status.emoji,
              style: AppFonts.primary(context, fontSize: isCompact ? 48 : 64),
            ),
          SizedBox(height: isCompact ? 16 : 24),
          Text(
            status.labelKey.tr().toUpperCase(),
            style: AppFonts.primary(
              context,
              color: Colors.white,
              fontSize: isCompact ? 22 : 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppFonts.primary(
                context,
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case HalalStatus.halal:
        return AppTheme.halalSolid;
      case HalalStatus.haram:
        return AppTheme.haramSolid;
      case HalalStatus.doubtful:
        return AppTheme.doubtfulSolid;
    }
  }
}

/// A reusable tile for displaying a single ingredient's halal status.
class IngredientTile extends StatelessWidget {
  final IngredientResult result;

  const IngredientTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getBorderColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                _getStatusIcon(result.status),
                color: _getBorderColor(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(result.ingredient),
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.reason,
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getBorderColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.status.labelKey.tr(),
              style: AppFonts.primary(
                context,
                color: _getBorderColor(),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(HalalStatus status) {
    switch (status) {
      case HalalStatus.halal:
        return IconlyBold.tick_square;
      case HalalStatus.haram:
        return IconlyBold.close_square;
      case HalalStatus.doubtful:
        return IconlyBold.info_square;
    }
  }

  Color _getBorderColor() {
    switch (result.status) {
      case HalalStatus.halal:
        return AppTheme.halalGreen;
      case HalalStatus.haram:
        return AppTheme.haramRed;
      case HalalStatus.doubtful:
        return AppTheme.doubtfulAmber.withAlpha(50);
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Glassmorphic info card widget.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context), width: 1),
      ),
      child: child,
    );
  }
}

/// Animated shimmer loading placeholder.
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppTheme.getBorderColor(context).withValues(alpha: 0.3),
      ),
    );
  }
}

class AppDialogs {
  /// Displays a customized confirmation dialog.
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String confirmText,
    required IconData icon,
    Color iconColor = AppTheme.haramRed,
    Color confirmColor = AppTheme.haramRed,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.getBorderColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: AppTheme.getBorderColor(context),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'general.cancel'.tr(),
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: AppFonts.primary(
                          context,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
