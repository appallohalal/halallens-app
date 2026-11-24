import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../services/auth_service.dart';
import '../config/auth_config.dart';
import 'register_screen.dart';
import 'banned_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isMandatory;
  final VoidCallback? onSuccess;

  const LoginScreen({
    super.key,
    this.isMandatory = false,
    this.onSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await AuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (res.success) {
        _handleSuccess();
      } else {
        if (AuthService.instance.isBanned) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BannedScreen(
                reason: AuthService.instance.banReason,
              ),
            ),
          );
          return;
        }
        setState(() {
          _errorMessage = res.error ?? 'auth.login_failed'.tr();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${'auth.unexpected_error'.tr()}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSuccess() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _skipAsGuest() {
    Navigator.of(context).pop(false);
  }

  Future<void> _showForgotPasswordModal() async {
    final resetEmailCtrl = TextEditingController(text: _emailController.text.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    int step = 1;
    bool sending = false;
    bool obscureNew = true;
    String? modalError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step == 1
                            ? 'Mot de passe oublié'
                            : 'Nouveau mot de passe',
                        style: AppFonts.primary(
                          ctx,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getTextPrimary(ctx),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step == 1
                        ? 'Entrez votre adresse e-mail pour recevoir un code de vérification à 6 chiffres.'
                        : 'Saisissez le code reçu par e-mail ainsi que votre nouveau mot de passe.',
                    style: AppFonts.secondary(
                      ctx,
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.haramRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        modalError!,
                        style: AppFonts.secondary(
                          ctx,
                          fontSize: 12.5,
                          color: AppTheme.haramRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  TextField(
                    controller: resetEmailCtrl,
                    enabled: step == 1 && !sending,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'auth.email'.tr(),
                      prefixIcon: const Icon(IconlyLight.message, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (step == 2) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      enabled: !sending,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Code de vérification (6 chiffres)',
                        counterText: '',
                        prefixIcon: const Icon(IconlyLight.shield_done, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      enabled: !sending,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(IconlyLight.lock, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? IconlyLight.hide : IconlyLight.show,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() => obscureNew = !obscureNew);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              final email = resetEmailCtrl.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setModalState(() => modalError = 'auth.email_invalid'.tr());
                                return;
                              }
                              setModalState(() {
                                sending = true;
                                modalError = null;
                              });

                              if (step == 1) {
                                final res = await AuthService.instance
                                    .requestPasswordResetCode(email);
                                if (!sheetCtx.mounted) return;
                                if (res.success) {
                                  setModalState(() {
                                    sending = false;
                                    step = 2;
                                  });
                                } else {
                                  setModalState(() {
                                    sending = false;
                                    modalError = res.message ?? 'Erreur lors de l\'envoi du code.';
                                  });
                                }
                              } else {
                                final code = codeCtrl.text.trim();
                                final newPass = newPassCtrl.text;
                                if (code.length != 6) {
                                  setModalState(() {
                                    sending = false;
                                    modalError = 'Veuillez entrer le code à 6 chiffres.';
                                  });
                                  return;
                                }
                                if (newPass.length < 6) {
                                  setModalState(() {
                                    sending = false;
                                    modalError = 'auth.password_min_error'.tr();
                                  });
                                  return;
                                }
                                final res = await AuthService.instance.confirmPasswordReset(
                                  email: email,
                                  code: code,
                                  newPassword: newPass,
                                );
                                if (!sheetCtx.mounted) return;
                                if (res.success) {
                                  _emailController.text = email;
                                  Navigator.of(sheetCtx).pop();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Mot de passe réinitialisé avec succès. Vous pouvez vous connecter.',
                                        ),
                                        backgroundColor: AppTheme.halalGreen,
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    sending = false;
                                    modalError = res.message ?? 'Code invalide ou expiré.';
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              step == 1
                                  ? 'Envoyer le code'
                                  : 'Réinitialiser le mot de passe',
                              style: AppFonts.primary(
                                ctx,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(
          isMandatory: widget.isMandatory,
          onSuccess: widget.onSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMandatoryAuth = widget.isMandatory || AuthConfig.isForceUserAuth;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (!isMandatoryAuth)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.getTextPrimary(context),
                ),
                onPressed: () => Navigator.of(context).pop(false),
              )
            : null,
        actions: [
          if (!isMandatoryAuth)
            TextButton(
              onPressed: _skipAsGuest,
              child: Text(
                'auth.skip'.tr(),
                style: AppFonts.primary(
                  context,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Title
                  Text(
                    'auth.welcome_back'.tr(),
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'auth.login_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: AppFonts.primary(
                        context,
                        fontSize: 13,
                        color: AppTheme.getTextSecondary(context),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            IconlyBold.danger,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppFonts.primary(
                                context,
                                fontSize: 13,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Email Address
                  _buildTextField(
                    controller: _emailController,
                    label: 'auth.email_label'.tr(),
                    hint: 'auth.email_hint'.tr(),
                    icon: IconlyLight.message,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null ||
                          val.trim().isEmpty ||
                          !val.contains('@')) {
                        return 'auth.email_invalid'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _buildTextField(
                    controller: _passwordController,
                    label: 'auth.password_label'.tr(),
                    hint: '••••••••',
                    icon: IconlyLight.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? IconlyLight.hide : IconlyLight.show,
                        color: AppTheme.getTextSecondary(context),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return 'auth.password_min_error'.tr();
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordModal,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Mot de passe oublié ?',
                        style: AppFonts.primary(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'auth.sign_in'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // Link to Register Screen
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.new_to_app'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 14,
                          color: AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _navigateToRegister,
                        child: Text(
                          'auth.create_account'.tr(),
                          style: AppFonts.primary(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Optional Skip / Continue as Guest (When Feature Toggle is OFF)
                  if (!isMandatoryAuth) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _skipAsGuest,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppTheme.getBorderColor(context),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'auth.explore_as_guest'.tr(),
                          style: AppFonts.primary(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppFonts.primary(
        context,
        fontSize: 15,
        color: AppTheme.getTextPrimary(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppFonts.primary(
          context,
          fontSize: 14,
          color: AppTheme.getTextSecondary(context),
        ),
        hintStyle: AppFonts.primary(
          context,
          fontSize: 14,
          color: AppTheme.getTextMuted(context),
        ),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryBlue),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.getCardColor(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
      ),
    );
  }
}
