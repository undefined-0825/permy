import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';

/// 「きみはどっち？」ダイアログ
/// LINE 2名トーク履歴からユーザー自身の名前を選択させる
class LineNameDialog extends StatefulWidget {
  const LineNameDialog({super.key, required this.names});

  final List<String> names;

  /// ダイアログを表示し、選択されたLINE名を返す。キャンセル時は null。
  static Future<String?> show(BuildContext context, List<String> names) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LineNameDialog(names: names),
    );
  }

  @override
  State<LineNameDialog> createState() => _LineNameDialogState();
}

class _LineNameDialogState extends State<LineNameDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('きみはどっち？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('このトーク履歴の中で、きみはどっちかな？', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...widget.names.map(
                  (name) => RadioListTile<String>(
                    title: Text(name, style: AppTextStyles.body),
                    value: name,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('あとで'),
        ),
        AppButton(
          text: '確定',
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
