import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_error_message_box.dart';
import 'domain/app_versioning.dart';
import 'domain/models.dart';
import 'domain/persona_diagnosis.dart';
import 'domain/telemetry_event.dart';
import 'infrastructure/api_client.dart';
import 'infrastructure/purchase_service.dart';
import 'infrastructure/share_receiver.dart';
import 'infrastructure/telemetry_queue.dart';
import 'infrastructure/token_store.dart';
import 'presentation/diagnosis_screen.dart';
import 'presentation/generate_screen.dart';
import 'presentation/onboarding_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String _backgroundImagePath =
      'assets/images/backgrounds/background_pink.png';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Permy',
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_backgroundImagePath, fit: BoxFit.cover),
            ...?child == null ? null : <Widget>[child],
          ],
        );
      },
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
  static const String _renderApiBaseUrl = 'https://permy-backend.onrender.com';
  static const String _localApiBaseUrl = 'http://10.0.2.2:8000';
  static const int _configuredTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 0,
  );

  late final ApiClient _apiClient;
  late final TelemetryQueue _telemetryQueue;
  late final PurchaseService _purchaseService;
  final ShareReceiver _shareReceiver = const ShareReceiver();

  bool _loading = true;
  bool _needsOnboarding = false;
  bool _needsDiagnosis = false;
  bool _initialDiagnosisFlowStarted = false;
  ApiError? _bootstrapError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final fallbackApiBaseUrl = kDebugMode
        ? _localApiBaseUrl
        : _renderApiBaseUrl;
    final apiBaseUrl = configuredApiBaseUrl.trim().isEmpty
        ? fallbackApiBaseUrl
        : configuredApiBaseUrl.trim();
    final timeoutSeconds = _configuredTimeoutSeconds > 0
        ? _configuredTimeoutSeconds
        : (kDebugMode ? 15 : 30);

    _apiClient = ApiClient(
      baseUrl: apiBaseUrl,
      tokenStore: const SecureTokenStore(),
      requestTimeout: Duration(seconds: timeoutSeconds),
      debugLog: (message) {
        if (kDebugMode) {
          debugPrint(message);
        }
      },
    );
    _telemetryQueue = TelemetryQueue(apiClient: _apiClient);
    _purchaseService = PurchaseService(storage: const FlutterSecureStorage());
    _bootstrap();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
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
    try {
      await _apiClient.bootstrapAuth();
      await _purchaseService.initialize();

      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;

      await _checkForAppUpdate(installedVersion);

      // app_opened イベント送信
      _telemetryQueue.enqueue(
        AppOpenedEvent(
          appVersion: installedVersion,
          os: _currentOsName(),
          deviceClass: 'phone',
        ),
      );

      // 初回フラグをチェック
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;

      final settings = await _apiClient.getSettings();
      final trueType = settings.settings['true_self_type']?.toString();
      final nightType = settings.settings['night_self_type']?.toString();

      if (!mounted) return;
      setState(() {
        _needsOnboarding = !hasCompletedOnboarding;
        _needsDiagnosis =
            (trueType == null || trueType.isEmpty) ||
            (nightType == null || nightType.isEmpty);
        _bootstrapError = null;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = ApiError(
          errorCode: 'INTERNAL_ERROR',
          message: '起動処理でエラーが発生したよ',
          httpStatus: 500,
        );
        _loading = false;
      });
    }
  }

  Future<void> _retryBootstrap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _bootstrapError = null;
    });
    await _bootstrap();
  }

  String _bootstrapErrorMessage(ApiError error) {
    switch (error.errorCode) {
      case 'UPSTREAM_TIMEOUT':
        return '接続に時間がかかっているよ。ネットワークを確認して、再試行してね。';
      case 'UPSTREAM_UNAVAILABLE':
        return 'サーバーに接続できなかったよ。回線かDNS設定を確認してね。';
      case 'AUTH_INVALID':
      case 'AUTH_REQUIRED':
        return '認証の初期化に失敗したよ。再試行してね。';
      default:
        return '起動時にエラーが発生したよ。再試行してね。';
    }
  }

  String _currentOsName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<void> _checkForAppUpdate(String installedVersion) async {
    try {
      final info = await _apiClient.getAppVersionInfo();

      final shouldForce =
          compareAppVersions(installedVersion, info.minSupportedVersion) < 0;
      final hasUpdate =
          compareAppVersions(installedVersion, info.latestVersion) < 0;

      if (!hasUpdate || !mounted) return;

      final storeUrl = Platform.isIOS ? info.iosStoreUrl : info.androidStoreUrl;

      await _showUpdateDialog(
        forceUpdate: shouldForce,
        latestVersion: info.latestVersion,
        storeUrl: storeUrl,
      );
    } catch (_) {
      // versionチェック失敗時は起動を継続
    }
  }

  Future<void> _showUpdateDialog({
    required bool forceUpdate,
    required String latestVersion,
    required String storeUrl,
  }) async {
    final canClose = !forceUpdate || storeUrl.isEmpty;

    await showDialog<void>(
      context: context,
      barrierDismissible: canClose,
      builder: (dialogContext) {
        return PopScope(
          canPop: canClose,
          child: AlertDialog(
            title: const Text('アップデートのお知らせ'),
            content: Text(
              forceUpdate
                  ? 'このバージョンでは利用できません。最新バージョン（$latestVersion）へ更新してください。'
                  : '新しいバージョン（$latestVersion）が利用できます。ストアで更新しますか？',
            ),
            actions: [
              if (canClose)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(forceUpdate ? '閉じる' : 'あとで'),
                ),
              TextButton(
                onPressed: () async {
                  if (storeUrl.isNotEmpty) {
                    final uri = Uri.parse(storeUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (canClose && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('ストアを開く'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (!mounted) return;
    setState(() {
      _needsOnboarding = false;
    });
  }

  Future<void> _startInitialDiagnosisFlow() async {
    if (!mounted || _initialDiagnosisFlowStarted) return;

    setState(() {
      _initialDiagnosisFlowStarted = true;
    });

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (diagnosisContext) => DiagnosisScreen(
          onCompleted: (List<DiagnosisAnswer> answers) {
            return _apiClient.completeDiagnosis(answers);
          },
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _initialDiagnosisFlowStarted = false;
      _needsDiagnosis = updated != true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_bootstrapError != null) {
      final error = _bootstrapError!;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppErrorMessageBox(
                title: '起動に失敗したよ',
                message: _bootstrapErrorMessage(error),
                errorCode: error.errorCode,
                detail: error.message,
                actionLabel: '再試行',
                onAction: _retryBootstrap,
              ),
            ),
          ),
        ),
      );
    }

    if (_needsOnboarding) {
      return OnboardingScreen(onCompleted: _onOnboardingCompleted);
    }

    if (_needsDiagnosis) {
      if (!_initialDiagnosisFlowStarted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startInitialDiagnosisFlow();
        });
      }
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return GenerateScreen(
      apiClient: _apiClient,
      shareReceiver: _shareReceiver,
      telemetryQueue: _telemetryQueue,
      purchaseService: _purchaseService,
    );
  }
}
