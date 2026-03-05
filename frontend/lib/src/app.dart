import 'package:flutter/material.dart';

import 'infrastructure/api_client.dart';
import 'infrastructure/share_receiver.dart';
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

class _AppRootState extends State<AppRoot> {
  late final ApiClient _apiClient;
  final ShareReceiver _shareReceiver = const ShareReceiver();

  bool _loading = true;
  bool _needsDiagnosis = false;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      tokenStore: const SecureTokenStore(),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _apiClient.bootstrapAuth();
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

  Future<void> _onDiagnosisCompleted(List<int> answers) async {
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

    return GenerateScreen(apiClient: _apiClient, shareReceiver: _shareReceiver);
  }
}
