import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import 'splash_screen.dart';

class BannedScreen extends StatefulWidget {
  final String? reason;

  const BannedScreen({super.key, this.reason});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  bool _isChecking = false;

  Future<void> _handleRecheck() async {
    setState(() => _isChecking = true);
    final stillBanned = await AuthService.instance.checkBanStatus();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!stillBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'auth.restriction_lifted'.tr(),
            style: AppFonts.primary(context, color: Colors.white),
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'auth.still_suspended'.tr(),
            style: AppFonts.primary(context, color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthService>(context);
    final effectiveReason = widget.reason ?? auth.banReason;
    final user = auth.currentUser;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Red Alert Illustration
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  Text(
                    'auth.account_suspended'.tr(),
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getTextPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'auth.suspended_message'.tr(),
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),

                  // Account Identifier Pill
                  if (user != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.email.isNotEmpty ? user.email : (user.username.isNotEmpty ? '@${user.username}' : user.name),
                            style: AppFonts.primary(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Reason Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF261214) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'auth.suspension_reason'.tr(),
                              style: AppFonts.primary(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (effectiveReason != null &&
                                  effectiveReason.trim().isNotEmpty &&
                                  effectiveReason.trim().toLowerCase() != 'null')
                              ? effectiveReason
                              : 'auth.default_ban_reason'.tr(),
                          style: AppFonts.primary(
                            context,
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Recheck Status Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _handleRecheck,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        _isChecking ? 'auth.checking'.tr() : 'auth.recheck_status'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
