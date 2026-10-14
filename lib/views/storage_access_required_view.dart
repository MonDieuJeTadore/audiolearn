import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import 'screen_mixin.dart';

/// Écran affiché lorsque l'utilisateur a refusé l'accès à tous
/// les fichiers, autorisation indispensable à AudioLearn.
class StorageAccessRequiredView extends StatefulWidget {
  final Future<void> Function() onGranted;

  const StorageAccessRequiredView({
    super.key,
    required this.onGranted,
  });

  @override
  State<StorageAccessRequiredView> createState() =>
      _StorageAccessRequiredViewState();
}

class _StorageAccessRequiredViewState extends State<StorageAccessRequiredView>
    with WidgetsBindingObserver {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour des Paramètres (y compris si l'utilisateur y est
  /// allé par lui-même), on revérifie l'autorisation.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startIfGranted();
    }
  }

  Future<void> _startIfGranted() async {
    if (_starting) return;

    if (await Permission.manageExternalStorage.isGranted) {
      _starting = true;
      await widget.onGranted();
    }
  }

  Future<void> _openAllFilesAccessSettings() async {
    // Ouvre directement la page "Accès à tous les fichiers"
    await Permission.manageExternalStorage.request();
    await _startIfGranted();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioLearn',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ScreenMixin.themeDataDark,
      home: Builder(
        builder: (context) {
          final AppLocalizations l10n = AppLocalizations.of(context)!;

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_off, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      l10n.storageAccessRequiredTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.storageAccessRequiredExplanation,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      key: const Key('openAllFilesAccessSettingsButton'),
                      onPressed: _openAllFilesAccessSettings,
                      child: Text(l10n.storageAccessRequiredButton),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}