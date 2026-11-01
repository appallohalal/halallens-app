import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Profile Management & GDPR Account Deletion Screen (GDPR Article 17)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _cityController;

  String _selectedCountry = 'France';
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  static const List<String> _countries = [
    'France',
    'Belgique',
    'Suisse',
    'Canada',
    'Maroc',
    'Algérie',
    'Tunisie',
    'Royaume-Uni',
    'Allemagne',
    'Espagne',
    'Italie',
    'Turquie',
    'États-Unis',
  ];

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');

    if (user != null && user.country.isNotEmpty) {
      if (_countries.contains(user.country)) {
        _selectedCountry = user.country;
      } else {
        _selectedCountry = _countries.first;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.instance.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        country: _selectedCountry,
        city: _cityController.text.trim(),
      );

      if (res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil mis à jour avec succès !',
              style: AppFonts.primary(context, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF088839),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = res.error ?? 'Échec de la mise à jour du profil.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: !_isDeleting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(IconlyBold.delete, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Supprimer mon compte ?',
                      style: AppFonts.primary(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attention : cette action est immédiate et irréversible.',
                    style: AppFonts.primary(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conformément à l\'Article 17 du RGPD (Droit à l\'effacement / Droit à l\'oubli), votre compte et l\'intégralité de vos données personnelles (nom, email, favoris et historique) seront définitivement effacés de nos serveurs sécurisés.',
                    style: AppFonts.primary(
                      context,
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: _isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    'general.cancel'.tr(),
                    style: AppFonts.primary(
                      context,
                      color: AppTheme.getTextSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isDeleting
                      ? null
                      : () async {
                          setDialogState(() => _isDeleting = true);
                          setState(() => _isDeleting = true);

                          try {
                            final res = await AuthService.instance.deleteAccount();

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx); // close dialog
                            }
                            if (!context.mounted) return;
                            Navigator.pop(context); // close edit profile screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res.message ??
                                      'Votre compte et vos données ont été définitivement supprimés (RGPD Art. 17).',
                                  style: AppFonts.primary(context, color: Colors.white),
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Erreur lors de la suppression: $e';
                                _isDeleting = false;
                              });
                            }
                          }
                        },
                  child: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Oui, supprimer définitivement',
                          style: AppFonts.primary(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

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
          'Modifier le profil',
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Avatar & GDPR Badge Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.getBorderColor(context),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF088839).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF088839).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (user?.name.isNotEmpty == true)
                              ? user!.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: AppFonts.primary(
                            context,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF088839),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Utilisateur',
                            style: AppFonts.primary(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF088839).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Compte vérifié • RGPD Conforme',
                              style: AppFonts.primary(
                                context,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF088839),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppFonts.primary(context, color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section: Personal Info
              Text(
                'Informations Personnelles',
                style: AppFonts.primary(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 12),

              // Full Name
              _buildInputField(
                label: 'Nom complet',
                controller: _nameController,
                icon: IconlyLight.profile,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez saisir votre nom complet';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Email Address
              _buildInputField(
                label: 'Adresse e-mail',
                controller: _emailController,
                icon: IconlyLight.message,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez renseigner votre e-mail';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Veuillez saisir une adresse e-mail valide';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Username
              _buildInputField(
                label: 'Nom d\'utilisateur (@identifiant)',
                controller: _usernameController,
                icon: IconlyLight.user,
              ),

              const SizedBox(height: 14),

              // Country Dropdown
              Text(
                'Pays de résidence',
                style: AppFonts.primary(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.getBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    icon: const Icon(IconlyLight.arrow_down_2, size: 18),
                    dropdownColor: AppTheme.getCardColor(context),
                    items: _countries.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: AppFonts.primary(
                            context,
                            fontSize: 13,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCountry = val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // City
              _buildInputField(
                label: 'Ville',
                controller: _cityController,
                icon: IconlyLight.location,
              ),

              const SizedBox(height: 24),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Enregistrer les modifications',
                          style: AppFonts.primary(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF088839),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _handleSaveProfile,
                ),
              ),

              const SizedBox(height: 36),

              // GDPR Danger Zone: Account Deletion (Article 17)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(IconlyLight.shield_done, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Conformité RGPD — Droit à l\'effacement',
                          style: AppFonts.primary(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En vertu de l\'Article 17 du RGPD (Droit à l\'oubli), vous pouvez à tout moment supprimer définitivement votre compte et effacer l\'intégralité de vos données de nos bases.',
                      style: AppFonts.primary(
                        context,
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(IconlyLight.delete, size: 18, color: Colors.redAccent),
                        label: Text(
                          'Supprimer mon compte définitivement',
                          style: AppFonts.primary(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isDeleting ? null : _showDeleteAccountConfirmation,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.primary(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppFonts.primary(
            context,
            fontSize: 13,
            color: AppTheme.getTextPrimary(context),
          ),
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTheme.getTextSecondary(context)),
            filled: true,
            fillColor: AppTheme.getCardColor(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF088839), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

