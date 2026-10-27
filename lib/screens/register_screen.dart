import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../services/auth_service.dart';
import '../config/auth_config.dart';
import 'static_page_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool isMandatory;
  final VoidCallback? onSuccess;

  const RegisterScreen({
    super.key,
    this.isMandatory = false,
    this.onSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToPrivacyPolicy = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _countryController.text = 'United States';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaticPageScreen(
          title: 'settings.privacy_title'.tr(),
          content: 'settings.privacy_content'.tr(),
          icon: IconlyLight.shield_done,
        ),
      ),
    );
  }

  void _openTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaticPageScreen(
          title: 'auth.terms_title'.tr(),
          content:
              'Welcome to HalalLens. By creating an account, you agree to these Terms of Service.\n\n'
              '1. Purpose & Verification:\nHalalLens assists consumers in analyzing product ingredients and identifying halal or haram additives. While our database and AI models are continuously updated, consumers should verify with local halal certification bodies when in doubt.\n\n'
              '2. Account Responsibility:\nYou are responsible for safeguarding your login credentials and for all actions conducted under your account.\n\n'
              '3. Community Integrity:\nUsers agree not to exploit the service or submit false reviews.\n\n'
              'Thank you for being part of the HalalLens community.',
          icon: IconlyLight.document,
        ),
      ),
    );
  }

  Future<void> _submitRegister() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_agreeToPrivacyPolicy) {
      setState(() {
        _errorMessage = 'auth.agree_required'.tr();
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await AuthService.instance.register(
        name: _nameController.text,
        username: _usernameController.text.isNotEmpty
            ? _usernameController.text
            : _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        country: _countryController.text,
        city: _cityController.text,
      );

      if (!mounted) return;

      if (res.success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          // Pop register screen and return success to root caller
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = res.error ?? 'auth.unexpected_error'.tr();
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

  void _skipAsGuest() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final isMandatoryAuth = widget.isMandatory || AuthConfig.isForceUserAuth;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        IconlyBold.shield_done,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),


                  // Title
                  Text(
                    'auth.create_your_account'.tr(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'auth.register_subtitle'.tr(),
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
                  const SizedBox(height: 20),

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

                  // 1. Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'auth.full_name'.tr(),
                    hint: 'auth.full_name_hint'.tr(),
                    icon: IconlyLight.profile,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'auth.name_required'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Username
                  _buildTextField(
                    controller: _usernameController,
                    label: 'auth.username'.tr(),
                    hint: 'auth.username_hint'.tr(),
                    icon: IconlyLight.user,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'auth.username_required'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. Email Address
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
                  const SizedBox(height: 12),

                  // 4. Password
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
                  const SizedBox(height: 12),

                  // 5. Country
                  _buildTextField(
                    controller: _countryController,
                    label: 'auth.country'.tr(),
                    hint: 'auth.country_hint'.tr(),
                    icon: IconlyLight.location,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'auth.country_required'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 6. City
                  _buildTextField(
                    controller: _cityController,
                    label: 'auth.city'.tr(),
                    hint: 'auth.city_hint'.tr(),
                    icon: IconlyLight.discovery,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'auth.city_required'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Privacy Policy & Terms Agreement Checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeToPrivacyPolicy,
                            activeColor: AppTheme.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(
                              color: AppTheme.getTextSecondary(context).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _agreeToPrivacyPolicy = val ?? false;
                                if (_agreeToPrivacyPolicy &&
                                    _errorMessage != null &&
                                    _errorMessage!.contains('Privacy')) {
                                  _errorMessage = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreeToPrivacyPolicy = !_agreeToPrivacyPolicy;
                                if (_agreeToPrivacyPolicy &&
                                    _errorMessage != null &&
                                    _errorMessage!.contains('Privacy')) {
                                  _errorMessage = null;
                                }
                              });
                            },
                            child: Text.rich(
                              TextSpan(
                                text: 'auth.agree_prefix'.tr(),
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 13,
                                  color: AppTheme.getTextSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: _openPrivacyPolicy,
                                      child: Text(
                                        'settings.privacy_title'.tr(),
                                        style: AppFonts.primary(
                                          context,
                                          fontSize: 13,
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' & ',
                                    style: AppFonts.primary(
                                      context,
                                      fontSize: 13,
                                      color: AppTheme.getTextSecondary(context),
                                    ),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: _openTermsOfService,
                                      child: Text(
                                        'auth.terms_of_service'.tr(),
                                        style: AppFonts.primary(
                                          context,
                                          fontSize: 13,
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (!_agreeToPrivacyPolicy) {
                                setState(() {
                                  _errorMessage = 'auth.agree_required'.tr();
                                });
                                return;
                              }
                              _submitRegister();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _agreeToPrivacyPolicy
                            ? AppTheme.primaryBlue
                            : AppTheme.primaryBlue.withValues(alpha: 0.65),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: _agreeToPrivacyPolicy ? 2 : 0,
                      ),
                      child: Text(
                        'auth.create_account_btn'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // Link back to Login Screen
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.already_have_account'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 14,
                          color: AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'auth.sign_in'.tr(),
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
                  const SizedBox(height: 16),
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
