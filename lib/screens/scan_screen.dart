import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/scanner_provider.dart';
import '../services/geo_ad_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';
import '../theme/app_fonts.dart';

/// Camera scanner screen with barcode detection overlay.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GeoAdService.instance.refreshNearbyAds();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_cameraController != null)
            MobileScanner(controller: _cameraController!, onDetect: _onDetect),

          // Dark overlay with cutout
          _buildScanOverlay(),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        IconlyLight.arrow_left,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'home.scan_barcode'.tr(),
                      style: AppFonts.primary(
                        context,
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _cameraController?.toggleTorch(),
                      icon: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom instruction
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'home.align_barcode'.tr(),
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'home.auto_scan'.tr(),
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48), // Padding from bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: ScanOverlayPainter(borderOpacity: _pulseAnimation.value),
        );
      },
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessing = true);

    context.read<ScannerProvider>().processBarcode(
      barcode,
      language: LanguageHelper.getLanguageName(context),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    ).then((_) {
      if (mounted) setState(() => _isProcessing = false);
    });
  }
}

/// Custom painter for the scan area overlay with animated border.
class ScanOverlayPainter extends CustomPainter {
  final double borderOpacity;

  ScanOverlayPainter({required this.borderOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const scanWidth = 280.0;
    const scanHeight = 180.0;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: scanWidth, height: scanHeight),
      const Radius.circular(16),
    );

    // Dark overlay
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // Animated border
    final borderPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: borderOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(scanRect, borderPaint);

    // Corner accents
    final cornerPaint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerSize = 30.0;
    final rect = scanRect.outerRect;

    // Top-left
    canvas.drawLine(
      Offset(rect.left + 16, rect.top),
      Offset(rect.left + 16 + cornerSize, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top + 16),
      Offset(rect.left, rect.top + 16 + cornerSize),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right - 16, rect.top),
      Offset(rect.right - 16 - cornerSize, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top + 16),
      Offset(rect.right, rect.top + 16 + cornerSize),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left + 16, rect.bottom),
      Offset(rect.left + 16 + cornerSize, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom - 16),
      Offset(rect.left, rect.bottom - 16 - cornerSize),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right - 16, rect.bottom),
      Offset(rect.right - 16 - cornerSize, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom - 16),
      Offset(rect.right, rect.bottom - 16 - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(ScanOverlayPainter oldDelegate) =>
      oldDelegate.borderOpacity != borderOpacity;
}
