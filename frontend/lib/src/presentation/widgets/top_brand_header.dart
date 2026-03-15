import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sample_app/core/theme/app_spacing.dart';

/// 全画面共通ブランドヘッダー。Scaffold.appBar に直接セットする。
class TopBrandHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopBrandHeader({super.key, this.actions, this.leading});

  final List<Widget>? actions;
  final Widget? leading;

  static const double _catSize = 64.0;
  static const double _logoHeight = 56.0;

  @override
  Size get preferredSize => const Size.fromHeight(_catSize);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // constraints.maxWidth = 画面幅（AppBar制約なし）
            final logoMaxWidth = constraints.maxWidth * 0.55;
            final effectiveLeading = leading ?? const BackButton();
            return SizedBox(
              height: _catSize,
              child: Stack(
                children: [
                  // 中央：猫＋ロゴ
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/top/permy_cat_silhouette.svg',
                          width: _catSize,
                          height: _catSize,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: logoMaxWidth),
                          child: Image.asset(
                            'assets/images/top/logo.png',
                            height: _logoHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 左：leadingボタン
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(child: effectiveLeading),
                  ),
                  // 右：actionsボタン群
                  if (actions != null && actions!.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
