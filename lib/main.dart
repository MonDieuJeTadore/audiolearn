import 'dart:io';

import 'package:audiolearn/viewmodels/audio_extractor_vm.dart';
import 'package:audiolearn/viewmodels/comment_vm.dart';
import 'package:audiolearn/viewmodels/date_format_vm.dart';
import 'package:audiolearn/viewmodels/extract_mp3_audio_player_vm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';

import 'constants.dart';
import 'services/help_data_service.dart';
import 'utils/ui_util.dart';
import 'viewmodels/picture_vm.dart';
import 'viewmodels/playlist_list_vm.dart';
import 'viewmodels/audio_download_vm.dart';
import 'viewmodels/audio_player_vm.dart';
import 'viewmodels/language_provider_vm.dart';
import 'viewmodels/text_to_speech_vm.dart';
import 'viewmodels/theme_provider_vm.dart';
import 'viewmodels/warning_message_vm.dart';
import 'services/settings_data_service.dart';
import 'utils/dir_util.dart';
import 'views/my_home_page.dart';
import 'views/screen_mixin.dart';

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure Flutter bindings are initialized.

  bool isTest = true; // Must be set to false instead of true before
  //                     generating the Android as well as the Windows
  //                     version of the app so that the app accesses the
  //                     correct application directory and not the test
  //                     directory. Must also be set to false when
  //                     debugging the application on the smartphone
  //                     but not when debugging on the emulator.

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Without this code, 'audiolearn' is displayed at the top left
    // of the app window instead of 'AudioLearn'.
    await windowManager.ensureInitialized();
    windowManager.setPreventClose(true); // intercept the close button
    WindowOptions windowOptions = const WindowOptions(
      title: 'AudioLearn',
    );
    windowManager.waitUntilReadyToShow(windowOptions);
  }

  String applicationPath = '';

  // Obtain or create the application directory (no permission request here)
  applicationPath = DirUtil.getApplicationPath(
    isTest: isTest,
  );

  // Setup SettingsDataService
  final SettingsDataService settingsDataService = SettingsDataService(
    isTest: isTest,
  );

  await settingsDataService.loadSettingsFromFile(
    settingsJsonPathFileName:
        '$applicationPath${Platform.pathSeparator}$kSettingsFileName',
  );

  // Now proceed with setting up the app window size and position if needed
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _setWindowsAppSizeAndPosition(
      settingsDataService: settingsDataService,
    );
  }

  // Initialize HelpDataService. This must be done before using it.
  await HelpDataService().initialize();
  await HelpDataService().clearLastHelpPosition();

  // Run the app
  runApp(MainApp(
    settingsDataService: settingsDataService,
  ));
}

/// If app runs on Windows, Linux or MacOS, set the app size
/// and position.
Future<void> _setWindowsAppSizeAndPosition({
  required SettingsDataService settingsDataService,
}) async {
  await getScreenList().then((List<Screen> screens) {
    final Screen screen = screens.first;

    // scaleFactor is the device pixel ratio, available without a
    // Flutter context. Stored values are in physical pixels, so we
    // divide by scaleFactor to get the logical pixels that
    // setWindowFrame() expects.
    final double scaleFactor = screen.scaleFactor;

    double posX = (settingsDataService.get(
            settingType: SettingType.appPosition,
            settingSubType: AppPosition.topX) as double) *
        scaleFactor;

    if (posX < 0.0) {
      posX = 0.0; // Ensure the window is not positioned off-screen
    }

    double posY = (settingsDataService.get(
            settingType: SettingType.appPosition,
            settingSubType: AppPosition.topY) as double) *
        scaleFactor;

    if (posY < 0.0) {
      posY = 0.0; // Ensure the window is not positioned off-screen
    }

    final double windowWidth = (settingsDataService.get(
            settingType: SettingType.appPosition,
            settingSubType: AppPosition.width) as double) *
        scaleFactor;
    final double windowHeight = (settingsDataService.get(
            settingType: SettingType.appPosition,
            settingSubType: AppPosition.height) as double) *
        scaleFactor;

    final Rect windowRect =
        Rect.fromLTWH(posX, posY, windowWidth, windowHeight);
    setWindowFrame(windowRect);
  });
}

class MainApp extends StatelessWidget with ScreenMixin {
  final SettingsDataService _settingsDataService;

  MainApp({
    required SettingsDataService settingsDataService,
    super.key,
  }) : _settingsDataService = settingsDataService;

  @override
  Widget build(BuildContext context) {
    final WarningMessageVM warningMessageVM = WarningMessageVM();

    final AudioDownloadVM audioDownloadVM = AudioDownloadVM(
      warningMessageVM: warningMessageVM,
      settingsDataService: _settingsDataService,
    );

    final CommentVM commentVM = CommentVM(
      isTest: _settingsDataService.isTest,
    );

    final PictureVM pictureVM = PictureVM(
      settingsDataService: _settingsDataService,
    );

    final PlaylistListVM playlistListVM = PlaylistListVM(
      warningMessageVM: warningMessageVM,
      audioDownloadVM: audioDownloadVM,
      commentVM: commentVM,
      pictureVM: pictureVM,
      settingsDataService: _settingsDataService,
    );

    final TextToSpeechVM textToSpeechVM = TextToSpeechVM(
      settingsDataService: _settingsDataService,
      playlistListVM: playlistListVM,
      commentVM: commentVM,
    );

    final AudioPlayerVM audioPlayerVM = AudioPlayerVM(
      settingsDataService: _settingsDataService,
      playlistListVM: playlistListVM,
      commentVM: commentVM,
    );

    // globalAudioPlayerVM is defined in ScreenMixin
    globalAudioPlayerVM = audioPlayerVM;

    // calling getUpToDateSelectablePlaylists() loads all the
    // playlist json files from the app dir and so enables
    // playlistListVM to know which playlists are
    // selected and which are not
    playlistListVM.getUpToDateSelectablePlaylists();

    // must be called after
    // playlistListVM.getUpToDateSelectablePlaylists()
    // otherwise the list of selected playlists is empty instead
    // of containing one selected playlist (as valid now)

    // not necessary
    // globalAudioPlayerVM.setCurrentAudioFromSelectedPlaylist();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => audioDownloadVM),
        ChangeNotifierProvider(
          create: (_) => audioPlayerVM,
        ),
        ChangeNotifierProvider(
          create: (_) => ExtractMp3AudioPlayerVM(),
        ),
        ChangeNotifierProvider(
          create: (_) => AudioExtractorVM(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProviderVM(
            appSettings: _settingsDataService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProviderVM(
            settingsDataService: _settingsDataService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => playlistListVM),
        ChangeNotifierProvider(create: (_) => warningMessageVM),
        ChangeNotifierProvider(create: (_) => commentVM),
        ChangeNotifierProvider(
            create: (_) => DateFormatVM(
                  settingsDataService: _settingsDataService,
                )),
        ChangeNotifierProvider(create: (_) => pictureVM),
        ChangeNotifierProvider(create: (_) => textToSpeechVM),
      ],
      child: Consumer2<ThemeProviderVM, LanguageProviderVM>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            navigatorKey: UiUtil.globalNavigatorKey,
            title: 'AudioLearn',
            // title: AppLocalizations.of(context)!.title,
            locale: languageProvider.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: themeProvider.currentTheme == AppTheme.dark
                ? ScreenMixin.themeDataDark
                : ScreenMixin.themeDataLight,
            home: MyHomePage(
              settingsDataService: _settingsDataService,
            ),
          );
        },
      ),
    );
  }
}
