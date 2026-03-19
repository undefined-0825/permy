import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/widgets/top_brand_header.dart';

void main() {
  testWidgets('leading未指定時は戻るボタンを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: TopBrandHeader(), body: SizedBox.shrink()),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('ロゴ画像はcontainで表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: TopBrandHeader(), body: SizedBox.shrink()),
      ),
    );

    final logoFinder = find.byWidgetPredicate((Widget widget) {
      if (widget is! Image) {
        return false;
      }
      final provider = widget.image;
      return provider is AssetImage &&
          provider.assetName == 'assets/images/top/logo.png';
    });

    expect(logoFinder, findsOneWidget);
    final logo = tester.widget<Image>(logoFinder);
    expect(logo.fit, BoxFit.contain);
  });

  testWidgets('leading指定時は指定ウィジェットを優先する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TopBrandHeader(leading: Icon(Icons.close)),
          body: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
