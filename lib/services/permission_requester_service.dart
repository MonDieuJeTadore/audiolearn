import 'package:permission_handler/permission_handler.dart';

import 'android_battery_optimization_service.dart';

class PermissionRequesterService {
  /// Retourne true si l'accès à tous les fichiers est accordé,
  /// condition indispensable pour accéder au répertoire de l'app.
  /// 
  /// Requires adding the lines below to the main and debug AndroidManifest.xml
  /// files in order to work on S20 - Android 13 !
  ///     `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>`
  ///     `<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>`
  ///     `<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>`
  static Future<bool> requestMultiplePermissions() async {
    // 1. Permission critique : accès à tous les fichiers
    //    (Android 11 / API 30 et plus). Ouvre les Paramètres et
    //    attend le retour de l'utilisateur.
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    // 2. Permissions d'exécution classiques (dialogues système)
    await [
      Permission.microphone,
      Permission.mediaLibrary,
      Permission.audio,
      Permission.videos,
      Permission.photos,
      Permission.notification,
    ].request();

    // 3. Request battery optimization exemption after other permissions
    final bool isExempt = await AndroidBatteryOptimizationService
        .isIgnoringBatteryOptimizations();

    if (!isExempt) {
      await AndroidBatteryOptimizationService
          .requestIgnoreBatteryOptimizations();
    }

    return Permission.manageExternalStorage.isGranted;
  }
}
