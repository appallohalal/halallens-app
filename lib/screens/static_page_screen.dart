import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class StaticPageScreen extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const StaticPageScreen({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
  });

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
          title,
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.getBorderColor(context),
                  width: 1.5,
                ),
              ),
              child: Text(
                content,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(
                    context,
                  ).withValues(alpha: 0.9),
                  fontSize: 15,
                  height: 1.8,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 ${'general.app_name'.tr()}',
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextMuted(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
