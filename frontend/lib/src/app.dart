import 'package:flutter/material.dart';

import 'domain/persona_diagnosis.dart';
import 'domain/telemetry_event.dart';
import 'infrastructure/api_client.dart';
import 'infrastructure/share_receiver.dart';
import 'infrastructure/telemetry_queue.dart';
import 'infrastructure/token_store.dart';
import 'presentation/diagnosis_screen.dart';
import 'presentation/generate_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Permy',
      theme: ThemeData(useMaterial3: true),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final ApiClient _apiClient;
  late final TelemetryQueue _telemetryQueue;
  final ShareReceiver _shareReceiver = const ShareReceiver();

  bool _loading = true;
  bool _needsDiagnosis = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      tokenStore: const SecureTokenStore(),
    );
    _telemetryQueue = TelemetryQueue(apiClient: _apiClient);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // バックグラウンド/終了時にキューをフラッシュ
      _telemetryQueue.flush();
    }
  }

  Future<void> _bootstrap() async {
    await _apiClient.bootstrapAuth();

    // app_opened イベント送信
    _telemetryQueue.enqueue(
      const AppOpenedEvent(
        appVersion: '1.0.0',
        os: 'android', // TODO: Platform.isAndroid/isIOS で分岐
        deviceClass: 'phone',
      ),
    );

    final settings = await _apiClient.getSettings();
    final trueType = settings.settings['true_self_type']?.toString();
    final nightType = settings.settings['night_self_type']?.toString();

    if (!mounted) return;
    setState(() {
      _needsDiagnosis =
          (trueType == null || trueType.isEmpty) ||
          (nightType == null || nightType.isEmpty);
      _loading = false;
    });
  }

  Future<void> _onDiagnosisCompleted(List<DiagnosisAnswer> answers) async {
    await _apiClient.completeDiagnosis(answers);
    if (!mounted) return;
    setState(() {
      _needsDiagnosis = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_needsDiagnosis) {
      return DiagnosisScreen(onCompleted: _onDiagnosisCompleted);
    }

    return GenerateScreen(
      apiClient: _apiClient,
      shareReceiver: _shareReceiver,
      telemetryQueue: _telemetryQueue,
    );
  }
}
