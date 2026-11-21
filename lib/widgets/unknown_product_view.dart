import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ad_service.dart';
import '../services/product_community_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/text_scan_screen.dart';

class UnknownProductView extends StatefulWidget {
  final String barcode;
  final VoidCallback onScanAnother;

  const UnknownProductView({
    super.key,
    required this.barcode,
    required this.onScanAnother,
  });

  @override
  State<UnknownProductView> createState() => _UnknownProductViewState();
}

class _UnknownProductViewState extends State<UnknownProductView> {
  final ImagePicker _picker = ImagePicker();

  File? _frontPhoto;
  File? _ingredientsPhoto;
  File? _certifierPhoto;
  bool _notifyWhenReady = true;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMsg;

  Future<void> _pickPhoto(int step, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final bytes = await file.length();
      if (bytes > ProductCommunityService.maxImageBytes) {
        setState(() => _errorMsg = 'unknown_product.image_too_large'.tr());
        return;
      }

      setState(() {
        _errorMsg = null;
        if (step == 1) _frontPhoto = file;
        if (step == 2) _ingredientsPhoto = file;
        if (step == 3) _certifierPhoto = file;
      });
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    }
  }

  void _showSourcePicker(int step) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(IconlyBold.camera, color: AppTheme.primaryBlue),
                title: Text(
                  'unknown_product.take_photo'.tr(),
                  style: AppFonts.primary(context, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(step, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(IconlyBold.image, color: AppTheme.halalGreen),
                title: Text(
                  'unknown_product.choose_gallery'.tr(),
                  style: AppFonts.primary(context, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(step, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPhotographFlow() {
    if (_frontPhoto == null) {
      _showSourcePicker(1);
    } else if (_ingredientsPhoto == null) {
      _showSourcePicker(2);
    } else {
      _showSourcePicker(3);
    }
  }

  Future<void> _submit() async {
    if (_frontPhoto == null && _ingredientsPhoto == null) {
      setState(() {
        _errorMsg = 'unknown_product.need_photos'.tr();
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      await ProductCommunityService.submitUnknownProduct(
        barcode: widget.barcode,
        frontPhoto: _frontPhoto,
        ingredientsPhoto: _ingredientsPhoto,
        certifierPhoto: _certifierPhoto,
        notifyWhenReady: _notifyWhenReady,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    if (_submitted) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.halalGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.halalGreen,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'unknown_product.submitted_title'.tr(),
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _notifyWhenReady
                    ? 'unknown_product.submitted_notify_desc'.tr()
                    : 'unknown_product.submitted_desc'.tr(),
                textAlign: TextAlign.center,
                style: AppFonts.secondary(
                  context,
                  fontSize: 14,
                  color: AppTheme.getTextSecondary(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: widget.onScanAnother,
                  icon: const Icon(IconlyLight.scan),
                  label: Text('result.scan_another'.tr()),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hide_source_rounded,
                    size: 30,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'unknown_product.title'.tr(),
                  textAlign: TextAlign.center,
                  style: AppFonts.primary(
                    context,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'unknown_product.subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: AppFonts.secondary(
                    context,
                    fontSize: 13.5,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'unknown_product.help_prompt'.tr(args: [widget.barcode]),
                    style: AppFonts.primary(
                      context,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3 numbered steps
                _buildStepTile(
                  context,
                  step: 1,
                  title: 'unknown_product.step1'.tr(),
                  file: _frontPhoto,
                  optional: false,
                  onTap: () => _showSourcePicker(1),
                  onRemove: () => setState(() => _frontPhoto = null),
                ),
                const SizedBox(height: 10),
                _buildStepTile(
                  context,
                  step: 2,
                  title: 'unknown_product.step2'.tr(),
                  file: _ingredientsPhoto,
                  optional: false,
                  onTap: () => _showSourcePicker(2),
                  onRemove: () => setState(() => _ingredientsPhoto = null),
                ),
                const SizedBox(height: 10),
                _buildStepTile(
                  context,
                  step: 3,
                  title: 'unknown_product.step3'.tr(),
                  file: _certifierPhoto,
                  optional: true,
                  onTap: () => _showSourcePicker(3),
                  onRemove: () => setState(() => _certifierPhoto = null),
                ),
                const SizedBox(height: 18),

                // Primary action button: Photographier le produit
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _startPhotographFlow,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(IconlyLight.camera, size: 20),
                    label: Text(
                      'unknown_product.photograph_btn'.tr(),
                      style: AppFonts.primary(
                        context,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Notify me checkbox
                InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _notifyWhenReady = !_notifyWhenReady),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _notifyWhenReady,
                            activeColor: AppTheme.primaryBlue,
                            onChanged: _isSubmitting
                                ? null
                                : (val) => setState(() => _notifyWhenReady = val ?? true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'unknown_product.notify_checkbox'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.haramRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: AppFonts.secondary(
                        context,
                        fontSize: 12.5,
                        color: AppTheme.haramRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                if (_frontPhoto != null || _ingredientsPhoto != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.halalGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'unknown_product.submitting'.tr()
                            : 'unknown_product.submit_btn'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Optional instant AI OCR scan shortcut
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                AdService.instance.showInterstitial(
                  onClosed: () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TextScanScreen(
                          autoLaunchCamera: true,
                          initialBarcode: widget.barcode,
                        ),
                      ),
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(IconlyBold.camera, size: 18),
              label: Text(
                'result.scan_label_ai'.tr(),
                style: AppFonts.primary(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: widget.onScanAnother,
              icon: const Icon(IconlyLight.scan, size: 18),
              label: Text('result.scan_another'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(
    BuildContext context, {
    required int step,
    required String title,
    required File? file,
    required bool optional,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final borderColor = AppTheme.getBorderColor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppTheme.halalGreen : borderColor,
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: file != null
                    ? AppTheme.halalGreen.withValues(alpha: 0.15)
                    : AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: file != null
                  ? const Icon(Icons.check_rounded, size: 16, color: AppTheme.halalGreen)
                  : Text(
                      '$step',
                      style: AppFonts.primary(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.primary(
                      context,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  if (optional && file == null)
                    Text(
                      'unknown_product.optional'.tr(),
                      style: AppFonts.secondary(
                        context,
                        fontSize: 11,
                        color: AppTheme.getTextMuted(context),
                      ),
                    ),
                ],
              ),
            ),
            if (file != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.haramRed),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ] else
              Icon(
                IconlyLight.camera,
                size: 18,
                color: AppTheme.getTextSecondary(context),
              ),
          ],
        ),
      ),
    );
  }
}
