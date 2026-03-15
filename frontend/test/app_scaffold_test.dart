import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/src/presentation/widgets/top_brand_header.dart';

void main() {
  testWidgets('appBar ありでも body を表示できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(appBar: TopBrandHeader(), body: Text('body-start')),
      ),
    );

    expect(find.text('body-start'), findsOneWidget);
  });
}
