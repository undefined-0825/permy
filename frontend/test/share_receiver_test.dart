import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sample_app/src/infrastructure/share_receiver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('permy/share_receiver/methods');
  late StreamController<List<SharedMediaFile>> mediaController;

  setUp(() {
    mediaController = StreamController<List<SharedMediaFile>>.broadcast();
    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[],
      mediaStream: mediaController.stream,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (_) async => null);
  });

  tearDown(() async {
    await mediaController.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('共有された txt ファイルの本文を読み取る', () async {
    final directory = await Directory.systemTemp.createTemp('permy-share-');
    final file = File('${directory.path}${Platform.pathSeparator}line.txt');
    await file.writeAsString('1行目\n2行目');

    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[
        SharedMediaFile(
          path: file.path,
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ],
      mediaStream: mediaController.stream,
    );

    final receiver = const ShareReceiver();
    final payload = await receiver.getInitialPayload();

    expect(payload?.text, '1行目\n2行目');
    expect(payload?.fileName, 'line.txt');

    await directory.delete(recursive: true);
  });

  test('共有テキストはそのまま本文として扱う', () async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[
        SharedMediaFile(
          path: 'こんにちは\nテスト共有',
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ],
      mediaStream: mediaController.stream,
    );

    final receiver = const ShareReceiver();
    final payload = await receiver.getInitialPayload();

    expect(payload?.text, 'こんにちは\nテスト共有');
    expect(payload?.fileName, isNull);
  });

  test('Android フォールバックで共有本文を受け取る', () async {
    final methodCalls = <String>[];

    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[
        SharedMediaFile(
          path:
              'content://jp.naver.line.android.line.common.FileProvider/chat.txt',
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ],
      mediaStream: mediaController.stream,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          methodCalls.add(call.method);
          if (call.method == 'getInitialSharePayload') {
            return <String, dynamic>{
              'text': 'LINE本文',
              'fileName': '[LINE] test.txt',
            };
          }
          return null;
        });

    final receiver = const ShareReceiver();
    final payload = await receiver.getInitialPayload();

    expect(payload?.text, 'LINE本文');
    expect(payload?.fileName, '[LINE] test.txt');
    expect(methodCalls, contains('resetInitialSharePayload'));
  });

  test('存在しないファイルパス文字列は本文扱いせずandroidフォールバックを使う', () async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[
        SharedMediaFile(
          path:
              '/data/user/0/jp.naver.line.android/cache/chat_export_20260301_120000.txt',
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ],
      mediaStream: mediaController.stream,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          if (call.method == 'getInitialSharePayload') {
            return <String, dynamic>{
              'text': 'LINE本文(native)',
              'fileName': '[LINE] fallback.txt',
            };
          }
          return null;
        });

    final receiver = const ShareReceiver();
    final payload = await receiver.getInitialPayload();

    expect(payload?.text, 'LINE本文(native)');
    expect(payload?.fileName, '[LINE] fallback.txt');
  });

  test('ネイティブ本文がある場合はプラグイン値より優先する', () async {
    ReceiveSharingIntent.setMockValues(
      initialMedia: <SharedMediaFile>[
        SharedMediaFile(
          path: 'content',
          type: SharedMediaType.text,
          mimeType: 'text/plain',
        ),
      ],
      mediaStream: mediaController.stream,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          if (call.method == 'getInitialSharePayload') {
            return <String, dynamic>{
              'text': 'LINE本文(native-priority)',
              'fileName': '[LINE] native.txt',
            };
          }
          return null;
        });

    final receiver = const ShareReceiver();
    final payload = await receiver.getInitialPayload();

    expect(payload?.text, 'LINE本文(native-priority)');
    expect(payload?.fileName, '[LINE] native.txt');
  });
}
