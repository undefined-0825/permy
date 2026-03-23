import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharePayload {
  SharePayload({required this.text, required this.fileName});

  final String text;
  final String? fileName;
}

abstract class ShareInput {
  Future<SharePayload?> getInitialPayload();

  Stream<SharePayload> get payloadStream;
}

class ShareReceiver implements ShareInput {
  const ShareReceiver();

  static const MethodChannel _methodChannel = MethodChannel(
    'permy/share_receiver/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'permy/share_receiver/events',
  );

  @override
  Future<SharePayload?> getInitialPayload() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();

    try {
      final nativePayload = await _getNativeInitialPayload();
      if (nativePayload != null) {
        return nativePayload;
      }

      return _buildFromMedia(files);
    } finally {
      await _resetPluginInitialMedia();
      await _resetNativeInitialPayload();
    }
  }

  @override
  Stream<SharePayload> get payloadStream {
    return Stream<SharePayload>.multi((controller) {
      String? lastSignature;

      void emitPayload(SharePayload payload) {
        final signature = '${payload.fileName ?? ''}\n${payload.text}';
        if (signature == lastSignature) {
          return;
        }
        lastSignature = signature;
        controller.add(payload);
      }

      final mediaSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .asyncMap(_buildFromMedia)
          .listen((payload) {
            if (payload == null) {
              return;
            }
            emitPayload(payload);
          }, onError: controller.addError);

      final nativeSubscription = _eventChannel
          .receiveBroadcastStream()
          .map(_payloadFromDynamic)
          .listen((payload) {
            if (payload == null) {
              return;
            }
            emitPayload(payload);
          }, onError: controller.addError);

      controller.onCancel = () async {
        await mediaSubscription.cancel();
        await nativeSubscription.cancel();
      };
    });
  }

  Future<SharePayload?> _buildFromMedia(List<SharedMediaFile> files) async {
    for (final file in files) {
      final trimmed = await _extractText(file);
      if (trimmed == null || trimmed.isEmpty) {
        continue;
      }

      return SharePayload(text: trimmed, fileName: _resolveFileName(file));
    }
    return null;
  }

  Future<SharePayload?> _getNativeInitialPayload() async {
    try {
      final payload = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getInitialSharePayload',
      );
      return _payloadFromMap(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resetPluginInitialMedia() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
  }

  Future<void> _resetNativeInitialPayload() async {
    try {
      await _methodChannel.invokeMethod<void>('resetInitialSharePayload');
    } catch (_) {}
  }

  Future<String?> _extractText(SharedMediaFile file) async {
    final source = file.path.trim();
    if (source.isEmpty) {
      return null;
    }

    if (file.type == SharedMediaType.text && !await File(source).exists()) {
      if (_looksLikeUri(source) || _looksLikeFilePath(source)) {
        return null;
      }
      return source;
    }

    return _tryReadText(source);
  }

  String? _resolveFileName(SharedMediaFile file) {
    final source = file.path.trim();
    if (source.isEmpty) {
      return null;
    }

    if (file.type == SharedMediaType.text &&
        !source.startsWith('content://') &&
        !File(source).existsSync()) {
      return null;
    }

    final uri = Uri.tryParse(source);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    final segments = source.split(Platform.pathSeparator);
    return segments.isEmpty ? null : segments.last;
  }

  SharePayload? _payloadFromDynamic(dynamic value) {
    if (value is Map) {
      return _payloadFromMap(Map<String, dynamic>.from(value));
    }
    return null;
  }

  SharePayload? _payloadFromMap(Map<String, dynamic>? payload) {
    final text = (payload?['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final fileName = (payload?['fileName'] as String?)?.trim();
    return SharePayload(
      text: text,
      fileName: fileName == null || fileName.isEmpty ? null : fileName,
    );
  }

  Future<String?> _tryReadText(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeUri(String value) {
    return value.startsWith('content://') || value.startsWith('file://');
  }

  bool _looksLikeFilePath(String value) {
    return value.startsWith('/') ||
        value.startsWith('\\') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
  }
}
