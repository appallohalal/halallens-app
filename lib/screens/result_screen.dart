import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/halal_result.dart';
import '../providers/scanner_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_native_widget.dart';
import '../widgets/geo_ad_banner_widget.dart';
import '../widgets/shared_widgets.dart';
import 'package:iconly/iconly.dart';
import '../models/history_item.dart';
import '../models/product.dart';
import '../services/saved_product_service.dart';

import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';
import 'text_scan_screen.dart';

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
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  IconlyLight.scan,
                  size: 38,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'result.fallback_title'.tr(),
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context)
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.isDark(context)
                        ? Colors.white12
                        : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${"result.barcode_prefix".tr()}$barcode',
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'result.fallback_desc'.tr(),
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Action 1: Camera Vision AI (Primary Hero Card)
              InkWell(
                onTap: () {
                  AdService.instance.showInterstitial(
                    onClosed: () {
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TextScanScreen(
                            autoLaunchCamera: true,
                            initialBarcode: barcode,
                          ),
                        ),
                      );
                    },
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          IconlyBold.camera,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'result.scan_label_ai'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'result.scan_label_ai_desc'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 2: Manual text entry (Secondary Card)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TextScanScreen(
                        autoLaunchCamera: false,
                        initialBarcode: barcode,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.isDark(context)
                          ? Colors.white12
                          : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          IconlyLight.edit,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'result.manual_input_ingredients'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: AppTheme.getTextPrimary(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'result.manual_input_ingredients_desc'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.getTextSecondary(context),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action 3: Scan another product
              TextButton.icon(
                onPressed: () {
                  AdService.instance.showInterstitial(
                    onClosed: () {
                      if (!context.mounted) return;
                      provider.reset();
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  );
                },
                icon: const Icon(IconlyLight.scan, size: 18),
                label: Text(
                  'result.scan_another'.tr(),
                  style: AppFonts.primary(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
            subtitle: _getStatusSubtitle(result),
          ),
          const SizedBox(height: 14),

          // Moderator Verification Note Banner (if verified by Admin team)
          if (product.moderatorNote != null && product.moderatorNote!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vérification Officielle Allo Halal',
                          style: AppFonts.primary(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.isDark(context)
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.moderatorNote!.trim(),
                          style: AppFonts.secondary(
                            context,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getTextPrimary(context),
                            height: 1.35,
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
