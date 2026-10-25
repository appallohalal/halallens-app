import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:iconly/iconly.dart';
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../utils/language_helper.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
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
          'settings.select_lang_title'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'settings.select_lang_desc'.tr(),
              style: AppFonts.primary(
                context,
                color: AppTheme.getTextSecondary(context),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: LanguageHelper.languages.length,
              itemBuilder: (context, index) {
                final lang = LanguageHelper.languages[index];
                final isSelected = context.locale.languageCode == lang['code'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue.withAlpha(25)
                        : AppTheme.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : AppTheme.getBorderColor(context),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await context.setLocale(Locale(lang['code']!));
                      if (!context.mounted) return;

                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${"settings.lang_saved".tr()}: ${lang['nativeName']}',
                            style: AppFonts.primary(
                              context,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: AppTheme.primaryBlue,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      // Return to settings
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryBlue.withAlpha(50)
                                  : AppTheme.getBackgroundColor(context),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                lang['name']!.substring(0, 1),
                                style: AppFonts.primary(
                                  context,
                                  color: isSelected
                                      ? AppTheme.primaryBlue
                                      : AppTheme.getTextSecondary(context),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['nativeName']!,
                                  style: AppFonts.primary(
                                    context,
                                    color: isSelected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.getTextPrimary(context),
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang['name']!,
                                  style: AppFonts.primary(
                                    context,
                                    color: AppTheme.getTextMuted(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              IconlyBold.tick_square,
                              color: AppTheme.primaryBlue,
                              size: 28,
                            )
                          else
                            Icon(
                              IconlyLight.arrow_right_2,
                              color: AppTheme.getTextMuted(context),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
