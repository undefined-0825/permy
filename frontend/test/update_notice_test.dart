import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/core/theme/app_theme.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/src/presentation/update_notice_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.lightTheme, home: child);
}

void main() {
  group('UpdateNoticeScreen', () {
    testWidgets('リリースノートのタイトルと本文が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const UpdateNoticeScreen(
            latestVersion: '2.0.0',
            storeUrl: 'https://play.google.com/store',
            releaseNoteTitle: 'v2.0 アップデート',
            releaseNoteBody: '・新機能Aを追加しました\n・バグを修正しました',
          ),
        ),
      );

      expect(find.text('v2.0 アップデート'), findsOneWidget);
      expect(find.textContaining('新機能A'), findsOneWidget);
      expect(find.text('バージョンアップする'), findsOneWidget);
    });

    testWidgets('リリースノートが空のときはデフォルト文言を表示する', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const UpdateNoticeScreen(
            latestVersion: '2.0.0',
            storeUrl: 'https://play.google.com/store',
            releaseNoteTitle: '',
            releaseNoteBody: '',
          ),
        ),
      );

      expect(find.text('バージョンアップのお知らせ'), findsOneWidget);
      expect(find.textContaining('2.0.0'), findsWidgets);
      expect(find.text('バージョンアップする'), findsOneWidget);
    });

    testWidgets('強制更新時は戻るボタンが無効', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const UpdateNoticeScreen(
            latestVersion: '2.0.0',
            storeUrl: 'https://play.google.com/store',
            releaseNoteTitle: 'テスト',
            releaseNoteBody: 'テスト内容',
            isForced: true,
          ),
        ),
      );

      // PopScope(canPop: false) の検証
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
      // 「あとで」は表示されない
      expect(find.text('あとで'), findsNothing);
    });

    testWidgets('任意更新時は「あとで」スキップ導線が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const UpdateNoticeScreen(
            latestVersion: '2.0.0',
            storeUrl: 'https://play.google.com/store',
            releaseNoteTitle: 'テスト',
            releaseNoteBody: 'テスト内容',
            isForced: false,
          ),
        ),
      );

      // canPop: true（任意は閉じられる）
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isTrue);
      // 「あとで」ボタンが表示される
      expect(find.text('あとで'), findsOneWidget);
    });

    testWidgets('storeUrlが空のときボタンが無効になる', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const UpdateNoticeScreen(
            latestVersion: '2.0.0',
            storeUrl: '',
            releaseNoteTitle: 'テスト',
            releaseNoteBody: 'テスト内容',
          ),
        ),
      );

      // AppButton の enabled プロパティ確認
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.enabled, isFalse);
    });
  });
}
