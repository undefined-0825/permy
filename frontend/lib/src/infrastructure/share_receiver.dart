import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharePayload {
  SharePayload({
    required this.text,
    required this.fileName,
  });

  final String text;
  final String? fileName;
}

abstract class ShareInput {
  Future<SharePayload?> getInitialPayload();

  Stream<SharePayload> get payloadStream;
}

class ShareReceiver implements ShareInput {
  const ShareReceiver();

  @override
  Future<SharePayload?> getInitialPayload() async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    return _buildFromMedia(files);
  }

  @override
  Stream<SharePayload> get payloadStream {
    final mediaStream = ReceiveSharingIntent.instance.getMediaStream().asyncMap(
      _buildFromMedia,
    );

    return mediaStream.where((payload) => payload != null).cast<SharePayload>();
  }

  Future<SharePayload?> _buildFromMedia(List<SharedMediaFile> files) async {
    for (final file in files) {
      final path = file.path;
      if (path.isEmpty || !path.toLowerCase().endsWith('.txt')) {
        continue;
      }

      final text = await File(path).readAsString();
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      return SharePayload(text: trimmed, fileName: path.split(Platform.pathSeparator).last);
    }
    return null;
  }
}
