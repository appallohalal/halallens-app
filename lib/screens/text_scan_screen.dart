import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/scanner_provider.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';
import '../utils/language_helper.dart';

/// Screen for scanning ingredient text from product packaging using Vision AI.
/// Supports all languages including Bengali.
class TextScanScreen extends StatefulWidget {
  final bool autoLaunchCamera;
  final String? initialBarcode;

  const TextScanScreen({
    super.key,
    this.autoLaunchCamera = false,
    this.initialBarcode,
  });

  @override
  State<TextScanScreen> createState() => _TextScanScreenState();
}

class _TextScanScreenState extends State<TextScanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  File? _selectedImage;
  bool _showEditor = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLaunchCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickImage(ImageSource.camera);
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95, // High quality for accurate AI Vision reading
        maxWidth: 1800,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _showEditor = false; // Bypass the editor completely for images
      });

      // Automatically trigger the analysis without waiting for a button tap
      _analyzeImageDirectly();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${"errors.error_prefix".tr()}: $e'),
            backgroundColor: AppTheme.haramRed,
          ),
        );
      }
    }
  }

  Future<void> _analyzeImageDirectly() async {
    if (_selectedImage == null) return;

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (!mounted) return;

      // Start processing but do not await it here.
      // ResultScreen handles the loading state beautifully.
      context.read<ScannerProvider>().processIngredientImage(
        base64Image,
        language: LanguageHelper.getLanguageName(context),
        barcode: widget.initialBarcode,
      );

      // Navigate to ResultScreen immediately
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResultScreen()),
        ).then((_) {
          // When returning from ResultScreen, clear the image to go back to initial state
          if (mounted) {
            setState(() {
              _selectedImage = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${"errors.generic_error".tr()}: $e'),
            backgroundColor: AppTheme.haramRed,
          ),
        );
      }
    }
  }

  void _analyzeText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    context.read<ScannerProvider>().processIngredientText(
      text,
      language: LanguageHelper.getLanguageName(context),
      barcode: widget.initialBarcode,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    ).then((_) {
      if (mounted) {
        setState(() {
          _textController.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      IconlyLight.arrow_left,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'text_scan.title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            if (widget.initialBarcode != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 16,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${"result.barcode_prefix".tr()}${widget.initialBarcode}',
                      style: AppFonts.primary(
                        context,
                        color: AppTheme.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _showEditor ? _buildEditorState() : _buildInitialState(),
            ),
          ],
        ),
      ),
    );
  }

  /// Initial state — choose camera or gallery
  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Hero illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconlyBold.image,
              size: 56,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'text_scan.title'.tr(),
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'text_scan.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 48),

          // Camera button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(IconlyLight.camera, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'home.analyze_text'.tr().toUpperCase(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Gallery button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: OutlinedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.getTextPrimary(context),
                side: BorderSide(
                  color: AppTheme.getBorderColor(context),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconlyLight.image,
                    size: 24,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'home.upload_image'.tr().toUpperCase(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Manual text entry option
          TextButton(
            onPressed: () {
              setState(() {
                _showEditor = true;
                _selectedImage = null;
                _textController.clear();
              });
            },
            child: Text(
              'home.analyze_text_desc'
                  .tr(), // "Type or paste ingredient text" acts as manual entry fallback
              style: AppFonts.primary(
                context,
                color: AppTheme.getTextSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Editor state — review image or type text manually
  Widget _buildEditorState() {
    final isImageMode = _selectedImage != null;

    return Column(
      children: [
        if (isImageMode)
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
                color: AppTheme.getCardColor(context),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
            ),
          )
        else
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: TextField(
                controller: _textController,
                onChanged: (_) {
                  setState(() {}); // Rebuild to update button active state
                },
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'text_scan.hint'.tr(),
                  hintStyle: AppFonts.primary(
                    context,
                    color: AppTheme.getTextMuted(context),
                    fontSize: 13,
                    height: 1.6,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.getBackgroundColor(context),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isImageMode
                      ? _analyzeImageDirectly
                      : (_textController.text.trim().isNotEmpty
                            ? _analyzeText
                            : null),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(IconlyBold.shield_done, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'text_scan.analyze_btn'.tr().toUpperCase(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: Icon(
                        IconlyLight.camera,
                        size: 18,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      label: Text(
                        'general.retake'.tr(),
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.getBorderColor(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _showEditor = false;
                          _textController.clear();
                        });
                      },
                      icon: Icon(
                        IconlyLight.close_square,
                        size: 18,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      label: Text(
                        'general.clear'.tr(),
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.getBorderColor(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
