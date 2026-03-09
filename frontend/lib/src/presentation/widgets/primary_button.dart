import 'package:flutter/material.dart';

/// プライマリボタン（design_rule.md セクション5.2準拠）
/// - グラデーション背景 (#FFB3C1 → #FF8FAB)
/// - Inner Glow効果 (boxShadow)
/// - 角丸 12pt
/// - 無効化時: #E6DCE8
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFFFFB3C1), Color(0xFFFF8FAB)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: isEnabled ? null : const Color(0xFFE6DCE8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFFFFB3C1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFFFFF),
                      ),
                    ),
                  )
                : DefaultTextStyle(
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}
