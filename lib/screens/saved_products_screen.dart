import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import '../models/history_item.dart';
import '../models/halal_result.dart';
import '../services/saved_product_service.dart';
import '../providers/scanner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/shared_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'result_screen.dart';
import '../theme/app_fonts.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  List<HistoryItem> _savedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedProducts();
  }

  void _loadSavedProducts() {
    setState(() {
      _savedItems = SavedProductService.getAllSavedProducts();
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await AppDialogs.showConfirmDialog(
      context: context,
      title: 'saved.clear_title'.tr(),
      subtitle: 'saved.clear_desc'.tr(),
      confirmText: 'general.remove'.tr(),
      icon: IconlyBold.delete,
    );

    if (confirm == true) {
      await SavedProductService.clearAllSavedProducts();
      _loadSavedProducts();
    }
  }

  Future<void> _removeItem(String id) async {
    await SavedProductService.removeSavedProduct(id);
    _loadSavedProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : _savedItems.isEmpty
                  ? _buildEmptyState()
                  : _buildSavedList(),
            ),
            AdBannerWidget(key: const ValueKey('banner_saved')),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              IconlyLight.arrow_left,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          Text(
            'saved.title'.tr(),
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_savedItems.isNotEmpty)
            IconButton(
              icon: const Icon(IconlyLight.delete, color: AppTheme.haramRed),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            )
          else
            const SizedBox(width: 48), // Balancing space
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconlyLight.bookmark,
              size: 80,
              color: AppTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'saved.no_saved'.tr(),
            style: AppFonts.primary(
              context,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'saved.no_saved_desc'.tr(),
            style: AppFonts.primary(
              context,
              fontSize: 16,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _savedItems.length,
      itemBuilder: (context, index) {
        final item = _savedItems[index];

        Color statusColor;
        switch (item.overallStatus) {
          case HalalStatus.halal:
            statusColor = AppTheme.primaryBlue;
            break;
          case HalalStatus.haram:
            statusColor = AppTheme.haramRed;
            break;
          case HalalStatus.doubtful:
            statusColor = AppTheme.doubtfulAmber;
            break;
        }

        // Use barcode as ID for deletion if available
        final saveId = item.barcode.isNotEmpty ? item.barcode : item.id;

        return Dismissible(
          key: Key('s_$saveId'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.haramRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(IconlyBold.delete, color: Colors.white),
          ),
          onDismissed: (direction) => _removeItem(saveId),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isImageScan ? IconlyLight.image : IconlyLight.scan,
                  color: statusColor,
                ),
              ),
              title: Text(
                item.productName == 'Scanned Image' ||
                        item.productName == 'Visual AI Analysis' ||
                        item.productName == 'general.scanned_image'.tr()
                    ? 'general.scanned_image'.tr()
                    : (item.productName == 'Scanned Ingredients' ||
                              item.productName ==
                                  'general.scanned_ingredients'.tr()
                          ? 'general.scanned_ingredients'.tr()
                          : (item.productName == 'Unknown Product' ||
                                    item.productName ==
                                        'general.unknown_product'.tr()
                                ? 'general.unknown_product'.tr()
                                : item.productName)),
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withAlpha(50)),
                      ),
                      child: Text(
                        item.overallStatus.labelKey.tr(),
                        style: AppFonts.secondary(
                          context,
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, h:mm a').format(item.scanDate),
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                // Restore state into the provider
                context.read<ScannerProvider>().restoreFromHistory(item);

                // Navigate to result screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ResultScreen()),
                ).then((_) {
                  // Reload when returning just in case they unsaved it
                  _loadSavedProducts();
                });
              },
            ),
          ),
        );
      },
    );
  }
}
