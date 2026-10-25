import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import '../models/history_item.dart';
import '../models/halal_result.dart';
import '../services/history_service.dart';
import '../providers/scanner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/shared_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'result_screen.dart';
import '../theme/app_fonts.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyItems = HistoryService.getAllHistory();
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await AppDialogs.showConfirmDialog(
      context: context,
      title: 'history.clear_title'.tr(),
      subtitle: 'history.clear_desc'.tr(),
      confirmText: 'general.delete'.tr(),
      icon: IconlyBold.delete,
    );

    if (confirm == true) {
      await HistoryService.clearAllHistory();
      _loadHistory();
    }
  }

  Future<void> _deleteItem(String id) async {
    await HistoryService.deleteHistoryItem(id);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            IconlyLight.arrow_left,
            color: AppTheme.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'history.title'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(IconlyLight.delete, color: AppTheme.haramRed),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  )
                : _historyItems.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(),
          ),
          AdBannerWidget(key: const ValueKey('banner_history')),
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
              IconlyLight.time_circle,
              size: 80,
              color: AppTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'history.no_history'.tr(),
            style: AppFonts.primary(
              context,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'history.no_history_desc'.tr(),
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

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final item = _historyItems[index];

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

        return Dismissible(
          key: Key(item.id),
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
          onDismissed: (direction) => _deleteItem(item.id),
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
                );
              },
            ),
          ),
        );
      },
    );
  }
}
