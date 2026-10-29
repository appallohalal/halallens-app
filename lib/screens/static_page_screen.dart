import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../config/cms_config.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Dynamic Static / Legal Page Screen supporting real-time CMS sync
/// for Help, About, Privacy Policy (GDPR compliant), and Terms of Service.
class StaticPageScreen extends StatefulWidget {
  final String title;
  final String content;
  final IconData icon;
  final String? pageKey; // 'help' | 'privacy' | 'about' | 'terms'

  const StaticPageScreen({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    this.pageKey,
  });

  @override
  State<StaticPageScreen> createState() => _StaticPageScreenState();
}

class _StaticPageScreenState extends State<StaticPageScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    CmsConfig.updateNotifier.addListener(_onCmsUpdated);
    _syncLatestCms();
  }

  @override
  void dispose() {
    CmsConfig.updateNotifier.removeListener(_onCmsUpdated);
    super.dispose();
  }

  void _onCmsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncLatestCms() async {
    // Background real-time fetch from CMS so the page is always up to date
    try {
      await CmsConfig.syncFromBackend();
    } catch (_) {}
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await CmsConfig.syncFromBackend();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _resolveTitle() {
    switch (widget.pageKey) {
      case 'help':
        return CmsConfig.getText('helpTitle', fallback: widget.title);
      case 'privacy':
        return CmsConfig.getText('privacyTitle', fallback: widget.title);
      case 'about':
        return CmsConfig.getText('aboutTitle', fallback: widget.title);
      case 'terms':
        return CmsConfig.getText('termsTitle', fallback: widget.title);
      default:
        return widget.title;
    }
  }

  String _resolveContent() {
    switch (widget.pageKey) {
      case 'help':
        return CmsConfig.getText('helpContent', fallback: widget.content);
      case 'privacy':
        return CmsConfig.getText('privacyContent', fallback: widget.content);
      case 'about':
        return CmsConfig.getText('aboutContent', fallback: widget.content);
      case 'terms':
        return CmsConfig.getText('termsContent', fallback: widget.content);
      default:
        return widget.content;
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolveTitle();
    final content = _resolveContent();
    final isPrivacy = widget.pageKey == 'privacy';
    final isHelp = widget.pageKey == 'help';

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
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser en direct',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.sync_rounded,
                    color: AppTheme.getTextSecondary(context),
                    size: 20,
                  ),
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Icon & Header Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isPrivacy
                        ? const Color(0xFF088839).withValues(alpha: 0.12)
                        : AppTheme.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 42,
                    color: isPrivacy ? const Color(0xFF088839) : AppTheme.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // GDPR Compliance Banner for Privacy Policy
              if (isPrivacy) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF088839).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF088839).withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            IconlyBold.shield_done,
                            color: Color(0xFF088839),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Conforme RGPD (UE 2016/679 - CNIL)',
                              style: AppFonts.primary(
                                context,
                                color: const Color(0xFF088839),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF088839),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Actif',
                              style: AppFonts.primary(
                                context,
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vos données personnelles sont protégées sous haute sécurité, chiffrées (TLS 1.3) et ne sont jamais vendues. Vous disposez d\'un droit d\'accès, de rectification et d\'effacement complet.',
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _launchExternalUrl(
                          'mailto:support@allohalal.fr?subject=Demande%20RGPD%20Allo%20Halal',
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF088839).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                IconlyLight.message,
                                size: 14,
                                color: Color(0xFF088839),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Contacter le DPO : support@allohalal.fr',
                                style: AppFonts.primary(
                                  context,
                                  color: const Color(0xFF088839),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Quick Contact Action Bar for Help Screen
              if (isHelp) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchExternalUrl('mailto:support@allohalal.fr'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.getBorderColor(context),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(IconlyLight.message, size: 20, color: Color(0xFF088839)),
                              const SizedBox(height: 6),
                              Text(
                                'E-mail Support',
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                'support@allohalal.fr',
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 10,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchExternalUrl('https://www.allohalal.fr'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.getBorderColor(context),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.language_rounded, size: 20, color: Colors.blueAccent),
                              const SizedBox(height: 6),
                              Text(
                                'Site Officiel',
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                'www.allohalal.fr',
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 10,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Main Policy / Page Content Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.getBorderColor(context),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SelectableText(
                  content,
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextPrimary(context).withValues(alpha: 0.92),
                    fontSize: 14.5,
                    height: 1.75,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bottom Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      '© 2026 ${'general.app_name'.tr()} — Tous droits réservés',
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextMuted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allo Halal • www.allohalal.fr • RGPD Conforme',
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextMuted(context).withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
