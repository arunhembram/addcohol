import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatefulWidget {
  final void Function(String barcode) onScanned;
  final String title;
  final String hintText;

  const QrScannerView({
    super.key,
    required this.onScanned,
    this.title = 'Scan QR Code',
    this.hintText = 'Align the QR code within the frame to scan',
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  late final MobileScannerController _controller;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded),
                    tooltip: 'Toggle Flashlight',
                    onPressed: () => _controller.toggleTorch(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded),
                    tooltip: 'Switch Camera',
                    onPressed: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: AppRadii.radiusMd,
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_hasDetected) return;
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final rawValue = barcode.rawValue;
                      if (rawValue != null && rawValue.isNotEmpty) {
                        _hasDetected = true;
                        widget.onScanned(rawValue);
                        break;
                      }
                    }
                  },
                ),
              ),
              // Scanner visual target frame
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                  borderRadius: AppRadii.radiusLg,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            widget.hintText,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
