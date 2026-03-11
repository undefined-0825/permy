import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 全画面共通ブランドヘッダー。Scaffold.appBar に直接セットする。
class TopBrandHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopBrandHeader({super.key, this.actions, this.leading});

  final List<Widget>? actions;
  final Widget? leading;

  static const double _catSize = 64.0;

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
            final logoWidth = constraints.maxWidth * 0.55;
            return SizedBox(
              height: _catSize,
              child: Stack(
                children: [
                  // 中央：猫＋ロゴ
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SvgPicture.asset(
                          'assets/images/top/permy_cat_silhouette.svg',
                          width: _catSize,
                          height: _catSize,
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/images/top/logo.png',
                          width: logoWidth,
                          fit: BoxFit.fitWidth,
                        ),
                      ],
                    ),
                  ),
                  // 左：leadingボタン
                  if (leading != null)
                    Positioned(
                      left: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(child: leading!),
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
