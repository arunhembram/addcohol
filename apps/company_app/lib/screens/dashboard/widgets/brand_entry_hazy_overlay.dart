import 'dart:ui';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/company_state_providers.dart';

/// Full-screen frosted-glass hazy overlay that prompts the company/visitor
/// for their Brand Name while displaying the live dashboard blurred in the background.
class BrandEntryHazyOverlay extends ConsumerStatefulWidget {
  const BrandEntryHazyOverlay({super.key});

  @override
  ConsumerState<BrandEntryHazyOverlay> createState() => _BrandEntryHazyOverlayState();
}

class _BrandEntryHazyOverlayState extends ConsumerState<BrandEntryHazyOverlay> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  static const List<Map<String, dynamic>> _quickBrands = [
    {'name': 'boAt', 'icon': Icons.headphones_rounded, 'color': Color(0xFFE11D48)},
    {'name': 'Zomato', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFE23744)},
    {'name': 'Pepsi', 'icon': Icons.local_drink_rounded, 'color': Color(0xFF004B93)},
    {'name': 'Amul', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF1E3A8A)},
    {'name': 'Cadbury', 'icon': Icons.cake_rounded, 'color': Color(0xFF581C87)},
    {'name': 'Britannia', 'icon': Icons.cookie_rounded, 'color': Color(0xFFDC2626)},
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(previewBrandNameProvider);
    _controller = TextEditingController(text: current);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitBrand(String brand) {
    final clean = brand.trim();
    if (clean.isNotEmpty) {
      ref.read(previewBrandNameProvider.notifier).state = clean;
    }
    ref.read(isBrandModalOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        // FROSTED GLASS HAZY BLUR: Creates the blurry hazy view of the home page underneath
        filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Pill & Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'DYNAMIC IN-STORE PREVIEW',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close and view dashboard',
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.neutral600),
                          onPressed: () => _submitBrand(_controller.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Title
                    const Text(
                      'Enter Your Brand Name',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Preview your customized advertisement live on acrylic tabletop checkout stands across 3,400+ retail stores in your target zones.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Brand Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.neutral50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (val) => _submitBrand(val),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Zomato, Amul, boAt, Pepsi...',
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.normal,
                            color: AppColors.neutral400,
                          ),
                          prefixIcon: const Icon(
                            Icons.branding_watermark_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: AppColors.neutral500),
                                  onPressed: () {
                                    setState(() {
                                      _controller.clear();
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Quick Brand Suggestion Chips
                    const Text(
                      'Or try one of these popular brands with 1-click:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickBrands.map((b) {
                        final name = b['name'] as String;
                        final isSelected = _controller.text.trim().toLowerCase() == name.toLowerCase();
                        final color = b['color'] as Color;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _controller.text = name;
                            });
                            _submitBrand(name);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.12) : AppColors.neutral100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : AppColors.neutral300,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  b['icon'] as IconData,
                                  size: 14,
                                  color: isSelected ? color : AppColors.neutral700,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? color : AppColors.neutral800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Main Submit CTA Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () => _submitBrand(_controller.text),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _controller.text.trim().isEmpty
                                ? 'Preview On Stand ➔'
                                : 'Preview "${_controller.text.trim()}" on Stand ➔',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
