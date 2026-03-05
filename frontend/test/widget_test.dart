import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/share_receiver.dart';
import 'package:sample_app/src/presentation/generate_screen.dart';

class _FakeApiClient implements AppApiClient {
  @override
  Future<void> bootstrapAuth() async {}

  @override
  Future<void> completeDiagnosis(List<int> answers) async {}

  @override
  Future<SettingsSnapshot> getSettings() async {
    return SettingsSnapshot(settings: <String, dynamic>{}, etag: 'test');
  }

  @override
  Future<GenerateResult> generate({required String historyText, int comboId = 0}) async {
    return GenerateResult(
      candidates: [
        Candidate(label: 'A', text: '返信案A'),
        Candidate(label: 'B', text: '返信案B'),
        Candidate(label: 'C', text: '返信案C'),
      ],
      plan: 'free',
      daily: DailyInfo(limit: 3, used: 1, remaining: 2),
    );
  }
}

class _FakeShareInput implements ShareInput {
  _FakeShareInput(this.initialPayload);

  final SharePayload? initialPayload;

  @override
  Future<SharePayload?> getInitialPayload() async => initialPayload;

  @override
  Stream<SharePayload> get payloadStream => const Stream.empty();
}

void main() {
  testWidgets('手入力欄なしで共有待ちを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(null),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('共有待ち'), findsOneWidget);
  });

  testWidgets('共有済みなら生成でA/B/Cを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('返信案を作る'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A: 返信案A'), findsOneWidget);
    expect(find.textContaining('B: 返信案B'), findsOneWidget);
    expect(find.textContaining('C: 返信案C'), findsOneWidget);
  });
}
