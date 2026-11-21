import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/halal_result.dart';
import '../providers/scanner_provider.dart';
import '../services/ad_service.dart';
import '../services/product_community_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_native_widget.dart';
import '../widgets/geo_ad_banner_widget.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/unknown_product_view.dart';
import 'package:iconly/iconly.dart';
import '../models/history_item.dart';
import '../models/product.dart';
import '../services/saved_product_service.dart';

import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            if (!provider.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        AdService.instance.showInterstitial(
                          onClosed: () {
                            if (!context.mounted) return;
                            provider.reset();
                            Navigator.pop(context);
                          },
                        );
                      },
                      icon: Icon(
                        IconlyLight.arrow_left,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'result.title'.tr(),
                        textAlign: TextAlign.center,
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (provider.product != null &&
                        provider.halalResult != null)
                      _SaveButton(
                        product: provider.product!,
                        halalResult: provider.halalResult!,
                      )
                    else
                      const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

            Expanded(child: _buildContent(context, provider)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScannerProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingState(context);
    }

    if (provider.errorMessage != null) {
      return _buildErrorState(context, provider);
    }

    if (provider.product != null && provider.halalResult != null) {
      return _buildResultState(context, provider);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryBlue.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  IconlyBold.shield_done,
                  color: AppTheme.primaryBlue,
                  size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            'result.analyzing_title'.tr(),
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'result.analyzing_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ScannerProvider provider) {
    final barcode = provider.lastScannedBarcode;
    final isBarcodeNotFound = barcode != null && barcode.isNotEmpty;

    if (isBarcodeNotFound) {
      return UnknownProductView(
        barcode: barcode,
        onScanAnother: () {
          AdService.instance.showInterstitial(
            onClosed: () {
              if (!context.mounted) return;
              provider.reset();
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
          );
        },
      );
    }

    // Default error state (e.g. network failure)
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.haramRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconlyLight.danger,
                size: 40,
                color: AppTheme.haramRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'result.not_found'.tr(),
              style: AppFonts.primary(
                context,
                color: AppTheme.getTextPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'errors.generic_error'.tr(),
              textAlign: TextAlign.center,
              style: AppFonts.primary(
                context,
                color: AppTheme.getTextSecondary(context),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  AdService.instance.showInterstitial(
                    onClosed: () {
                      if (!context.mounted) return;
                      provider.reset();
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  );
                },
                icon: const Icon(IconlyLight.scan),
                label: Text('result.scan_again'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState(BuildContext context, ScannerProvider provider) {
    final product = provider.product!;
    final result = provider.halalResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          StatusCard(
            status: result.overallStatus,
            subtitle: _buildBannerSubtitle(product, result),
          ),
          const SizedBox(height: 14),

          // Halal Certification & Official Verification Banner
          _buildCertificationSection(context, product, result),

          // Dynamic User-Facing Alerts from Back-Office (localized)
          if (product.alertsForLocale(context.locale.languageCode).isNotEmpty) ...[
            _buildUserAlertsSection(
              context,
              product.alertsForLocale(context.locale.languageCode),
            ),
            const SizedBox(height: 14),
          ],

          // Product info card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (product.imageUrl != null &&
                        product.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imageUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const ShimmerLoading(
                              width: 70,
                              height: 70,
                              borderRadius: 12,
                            );
                          },
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppTheme.getBorderColor(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              IconlyLight.image,
                              color: AppTheme.getTextMuted(context),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.getBorderColor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          IconlyLight.image,
                          color: AppTheme.getTextMuted(context),
                          size: 28,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedProductName(product.name),
                            style: AppFonts.primary(
                              context,
                              color: AppTheme.getTextPrimary(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.brands != null &&
                              product.brands!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.brands!,
                              style: AppFonts.secondary(
                                context,
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (product.quantity != null &&
                              product.quantity!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              product.quantity!,
                              style: AppFonts.secondary(
                                context,
                                color: AppTheme.getTextMuted(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (product.barcode.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getBorderColor(
                        context,
                      ).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconlyLight.document,
                          size: 14,
                          color: AppTheme.getTextMuted(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${'result.barcode_prefix'.tr()}${product.barcode}',
                          style: AppFonts.secondary(
                            context,
                            color: AppTheme.getTextMuted(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // User Actions: Signaler une erreur & Partager
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReportErrorSheet(context, product),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    side: BorderSide(color: AppTheme.getBorderColor(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: AppTheme.getTextPrimary(context),
                  ),
                  label: Text(
                    'result.report_error'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.primary(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareProduct(context, product, result),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    side: BorderSide(color: AppTheme.getBorderColor(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppTheme.getTextPrimary(context),
                  ),
                  label: Text(
                    'result.share'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.primary(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // AI/Local Analysis Badge (Ultra-Minimal Case - Text Only)
          Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'result.verified_by'.tr(),
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextMuted(
                      context,
                    ).withValues(alpha: 0.5),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Analysis summary
          _buildSummarySection(context, result),
          const SizedBox(height: 20),

          // Geo-Targeted Local Partner Banner (shown if user is within campaign radius)
          const GeoAdBannerWidget(margin: EdgeInsets.only(bottom: 16)),

          // Native Ad
          const AdNativeWidget(),
          const SizedBox(height: 16),

          // Ingredient details
          Text(
            'result.detailed_breakdown'.tr(),
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          if (result.ingredientResults.isEmpty)
            GlassCard(
              child: Row(
                children: [
                  Icon(
                    IconlyLight.info_circle,
                    color: AppTheme.getTextSecondary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'result.no_ingredients'.tr(),
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...result.ingredientResults.map((ir) => IngredientTile(result: ir)),

          const SizedBox(height: 24),

          // Scan again button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                AdService.instance.showInterstitial(
                  onClosed: () {
                    if (!context.mounted) return;
                    provider.reset();
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                );
              },
              icon: const Icon(IconlyLight.scan),
              label: Text('result.scan_another'.tr()),
            ),
          ),
          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.getDoubtfulBgColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.getDoubtfulBorderColor(context),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  IconlyLight.info_circle,
                  color: AppTheme.getDoubtfulTextColor(context),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'result.disclaimer'.tr(),
                    style: AppFonts.primary(
                      context,
                      color: AppTheme.getDoubtfulTextColor(context),
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, HalalResult result) {
    return Row(
      children: [
        _buildSummaryChip(
          context,
          '${result.haramIngredients.length}',
          'result.haram_label'.tr(),
          AppTheme.getHaramTextColor(context),
          AppTheme.getHaramBgColor(context),
          AppTheme.getHaramBorderColor(context),
        ),
        const SizedBox(width: 8),
        _buildSummaryChip(
          context,
          '${result.doubtfulIngredients.length}',
          'result.doubtful_label'.tr(),
          AppTheme.getDoubtfulTextColor(context),
          AppTheme.getDoubtfulBgColor(context),
          AppTheme.getDoubtfulBorderColor(context),
        ),
        const SizedBox(width: 8),
        _buildSummaryChip(
          context,
          '${result.halalIngredients.length}',
          'result.halal_label'.tr(),
          AppTheme.getHalalTextColor(context),
          AppTheme.getHalalBgColor(context),
          AppTheme.getHalalBorderColor(context),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(
    BuildContext context,
    String count,
    String label,
    Color textColor,
    Color bgColor,
    Color borderColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: AppFonts.primary(
                context,
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppFonts.secondary(
                context,
                color: textColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusSubtitle(HalalResult result) {
    switch (result.overallStatus) {
      case HalalStatus.halal:
        return 'result.halal_desc'.tr();
      case HalalStatus.haram:
        return 'result.haram_desc'.tr(
          args: [
            result.haramIngredients.length.toString(),
            result.haramIngredients.join(", "),
          ],
        );
      case HalalStatus.doubtful:
        if (result.doubtfulIngredients.isNotEmpty) {
          return 'result.doubtful_desc'.tr(
            args: [result.doubtfulIngredients.length.toString()],
          );
        }
        return 'result.unverified_desc'.tr();
    }
  }

  String _getLocalizedProductName(String name) {
    if (name == 'Scanned Image' ||
        name == 'Visual AI Analysis' ||
        name == 'general.scanned_image'.tr()) {
      return 'general.scanned_image'.tr();
    } else if (name == 'Scanned Ingredients' ||
        name == 'general.scanned_ingredients'.tr()) {
      return 'general.scanned_ingredients'.tr();
    } else if (name == 'Unknown Product' ||
        name == 'general.unknown_product'.tr()) {
      return 'general.unknown_product'.tr();
    }
    return name;
  }

  String? _formatExpiryMonthYear(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) return null;
    final mm = parsed.month.toString().padLeft(2, '0');
    return '$mm/${parsed.year}';
  }

  bool _isCertificateExpired(String? iso) {
    if (iso == null || iso.trim().isEmpty) return false;
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return parsed.isBefore(todayDate);
  }

  String _formatDateFull(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) return '';
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    return '$dd/$mm/${parsed.year}';
  }

  String _buildBannerSubtitle(Product product, HalalResult result) {
    final effectiveCertifier = (product.certifier != null && product.certifier!.trim().isNotEmpty)
        ? product.certifier!.trim()
        : (result.certifier != null && result.certifier!.trim().isNotEmpty)
            ? result.certifier!.trim()
            : null;

    if (effectiveCertifier != null && result.overallStatus == HalalStatus.halal) {
      final expiry = _formatExpiryMonthYear(product.certificateExpiresAt);
      final isExpired = _isCertificateExpired(product.certificateExpiresAt);
      if (expiry != null) {
        if (isExpired) {
          return '${_formatCertifiedBy(effectiveCertifier)} (${'result.cert_expired'.tr(args: [expiry])})';
        }
        return '${_formatCertifiedBy(effectiveCertifier)}, ${'result.valid_until'.tr(args: [expiry])}';
      }
      return _formatCertifiedBy(effectiveCertifier);
    }
    return _getStatusSubtitle(result);
  }

  Widget _buildUserAlertsSection(BuildContext context, List<String> alerts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getDoubtfulBgColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getDoubtfulBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alerts.map((alertText) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: AppTheme.getDoubtfulTextColor(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alertText,
                    style: AppFonts.primary(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getDoubtfulTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _shareProduct(
    BuildContext context,
    Product product,
    HalalResult result,
  ) async {
    final statusStr = result.overallStatus.name.toUpperCase();
    final certStr = (product.certifier ?? result.certifier ?? '').trim();
    final buffer = StringBuffer()
      ..writeln('${product.name}${product.brands != null && product.brands!.isNotEmpty ? " (${product.brands})" : ""}')
      ..writeln('${'result.barcode_prefix'.tr()}${product.barcode}')
      ..writeln('Statut: $statusStr');
    if (certStr.isNotEmpty) {
      buffer.writeln(_formatCertifiedBy(certStr));
    }
    buffer.write('Vérifié via Allo Halal');

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString()),
    );
  }

  void _showReportErrorSheet(BuildContext context, Product product) {
    String selectedType = 'ingredients';
    final msgController = TextEditingController();
    bool isSending = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'result.report_error_title'.tr(),
                  style: AppFonts.primary(
                    context,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'result.report_error_type'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'ingredients', child: Text('result.report_type_ingredients'.tr())),
                    DropdownMenuItem(value: 'certifier', child: Text('result.report_type_certifier'.tr())),
                    DropdownMenuItem(value: 'status', child: Text('result.report_type_status'.tr())),
                    DropdownMenuItem(value: 'other', child: Text('result.report_type_other'.tr())),
                  ],
                  onChanged: (v) => setSheetState(() => selectedType = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'result.report_error_hint'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(color: AppTheme.haramRed, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final msg = msgController.text.trim();
                            if (msg.isEmpty) {
                              setSheetState(() => errorText = 'result.report_error_required'.tr());
                              return;
                            }
                            setSheetState(() {
                              isSending = true;
                              errorText = null;
                            });
                            try {
                              await ProductCommunityService.submitProductErrorReport(
                                barcode: product.barcode,
                                productId: product.id,
                                productName: product.name,
                                reportType: selectedType,
                                message: msg,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('result.report_error_success'.tr())),
                              );
                            } catch (e) {
                              setSheetState(() {
                                isSending = false;
                                errorText = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('result.report_error_submit'.tr()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatCertifiedBy(String certifier) {
    final localized = 'result.certified_by'.tr(args: [certifier]);
    return localized.replaceAll('{0}', certifier).replaceAll('{}', certifier);
  }

  Widget _buildCertificationSection(
    BuildContext context,
    Product product,
    HalalResult result,
  ) {
    final effectiveCertifier = (product.certifier != null && product.certifier!.trim().isNotEmpty)
        ? product.certifier!.trim()
        : (result.certifier != null && result.certifier!.trim().isNotEmpty)
            ? result.certifier!.trim()
            : null;

    final isOfficiallyVerified = product.verifiedOfficial || result.verifiedOfficial;
    final hasCertifier = effectiveCertifier != null;
    final hasModeratorNote = product.moderatorNote != null && product.moderatorNote!.trim().isNotEmpty;
    final verifiedDateStr = _formatDateFull(product.verifiedAt ?? product.verificationUpdatedAt);
    final proofUrl = product.certificateProofUrl;

    // Case 1: Officially Verified by Allo Halal Admin team (only when badge checkbox is enabled)
    if (isOfficiallyVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? const Color(0xFF0F2338)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        IconlyBold.shield_done,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'result.official_verification'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.isDark(context)
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1D4ED8),
                            ),
                          ),
                          Text(
                            verifiedDateStr.isNotEmpty
                                ? 'result.certificate_checked_on'.tr(args: [verifiedDateStr])
                                : (hasModeratorNote
                                    ? product.moderatorNote!.trim()
                                    : 'result.official_verification_desc'.tr()),
                            style: AppFonts.secondary(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.getTextPrimary(context).withValues(alpha: 0.85),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (proofUrl != null && proofUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final uri = Uri.tryParse(proofUrl);
                          if (uri != null) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          foregroundColor: const Color(0xFF1D4ED8),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          'result.view_proof'.tr(),
                          style: AppFonts.primary(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasCertifier) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatCertifiedBy(effectiveCertifier),
                          style: AppFonts.primary(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.isDark(context)
                                ? const Color(0xFF34D399)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    // Case 2: Known Certifier detected (AVS, Achahada, Mosquée de Paris, ARGML, etc.)
    if (hasCertifier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? const Color(0xFF063321)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatCertifiedBy(effectiveCertifier),
                        style: AppFonts.primary(
                          context,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.isDark(context)
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'result.recognized_certifier_desc'.tr(),
                        style: AppFonts.secondary(
                          context,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getTextPrimary(context).withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    // Case 3: Halal by ingredients, but no specific certification body detected on packaging
    if (result.overallStatus == HalalStatus.halal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.isDark(context)
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'result.no_certifier_detected'.tr(),
                    style: AppFonts.secondary(
                      context,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _SaveButton extends StatefulWidget {
  final Product product;
  final HalalResult halalResult;

  const _SaveButton({required this.product, required this.halalResult});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    final saveId = widget.product.barcode.isNotEmpty
        ? widget.product.barcode
        : widget.product.name;
    _isSaved = SavedProductService.isSaved(saveId);
  }

  void _toggleSave() async {
    final item = HistoryItem(
      id: widget.product.barcode.isNotEmpty
          ? widget.product.barcode
          : widget.product.name,
      productName: widget.product.name,
      barcode: widget.product.barcode,
      overallStatus: widget.halalResult.overallStatus,
      scanDate: DateTime.now(),
      isImageScan:
          false, // Image save doesn't need strict tracking in favor of model restoration
      halalResult: widget.halalResult,
      product: widget.product,
    );

    final isNowSaved = await SavedProductService.toggleSavedStatus(item);
    setState(() {
      _isSaved = isNowSaved;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowSaved
                ? 'result.saved_success'.tr()
                : 'result.removed_success'.tr(),
            style: AppFonts.primary(
              context,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isNowSaved
              ? AppTheme.primaryBlue
              : AppTheme.haramRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggleSave,
      icon: Icon(
        _isSaved ? IconlyBold.bookmark : IconlyLight.bookmark,
        color: _isSaved
            ? AppTheme.primaryBlue
            : AppTheme.getTextPrimary(context),
        size: 26,
      ),
    );
  }
}
