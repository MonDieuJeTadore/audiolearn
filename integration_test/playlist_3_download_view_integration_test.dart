import 'dart:io';

import 'package:audiolearn/models/audio.dart';
import 'package:audiolearn/viewmodels/comment_vm.dart';
import 'package:audiolearn/viewmodels/date_format_vm.dart';
import 'package:audiolearn/viewmodels/picture_vm.dart';
import 'package:audiolearn/views/widgets/confirm_action_dialog.dart';
import 'package:audiolearn/views/widgets/audio_modification_dialog.dart';
import 'package:audiolearn/views/widgets/comment_add_edit_dialog.dart';
import 'package:audiolearn/views/widgets/comment_list_add_dialog.dart';
import 'package:audiolearn/views/widgets/playlist_comment_list_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;

import 'package:audiolearn/viewmodels/audio_player_vm.dart';
import 'package:audiolearn/constants.dart';
import 'package:audiolearn/models/playlist.dart';
import 'package:audiolearn/services/json_data_service.dart';
import 'package:audiolearn/viewmodels/audio_download_vm.dart';
import 'package:audiolearn/viewmodels/playlist_list_vm.dart';
import 'package:audiolearn/viewmodels/warning_message_vm.dart';
import 'package:audiolearn/services/settings_data_service.dart';
import 'package:audiolearn/utils/dir_util.dart';
import 'package:audiolearn/main.dart' as app;

import '../test/viewmodels/custom_mock_youtube_explode.dart';
import 'integration_test_util.dart';
import 'sort_filter_integration_test.dart';

void main() {
  // Necessary to avoid FatalFailureException (FatalFailureException: Failed
  // to perform an HTTP request to YouTube due to a fatal failure. In most
  // cases, this error indicates that YouTube most likely changed something,
  // which broke the library.
  // If this issue persists, please report it on the project's GitHub page.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  playlistDownloadViewSortFilterIntegrationTest();

  // url used in integration_test/audio_download_vm_integration_test.dart
  // which works:
  // 'https://youtube.com/playlist?list=PLzwWSJNcZTMRB9ILve6fEIS_OHGrV5R2o';
  const String youtubeNewPlaylistTitle =
      'audio_learn_new_youtube_playlist_test';
  group('AudioDownloadVM using CustomMockYoutubeExplode Tests', () {
    late CustomMockYoutubeExplode mockYoutubeExplode;

    setUp(() async {
      mockYoutubeExplode = CustomMockYoutubeExplode();
    });

    testWidgets(
        'Download single video audio in playlist already containing the audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      WarningMessageVM warningMessageVM = WarningMessageVM();
      // MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
      //   warningMessageVM: warningMessageVM,
      //
      // );
      // mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      audioDownloadVM.youtubeExplode = mockYoutubeExplode;

      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: audioDownloadVM,
        commentVM: CommentVM(isTest: true),
        pictureVM: PictureVM(
          settingsDataService: settingsDataService,
        ),
        settingsDataService: settingsDataService,
      );

      // calling getUpToDateSelectablePlaylists() loads all the
      // playlist json files from the app dir and so enables
      // playlistListVM to know which playlists are
      // selected and which are not
      playlistListVM.getUpToDateSelectablePlaylists();

      AudioPlayerVM audioPlayerVM = AudioPlayerVM(
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        commentVM: CommentVM(isTest: true),
      );

      DateFormatVM dateFormatVM = DateFormatVM(
        settingsDataService: settingsDataService,
      );

      await IntegrationTestUtil
          .launchIntegrTestAppEnablingInternetAccessWithMock(
        tester: tester,
        audioDownloadVM: audioDownloadVM,
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        warningMessageVM: warningMessageVM,
        audioPlayerVM: audioPlayerVM,
        dateFormatVM: dateFormatVM,
        forcedLocale: const Locale('en'),
      );

      const String youtubeAudioSourceAndTargetPlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String downloadedSingleVideoAudioTitle =
          'audio learn test short video one';

      // Copy the URL of source playlist audio file which wiil
      // be downloaded to the same (source) playlist, causing a
      // warning error to be displayed ...

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(downloadedSingleVideoAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy video URL popup menu item and tap on it
      final Finder popupCopyVideoUrlMenuItem =
          find.byKey(const Key("popup_copy_youtube_video_url"));

      await tester.tap(popupCopyVideoUrlMenuItem);
      await tester.pumpAndSettle();

      ClipboardData? clipboardData =
          await Clipboard.getData(Clipboard.kTextPlain);
      String singleVideoToDownloadUrl = clipboardData?.text ?? '';

      // Enter the single video URL to download into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        singleVideoToDownloadUrl,
      );
      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, singleVideoToDownloadUrl);

      // Open the target playlist selection dialog by tapping the
      // download single video button
      await tester.tap(find.byKey(const Key('downloadSingleVideoButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Select a Playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be downloaded

      final Finder radioListTile = find
          .ancestor(
            of: find.text(youtubeAudioSourceAndTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      // Check the value of the select one playlist
      // confirmation dialog title
      Text confirmationDialogTitle =
          tester.widget(find.byKey(const Key('confirmationDialogTitleKey')));
      expect(confirmationDialogTitle.data, 'CONFIRMATION');

      final Text confirmationDialogMessageTextWidget = tester
          .widget<Text>(find.byKey(const Key('confirmationDialogMessageKey')));

      expect(confirmationDialogMessageTextWidget.data,
          'Confirm target playlist "$youtubeAudioSourceAndTargetPlaylistTitle" for downloading single video audio in spoken quality.');

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('okButtonKey')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Audio "$downloadedSingleVideoAudioTitle" is contained in file "230628-033811-audio learn test short video one 23-06-10.mp3" present in the target playlist "$youtubeAudioSourceAndTargetPlaylistTitle" directory and so won\'t be redownloaded.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField containing the invalid single
      // video URL was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, singleVideoToDownloadUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        'Download single video audio in playlist not containing the audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      WarningMessageVM warningMessageVM = WarningMessageVM();
      // MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
      //   warningMessageVM: warningMessageVM,
      //
      // );
      // mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      audioDownloadVM.youtubeExplode = mockYoutubeExplode;

      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: audioDownloadVM,
        commentVM: CommentVM(isTest: true),
        pictureVM: PictureVM(
          settingsDataService: settingsDataService,
        ),
        settingsDataService: settingsDataService,
      );

      // calling getUpToDateSelectablePlaylists() loads all the
      // playlist json files from the app dir and so enables
      // playlistListVM to know which playlists are
      // selected and which are not
      playlistListVM.getUpToDateSelectablePlaylists();

      AudioPlayerVM audioPlayerVM = AudioPlayerVM(
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        commentVM: CommentVM(isTest: true),
      );

      DateFormatVM dateFormatVM = DateFormatVM(
        settingsDataService: settingsDataService,
      );

      await IntegrationTestUtil
          .launchIntegrTestAppEnablingInternetAccessWithMock(
        tester: tester,
        audioDownloadVM: audioDownloadVM,
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        warningMessageVM: warningMessageVM,
        audioPlayerVM: audioPlayerVM,
        dateFormatVM: dateFormatVM,
        forcedLocale: const Locale('en'),
      );

      const String localAudioTargetPlaylistTitle = 'local_3';
      const String downloadedSingleVideoAudioTitle =
          'audio learn test short video one';

      // Copy the URL of source playlist audio file which wiil
      // be downloaded to the same (source) playlist, causing a
      // warning error to be displayed ...

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(downloadedSingleVideoAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy video URL popup menu item and tap on it
      final Finder popupCopyVideoUrlMenuItem =
          find.byKey(const Key("popup_copy_youtube_video_url"));

      await tester.tap(popupCopyVideoUrlMenuItem);
      await tester.pumpAndSettle();

      ClipboardData? clipboardData =
          await Clipboard.getData(Clipboard.kTextPlain);
      String singleVideoToDownloadUrl = clipboardData?.text ?? '';

      // Enter the single video URL to download into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        singleVideoToDownloadUrl,
      );
      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, singleVideoToDownloadUrl);

      // Open the target playlist selection dialog by tapping the
      // download single video button
      await tester.tap(find.byKey(const Key('downloadSingleVideoButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Select a Playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be downloaded

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('okButtonKey')));
      await tester.pumpAndSettle();

      // Ensure the URL TextField containing the invalid single
      // video URL was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, singleVideoToDownloadUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('''Executing update playable audio list after manually deleting audio
           files test''', () {
    testWidgets('Manually delete all audio in Youtube playlist directory.',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_deleting_audios_and_updating_playlists",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistTitle = 'S8 audio';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      String youtubePlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$youtubePlaylistTitle';

      List<String> youtubePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: youtubePlaylistPath,
        fileExtension: 'mp3',
      );

      // *** Manually deleting audio files from Youtube
      // playlist directory

      DirUtil.deleteMp3FilesInDir(
        filePath: youtubePlaylistPath,
      );

      // *** Updating the Youtube playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the audio
      // which were manually deleted from the Youtube playlist
      // directory

      // First, find the Youtube playlist ListTile Text widget
      final Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(youtubePlaylistTitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder youtubePlaylistListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: youtubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Tap the 'Toggle List' button to hide the list of playlist
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Test that the Youtube playlist is still showing the
      // deleted audio

      Finder audioListTileTextWidgetFinder;

      for (String audioTitle in youtubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now update the playable audio list of the Youtube
      // playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      Finder youtubePlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      // Now find the update playlist popup menu item and tap on it
      Finder popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the warning dialog

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playable audio list for playlist "$youtubePlaylistTitle" was updated. 4 audio(s) were removed.',
        isWarningConfirming: false,
      );

      // Test that the youtube playlist is no longer showing the
      // deleted audio

      for (String audioTitle in youtubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsNothing);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the no selected audio title is displayed
      expect(find.text("No audio selected"), findsOneWidget);

      await IntegrationTestUtil.verifyTopButtonsState(
        tester: tester,
        areEnabled: false,
        audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
        setAudioSpeedTextButtonValue: '1.00x',
      );

      // Now execute again the playlist update of the Youtube playlist.
      // This update won't change anything in the playlist.

      // Return to playlist download view
      Finder playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      youtubePlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the update playlist popup menu item and tap on it
      popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying that no warning dialog is displayed since nothing
      // was updated in the playlist

      // Check the value of the warning dialog title
      expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Manually delete all audio in local playlist directory.',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_deleting_audios_and_updating_playlists",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'Local_2_audios';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      String localPlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$localPlaylistTitle';

      // Obtaining the list of audio files in order to use it to
      // verify the displayed audio list before updating the
      // 'local_2_audios' playlist
      List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: localPlaylistPath,
        fileExtension: 'mp3',
      );

      // *** Manually deleting audio files from local
      // playlist directory

      DirUtil.deleteMp3FilesInDir(
        filePath: localPlaylistPath,
      );

      // *** Updating the local playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the audio
      // which were manually deleted from the local playlist
      // directory

      // First, find the local playlist ListTile Text widget
      final Finder localPlaylistListTileTextWidgetFinder =
          find.text(localPlaylistTitle);

      // Then obtain the local source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder localPlaylistListTileWidgetFinder = find.ancestor(
        of: localPlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: localPlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Test that the local playlist is still showing the
      // deleted audio

      for (String audioTitle in localPlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now update the playable audio list of the local
      // playlist

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      Finder localPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the update playlist popup menu item and tap on it
      Finder popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the warning dialog

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playable audio list for playlist "$localPlaylistTitle" was updated. 2 audio(s) were removed.',
        isWarningConfirming: false,
      );

      // Test that the local playlist is no longer showing the
      // deleted audio

      for (String audioTitle in localPlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsNothing);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the no selected audio title is displayed
      expect(find.text("No audio selected"), findsOneWidget);

      await IntegrationTestUtil.verifyTopButtonsState(
        tester: tester,
        areEnabled: false,
        audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
        setAudioSpeedTextButtonValue: '1.00x',
      );

      // Now execute again the playlist update of the Youtube playlist.
      // This update won't change anything in the playlist.

      // Return to playlist download view
      Finder playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      localPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the update playlist popup menu item and tap on it
      popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying that no warning dialog is displayed since nothing
      // was updated in the playlist

      // Check the value of the warning dialog title
      expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Manually delete some audio in Youtube playlist directory.',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_deleting_audios_and_updating_playlists",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistTitle = 'S8 audio';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      String youtubePlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$youtubePlaylistTitle';

      List<String> youtubePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: youtubePlaylistPath,
        fileExtension: 'mp3',
      );

      // *** Manually deleting audio files from Youtube
      // playlist directory

      DirUtil.deleteFileIfExist(
        pathFileName:
            "$youtubePlaylistPath${path.separator}${youtubePlaylistMp3Lst[0]}",
      );

      // *** Updating the Youtube playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the audio
      // which were manually deleted from the Youtube playlist
      // directory

      // First, find the Youtube playlist ListTile Text widget
      final Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(youtubePlaylistTitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder youtubePlaylistListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: youtubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Tap the 'Toggle List' button to hide the list of playlist
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Test that the Youtube playlist is still showing the
      // deleted audio

      for (String audioTitle in youtubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now update the playable audio list of the Youtube
      // playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      final Finder youtubePlaylistListTileLeadingMenuIconButton =
          find.descendant(
        of: youtubePlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();
      // Now find the update playlist popup menu item and tap on it
      final Finder popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playable audio list for playlist "$youtubePlaylistTitle" was updated. 1 audio(s) were removed.',
        isWarningConfirming: false,
      );

      // Test that the youtube playlist is no longer showing the
      // deleted audio

      int indexOfDeletedAudio = 0;

      for (String audioTitle in youtubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        if (indexOfDeletedAudio == 0) {
          expect(audioListTileTextWidgetFinder, findsNothing);
        } else {
          expect(audioListTileTextWidgetFinder, findsOneWidget);
        }

        indexOfDeletedAudio++;
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the displayed selected audio title
      expect(
          find.text(
              "3 fois où un économiste m'a ouvert les yeux (Giraud, Lefournier, Porcher)\n16:26"),
          findsOneWidget);

      await IntegrationTestUtil.verifyTopButtonsState(
        tester: tester,
        areEnabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
        setAudioSpeedTextButtonValue: '1.25x',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Manually delete some audio in local playlist directory.',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_deleting_audios_and_updating_playlists",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'Local_2_audios';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      String localPlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$localPlaylistTitle';

      List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: localPlaylistPath,
        fileExtension: 'mp3',
      );

      // *** Manually deleting audio files from local
      // playlist directory

      DirUtil.deleteFileIfExist(
        pathFileName:
            "$localPlaylistPath${path.separator}${localPlaylistMp3Lst[0]}",
      );

      // *** Updating the local playlist

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the audio
      // which were manually deleted from the local playlist
      // directory

      // First, find the local playlist ListTile Text widget
      final Finder localPlaylistListTileTextWidgetFinder =
          find.text(localPlaylistTitle);

      // Then obtain the local source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder localPlaylistListTileWidgetFinder = find.ancestor(
        of: localPlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: localPlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Test that the local playlist is still showing the
      // deleted audio

      for (String audioTitle in localPlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now update the playable audio list of the local
      // playlist

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      final Finder localPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the update playlist popup menu item and tap on it
      final Finder popupUpdatePlayableAudioListPlaylistMenuItem =
          find.byKey(const Key("popup_menu_update_playable_audio_list"));

      await tester.tap(popupUpdatePlayableAudioListPlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playable audio list for playlist "$localPlaylistTitle" was updated. 1 audio(s) were removed.',
        isWarningConfirming: false,
      );

      // Test that the local playlist is no longer showing the
      // deleted audio

      int indexOfDeletedAudio = 0;

      for (String audioTitle in localPlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        if (indexOfDeletedAudio == 0) {
          expect(audioListTileTextWidgetFinder, findsNothing);
        } else {
          expect(audioListTileTextWidgetFinder, findsOneWidget);
        }

        indexOfDeletedAudio++;
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify the displayed selected audio title
      expect(
          find.text(
              "3 fois où un économiste m'a ouvert les yeux (Giraud, Lefournier, Porcher)\n16:26"),
          findsOneWidget);

      await IntegrationTestUtil.verifyTopButtonsState(
        tester: tester,
        areEnabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
        setAudioSpeedTextButtonValue: '1.25x',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Delete audio test', () {
    group('In playlist download view', () {
      group('Using SF parms, delete an audio test', () {
        testWidgets(
            '''SF parms 'default' is applied. Then, click on the menu icon of the
           commented audio "Les besoins artificiels par R.Keucheyan" and select
           'Delete Audio ...'. Verify the displayed warning. Then click on the
           'Confirm' button. Verify the suppression of the audio mp3 file as well
           as its comment file. Verify also the updated playlist playable audio
           list.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'delete_filtered_audio_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          String defaultSortFilterParmName =
              'default'; // SF parm when opening the app

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Verify the presence of the audio comment files which will be later
          // deleted

          String audioCommentFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.json";

          List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            true,
          );

          String commentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(commentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio popup menu item and tap on it
          final Finder popupDeleteMenuItem =
              find.byKey(const Key("popup_menu_delete_audio"));

          await tester.tap(popupDeleteMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$commentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            defaultSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify that the audio comment files were deleted

          listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 18);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(commentedAudioTitleToDelete),
            true,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''SF parms 'default' is applied. Then, click on the menu icon of the
           uncommented audio "Les besoins artificiels par R.Keucheyan" which is
           uncommented in 'delete_filtered_audio_one_uncommented_more_test') and
           select 'Delete Audio ...'. Verify the suppression of the audio mp3. Verify
           also the updated playlist playable audio list and the new not totally
           played selected audio and the new not totally played selected audio.''',
            (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName:
                'delete_filtered_audio_one_uncommented_more_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          String defaultSortFilterParmName =
              'default'; // SF parm when opening the app

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          String uncommentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(uncommentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio popup menu item and tap on it
          final Finder popupCopyMenuItem =
              find.byKey(const Key("popup_menu_delete_audio"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            defaultSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 18);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(uncommentedAudioTitleToDelete),
            true,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Defined SF parms 'applied' is applied. Then, click on the menu icon of
           of the audio "Les besoins artificiels par R.Keucheyan" and select
           'Delete Audio ...'. Verify the displayed warning. Then click on the
           'Confirm' button. Verify the suppression of the audio mp3 file as well
           as its comment file. Verify also the updated playlist playable audio
           list.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'delete_filtered_audio_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          // Now open the audio popup menu
          await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
          await tester.pumpAndSettle();

          // Find the sort/filter audio menu item and tap on it to
          // open the audio sort filter dialog
          await tester.tap(
              find.byKey(const Key('define_sort_and_filter_audio_menu_item')));
          await tester.pumpAndSettle();

          // Now select the 'Audio title'item in the 'Sort by' dropdown button

          await tester
              .tap(find.byKey(const Key('sortingOptionDropdownButton')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Audio title'));
          await tester.pumpAndSettle();

          // Then delete the "Audio download date" descending sort option

          // Find the Text with "Audio downl date" which is located in the
          // selected sort parameters ListView
          final Finder textFinder = find.descendant(
            of: find.byKey(const Key('selectedSortingOptionsListView')),
            matching: find.text('Audio downl date'),
          );

          // Then find the ListTile ancestor of the 'Audio downl date' Text
          // widget. The ascending/descending and remove icon buttons are
          // contained in their ListTile ancestor
          final Finder listTileFinder = find.ancestor(
            of: textFinder,
            matching: find.byType(ListTile),
          );

          // Now, within that ListTile, find the sort option delete IconButton
          // with key 'removeSortingOptionIconButton'
          final Finder iconButtonFinder = find.descendant(
            of: listTileFinder,
            matching: find.byKey(const Key('removeSortingOptionIconButton')),
          );

          // Tap on the delete icon button to delete the 'Audio downl date'
          // descending sort option
          await tester.tap(iconButtonFinder);
          await tester.pumpAndSettle();

          // Click on the "Apply" button. This closes the sort/filter dialog
          // and updates the sort/filter playlist download view dropdown
          // button with the newly created sort/filter parms
          await tester
              .tap(find.byKey(const Key('applySortFilterOptionsTextButton')));
          await tester.pumpAndSettle();

          String appliedSortFilterParmName =
              'applied'; // SF parm after clicking on 'Apply' in SF Dialog

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Verify the presence of the audio comment files which will be later
          // deleted

          String audioCommentFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.json";

          List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            true,
          );

          String commentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(commentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio popup menu item and tap on it
          final Finder popupCopyMenuItem =
              find.byKey(const Key("popup_menu_delete_audio"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$commentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            appliedSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify that the audio comment files were deleted

          listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 18);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(commentedAudioTitleToDelete),
            true,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle =
              "La surpopulation mondiale par Jancovici et Barrau";
          String currentAudioSubTitle =
              "0:06:06.4 2.79 MB at 2.73 MB/sec on 07/01/2024 at 16:36";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Defined SF parms 'applied' is applied. Then, click on the menu icon of the
           uncommented audio "Les besoins artificiels par R.Keucheyan" and select
           'Delete Audio ...'. Verify the suppression of the audio mp3. Verify
           also the updated playlist playable audio list and the new not totally
           played selected audio.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName:
                'delete_filtered_audio_one_uncommented_more_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          // Now open the audio popup menu
          await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
          await tester.pumpAndSettle();

          // Find the sort/filter audio menu item and tap on it to
          // open the audio sort filter dialog
          await tester.tap(
              find.byKey(const Key('define_sort_and_filter_audio_menu_item')));
          await tester.pumpAndSettle();

          // Now select the 'Audio title'item in the 'Sort by' dropdown button

          await tester
              .tap(find.byKey(const Key('sortingOptionDropdownButton')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Audio title'));
          await tester.pumpAndSettle();

          // Then delete the "Audio download date" descending sort option

          // Find the Text with "Audio downl date" which is located in the
          // selected sort parameters ListView
          final Finder textFinder = find.descendant(
            of: find.byKey(const Key('selectedSortingOptionsListView')),
            matching: find.text('Audio downl date'),
          );

          // Then find the ListTile ancestor of the 'Audio downl date' Text
          // widget. The ascending/descending and remove icon buttons are
          // contained in their ListTile ancestor
          final Finder listTileFinder = find.ancestor(
            of: textFinder,
            matching: find.byType(ListTile),
          );

          // Now, within that ListTile, find the sort option delete IconButton
          // with key 'removeSortingOptionIconButton'
          final Finder iconButtonFinder = find.descendant(
            of: listTileFinder,
            matching: find.byKey(const Key('removeSortingOptionIconButton')),
          );

          // Tap on the delete icon button to delete the 'Audio downl date'
          // descending sort option
          await tester.tap(iconButtonFinder);
          await tester.pumpAndSettle();

          // Click on the "Apply" button. This closes the sort/filter dialog
          // and updates the sort/filter playlist download view dropdown
          // button with the newly created sort/filter parms
          await tester
              .tap(find.byKey(const Key('applySortFilterOptionsTextButton')));
          await tester.pumpAndSettle();

          String appliedSortFilterParmName =
              'applied'; // SF parm after clicking on 'Apply' in SF Dialog

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Scrolling down the audios list in order to display the commented
          // audio title to delete

          // Find the audio list widget using its key
          final Finder listFinder = find.byKey(const Key('audio_list'));

          // Perform the scroll action
          await tester.drag(listFinder, const Offset(0, -1000));
          await tester.pumpAndSettle();

          String uncommentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(uncommentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio popup menu item and tap on it
          final Finder popupCopyMenuItem =
              find.byKey(const Key("popup_menu_delete_audio"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            appliedSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 18);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(uncommentedAudioTitleToDelete),
            true,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle =
              "La surpopulation mondiale par Jancovici et Barrau";
          String currentAudioSubTitle =
              "0:06:06.4 2.79 MB at 2.73 MB/sec on 07/01/2024 at 16:36";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
      group(
          '''From playlist as well. Using SF parms, delete an audio from playlist
             as well test''', () {
        testWidgets(
            '''SF parms 'default' is applied. Then, click on the menu icon of the
           commented audio "Les besoins artificiels par R.Keucheyan" and select
           'Delete Audio from Playlist as well ...'. Verify the displayed warning.
           Then click on the 'Confirm' button. Verify the suppression of the audio
           mp3 file as well as its comment file. Verify also the updated playlist
           playable audio list.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'delete_filtered_audio_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          String defaultSortFilterParmName =
              'default'; // SF parm when opening the app

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Verify the presence of the audio comment files which will be later
          // deleted

          String audioCommentFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.json";

          List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            true,
          );

          String commentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(commentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio from playlist as well popup menu item
          // and tap on it
          final Finder popupCopyMenuItem = find
              .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$commentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$commentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$commentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the warning dialog
          await IntegrationTestUtil.verifyAndCloseWarningDialog(
            tester: tester,
            warningDialogMessage:
                'If the deleted audio "$commentedAudioTitleToDelete" remains in the "$youtubePlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
            isWarningConfirming: false,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            defaultSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify that the audio comment files were deleted

          listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 17);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''SF parms 'default' is applied. Then, click on the menu icon of the
           uncommented audio "Les besoins artificiels par R.Keucheyan" which is
           uncommented in 'delete_filtered_audio_one_uncommented_more_test') and
           select 'Delete Audio from Playlist as well ...'. Verify the suppression
           of the audio mp3. Verify also the updated playlist playable audio list
           and the new not totally played selected audio and the new not totally
           played selected audio.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName:
                'delete_filtered_audio_one_uncommented_more_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          String defaultSortFilterParmName =
              'default'; // SF parm when opening the app

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          String uncommentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(uncommentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio from playlist as well popup menu item
          // and tap on it
          final Finder popupCopyMenuItem = find
              .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$uncommentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$uncommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the warning dialog
          await IntegrationTestUtil.verifyAndCloseWarningDialog(
            tester: tester,
            warningDialogMessage:
                'If the deleted audio "$uncommentedAudioTitleToDelete" remains in the "$youtubePlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
            isWarningConfirming: false,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            defaultSortFilterParmName,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 17);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Saved defined SF parms 'Title asc' is applied. Then, click on the menu
           icon of the audio "Les besoins artificiels par R.Keucheyan"
           and select 'Delete Audio from Playlist as well ...'. Verify the displayed
           warning. Then click on the 'Confirm' button. Verify the suppression of
           the audio mp3 file as well as its comment file. Verify also the updated
           playlist playable audio list.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'delete_filtered_audio_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          // Now open the audio popup menu
          await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
          await tester.pumpAndSettle();

          // Find the sort/filter audio menu item and tap on it to
          // open the audio sort filter dialog
          await tester.tap(
              find.byKey(const Key('define_sort_and_filter_audio_menu_item')));
          await tester.pumpAndSettle();

          // Type "Title asc" in the 'Save as' TextField

          String saveAsTitle = 'Title asc';

          await tester.enterText(
              find.byKey(const Key('sortFilterSaveAsUniqueNameTextField')),
              saveAsTitle);
          await tester.pumpAndSettle();

          // Now select the 'Audio title'item in the 'Sort by' dropdown button

          await tester
              .tap(find.byKey(const Key('sortingOptionDropdownButton')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Audio title'));
          await tester.pumpAndSettle();

          // Then delete the "Audio download date" descending sort option

          // Find the Text with "Audio downl date" which is located in the
          // selected sort parameters ListView
          final Finder textFinder = find.descendant(
            of: find.byKey(const Key('selectedSortingOptionsListView')),
            matching: find.text('Audio downl date'),
          );

          // Then find the ListTile ancestor of the 'Audio downl date' Text
          // widget. The ascending/descending and remove icon buttons are
          // contained in their ListTile ancestor
          final Finder listTileFinder = find.ancestor(
            of: textFinder,
            matching: find.byType(ListTile),
          );

          // Now, within that ListTile, find the sort option delete IconButton
          // with key 'removeSortingOptionIconButton'
          final Finder iconButtonFinder = find.descendant(
            of: listTileFinder,
            matching: find.byKey(const Key('removeSortingOptionIconButton')),
          );

          // Tap on the delete icon button to delete the 'Audio downl date'
          // descending sort option
          await tester.tap(iconButtonFinder);
          await tester.pumpAndSettle();

          // Click on the "Save" button. This closes the sort/filter dialog
          // and updates the sort/filter playlist download view dropdown
          // button with the newly created sort/filter parms
          await tester
              .tap(find.byKey(const Key('saveSortFilterOptionsTextButton')));
          await tester.pumpAndSettle();

          // Change unplayed to fully listened status of the "La
          // surpopulation mondiale par Jancovici et Barrau" audio

          String unplayedThenFullyListenedAudioTitle =
              "La surpopulation mondiale par Jancovici et Barrau";

          // Then, tap on the unplayed Audio ListTile Text widget finder to
          // select this unplayed audio. This switch to the audio player view.
          final Finder thirdDownloadedAudioListTileTextWidgetFinder =
              find.text(unplayedThenFullyListenedAudioTitle);

          await tester.tap(thirdDownloadedAudioListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Then skip to the end of the audio to set it as fully played
          await tester
              .tap(find.byKey(const Key('audioPlayerViewSkipToEndButton')));
          await tester.pumpAndSettle();

          // Now, go back to the playlist download view
          Finder audioPlayerNavButtonFinder =
              find.byKey(const ValueKey('playlistDownloadViewIconButton'));
          await tester.tap(audioPlayerNavButtonFinder);
          await tester.pumpAndSettle();

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Verify the presence of the audio comment files which will be later
          // deleted

          String audioCommentFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.json";

          List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            true,
          );

          String commentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(commentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Scrolling down the audios list in order to display the commented
          // audio title to delete

          // Find the audio list widget using its key
          final Finder listFinder = find.byKey(const Key('audio_list'));

          // Perform the scroll action
          await tester.drag(listFinder, const Offset(0, -1000));
          await tester.pumpAndSettle();

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio from playlist as well popup menu item
          // and tap on it
          final Finder popupCopyMenuItem = find
              .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$commentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$commentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$commentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the warning dialog
          await IntegrationTestUtil.verifyAndCloseWarningDialog(
            tester: tester,
            warningDialogMessage:
                'If the deleted audio "$commentedAudioTitleToDelete" remains in the "$youtubePlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
            isWarningConfirming: false,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            saveAsTitle,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify that the audio comment files were deleted

          listCommentJsonFileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio${path.separator}$kCommentDirName",
            fileExtension: 'json',
          );

          expect(
            listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 17);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(commentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Saved defined SF parms 'Title asc' is applied. Then, click on the menu
           icon of the uncommented audio "Les besoins artificiels par R.Keucheyan"
           and select 'Delete Audio from Playlist as well ...'. Verify the suppression
           of the audio mp3. Verify also the updated playlist playable audio list
           and the new not totally played selected audio and the new not totally
           played selected audio.''', (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName:
                'delete_filtered_audio_one_uncommented_more_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'S8 audio';

          // Now open the audio popup menu
          await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
          await tester.pumpAndSettle();

          // Find the sort/filter audio menu item and tap on it to
          // open the audio sort filter dialog
          await tester.tap(
              find.byKey(const Key('define_sort_and_filter_audio_menu_item')));
          await tester.pumpAndSettle();

          // Type "Title asc" in the 'Save as' TextField

          String saveAsTitle = 'Title asc';

          await tester.enterText(
              find.byKey(const Key('sortFilterSaveAsUniqueNameTextField')),
              saveAsTitle);
          await tester.pumpAndSettle();

          // Now select the 'Audio title'item in the 'Sort by' dropdown button

          await tester
              .tap(find.byKey(const Key('sortingOptionDropdownButton')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Audio title'));
          await tester.pumpAndSettle();

          // Then delete the "Audio download date" descending sort option

          // Find the Text with "Audio downl date" which is located in the
          // selected sort parameters ListView
          final Finder textFinder = find.descendant(
            of: find.byKey(const Key('selectedSortingOptionsListView')),
            matching: find.text('Audio downl date'),
          );

          // Then find the ListTile ancestor of the 'Audio downl date' Text
          // widget. The ascending/descending and remove icon buttons are
          // contained in their ListTile ancestor
          final Finder listTileFinder = find.ancestor(
            of: textFinder,
            matching: find.byType(ListTile),
          );

          // Now, within that ListTile, find the sort option delete IconButton
          // with key 'removeSortingOptionIconButton'
          final Finder iconButtonFinder = find.descendant(
            of: listTileFinder,
            matching: find.byKey(const Key('removeSortingOptionIconButton')),
          );

          // Tap on the delete icon button to delete the 'Audio downl date'
          // descending sort option
          await tester.tap(iconButtonFinder);
          await tester.pumpAndSettle();

          // Click on the "Save" button. This closes the sort/filter dialog
          // and updates the sort/filter playlist download view dropdown
          // button with the newly created sort/filter parms
          await tester
              .tap(find.byKey(const Key('saveSortFilterOptionsTextButton')));
          await tester.pumpAndSettle();

          // Change unplayed to fully listened status of the "La
          // surpopulation mondiale par Jancovici et Barrau" audio

          String unplayedThenFullyListenedAudioTitle =
              "La surpopulation mondiale par Jancovici et Barrau";

          // Then, tap on the unplayed Audio ListTile Text widget finder to
          // select this unplayed audio. This switch to the audio player view.
          final Finder thirdDownloadedAudioListTileTextWidgetFinder =
              find.text(unplayedThenFullyListenedAudioTitle);

          await tester.tap(thirdDownloadedAudioListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Then skip to the end of the audio to set it as fully played
          await tester
              .tap(find.byKey(const Key('audioPlayerViewSkipToEndButton')));
          await tester.pumpAndSettle();

          // Now, go back to the playlist download view
          Finder audioPlayerNavButtonFinder =
              find.byKey(const ValueKey('playlistDownloadViewIconButton'));
          await tester.tap(audioPlayerNavButtonFinder);
          await tester.pumpAndSettle();

          // Verify the presence of the audio file which will be later deleted

          String audioFileNameToDelete =
              "240107-094520-Les besoins artificiels par R.Keucheyan 24-01-05.mp3";

          List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            true,
          );

          // Scrolling down the audios list in order to display the commented
          // audio title to delete

          // Find the audio list widget using its key
          final Finder listFinder = find.byKey(const Key('audio_list'));

          // Perform the scroll action
          await tester.drag(listFinder, const Offset(0, -1000));
          await tester.pumpAndSettle();

          String uncommentedAudioTitleToDelete =
              "Les besoins artificiels par R.Keucheyan";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(uncommentedAudioTitleToDelete);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
              find.ancestor(
            of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder
              commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
              find.descendant(
            of: commentedAudioTitleToDeleteListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester
              .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio from playlist as well popup menu item
          // and tap on it
          final Finder popupCopyMenuItem = find
              .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$uncommentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$uncommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the warning dialog
          await IntegrationTestUtil.verifyAndCloseWarningDialog(
            tester: tester,
            warningDialogMessage:
                'If the deleted audio "$uncommentedAudioTitleToDelete" remains in the "$youtubePlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
            isWarningConfirming: false,
          );

          // Verify that the applyed Sort/Filter parms name is displayed
          // after the selected playlist title

          Text selectedSortFilterParmsName = tester
              .widget(find.byKey(const Key('selectedPlaylistSFparmNameText')));

          expect(
            selectedSortFilterParmsName.data,
            saveAsTitle,
          );

          // Verify that the audio file was deleted

          listMp3FileNames = DirUtil.listFileNamesInDir(
            directoryPath:
                "$kApplicationPathWindowsTest${path.separator}S8 audio",
            fileExtension: 'mp3',
          );

          expect(
            listMp3FileNames.contains(audioFileNameToDelete),
            false,
          );

          // Verify the 'S8 audio' playlist json file

          Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

          expect(loadedPlaylist.downloadedAudioLst.length, 17);

          List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            downloadedAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          List<String> playableAudioLst = loadedPlaylist.playableAudioLst
              .map((Audio audio) => audio.validVideoTitle)
              .toList();

          expect(
            playableAudioLst.contains(uncommentedAudioTitleToDelete),
            false,
          );

          // Setting to this variables the currently selected audio title/subTitle
          // of the 'S8 audio' playlist
          String currentAudioTitle = "La résilience insulaire par Fiona Roche";
          String currentAudioSubTitle =
              "0:10:52.0 4.97 MB at 2.67 MB/sec on 07/01/2024 at 08:16";

          // Verify that the current audio is displayed with the correct
          // title and subtitle color
          await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
            tester: tester,
            currentAudioTitle: currentAudioTitle,
            currentAudioSubTitle: currentAudioSubTitle,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
      group('In playlist download view, delete an audio test', () {
        testWidgets('''Delete an audio only and then switch to AudioPlayerView
           screen.''', (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          const String localAudioPlaylistTitle = 'local_audio_playlist_2';
          const String uniqueAudioTitle = 'audio learn test short video one';

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          await app.main();
          await tester.pumpAndSettle();

          // Tap the 'Toggle List' button to display the playlist list
          await tester.tap(find.byKey(const Key('playlist_toggle_button')));
          await tester.pumpAndSettle();

          // Select the playlist containing the unique audio to delete

          await IntegrationTestUtil.selectPlaylist(
            tester: tester,
            playlistToSelectTitle: localAudioPlaylistTitle,
          );

          // Before deleting the unique audio to which a picture is
          // associated, verify that the playlist picture directory
          // contains the audio picture file.

          List<String> localPlaylistPictureLst = DirUtil.listFileNamesInDir(
            directoryPath:
                '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioPlaylistTitle${path.separator}$kPictureDirName',
            fileExtension: 'json',
          );

          expect(localPlaylistPictureLst,
              ["230628-033811-audio learn test short video one 23-06-10.json"]);

          // Now we want to tap the popup menu of the unique Audio ListTile
          // "audio learn test short video one"

          // First, find the Audio sublist ListTile Text widget
          final Finder uniqueAudioListTileTextWidgetFinder =
              find.text(uniqueAudioTitle);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder uniqueAudioListTileWidgetFinder = find.ancestor(
            of: uniqueAudioListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder uniqueAudioListTileLeadingMenuIconButton =
              find.descendant(
            of: uniqueAudioListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester.tap(uniqueAudioListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio popup menu item and tap on it
          final Finder popupCopyMenuItem =
              find.byKey(const Key("popup_menu_delete_audio"));

          await tester.tap(popupCopyMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the selected playlist TextField still
          // contains the title of the source playlist

          Text selectedPlaylistTitleText = tester
              .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

          expect(
            selectedPlaylistTitleText.data,
            localAudioPlaylistTitle,
          );

          // Now verifying that the audio was physically deleted from the
          // local playlist directory.

          List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
            directoryPath:
                '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
            fileExtension: 'mp3',
          );

          // Verify the local target playlist directory content
          expect(localPlaylistMp3Lst, []);

          // Verify that the playlist picture directory no longer contains
          // the deleted audio picture file.

          localPlaylistPictureLst = DirUtil.listFileNamesInDir(
            directoryPath:
                '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle${path.separator}$kPictureDirName',
            fileExtension: 'json',
          );

          expect(localPlaylistPictureLst, []);

          // Now we tap on the AudioPlayerView icon button to open
          // AudioPlayerView screen

          final appScreenNavigationButton =
              find.byKey(const ValueKey('audioPlayerViewIconButton'));
          await tester.tap(appScreenNavigationButton);
          await tester.pumpAndSettle();

          // Now verifying that 'No audio selected' is displayed in the
          // AudioPlayerView screen

          final Finder noAudioSelectedTextWidgetFinder =
              find.text('No audio selected');
          expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

          // Now verifying that the audio player view audio position
          // is 0:00

          final Finder audioPlayerViewAudioPositionFinder =
              find.byKey(const Key('audioPlayerViewAudioPosition'));
          final Text audioPlayerViewAudioPositionTextWidget =
              tester.widget<Text>(audioPlayerViewAudioPositionFinder);
          expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

          // Now verifying that the audio player view audio remaining
          // duration 0:00

          final Finder audioPlayerViewAudioRemainingDurationFinder =
              find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
          final Text audioPlayerViewAudioRemainingDurationTextWidget =
              tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
          expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('''Delete an audio from playlist as well and then switch to
           AudioPlayerView screen.''', (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          const String localAudioPlaylistTitle = 'local_audio_playlist_2';
          const String uniqueAudioTitle = 'audio learn test short video one';

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          await app.main();
          await tester.pumpAndSettle();

          // Tap the 'Toggle List' button to display the playlist list
          await tester.tap(find.byKey(const Key('playlist_toggle_button')));
          await tester.pumpAndSettle();

          // Select the playlist containing the unique audio to delete

          await IntegrationTestUtil.selectPlaylist(
            tester: tester,
            playlistToSelectTitle: localAudioPlaylistTitle,
          );

          // Now we want to tap the popup menu of the unique Audio ListTile
          // "audio learn test short video one"

          // First, find the Audio sublist ListTile Text widget
          final Finder uniqueAudioListTileTextWidgetFinder =
              find.text(uniqueAudioTitle);

          // Then obtain the Audio ListTile widget enclosing the Text widget by
          // finding its ancestor
          final Finder uniqueAudioListTileWidgetFinder = find.ancestor(
            of: uniqueAudioListTileTextWidgetFinder,
            matching: find.byType(ListTile),
          );

          // Now find the leading menu icon button of the Audio ListTile
          // and tap on it
          final Finder uniqueAudioListTileLeadingMenuIconButton =
              find.descendant(
            of: uniqueAudioListTileWidgetFinder,
            matching: find.byIcon(Icons.menu),
          );

          // Tap the leading menu icon button to open the popup menu
          await tester.tap(uniqueAudioListTileLeadingMenuIconButton);
          await tester.pumpAndSettle();

          // Now find the delete audio from playlist as well popup menu
          // item and tap on it. Since the audio is deleted from a local
          // plalist, no warning is displayed indicating that the audio
          // will be redownloaded unless it is suppressed from the Youtube
          // playlist as well !
          final Finder popupDeleteMenuItem = find
              .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

          await tester.tap(popupDeleteMenuItem);
          await tester.pumpAndSettle();

          // Now verifying the selected playlist TextField still
          // contains the title of the source playlist

          Text selectedPlaylistTitleText = tester
              .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

          expect(
            selectedPlaylistTitleText.data,
            localAudioPlaylistTitle,
          );

          // Now verifying that the audio was physically deleted from the
          // local playlist directory.

          List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
            directoryPath:
                '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
            fileExtension: 'mp3',
          );

          // Verify the local target playlist directory content
          expect(localPlaylistMp3Lst, []);

          // Now we tap on the AudioPlayerView icon button to open
          // AudioPlayerView screen

          final appScreenNavigationButton =
              find.byKey(const ValueKey('audioPlayerViewIconButton'));
          await tester.tap(appScreenNavigationButton);
          await tester.pumpAndSettle();

          // Now verifying that 'No audio selected' is displayed in the
          // AudioPlayerView screen

          final Finder noAudioSelectedTextWidgetFinder =
              find.text('No audio selected');
          expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

          // Now verifying that the audio player view audio position
          // is 0:00

          final Finder audioPlayerViewAudioPositionFinder =
              find.byKey(const Key('audioPlayerViewAudioPosition'));
          final Text audioPlayerViewAudioPositionTextWidget =
              tester.widget<Text>(audioPlayerViewAudioPositionFinder);
          expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

          // Now verifying that the audio player view audio remaining
          // duration 0:00

          final Finder audioPlayerViewAudioRemainingDurationFinder =
              find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
          final Text audioPlayerViewAudioRemainingDurationTextWidget =
              tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
          expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
    });
    group('Delete non downloaded type from Youtube playlist as well.', () {
      testWidgets(
          '''Delete imported commented audio from Youtube playlist. Click on the menu icon
           of the imported and commented audio "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES
           DISCOURS CATASTROPHISTES" and select 'Delete Audio from Playlist as well ...'.
           Verify the displayed confirmation dialog. Then click on the 'Confirm' button. Verify
           the suppression of the audio mp3 file as well as its comment file. Verify also the
           updated playlist downloaded and playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete =
            "250812-162933-DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES 23-11-07.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        // Verify the presence of the audio comment files which will be later
        // deleted

        const String audioCommentFileNameToDelete =
            "250812-162933-DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES 23-11-07.json";

        List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName",
          fileExtension: 'json',
        );

        expect(
          listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
          true,
        );

        String importedCommentedAudioTitleToDelete =
            "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES";

        // First, find the Audio sublist ListTile Text widget
        final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(importedCommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: commentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester
            .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$importedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Verify that the audio file was deleted

        listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          false,
        );

        // Verify that the audio comment file was deleted as well

        List<String> listCommentedFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              '$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName',
          fileExtension: 'json',
        );

        expect(
          listCommentedFileNames.contains(audioCommentFileNameToDelete),
          false,
        );

        // Verify that the audio comment files were deleted

        listCommentJsonFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName",
          fileExtension: 'json',
        );

        expect(
          listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
          false,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(importedCommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(importedCommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String currentAudioTitle = "L’uniforme arrive en France en 2024";
        String currentAudioSubTitle =
            "0:00:18.4 183.6 KB at 127.1 KB/sec on 12/08/2025 at 16:29";

        // Verify that the current audio is displayed with the correct
        // title and subtitle color
        await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
          tester: tester,
          currentAudioTitle: currentAudioTitle,
          currentAudioSubTitle: currentAudioSubTitle,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Delete imported uncommented audio from Youtube playlist. First, delete the DETTE
           PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES.json comment file.
           Then click on the menu icon of the imported and uncommented audio "DETTE PUBLIQUE
           - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES" and select 'Delete Audio from
           Playlist as well ...'. Verify that the confirmation dialog is not displayed. Then
           verify the suppression of the audio mp3 file. Verify also the updated playlist
           downloaded and playable audio list.''', (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete =
            "250812-162933-DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES 23-11-07.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        // Now delete the audio comment file so that deleting this imported
        // uncommented audio is tested

        const String audioCommentFileNameToDelete =
            "250812-162933-DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES 23-11-07.json";

        DirUtil.deleteFileIfExist(
          pathFileName:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName${path.separator}$audioCommentFileNameToDelete",
        );

        String importedUncommentedAudioTitleToDelete =
            "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            importedUncommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(importedUncommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder importedUncommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: importedUncommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            importedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: importedUncommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            importedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying that the confirm action dialog is not displayed
        Finder confirmActionDialogFinder = find.byType(ConfirmActionDialog);
        expect(confirmActionDialogFinder, findsNothing);

        // Verify that the audio file was deleted

        listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          false,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(importedUncommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(importedUncommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String currentAudioTitle = "L’uniforme arrive en France en 2024";
        String currentAudioSubTitle =
            "0:00:18.4 183.6 KB at 127.1 KB/sec on 12/08/2025 at 16:29";

        // Verify that the current audio is displayed with the correct
        // title and subtitle color
        await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
          tester: tester,
          currentAudioTitle: currentAudioTitle,
          currentAudioSubTitle: currentAudioSubTitle,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Delete converted commented audio from Youtube playlist. Click on the menu icon
           of the text to speech and commented audio "aaa" and select 'Delete Audio from Playlist
           as well ...'.
           Verify the displayed confirmation dialog. Then click on the 'Confirm' button. Verify
           the suppression of the audio mp3 file as well as its comment file. Verify also the
           updated playlist downloaded and playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete = "aaa.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        // Verify the presence of the audio comment files which will be later
        // deleted

        const String audioCommentFileNameToDelete = "aaa.json";

        List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName",
          fileExtension: 'json',
        );

        expect(
          listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
          true,
        );

        // Drag up to make sure that the audio to delete is visible
        // Find the audio list widget using its key
        Finder listFinder = find.byKey(const Key('audio_list'));

        // Perform the scroll action
        await tester.drag(listFinder, const Offset(0, 100));
        await tester.pumpAndSettle();

        String convertedCommentedAudioTitleToDelete = "aaa";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(convertedCommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder convertedCommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Find the audio list widget using its key
        listFinder = find.byKey(const Key('audio_list'));
        // Perform the scroll action
        await tester.drag(listFinder, const Offset(0, 200));
        await tester.pumpAndSettle();

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            convertedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: convertedCommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            convertedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$convertedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Verify that the audio file was deleted

        listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          false,
        );

        // Verify that the audio comment file was deleted as well

        List<String> listCommentedFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              '$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName',
          fileExtension: 'json',
        );

        expect(
          listCommentedFileNames.contains(audioCommentFileNameToDelete),
          false,
        );

        // Verify that the audio comment files were deleted

        listCommentJsonFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName",
          fileExtension: 'json',
        );

        expect(
          listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
          false,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(convertedCommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(convertedCommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String currentAudioTitle = "bbb";
        String currentAudioSubTitle =
            "0:00:15.5 155.1 KB converted on 25/08/2025 at 17:53";

        // Verify that the current audio is displayed with the correct
        // title and subtitle color
        await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
          tester: tester,
          currentAudioTitle: currentAudioTitle,
          currentAudioSubTitle: currentAudioSubTitle,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Delete converted uncommented audio from Youtube playlist. First delete the aaa.json
          comment file. Then click on the menu icon of the text to speech audio "aaa" and select
          'Delete Audio from Playlist as well ...'. Verify that the confirmation dialog is not
          displayed. Then verify the suppression of the audio mp3 file. Verify also the updated
          playlist downloaded and playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete = "aaa.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        // Now delete the audio comment file so that deleting this imported
        // uncommented audio is tested

        const String audioCommentFileNameToDelete = "aaa.json";

        DirUtil.deleteFileIfExist(
          pathFileName:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName${path.separator}$audioCommentFileNameToDelete",
        );

        // Drag up to make sure that the audio to delete is visible
        // Find the audio list widget using its key
        final Finder listFinder = find.byKey(const Key('audio_list'));

        // Perform the scroll action
        await tester.drag(listFinder, const Offset(0, 300));
        await tester.pumpAndSettle();

        String convertedUncommentedAudioTitleToDelete = "aaa";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            convertedUncommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(convertedUncommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder
            convertedUncommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: convertedUncommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            convertedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: convertedUncommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            convertedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying that the confirm action dialog is not displayed
        Finder confirmActionDialogFinder = find.byType(ConfirmActionDialog);
        expect(confirmActionDialogFinder, findsNothing);

        // Verify that the audio file was deleted

        listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          false,
        );

        // Verify that the audio comment file was deleted as well

        List<String> listCommentedFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              '$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName',
          fileExtension: 'json',
        );

        expect(
          listCommentedFileNames.contains(audioCommentFileNameToDelete),
          false,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(convertedUncommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(convertedUncommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String currentAudioTitle = "bbb";
        String currentAudioSubTitle =
            "0:00:15.5 155.1 KB converted on 25/08/2025 at 17:53";

        // Verify that the current audio is displayed with the correct
        // title and subtitle color
        await IntegrationTestUtil.verifyCurrentAudioTitleAndSubTitleColor(
          tester: tester,
          currentAudioTitle: currentAudioTitle,
          currentAudioSubTitle: currentAudioSubTitle,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
    group('Cancel deletion test.', () {
      testWidgets(
          '''Cancel deletion of downloaded uncommented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        // Now delete the audio comment file so that canceling deletion
        // of this downloaded uncommented audio is tested

        const String audioCommentFileNameToDelete =
            "250812-162929-L’uniforme arrive en France en 2024 23-12-11.json";

        DirUtil.deleteFileIfExist(
          pathFileName:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName${path.separator}$audioCommentFileNameToDelete",
        );

        String downloadedUncommentedAudioTitleToDelete =
            "L’uniforme arrive en France en 2024";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            downloadedUncommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(downloadedUncommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder
            downloadedUncommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: downloadedUncommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            downloadedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: downloadedUncommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            downloadedUncommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the audio "$downloadedUncommentedAudioTitleToDelete" from the Youtube playlist',
          confirmActionDialogMessagePossibleLst: [
            'Delete the audio "$downloadedUncommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
          ],
          closeDialogWithConfirmButton: false, // Cancel the deletion
          usePumpAndSettle: true,
        );

        // Ensure the warning dialog is not displayed (bug fix)
        expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Cancel deletion of downloaded commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        String downloadedCommentedAudioTitleToDelete =
            "L’uniforme arrive en France en 2024";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(downloadedCommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder downloadedCommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            downloadedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: downloadedCommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            downloadedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the audio "$downloadedCommentedAudioTitleToDelete" from the Youtube playlist',
          confirmActionDialogMessagePossibleLst: [
            'Delete the audio "$downloadedCommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Now verifying the confirm action dialog title and message
        // and cancel the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$downloadedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: false, // Cancel the deletion
          usePumpAndSettle: true,
        );

        // Ensure the warning dialog is not displayed (bug fix)
        expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Cancel deletion of imported commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete =
            "250812-162933-DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES 23-11-07.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        String importedCommentedAudioTitleToDelete =
            "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES";

        // First, find the Audio sublist ListTile Text widget
        final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(importedCommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder commentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: commentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder commentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: commentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester
            .tap(commentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$importedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: false, // Cancel the deletion
          usePumpAndSettle: true,
        );

        // Ensure the warning dialog is not displayed (bug fix)
        expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''Cancel deletion of converted commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Verify the presence of the audio file which will be later deleted

        const String audioFileNameToDelete = "aaa.mp3";

        final String youtubePlaylistDirectoryPath =
            "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

        List<String> listMp3FileNames = DirUtil.listFileNamesInDir(
          directoryPath: youtubePlaylistDirectoryPath,
          fileExtension: 'mp3',
        );

        expect(
          listMp3FileNames.contains(audioFileNameToDelete),
          true,
        );

        // Verify the presence of the audio comment files which will be later
        // deleted

        const String audioCommentFileNameToDelete = "aaa.json";

        List<String> listCommentJsonFileNames = DirUtil.listFileNamesInDir(
          directoryPath:
              "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName",
          fileExtension: 'json',
        );

        expect(
          listCommentJsonFileNames.contains(audioCommentFileNameToDelete),
          true,
        );

        // Drag up to make sure that the audio to delete is visible
        // Find the audio list widget using its key
        final Finder listFinder = find.byKey(const Key('audio_list'));

        // Perform the scroll action
        await tester.drag(listFinder, const Offset(0, 300));
        await tester.pumpAndSettle();

        String convertedCommentedAudioTitleToDelete = "aaa";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(convertedCommentedAudioTitleToDelete);

        // Then obtain the Audio ListTile widget enclosing the Text widget by
        // finding its ancestor
        final Finder convertedCommentedAudioTitleToDeleteListTileWidgetFinder =
            find.ancestor(
          of: convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder,
          matching: find.byType(ListTile),
        );

        // Now find the leading menu icon button of the Audio ListTile
        // and tap on it
        final Finder
            convertedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton =
            find.descendant(
          of: convertedCommentedAudioTitleToDeleteListTileWidgetFinder,
          matching: find.byIcon(Icons.menu),
        );

        // Tap the leading menu icon button to open the popup menu
        await tester.tap(
            convertedCommentedAudioTitleToDeleteListTileLeadingMenuIconButton);
        await tester.pumpAndSettle();

        // Now find the delete audio from playlist as well popup menu item
        // and tap on it
        final Finder popupCopyMenuItem = find
            .byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

        await tester.tap(popupCopyMenuItem);
        await tester.pumpAndSettle();

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$convertedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: false, // Cancel the deletion
          usePumpAndSettle: true,
        );

        // Ensure the warning dialog is not displayed (bug fix)
        expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
    group('In audio player view, delete an audio test', () {
      testWidgets('''Delete an audio.''', (WidgetTester tester) async {
        // Purge the test playlist directory if it exists so that the
        // playlist list is empty
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );

        // Copy the test initial audio data to the app dir
        DirUtil.copyFilesFromDirAndSubDirsToDirectory(
          sourceRootPath:
              "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
          destinationRootPath: kApplicationPathWindowsTest,
        );

        const String localAudioPlaylistTitle = 'local_audio_playlist_2';

        final SettingsDataService settingsDataService = SettingsDataService(
          isTest: true,
        );

        // Load the settings from the json file. This is necessary
        // otherwise the ordered playlist titles will remain empty
        // and the playlist list will not be filled with the
        // playlists available in the download app test dir
        await settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

        await app.main();
        await tester.pumpAndSettle();

        // Tap the 'Toggle List' button to display the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // Select the playlist containing the unique audio to
        // delete

        await IntegrationTestUtil.selectPlaylist(
          tester: tester,
          playlistToSelectTitle: localAudioPlaylistTitle,
        );

        // Before deleting the unique audio to which a picture is
        // associated, verify that the playlist picture directory
        // contains the audio picture file.

        List<String> localPlaylistPictureLst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioPlaylistTitle${path.separator}$kPictureDirName',
          fileExtension: 'json',
        );

        expect(localPlaylistPictureLst,
            ["230628-033811-audio learn test short video one 23-06-10.json"]);

        // Now we tap on the AudioPlayerView icon button to open
        // AudioPlayerView screen

        Finder appScreenNavigationButton =
            find.byKey(const ValueKey('audioPlayerViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Tap on the Audio Player View appbar menu and then on 'Delete audio ...'
        // menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio',
        );

        // Now verifying that 'No audio selected' is displayed in the
        // AudioPlayerView screen

        final Finder noAudioSelectedTextWidgetFinder =
            find.text('No audio selected');
        expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

        // Now verifying that the audio player view audio position
        // is 0:00

        final Finder audioPlayerViewAudioPositionFinder =
            find.byKey(const Key('audioPlayerViewAudioPosition'));
        final Text audioPlayerViewAudioPositionTextWidget =
            tester.widget<Text>(audioPlayerViewAudioPositionFinder);
        expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

        // Now verifying that the audio player view audio remaining
        // duration 0:00

        final Finder audioPlayerViewAudioRemainingDurationFinder =
            find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
        final Text audioPlayerViewAudioRemainingDurationTextWidget =
            tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
        expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        Text selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the audio player view top buttons state

        await IntegrationTestUtil.verifyTopButtonsState(
          tester: tester,
          areEnabled: false,
          audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
          setAudioSpeedTextButtonValue: '1.00x',
        );

        // Now verifying that the audio was physically deleted from the
        // local playlist directory.

        List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
          fileExtension: 'mp3',
        );

        // Verify the local target playlist directory content
        expect(localPlaylistMp3Lst, []);

        // Verify that the playlist picture directory no longer contains
        // the deleted audio picture file.

        localPlaylistPictureLst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle${path.separator}$kPictureDirName',
          fileExtension: 'json',
        );

        expect(localPlaylistPictureLst, []);

        // Now, go back to the playlist download view.
        appScreenNavigationButton =
            find.byKey(const ValueKey('playlistDownloadViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the playlist audio list is empty

        List<String> playlistsTitles = [
          'local_audio_playlist_2',
          'local_no_selected_audio',
        ];

        List<String> audioTitles = [];

        IntegrationTestUtil.checkPlaylistAndAudioTitlesOrderInListTile(
          tester: tester,
          playlistTitlesOrderedLst: playlistsTitles,
          audioTitlesOrderedLst: audioTitles,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''On playlist with no selected audio, delete an audio after its selection.''',
          (WidgetTester tester) async {
        // Purge the test playlist directory if it exists so that the
        // playlist list is empty
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );

        // Copy the test initial audio data to the app dir
        DirUtil.copyFilesFromDirAndSubDirsToDirectory(
          sourceRootPath:
              "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
          destinationRootPath: kApplicationPathWindowsTest,
        );

        const String localAudioPlaylistTitle = 'local_no_selected_audio';
        const String uniqueAudioToDeleteTitle =
            'audio learn test short video one';

        final SettingsDataService settingsDataService = SettingsDataService(
          isTest: true,
        );

        // Load the settings from the json file. This is necessary
        // otherwise the ordered playlist titles will remain empty
        // and the playlist list will not be filled with the
        // playlists available in the download app test dir
        await settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

        await app.main();
        await tester.pumpAndSettle();

        // Tap the 'Toggle List' button to display the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // Select the not selected local playlist containing the unique audio
        // to delete

        await IntegrationTestUtil.selectPlaylist(
          tester: tester,
          playlistToSelectTitle: localAudioPlaylistTitle,
        );

        // Now we tap on the AudioPlayerView icon button to open
        // AudioPlayerView screen

        Finder appScreenNavigationButton =
            find.byKey(const ValueKey('audioPlayerViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Tap the appbar leading popup menu button. Nothing is
        // displayed since no audio is selected
        await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
        await tester.pumpAndSettle();

        // Since no audio is selected, verify that the left appbar
        // menu is not displayable

        Finder popupDeleteMenuItem =
            find.byKey(const Key("popup_menu_delete_audio"));

        expect(popupDeleteMenuItem, findsNothing);

        // Tap on the 'No audio selected' title to open the list
        // of playable audio

        await tester.tap(find.text('No audio selected'));
        await tester.pumpAndSettle();

        // Select an Audio in the AudioPlayableListDialog
        await IntegrationTestUtil.selectAudioInAudioPlayableDialog(
          tester: tester,
          audioToSelectTitle: uniqueAudioToDeleteTitle,
        );

        // Tap on the Audio Player View appbar menu and then on
        // 'Delete audio ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio',
        );

        // Now verifying that 'No audio selected' is displayed in the
        // AudioPlayerView screen

        final Finder noAudioSelectedTextWidgetFinder =
            find.text('No audio selected');
        expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

        // Since no audio is selected, verify that the left appbar
        // menu is not displayed
        popupDeleteMenuItem = find.byKey(const Key("popup_menu_delete_audio"));

        expect(popupDeleteMenuItem, findsNothing);

        // Now verifying that the audio player view audio position
        // is 0:00

        final Finder audioPlayerViewAudioPositionFinder =
            find.byKey(const Key('audioPlayerViewAudioPosition'));
        final Text audioPlayerViewAudioPositionTextWidget =
            tester.widget<Text>(audioPlayerViewAudioPositionFinder);
        expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

        // Now verifying that the audio player view audio remaining
        // duration 0:00

        final Finder audioPlayerViewAudioRemainingDurationFinder =
            find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
        final Text audioPlayerViewAudioRemainingDurationTextWidget =
            tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
        expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        Text selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the audio player view top buttons state

        await IntegrationTestUtil.verifyTopButtonsState(
          tester: tester,
          areEnabled: false,
          audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
          setAudioSpeedTextButtonValue: '1.00x',
        );

        // Now verifying that the audio was physically deleted from the
        // local playlist directory.

        List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
          fileExtension: 'mp3',
        );

        // Verify the local target playlist directory content
        expect(localPlaylistMp3Lst, []);

        // Now, go back to the playlist download view.
        appScreenNavigationButton =
            find.byKey(const ValueKey('playlistDownloadViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the playlist audio list is empty

        List<String> playlistsTitles = [
          'local_audio_playlist_2',
          localAudioPlaylistTitle,
        ];

        List<String> audioTitles = [];

        IntegrationTestUtil.checkPlaylistAndAudioTitlesOrderInListTile(
          tester: tester,
          playlistTitlesOrderedLst: playlistsTitles,
          audioTitlesOrderedLst: audioTitles,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets('''Delete unique playing audio only.''',
          (WidgetTester tester) async {
        // Purge the test playlist directory if it exists so that the
        // playlist list is empty
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );

        // Copy the test initial audio data to the app dir
        DirUtil.copyFilesFromDirAndSubDirsToDirectory(
          sourceRootPath:
              "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
          destinationRootPath: kApplicationPathWindowsTest,
        );

        const String localAudioPlaylistTitle = 'local_audio_playlist_2';

        final SettingsDataService settingsDataService = SettingsDataService(
          isTest: true,
        );

        // Load the settings from the json file. This is necessary
        // otherwise the ordered playlist titles will remain empty
        // and the playlist list will not be filled with the
        // playlists available in the download app test dir
        await settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

        await app.main();
        await tester.pumpAndSettle();

        // Tap the 'Toggle List' button to display the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // Select the playlist containing the unique audio to
        // delete

        await IntegrationTestUtil.selectPlaylist(
          tester: tester,
          playlistToSelectTitle: localAudioPlaylistTitle,
        );

        // Now we tap on the AudioPlayerView icon button to open
        // AudioPlayerView screen

        Finder appScreenNavigationButton =
            find.byKey(const ValueKey('audioPlayerViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
          tester: tester,
        );

        // Now tap on the Play button to play the audio which will
        // be deleted
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        await Future.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Tap on the Audio Player View appbar menu and then on
        // 'Delete audio ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio',
        );

        // Now verifying that 'No audio selected' is displayed in the
        // AudioPlayerView screen

        final Finder noAudioSelectedTextWidgetFinder =
            find.text('No audio selected');
        expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

        // Ensure the pause button is not displayed. This confirm
        // that the deleted audio is not playing.
        expect(find.byIcon(Icons.pause), findsNothing);

        // Now verifying that the audio player view audio position
        // is 0:00

        final Finder audioPlayerViewAudioPositionFinder =
            find.byKey(const Key('audioPlayerViewAudioPosition'));
        final Text audioPlayerViewAudioPositionTextWidget =
            tester.widget<Text>(audioPlayerViewAudioPositionFinder);
        expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

        // Now verifying that the audio player view audio remaining
        // duration 0:00

        final Finder audioPlayerViewAudioRemainingDurationFinder =
            find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
        final Text audioPlayerViewAudioRemainingDurationTextWidget =
            tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
        expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        Text selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the audio player view top buttons state

        await IntegrationTestUtil.verifyTopButtonsState(
          tester: tester,
          areEnabled: false,
          audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
          setAudioSpeedTextButtonValue: '1.00x',
        );

        // Now verifying that the audio was physically deleted from the
        // local playlist directory.

        List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
          fileExtension: 'mp3',
        );

        // Verify the local target playlist directory content
        expect(localPlaylistMp3Lst, []);

        // Now, go back to the playlist download view.
        appScreenNavigationButton =
            find.byKey(const ValueKey('playlistDownloadViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the playlist audio list is empty

        List<String> playlistsTitles = [
          'local_audio_playlist_2',
          'local_no_selected_audio',
        ];

        List<String> audioTitles = [];

        IntegrationTestUtil.checkPlaylistAndAudioTitlesOrderInListTile(
          tester: tester,
          playlistTitlesOrderedLst: playlistsTitles,
          audioTitlesOrderedLst: audioTitles,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets('''From local playlist as well, delete an audio.''',
          (WidgetTester tester) async {
        // Purge the test playlist directory if it exists so that the
        // playlist list is empty
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );

        // Copy the test initial audio data to the app dir
        DirUtil.copyFilesFromDirAndSubDirsToDirectory(
          sourceRootPath:
              "$kDownloadAppTestSavedDataDir${path.separator}one_local_playlist_with_one_audio",
          destinationRootPath: kApplicationPathWindowsTest,
        );

        const String localAudioPlaylistTitle = 'local_audio_playlist_2';

        final SettingsDataService settingsDataService = SettingsDataService(
          isTest: true,
        );

        // Load the settings from the json file. This is necessary
        // otherwise the ordered playlist titles will remain empty
        // and the playlist list will not be filled with the
        // playlists available in the download app test dir
        await settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

        await app.main();
        await tester.pumpAndSettle();

        // Tap the 'Toggle List' button to display the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // Select the playlist containing the unique audio to
        // delete

        await IntegrationTestUtil.selectPlaylist(
          tester: tester,
          playlistToSelectTitle: localAudioPlaylistTitle,
        );

        // Now we tap on the AudioPlayerView icon button to open
        // AudioPlayerView screen

        Finder appScreenNavigationButton =
            find.byKey(const ValueKey('audioPlayerViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
          tester: tester,
        );

        // Tap on the Audio Player View appbar menu and then on 'Delete audio
        // from Playlist as well ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
        );

        // Now verifying that 'No audio selected' is displayed in the
        // AudioPlayerView screen

        final Finder noAudioSelectedTextWidgetFinder =
            find.text('No audio selected');
        expect(noAudioSelectedTextWidgetFinder, findsOneWidget);

        // Now verifying that the audio player view audio position
        // is 0:00

        final Finder audioPlayerViewAudioPositionFinder =
            find.byKey(const Key('audioPlayerViewAudioPosition'));
        final Text audioPlayerViewAudioPositionTextWidget =
            tester.widget<Text>(audioPlayerViewAudioPositionFinder);
        expect(audioPlayerViewAudioPositionTextWidget.data, '0:00');

        // Now verifying that the audio player view audio remaining
        // duration 0:00

        final Finder audioPlayerViewAudioRemainingDurationFinder =
            find.byKey(const Key('audioPlayerViewAudioRemainingDuration'));
        final Text audioPlayerViewAudioRemainingDurationTextWidget =
            tester.widget<Text>(audioPlayerViewAudioRemainingDurationFinder);
        expect(audioPlayerViewAudioRemainingDurationTextWidget.data, '0:00');

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        Text selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the audio player view top buttons state

        await IntegrationTestUtil.verifyTopButtonsState(
          tester: tester,
          areEnabled: false,
          audioLearnAppViewType: AudioLearnAppViewType.audioPlayerView,
          setAudioSpeedTextButtonValue: '1.00x',
        );

        // Now verifying that the audio was physically deleted from the
        // local playlist directory.

        List<String> localPlaylistMp3Lst = DirUtil.listFileNamesInDir(
          directoryPath:
              '$kApplicationPathWindowsTest${path.separator}$localAudioPlaylistTitle',
          fileExtension: 'mp3',
        );

        // Verify the local target playlist directory content
        expect(localPlaylistMp3Lst, []);

        // Now, go back to the playlist download view.
        appScreenNavigationButton =
            find.byKey(const ValueKey('playlistDownloadViewIconButton'));
        await tester.tap(appScreenNavigationButton);
        await tester.pumpAndSettle();

        // Now verifying the selected playlist TextField still
        // contains the title of the source playlist

        selectedPlaylistTitleText = tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

        expect(
          selectedPlaylistTitleText.data,
          localAudioPlaylistTitle,
        );

        // Verify the playlist audio list is empty

        List<String> playlistsTitles = [
          'local_audio_playlist_2',
          'local_no_selected_audio',
        ];

        List<String> audioTitles = [];

        IntegrationTestUtil.checkPlaylistAndAudioTitlesOrderInListTile(
          tester: tester,
          playlistTitlesOrderedLst: playlistsTitles,
          audioTitlesOrderedLst: audioTitles,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''From Youtube playlist as well, delete the downloaded and commented audio "Les besoins
            artificiels par R.Keucheyan". Verify the displayed confirm action dialogs, clicking on the
            'Confirm' button. Verify as well the final warning. Then verify the suppression of the audio
            mp3 file as well as its comment file. Verify also the new current audio title with duration
            displayed in the playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'delete_filtered_audio_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'S8 audio';

        String downloadedCommentedAudioTitleToDelete =
            "Les besoins artificiels par R.Keucheyan";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(downloadedCommentedAudioTitleToDelete);

        // Type on the audio title to open the audio player view
        await tester
            .tap(downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder);
        await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
          tester: tester,
        );

        // Tap on the Audio Player View appbar menu and then on 'Delete audio
        // from Playlist as well ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
        );

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the audio "$downloadedCommentedAudioTitleToDelete" from the Youtube playlist',
          confirmActionDialogMessagePossibleLst: [
            'Delete the audio "$downloadedCommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$downloadedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Now verifying the warning dialog
        await IntegrationTestUtil.verifyAndCloseWarningDialog(
          tester: tester,
          warningDialogMessage:
              'If the deleted audio "$downloadedCommentedAudioTitleToDelete" remains in the "$youtubePlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
          isWarningConfirming: false,
        );

        // Verify the 'S8 audio' playlist json file

        Playlist loadedPlaylist = _loadPlaylist(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 17);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(downloadedCommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(downloadedCommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title
        // in the audio player view
        String currentAudioTitleWithDuration =
            "La résilience insulaire par Fiona Roche\n10:52";

        // Verify that the current audio is displayed with the correct
        // title with duration
        expect(find.text(currentAudioTitleWithDuration), findsOneWidget);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''From Youtube playlist as well, delete the imported and commented audio "DETTE
           PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES".
           Verify the displayed confirmation dialog. Then click on the 'Confirm' button. Verify
           the suppression of the audio mp3 file as well as its comment file. Verify the updated
           playlist downloaded and playable audio list. Verify also the new current audio title
           with duration displayed in the playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';
        String importedCommentedAudioTitleToDelete =
            "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            importedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(importedCommentedAudioTitleToDelete);

        // Type on the audio title to open the audio player view
        await tester
            .tap(importedCommentedAudioTitleToDeleteListTileTextWidgetFinder);
        await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
          tester: tester,
        );

        // Tap on the Audio Player View appbar menu and then on 'Delete audio
        // from Playlist as well ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
        );

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$importedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(importedCommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(importedCommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String currentAudioTitleWithDuration = "bbb\n0:16";

        // Verify that the current audio is displayed with the correct
        // title with duration
        expect(find.text(currentAudioTitleWithDuration), findsOneWidget);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''From Youtube playlist as well, delete the converted and commented audio "aaa".
           Verify the displayed confirmation dialog. Then click on the 'Confirm' button. Verify
           the suppression of the audio mp3 file as well as its comment file. Verify the updated
           playlist downloaded and playable audio list. Verify also the new current audio title
           with duration displayed in the playable audio list.''',
          (WidgetTester tester) async {
        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'import_audios_integr_test',
          tapOnPlaylistToggleButton: false,
        );

        const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

        // Drag up to make sure that the audio to delete is visible
        // Find the audio list widget using its key
        final Finder listFinder = find.byKey(const Key('audio_list'));

        // Perform the scroll action
        await tester.drag(listFinder, const Offset(0, 300));
        await tester.pumpAndSettle();

        String convertedCommentedAudioTitleToDelete = "aaa";

        // First, find the Audio sublist ListTile Text widget
        final Finder
            convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
            find.text(convertedCommentedAudioTitleToDelete);

        // Type on the audio title to open the audio player view
        await tester
            .tap(convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder);
        await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
          tester: tester,
        );

        // Tap on the Audio Player View appbar menu and then on 'Delete audio
        // from Playlist as well ...' menu item
        await IntegrationTestUtil.typeOnAppbarMenuItem(
          tester: tester,
          appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
        );

        // Now verifying the confirm action dialog title and message
        // and confirm the deletion
        await IntegrationTestUtil.verifyConfirmActionDialog(
          tester: tester,
          confirmActionDialogTitle:
              'Confirm deletion of the commented audio "$convertedCommentedAudioTitleToDelete"',
          confirmActionDialogMessagePossibleLst: [
            'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
          ],
          closeDialogWithConfirmButton: true,
          usePumpAndSettle: true,
        );

        // Verify the 'urgent_actus_17-12-2023' playlist json file

        Playlist loadedPlaylist =
            _loadPlaylistFromPlaylistsDir(youtubePlaylistTitle);

        expect(loadedPlaylist.downloadedAudioLst.length, 4);
        expect(loadedPlaylist.playableAudioLst.length, 4);

        List<String> downloadedAudioLst = loadedPlaylist.downloadedAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          downloadedAudioLst.contains(convertedCommentedAudioTitleToDelete),
          false,
        );

        List<String> playableAudioLst = loadedPlaylist.playableAudioLst
            .map((Audio audio) => audio.validVideoTitle)
            .toList();

        expect(
          playableAudioLst.contains(convertedCommentedAudioTitleToDelete),
          false,
        );

        // Setting to this variables the currently selected audio title/subTitle
        // of the 'S8 audio' playlist
        String noAudioSelectedTitle = "No audio selected";

        // Verify that the current audio is displayed with the correct
        // title with duration
        expect(find.text(noAudioSelectedTitle), findsOneWidget);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      group('Cancel deletion test.', () {
        testWidgets(
            '''Cancel deletion of downloaded uncommented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
            (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'import_audios_integr_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

          final String youtubePlaylistDirectoryPath =
              "$kPlaylistDownloadRootPathWindowsTest${path.separator}$youtubePlaylistTitle";

          // Now delete the audio comment file so that canceling deletion
          // of this downloaded uncommented audio is tested

          const String audioCommentFileNameToDelete =
              "250812-162929-L’uniforme arrive en France en 2024 23-12-11.json";

          DirUtil.deleteFileIfExist(
            pathFileName:
                "$youtubePlaylistDirectoryPath${path.separator}$kCommentDirName${path.separator}$audioCommentFileNameToDelete",
          );

          String downloadedUncommentedAudioTitleToDelete =
              "L’uniforme arrive en France en 2024";

          // First, find the Audio sublist ListTile Text widget
          final Finder
              downloadedUncommentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(downloadedUncommentedAudioTitleToDelete);

          // Type on the audio title to open the audio player view
          await tester.tap(
              downloadedUncommentedAudioTitleToDeleteListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Tap on the Audio Player View appbar menu and then on 'Delete audio
          // from Playlist as well ...' menu item
          await IntegrationTestUtil.typeOnAppbarMenuItem(
            tester: tester,
            appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$downloadedUncommentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$downloadedUncommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: false, // Cancel the deletion
            usePumpAndSettle: true,
          );

          // Ensure the warning dialog is not displayed (bug fix)
          expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Cancel deletion of downloaded commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
            (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'import_audios_integr_test',
            tapOnPlaylistToggleButton: false,
          );

          const String youtubePlaylistTitle = 'urgent_actus_17-12-2023';

          String downloadedCommentedAudioTitleToDelete =
              "L’uniforme arrive en France en 2024";

          // First, find the Audio sublist ListTile Text widget
          final Finder
              downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(downloadedCommentedAudioTitleToDelete);

          // Type on the audio title to open the audio player view
          await tester.tap(
              downloadedCommentedAudioTitleToDeleteListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Tap on the Audio Player View appbar menu and then on 'Delete audio
          // from Playlist as well ...' menu item
          await IntegrationTestUtil.typeOnAppbarMenuItem(
            tester: tester,
            appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the audio "$downloadedCommentedAudioTitleToDelete" from the Youtube playlist',
            confirmActionDialogMessagePossibleLst: [
              'Delete the audio "$downloadedCommentedAudioTitleToDelete" from the playlist "$youtubePlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
            ],
            closeDialogWithConfirmButton: true,
            usePumpAndSettle: true,
          );

          // Now verifying the confirm action dialog title and message
          // and cancel the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$downloadedCommentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: false, // Cancel the deletion
            usePumpAndSettle: true,
          );

          // Ensure the warning dialog is not displayed (bug fix)
          expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Cancel deletion of imported commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
            (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'import_audios_integr_test',
            tapOnPlaylistToggleButton: false,
          );

          String importedCommentedAudioTitleToDelete =
              "DETTE PUBLIQUE - LA RÉALITÉ DERRIÈRE LES DISCOURS CATASTROPHISTES";

          // First, find the Audio sublist ListTile Text widget
          final Finder commentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(importedCommentedAudioTitleToDelete);

          // Type on the audio title to open the audio player view
          await tester.tap(commentedAudioTitleToDeleteListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Tap on the Audio Player View appbar menu and then on 'Delete audio
          // from Playlist as well ...' menu item
          await IntegrationTestUtil.typeOnAppbarMenuItem(
            tester: tester,
            appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$importedCommentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: false, // Cancel the deletion
            usePumpAndSettle: true,
          );

          // Ensure the warning dialog is not displayed (bug fix)
          expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets(
            '''Cancel deletion of converted commented audio from Youtube playlist. This verifies a
            bug correction on UiUtil done on 30/09/2025.''',
            (WidgetTester tester) async {
          await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
            tester: tester,
            savedTestDataDirName: 'import_audios_integr_test',
            tapOnPlaylistToggleButton: false,
          );

          // Drag up to make sure that the audio to delete is visible
          // Find the audio list widget using its key
          final Finder listFinder = find.byKey(const Key('audio_list'));

          // Perform the scroll action
          await tester.drag(listFinder, const Offset(0, 300));
          await tester.pumpAndSettle();

          String convertedCommentedAudioTitleToDelete = "aaa";

          // First, find the Audio sublist ListTile Text widget
          final Finder
              convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder =
              find.text(convertedCommentedAudioTitleToDelete);

          // Type on the audio title to open the audio player view
          await tester.tap(
              convertedCommentedAudioTitleToDeleteListTileTextWidgetFinder);
          await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
            tester: tester,
          );

          // Tap on the Audio Player View appbar menu and then on 'Delete audio
          // from Playlist as well ...' menu item
          await IntegrationTestUtil.typeOnAppbarMenuItem(
            tester: tester,
            appbarMenuKeyStr: 'popup_menu_delete_audio_from_playlist_aswell',
          );

          // Now verifying the confirm action dialog title and message
          // and confirm the deletion
          await IntegrationTestUtil.verifyConfirmActionDialog(
            tester: tester,
            confirmActionDialogTitle:
                'Confirm deletion of the commented audio "$convertedCommentedAudioTitleToDelete"',
            confirmActionDialogMessagePossibleLst: [
              'The audio contains 1 comment(s) which will be deleted as well. Confirm deletion ?',
            ],
            closeDialogWithConfirmButton: false, // Cancel the deletion
            usePumpAndSettle: true,
          );

          // Ensure the warning dialog is not displayed (bug fix)
          expect(find.byKey(const Key('warningDialogTitle')), findsNothing);

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
    });
  });
  group('Bug fix tests', () {
    testWidgets('Verifying with partial download of single video audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      String singleVideoUrl = 'https://youtu.be/uv3VQoWSjBE';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Enter the single video URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        singleVideoUrl,
      );
      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, singleVideoUrl);

      // Tap the 'Download single video button' button. Before fixing
      // the bug, this caused an exception to be thrown
      await tester.tap(find.byKey(const Key('downloadSingleVideoButton')));
      await tester.pumpAndSettle();

      // Now find the cancel button and tap on it since the audio
      // download can not be done in the test environment
      await tester.tap(find.byKey(const Key('cancelButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Verifying execution of "Delete audio from playlist as well"
           playlist menu item''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}delete_audio_from_audio_learn_short_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubeAudioPlaylistTitle = 'audio_learn_short';
      const String audioToDeleteTitle =
          '15 minutes de Janco pour retourner un climatosceptique';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the playlist containing the audio to move to the target
      // local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioPlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(audioToDeleteTitle).first;

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDeleteAudioFromPlaylistAsWellMenuItem =
          find.byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

      await tester.tap(popupDeleteAudioFromPlaylistAsWellMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the confirm action dialog title and message
      // and confirm the deletion
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            'Confirm deletion of the audio "$audioToDeleteTitle" from the Youtube playlist',
        confirmActionDialogMessagePossibleLst: [
          'Delete the audio "$audioToDeleteTitle" from the playlist "$youtubeAudioPlaylistTitle" defined on the Youtube site, otherwise the audio will be downloaded again during the next playlist download. Or click on "Cancel" and choose "Delete Audio ..." instead of "Delete Audio from Playlist as well ...". So, the audio will be removed from the playable audio list, but will remain in the downloaded audio list, which will prevent its re-download.',
        ],
        closeDialogWithConfirmButton: true,
        usePumpAndSettle: true,
      );

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'If the deleted audio "$audioToDeleteTitle" remains in the "$youtubeAudioPlaylistTitle" playlist located on Youtube, it will be downloaded again the next time you download the playlist !',
        isWarningConfirming: false,
      );

      // Check the saved youtube audio playlist values in the json file

      final youtubeAudioPlaylistPath = path.join(
        kApplicationPathWindowsTest,
        youtubeAudioPlaylistTitle,
      );

      final youtubeAudioPlaylistFilePathName = path.join(
        youtubeAudioPlaylistPath,
        '$youtubeAudioPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedYoutubeAudioPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: youtubeAudioPlaylistFilePathName,
        type: Playlist,
      );

      final expectedAudioPlaylistFilePathName = path.join(
        youtubeAudioPlaylistPath,
        '${youtubeAudioPlaylistTitle}_expected.json',
      );

      // Load playlist from the json file
      Playlist loadedExpectedAudioPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: expectedAudioPlaylistFilePathName,
        type: Playlist,
      );

      int loadedDownloadedAudioLastItemIndex =
          loadedYoutubeAudioPlaylist.downloadedAudioLst.length - 1;
      expect(
        loadedYoutubeAudioPlaylist
            .downloadedAudioLst[loadedDownloadedAudioLastItemIndex]
            .audioFileName,
        loadedYoutubeAudioPlaylist.playableAudioLst[0].audioFileName,
      );

      expect(
          loadedYoutubeAudioPlaylist
              .downloadedAudioLst[loadedDownloadedAudioLastItemIndex]
              .audioFileName,
          loadedExpectedAudioPlaylist
              .downloadedAudioLst[loadedDownloadedAudioLastItemIndex]
              .audioFileName);
      expect(loadedYoutubeAudioPlaylist.playableAudioLst[0].audioFileName,
          loadedExpectedAudioPlaylist.playableAudioLst[0].audioFileName);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Click on download at musical quality checkbox bug fix',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the Youtube playlist to select

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'audio_player_view_2_shorts_test',
      );

      // Now tap the download at musical quality checkbox
      await tester.tap(find.byKey(const Key('audio_quality_checkbox')));
      await tester.pumpAndSettle();

      // Verify that the download at musical quality checkbox is
      // checked
      Finder downloadAtMusicalQualityCheckBoxFinder =
          find.byKey(const Key('audio_quality_checkbox'));
      Checkbox downloadAtMusicalQualityCheckBoxWidget =
          tester.widget<Checkbox>(downloadAtMusicalQualityCheckBoxFinder);
      expect(downloadAtMusicalQualityCheckBoxWidget.value, true);

      Finder snackBarMessageFinder = find.text("Download at music quality");
      expect(snackBarMessageFinder, findsOneWidget);

      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Now retap the download at musical quality checkbox
      await tester.tap(find.byKey(const Key('audio_quality_checkbox')));
      await tester.pumpAndSettle();

      // Verify that the download at musical quality checkbox is
      // unchecked
      downloadAtMusicalQualityCheckBoxFinder =
          find.byKey(const Key('audio_quality_checkbox'));
      downloadAtMusicalQualityCheckBoxWidget =
          tester.widget<Checkbox>(downloadAtMusicalQualityCheckBoxFinder);
      expect(downloadAtMusicalQualityCheckBoxWidget.value, false);

      snackBarMessageFinder = find.text("Download at audio quality");
      expect(snackBarMessageFinder, findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Delete existing playlist test', () {
    testWidgets('Delete selected Youtube playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle =
          'audio_learn_test_download_2_small_videos';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the playlist to delete ListTile

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubePlaylistToDeleteTitle,
      );

      // First, find the Playlist ListTile Text widget
      final Finder youtubePlaylistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying and closing the confirm dialog

      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Supprimer la playlist Youtube "$youtubePlaylistToDeleteTitle"',
        confirmDialogMessage:
            'Suppression de la playlist, de ses 2 fichiers audio, de ses 2 commentaire(s) audio, de ses 0 photo(s) audio ainsi que de son fichier JSON et de son répertoire.',
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'local_audio_playlist_2',
            'local_3'
          ]);

      final String youtubePlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        youtubePlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(youtubePlaylistToDeletePath).existsSync(), false);

      // Since the deleted playlist was selected, there is no longer
      // a selected playlist. So, the selected playlist widgets
      // are disabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Verifying that the selected playlist text field is empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        '',
        reason: 'Selected playlist text field is not empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('From playlists root dir, delete selected Youtube playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle =
          'audio_learn_test_download_2_small_videos';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the playlist to delete ListTile

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubePlaylistToDeleteTitle,
      );

      // First, find the Playlist ListTile Text widget
      final Finder youtubePlaylistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying and closing the confirm dialog

      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Delete Youtube Playlist "$youtubePlaylistToDeleteTitle"',
        confirmDialogMessage:
            "Deleting the playlist and its 2 audios, 0 audio comment(s), 1 audio picture(s) as well as its JSON file and its directory.",
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'local_3',
            'local_audio_playlist_2',
          ]);

      final String youtubePlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        youtubePlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(youtubePlaylistToDeletePath).existsSync(), false);

      // Since the deleted playlist was selected, there is no longer
      // a selected playlist. So, the selected playlist widgets
      // are disabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Verifying that the selected playlist text field is empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        '',
        reason: 'Selected playlist text field is not empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Cancel delete selected Youtube playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle =
          'audio_learn_test_download_2_small_videos';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder youtubePlaylistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test cancelling deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now find the cancel button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('cancelButtonKey')));
      await tester.pumpAndSettle();

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is still in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            youtubePlaylistToDeleteTitle,
            'local_audio_playlist_2',
            'local_3'
          ]);

      final String youtubePlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        youtubePlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory still exist
      expect(Directory(youtubePlaylistToDeletePath).existsSync(), true);

      // Since the playlist deletion was cancelled and the playlist was
      // selected, the selected playlist widgets are enabled. Checking
      // this now:

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: false,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Verifying that the selected playlist text field is empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        youtubePlaylistToDeleteTitle,
        reason: 'Selected playlist text field is empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete selected local playlist', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistToDeleteTitle = 'local_audio_playlist_2';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder localPlaylistToDeleteListTileTextWidgetFinder =
          find.text(localPlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: localPlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder localPlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(localPlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying and closing the confirm dialog
      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Supprimer la playlist locale "$localPlaylistToDeleteTitle"',
        confirmDialogMessage:
            'Suppression de la playlist, de ses 0 fichiers audio, de ses 0 commentaire(s) audio, de ses 0 photo(s) audio ainsi que de son fichier JSON et de son répertoire.',
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'audio_learn_test_download_2_small_videos',
            'local_3'
          ]);

      final String localPlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        localPlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(localPlaylistToDeletePath).existsSync(), false);

      // Since the deleted playlist was selected, there is no longer
      // a selected playlist. So, the selected playlist widgets
      // are disabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Verifying that the selected playlist text field is empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        '',
        reason: 'Selected playlist text field is not empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('From playlists root dir, delete selected local playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistToDeleteTitle = 'local_audio_playlist_2';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder localPlaylistToDeleteListTileTextWidgetFinder =
          find.text(localPlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: localPlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder localPlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(localPlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying and closing the confirm dialog
      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Delete Local Playlist "$localPlaylistToDeleteTitle"',
        confirmDialogMessage:
            "Deleting the playlist and its 0 audios, 0 audio comment(s), 0 audio picture(s) as well as its JSON file and its directory.",
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_learn_test_download_2_small_videos',
            'audio_player_view_2_shorts_test',
            'local_3'
          ]);

      final String localPlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        localPlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(localPlaylistToDeletePath).existsSync(), false);

      // Since the deleted playlist was selected, there is no longer
      // a selected playlist. So, the selected playlist widgets
      // are disabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Verifying that the selected playlist text field is empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        '',
        reason: 'Selected playlist text field is not empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Cancel delete selected local playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistToDeleteTitle = 'local_audio_playlist_2';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder localPlaylistToDeleteListTileTextWidgetFinder =
          find.text(localPlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: localPlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder localPlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(localPlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test cancelling deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now find the cancel button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('cancelButtonKey')));
      await tester.pumpAndSettle();

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the cancelled deleting playlist title is still in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'audio_learn_test_download_2_small_videos',
            localPlaylistToDeleteTitle,
            'local_3'
          ]);

      final String localPlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        localPlaylistToDeleteTitle,
      );

      // Check that the deletion cancelled playlist directory still exist
      expect(Directory(localPlaylistToDeletePath).existsSync(), true);

      // Since the deletion of the selected playlist was cancelled,
      // there is still a selected playlist. So, the selected playlist
      // widgets are enabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the playlist whose deletion was cancelled has no audio,
      // the audui menu items are disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Verifying that the selected playlist text field is not empty
      expect(
        tester
            .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')))
            .data,
        localPlaylistToDeleteTitle,
        reason: 'Selected playlist text field is not empty',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Delete non selected Youtube playlist while another Youtube
           playlist is selected''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle =
          'audio_learn_test_download_2_small_videos';

      const String youtubePlaylistToSelectTitle =
          'audio_player_view_2_shorts_test';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to obtain its ListTile

      // First, find the Playlist ListTile Text widget
      final Finder youtubePlaylistToSelectListTileTextWidgetFinder =
          find.text(youtubePlaylistToSelectTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToSelectListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToSelectListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToSelectListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToSelectListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToSelectListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder playlistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder playlistToDeleteListTileWidgetFinder = find.ancestor(
        of: playlistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: playlistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying the confirm dialog message

      // Since the copied audio contains comment(s), deleting it
      // causes a confirm action dialog to be displayed.
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            'Supprimer la playlist Youtube "$youtubePlaylistToDeleteTitle"',
        confirmActionDialogMessagePossibleLst: [
          "Suppression de la playlist, de ses 2 fichiers audio, de ses 2 commentaire(s) audio, de ses 0 photo(s) audio ainsi que de son fichier JSON et de son répertoire."
        ],
        closeDialogWithConfirmButton: true,
        usePumpAndSettle: true,
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'local_audio_playlist_2',
            'local_3'
          ]);

      final String newPlaylistPath = path.join(
        kApplicationPathWindowsTest,
        youtubeNewPlaylistTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(newPlaylistPath).existsSync(), false);

      // Since the deleted playlist was not selected and that another
      // Youtube playlist was selected, the selected playlist widgets
      // remain enabled. Checking this now:

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Delete non selected Youtube playlist while a local playlist is
           selected''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle =
          'audio_learn_test_download_2_small_videos';

      const String localPlaylistToSelectTitle = 'local_audio_playlist_2';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to obtain its ListTile

      // First, find the Playlist ListTile Text widget
      final Finder localPlaylistToSelectListTileTextWidgetFinder =
          find.text(localPlaylistToSelectTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToSelectListTileWidgetFinder = find.ancestor(
        of: localPlaylistToSelectListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder localPlaylistToSelectListTileCheckboxWidgetFinder =
          find.descendant(
        of: localPlaylistToSelectListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(localPlaylistToSelectListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder playlistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder playlistToDeleteListTileWidgetFinder = find.ancestor(
        of: playlistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: playlistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the confirm dialog message

      final Text deletePlaylistDialogTitleWidget = tester
          .widget<Text>(find.byKey(const Key('confirmDialogTitleOneKey')));

      expect(deletePlaylistDialogTitleWidget.data,
          'Supprimer la playlist Youtube "$youtubePlaylistToDeleteTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'local_audio_playlist_2',
            'local_3'
          ]);

      final String newPlaylistPath = path.join(
        kApplicationPathWindowsTest,
        youtubeNewPlaylistTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(newPlaylistPath).existsSync(), false);

      // Since the deleted playlist was not selected and that a local
      // playlist was selected, the selected playlist widgets remain
      // enabled, except the download selected playlist button.
      // Checking this now:

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      // since a local playlist is selected, the download
      // audio of selected playlist button is disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the selected local playlist has no audio, the
      // audio menu item is disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete non selected local playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}2_youtube_2_local_playlists_delete_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistToDeleteTitle = 'local_audio_playlist_2';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the playlist to delete ListTile

      // First, find the Playlist ListTile Text widget
      final Finder localPlaylistToDeleteListTileTextWidgetFinder =
          find.text(localPlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: localPlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: localPlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Simulate a tap outside the delete dialog to verify that the
      // dialog can not be closed by error if the user type outside it
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify that the dialog is not closed
      expect(find.byType(ConfirmActionDialog), findsOneWidget);

      // Now verifying and closing the confirm dialog
      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Supprimer la playlist locale "$localPlaylistToDeleteTitle"',
        confirmDialogMessage:
            'Suppression de la playlist, de ses 0 fichiers audio, de ses 0 commentaire(s) audio, de ses 0 photo(s) audio ainsi que de son fichier JSON et de son répertoire.',
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'audio_player_view_2_shorts_test',
            'audio_learn_test_download_2_small_videos',
            'local_3'
          ]);

      final String localPlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        localPlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(localPlaylistToDeletePath).existsSync(), false);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Delete renamed Youtube playlist. Before improving the Playlist == method,
                   this test would fail.''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}delete_youube_playlist_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String youtubePlaylistToDeleteTitle = 'Bible Bénie A Supprimer';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // First, find the Playlist ListTile Text widget
      final Finder youtubePlaylistToDeleteListTileTextWidgetFinder =
          find.text(youtubePlaylistToDeleteTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToDeleteListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToDeleteListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToDeleteListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToDeleteListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistToDeleteListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(firstPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying and closing the confirm dialog

      await IntegrationTestUtil.verifyAndCloseConfirmActionDialog(
        tester: tester,
        confirmDialogTitleOne:
            'Supprimer la playlist Youtube "$youtubePlaylistToDeleteTitle"',
        confirmDialogMessage:
            'Suppression de la playlist, de ses 9 fichiers audio, de ses 2 commentaire(s) audio, de ses 1 photo(s) audio ainsi que de son fichier JSON et de son répertoire.',
        confirmOrCancelAction: true, // Confirm button is tapped
      );

      // Reload the settings from the json file.
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      // Check that the deleted playlist title is no longer in the
      // playlist titles list of the settings data service
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          ['Bible Bénie', 'Nouvelle Bible Bénie']);

      final String youtubePlaylistToDeletePath = path.join(
        kApplicationPathWindowsTest,
        youtubePlaylistToDeleteTitle,
      );

      // Check that the deleted playlist directory no longer exist
      expect(Directory(youtubePlaylistToDeletePath).existsSync(), false);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('PlaylistDownloadView buttons state test', () {
    testWidgets('PlaylistDownloadView displayed with no selected playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // since no playlist is selected, verify that no button is
      // enabled
      await _ensureNoButtonIsEnabledSinceNoPlaylistIsSelected(tester);

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // since no playlist is selected, verify that no button is
      // enabled
      await _ensureNoButtonIsEnabledSinceNoPlaylistIsSelected(tester);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Select a local playlist with no audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'local_audio_playlist_2',
      );

      // since a local playlist is selected, verify that
      // some buttons are enabled and some are disabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the selected local playlist has no audio, the
      // audio menu item is disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Select a Youtube playlist with no audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the Youtube playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'audio_player_view_2_shorts_test',
      );

      // since a Youtube playlist is selected, verify that all
      // buttons are enabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the selected local playlist has no audio, the
      // audio menu item is disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Select a local playlist with audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'local_3',
      );

      // since a local playlist is selected, verify that
      // some buttons are enabled and some are disabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      // since the playlist has audio, the audio popup menu
      // button is enabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Select a Youtube playlist with audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the Youtube playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'audio_learn_test_download_2_small_videos',
      );

      // since a Youtube playlist is selected, verify that all
      // buttons are enabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      // since the playlist has audio, the audio popup menu
      // button is enabled
      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete a Youtube playlist with audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the Youtube playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'audio_learn_test_download_2_small_videos',
      );

      // First, find the Playlist ListTile Text widget
      const String youtubePlaylistToSelectTitle =
          'audio_learn_test_download_2_small_videos';

      final Finder youtubePlaylistToSelectListTileTextWidgetFinder =
          find.text(youtubePlaylistToSelectTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder youtubePlaylistToSelectListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistToSelectListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder youtubePlaylistToSelectListTileCheckboxWidgetFinder =
          find.descendant(
        of: youtubePlaylistToSelectListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(youtubePlaylistToSelectListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // now delete the selected playlist

      // find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder youtubePlaylistToDeleteListTileLeadingMenuIconButton =
          find.descendant(
        of: youtubePlaylistToSelectListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistToDeleteListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the confirm dialog message

      final Text deletePlaylistDialogTitleWidget = tester
          .widget<Text>(find.byKey(const Key('confirmDialogTitleOneKey')));

      expect(deletePlaylistDialogTitleWidget.data,
          'Delete Youtube Playlist "$youtubePlaylistToSelectTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // since the Youtube playlist was deleted, verify that all
      // buttons are disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete a local playlist with 1 audio',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the local playlist
      // Find the local playlist to select

      // First, find the Playlist ListTile Text widget
      const String localPlaylistTitle = 'local_3';
      final Finder localPlaylistToSelectListTileTextWidgetFinder =
          find.text(localPlaylistTitle);

      // Then obtain the Playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      final Finder localPlaylistToSelectListTileWidgetFinder = find.ancestor(
        of: localPlaylistToSelectListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );
      // Select the local playlist

      // Now find the Checkbox widget located in the Playlist ListTile
      // and tap on it to select the playlist
      final Finder localPlaylistToSelectListTileCheckboxWidgetFinder =
          find.descendant(
        of: localPlaylistToSelectListTileWidgetFinder,
        matching: find.byType(Checkbox),
      );

      // Tap the ListTile Playlist checkbox to select it
      await tester.tap(localPlaylistToSelectListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();
      // now delete the selected playlist

      // find the leading menu icon button of the Playlist to
      // delete ListTile and tap on it
      final Finder localPlaylistToDeleteListTileLeadingMenuIconButton =
          find.descendant(
        of: localPlaylistToSelectListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localPlaylistToDeleteListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Material).last, // The popup menu is wrapped in Material
        const Offset(0, -300),
      );

      await tester.pumpAndSettle();

      // Now find the delete playlist popup menu item and tap on it
      final Finder popupDeletePlaylistMenuItem =
          find.byKey(const Key("popup_menu_delete_playlist"));

      await tester.tap(popupDeletePlaylistMenuItem);
      await tester.pumpAndSettle();

      // Now verifying the confirm dialog message

      final Text deletePlaylistDialogTitleWidget = tester
          .widget<Text>(find.byKey(const Key('confirmDialogTitleOneKey')));

      expect(deletePlaylistDialogTitleWidget.data,
          'Delete Local Playlist "$localPlaylistTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // since the local playlist was deleted, verify that all
      // buttons are disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete a unique audio in a local playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'local_3',
      );

      // now delete the unique audio of the playlist

      // Now we want to tap the popup menu of the unique Audio ListTile
      // "audio learn test short video two"

      // First, find the Audio sublist ListTile Text widget
      final Finder uniqueAudioListTileTextWidgetFinder =
          find.text('audio learn test short video two');

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder uniqueAudioListTileWidgetFinder = find.ancestor(
        of: uniqueAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder uniqueAudioListTileLeadingMenuIconButton = find.descendant(
        of: uniqueAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(uniqueAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the delete audio popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_delete_audio"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the selected local playlist has no audio, the
      // audio menu item is disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete a unique audio in a Youtube playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of no selected playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the Youtube playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'audio_learn_new_youtube_playlist_test',
      );

      // now delete the unique audio of the playlist

      // Now we want to tap the popup menu of the unique Audio ListTile
      // "audio learn test short video two"

      // First, find the Audio sublist ListTile Text widget
      final Finder uniqueAudioListTileTextWidgetFinder =
          find.text('audio learn test short video two');

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder uniqueAudioListTileWidgetFinder = find.ancestor(
        of: uniqueAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder uniqueAudioListTileLeadingMenuIconButton = find.descendant(
        of: uniqueAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(uniqueAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the delete audio popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_delete_audio"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_up_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'move_down_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'download_sel_playlist_button',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_quality_checkbox',
      );

      IntegrationTestUtil.verifyWidgetIsEnabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now open the audio popup menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // since the selected local playlist has no audio, the
      // audio menu item is disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    group('Open app with or without selected playlist', () {
      group('With playlist list displayed', () {
        testWidgets('Selected local playlist with no audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          await app.main();
          await tester.pumpAndSettle();

          // since a local playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyLocalSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: true,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Youtube playlist with no audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle =
              'audio_player_view_2_shorts_test';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyYoutubeSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: true,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Local playlist with audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle = 'local_3';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyLocalSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: true,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Youtube playlist with audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle =
              'audio_learn_new_youtube_playlist_test';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyYoutubeSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: true,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
      group('With playlist list not displayed', () {
        testWidgets('Selected local playlist with no audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          // Changing the playlists list display before starting the
          // application
          settingsDataService.set(
              settingType: SettingType.playlists,
              settingSubType:
                  Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
              value: false);

          settingsDataService.saveSettings();

          await app.main();
          await tester.pumpAndSettle();

          // since a local playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyLocalSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: false,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Youtube playlist with no audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          // Changing the playlists list display before starting the
          // application
          settingsDataService.set(
              settingType: SettingType.playlists,
              settingSubType:
                  Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
              value: false);

          settingsDataService.saveSettings();

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle =
              'audio_player_view_2_shorts_test';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyYoutubeSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: false,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Local playlist with audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          // Changing the playlists list display before starting the
          // application
          settingsDataService.set(
              settingType: SettingType.playlists,
              settingSubType:
                  Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
              value: false);

          settingsDataService.saveSettings();

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle = 'local_3';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyLocalSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: false,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
        testWidgets('Selected Youtube playlist with audio',
            (WidgetTester tester) async {
          // Purge the test playlist directory if it exists so that the
          // playlist list is empty
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );

          // Copy the test initial audio data to the app dir
          DirUtil.copyFilesFromDirAndSubDirsToDirectory(
            sourceRootPath:
                "$kDownloadAppTestSavedDataDir${path.separator}playlist_download_view_button_state_at_app_start_test",
            destinationRootPath: kApplicationPathWindowsTest,
          );

          final SettingsDataService settingsDataService = SettingsDataService(
            isTest: true,
          );

          // Load the settings from the json file. This is necessary
          // otherwise the ordered playlist titles will remain empty
          // and the playlist list will not be filled with the
          // playlists available in the download app test dir
          await settingsDataService.loadSettingsFromFile(
              settingsJsonPathFileName:
                  "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

          // Changing the playlists list display before starting the
          // application
          settingsDataService.set(
              settingType: SettingType.playlists,
              settingSubType:
                  Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
              value: false);

          settingsDataService.saveSettings();

          const String initiallySelectedPlaylistTitle =
              'local_audio_playlist_2';
          const String nowSelectedPlaylistTitle =
              'audio_learn_new_youtube_playlist_test';

          _modifySelectedPlaylistBeforeStartingApplication(
            playlistToUnselectTitle: initiallySelectedPlaylistTitle,
            playlistToSelectTitle: nowSelectedPlaylistTitle,
          );

          await app.main();
          await tester.pumpAndSettle();

          // since a locYoutubeal playlist is selected, verify that
          // some buttons and checkbox are enabled and some are disabled
          await _verifyYoutubeSelectedPlaylistButtonsAndCheckbox(
            tester: tester,
            isPlaylistListDisplayed: false,
          );

          // Purge the test playlist directory so that the created test
          // files are not uploaded to GitHub
          DirUtil.deleteFilesInDirAndSubDirs(
            rootPath: kApplicationPathWindowsTest,
          );
        });
      });
    });
  });
  group('Rename audio file test and verify comment and picture rename', () {
    testWidgets('''Not existing new audio file name and the renamed audio has
                   comments.''', (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "Really short video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // Deletion of comment file used by another test, but not needed
      // for this test
      final String commentFilePath =
          "$kApplicationPathWindowsTest${path.separator}$youtubePlaylistTitle${path.separator}$kCommentDirName${path.separator}231117-002826-Really short video 23-07-01.json";
      DirUtil.deleteFileIfExist(pathFileName: commentFilePath);

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "Really short video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the button text
      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Rename');

      // Verify the dialog title
      expect(find.text('Rename Audio File'), findsOneWidget);

      // Now enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String oldFileName = '231117-002826-Really short video 23-07-01';

      expect(textField.controller!.text, "$oldFileName.mp3");

      // Enter new file name

      const String newFileName = '231117-Really short video 23-07-01';

      await tester.enterText(
        textFieldFinder,
        "$newFileName.mp3",
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is displayed
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Audio file \"$oldFileName.mp3\" renamed to \"$newFileName.mp3\" as well as comment file \"$oldFileName.json\" renamed to \"$newFileName.json\".",
        isWarningConfirming: true,
      );

      // Verify that the renamed audio file exists
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$newFileName.mp3";
      expect(File(renamedAudioFilePath).existsSync(), true);

      // Verify that the renamed comment file exists
      final String renamedCommentFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$kCommentDirName${path.separator}$newFileName.json";
      expect(File(renamedCommentFilePath).existsSync(), true);

      // Check the new file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, "$newFileName.mp3");

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Not existing new audio file name and not existing new comment
                   file name (the renamed audio has a comment file which will be
                   renamed as well).''', (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // Before renaming the audio file, we verify that the audio has
      // a comment

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // The audio file we will rename has a comment linked to this
      // file name. Before renaming the file, verify the comment exist ...
      String expectedCommentTitle =
          'morning _ cinematic accessible after renaming';

      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: expectedCommentTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the button text
      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Rename');

      // Verify the dialog title
      expect(find.text('Rename Audio File'), findsOneWidget);

      // Now enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String oldMp3FileName =
          '231117-002828-morning _ cinematic video 23-07-01.mp3';

      expect(textField.controller!.text, oldMp3FileName);

      // Enter new file name

      const String newMp3FileName = '240610-Renamed video 23-07-01.mp3';
      const String newCommentFileName = '240610-Renamed video 23-07-01.json';

      await tester.enterText(
        textFieldFinder,
        newMp3FileName,
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is displayed

      final String oldJsonFileName = oldMp3FileName.replaceAll('mp3', 'json');
      final String newJsonFileName = newMp3FileName.replaceAll('mp3', 'json');

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Audio file \"$oldMp3FileName\" renamed to \"$newMp3FileName\" as well as comment file \"$oldJsonFileName\" renamed to \"$newJsonFileName\".",
        isWarningConfirming: true,
      );

      // Verify that the renamed audio file exists
      final String renamedAudioFilePathName =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$newMp3FileName";
      expect(File(renamedAudioFilePathName).existsSync(), true);

      // Verify that the renamed comment file exists
      final String renamedCommentFilePathName =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$kCommentDirName${path.separator}$newCommentFileName";
      expect(File(renamedCommentFilePathName).existsSync(), true);

      // Check the new file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, newMp3FileName);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // The audio file we could not rename still access to its comment ...
      await _checkAudioCommentInAudioPlayerView(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: expectedCommentTitle,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Existing new audio file name. The new file name is the name of an
           existing file in the same directory. In this case, a warning is
           displayed and the file is not renamed.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // Before renaming the audio file, we verify that the audio has
      // a comment

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Rename Audio File'), findsOneWidget);

      // Now enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String initialFileName =
          '231117-002828-morning _ cinematic video 23-07-01.mp3';

      expect(textField.controller!.text, initialFileName);

      // Now entering the name of an existing file in the audio directory
      // in the file name TextField
      const String fileNameOfExistingFile =
          '231117-002826-Really short video 23-07-01.mp3';

      await tester.enterText(
        textFieldFinder,
        fileNameOfExistingFile,
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Since file name is the name of an existing file in the audio
      // directory, a warning will be displayed ...

      // Ensure the warning dialog is shown
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "The file name \"$fileNameOfExistingFile\" already exists in the same directory and cannot be used.",
      );

      // Verify that the old name file exists
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$initialFileName";
      expect(File(renamedAudioFilePath).existsSync(), true);

      // Check the old file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio old file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, initialFileName);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Invalid new file name with no mp3 extension. In this case, the displayed confirmation
           shows that a MP3 extention was added and that the file was renamed.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // Before renaming the audio file, we verify that the audio has
      // a comment

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Rename Audio File'), findsOneWidget);

      // Now enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String initialFileNameNoExt =
          '231117-002828-morning _ cinematic video 23-07-01';

      expect(textField.controller!.text, '$initialFileNameNoExt.mp3');

      // Now entering an invalid file name in the file name TextField
      const String renamedFileNameNoExt = 'Really short video';

      await tester.enterText(
        textFieldFinder,
        renamedFileNameNoExt,
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Since file name has no mp3 extension a warning will be displayed ...

      // Ensure the warning dialog is displayed
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Audio file \"$initialFileNameNoExt.mp3\" renamed to \"$renamedFileNameNoExt.mp3\" as well as comment file \"$initialFileNameNoExt.json\" renamed to \"$renamedFileNameNoExt.json\".",
        isWarningConfirming: true,
      );

      // Verify that the old name file no longer exists
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubePlaylistTitle${path.separator}$initialFileNameNoExt.mp3";
      expect(File(renamedAudioFilePath).existsSync(), false);

      // Check the old file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, '$renamedFileNameNoExt.mp3');

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Not existing new audio file name and existing new comment
                   file name. The renamed audio has a comment file which will be
                   renamed as well, but since a comment file exist with
                   the renamed comment file name, a warning will be displayed
                   and the file will not be renamed.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
      const String audioToRenameTitle =
          "Quand Aurélien Barrau va dans une école de management";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_corrected_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // Before renaming the audio file, we verify that the audio has
      // a comment

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioToRenameTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // The audio file we will rename has a comment linked to this
      // file name. Before renaming the file, verify the comment exist ...

      String anAudioCommentTitle = 'Aurélien three';

      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: anAudioCommentTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "Quand Aurélien Barrau va dans une école de management"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the button text
      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Rename');

      // Verify the dialog title
      expect(find.text('Rename Audio File'), findsOneWidget);

      // Now enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField
      expect(textField.controller!.text,
          '240722-081104-Quand Aurélien Barrau va dans une école de management 23-09-10.mp3');

      const String newFileName = 'New file name.mp3';

      await tester.enterText(
        textFieldFinder,
        newFileName,
      );

      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Since file name is the name of an existing comment file in the
      // audio comment directory, a warning will be displayed ...

      // Ensure the warning dialog is displayed
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "The comment file name \"${newFileName.substring(0, newFileName.length - 4)}.json\" already exists in the comment directory and so renaming the audio file with the name \"$newFileName\" is not possible.",
      );

      // Verify that the old name file exists
      const String initialFileName =
          "240722-081104-Quand Aurélien Barrau va dans une école de management 23-09-10.mp3";
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}$youtubePlaylistTitle${path.separator}$initialFileName";
      expect(File(renamedAudioFilePath).existsSync(), true);

      // Check the old file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio old file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, initialFileName);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Not existing new audio file name and the renamed audio has 1 comment as well
           as 1 pictures.''', (WidgetTester tester) async {
      const String localPlaylistTitle = 'local'; // Youtube playlist
      const String audioTitle = "Really short video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'rename_audio_file_test',
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      final PictureVM pictureVM = PictureVM(
        settingsDataService: settingsDataService,
      );

      // Load the application picture audio map from the
      // application picture audio map json file.
      Map<String, List<String>> applicationPictureAudioMap =
          pictureVM.readAppPictureAudioMap();

      List pictureAudioMapLst = (applicationPictureAudioMap[
              "Liguria_Italy_Coast_Houses_Riomaggiore_Crag_513222_3840x2400.jpg"]
          as List);

      expect(pictureAudioMapLst.length, 2);
      expect(
        pictureAudioMapLst[0],
        "local|231117-002828-morning _ cinematic video 23-07-01",
      );
      expect(
        pictureAudioMapLst[1],
        "local|231117-002826-Really short video 23-07-01",
      );

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "Really short video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String oldFileName = '231117-002826-Really short video 23-07-01';

      expect(textField.controller!.text, "$oldFileName.mp3");

      // Enter new file name

      const String newFileName = 'modified-Really short video 23-07-01';

      await tester.enterText(
        textFieldFinder,
        "$newFileName.mp3",
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is displayed
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Audio file \"$oldFileName.mp3\" renamed to \"$newFileName.mp3\" as well as comment and picture files \"$oldFileName.json\" renamed to \"$newFileName.json\".",
        isWarningConfirming: true,
      );

      // Verify that the renamed audio file exists
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localPlaylistTitle${path.separator}$newFileName.mp3";
      expect(File(renamedAudioFilePath).existsSync(), true);

      // Verify that the renamed comment file exists
      final String renamedCommentFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localPlaylistTitle${path.separator}$kCommentDirName${path.separator}$newFileName.json";
      expect(File(renamedCommentFilePath).existsSync(), true);

      // Verify that the renamed picture file exists
      final String renamedPictureFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localPlaylistTitle${path.separator}$kPictureDirName${path.separator}$newFileName.json";
      expect(File(renamedPictureFilePath).existsSync(), true);

      // Load the application picture audio map from the
      // application picture audio map json file.
      applicationPictureAudioMap = pictureVM.readAppPictureAudioMap();

      pictureAudioMapLst = (applicationPictureAudioMap[
              "Liguria_Italy_Coast_Houses_Riomaggiore_Crag_513222_3840x2400.jpg"]
          as List);

      expect(pictureAudioMapLst.length, 2);
      expect(
        pictureAudioMapLst[0],
        "local|231117-002828-morning _ cinematic video 23-07-01",
      );
      expect(
        pictureAudioMapLst[1],
        "local|modified-Really short video 23-07-01",
      );

      // Check the new file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, "$newFileName.mp3");

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Not existing new audio file name and the renamed audio has no comment and 2
           pictures.''', (WidgetTester tester) async {
      const String localPlaylistTitle = 'local'; // Youtube playlist
      const String audioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'rename_audio_file_test',
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      final PictureVM pictureVM = PictureVM(
        settingsDataService: settingsDataService,
      );

      // Load the application picture audio map from the
      // application picture audio map json file.
      Map<String, List<String>> applicationPictureAudioMap =
          pictureVM.readAppPictureAudioMap();

      List pictureAudioMapLst = (applicationPictureAudioMap[
              "Liguria_Italy_Coast_Houses_Riomaggiore_Crag_513222_3840x2400.jpg"]
          as List);

      expect(pictureAudioMapLst.length, 2);
      expect(
        pictureAudioMapLst[0],
        "local|231117-002828-morning _ cinematic video 23-07-01",
      );
      expect(
        pictureAudioMapLst[1],
        "local|231117-002826-Really short video 23-07-01",
      );

      pictureAudioMapLst =
          (applicationPictureAudioMap["wallpaper.jpg"] as List);

      expect(pictureAudioMapLst.length, 1);
      expect(
        pictureAudioMapLst[0],
        "local|231117-002828-morning _ cinematic video 23-07-01",
      );

      // First, find the audio sublist ListTile Text widget

      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "Really short video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      final Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the rename audio file popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_rename_audio_file"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Enter the new file name

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField

      const String oldFileName =
          '231117-002828-morning _ cinematic video 23-07-01';

      expect(textField.controller!.text, "$oldFileName.mp3");

      // Enter new file name

      const String newFileName = 'modified-morning _ cinematic video 23-07-01';

      await tester.enterText(
        textFieldFinder,
        "$newFileName.mp3",
      );
      await tester.pumpAndSettle();

      // Now tap the rename button
      await tester.tap(find.byKey(const Key('audioModificationButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is displayed
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Audio file \"$oldFileName.mp3\" renamed to \"$newFileName.mp3\" as well as picture file \"$oldFileName.json\" renamed to \"$newFileName.json\".",
        isWarningConfirming: true,
      );

      // Verify that the renamed audio file exists
      final String renamedAudioFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localPlaylistTitle${path.separator}$newFileName.mp3";
      expect(File(renamedAudioFilePath).existsSync(), true);

      // Verify that the renamed picture file exists
      final String renamedPictureFilePath =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localPlaylistTitle${path.separator}$kPictureDirName${path.separator}$newFileName.json";
      expect(File(renamedPictureFilePath).existsSync(), true);

      // Load the application picture audio map from the
      // application picture audio map json file.
      applicationPictureAudioMap = pictureVM.readAppPictureAudioMap();

      pictureAudioMapLst =
          (applicationPictureAudioMap["wallpaper.jpg"] as List);

      expect(pictureAudioMapLst.length, 1);
      expect(
        pictureAudioMapLst[0],
        "local|modified-morning _ cinematic video 23-07-01",
      );

      pictureAudioMapLst = (applicationPictureAudioMap[
              "Liguria_Italy_Coast_Houses_Riomaggiore_Crag_513222_3840x2400.jpg"]
          as List);

      expect(pictureAudioMapLst.length, 2);
      expect(
        pictureAudioMapLst[0],
        "local|231117-002826-Really short video 23-07-01",
      );
      expect(
        pictureAudioMapLst[1],
        "local|modified-morning _ cinematic video 23-07-01",
      );

      // Check the new file name in the audio info dialog

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new file name

      final Text audioFileNameTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioFileNameKey')));

      expect(audioFileNameTitleTextWidget.data, "$newFileName.mp3");

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Modify audio title test and verify comment display change', () {
    testWidgets('Downl audio change audio title', (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String originalAudioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the audio sublist ListTile Text widget
      Finder audioListTileTextWidgetFinder = find.text(originalAudioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the modify audio title popup menu item and tap on
      // it
      final Finder popupModifyAudioTitleMenuItem =
          find.byKey(const Key("popup_menu_modify_audio_title"));

      await tester.tap(popupModifyAudioTitleMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Modify Audio Title'), findsOneWidget);

      // Verify the dialog comment
      expect(
          find.text(
              'Modify the audio title to allow adjusting its playback order.'),
          findsOneWidget);

      // Verify the button text

      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Modify');

      // Now enter the new title

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField
      expect(textField.controller!.text, 'morning _ cinematic video');

      const String newTitle = 'Morning cinematic video';
      await tester.enterText(
        textFieldFinder,
        newTitle,
      );

      await tester.pumpAndSettle();

      // Now tap on the Modify button
      await tester.tap(audioModificationButtonFinder);
      await tester.pumpAndSettle();

      // Check the modified audio title in the audio info dialog

      // First, find the audio sublist ListTile Text widget
      // using the new title
      audioListTileTextWidgetFinder = find.text(newTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Find the leading menu icon button of the audio ListTile
      // and tap on it

      audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new title

      final Text audioTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('validVideoTitleKey')));

      expect(audioTitleTextWidget.data, newTitle);

      // Verify the presence of Original video title label
      expect(find.text('Original video title'), findsOneWidget);

      // Verify the absence of Audio title label
      expect(find.text('Audio title'), findsNothing);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Verifying that the comment of the audio displays the modified audio title
      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: 'morning _ cinematic accessible after renaming',
        audioTitleToVerifyInCommentAddEditDialog: newTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Imported audio change audio title',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "Really short video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the audio sublist ListTile Text widget
      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the modify audio title popup menu item and tap on
      // it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_modify_audio_title"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Modify Audio Title'), findsOneWidget);

      // Verify the dialog comment
      expect(
          find.text(
              'Modify the audio title to allow adjusting its playback order.'),
          findsOneWidget);

      // Verify the button text

      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Modify');

      // Now enter the new title

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField
      expect(textField.controller!.text, 'Really short video');

      const String newTitle = 'Really really short imported audio';
      await tester.enterText(
        textFieldFinder,
        newTitle,
      );

      await tester.pumpAndSettle();

      // Now tap on the Modify button
      await tester.tap(audioModificationButtonFinder);
      await tester.pumpAndSettle();

      // Check the modified audio title in the audio info dialog

      // First, find the audio sublist ListTile Text widget
      // using the new title
      audioListTileTextWidgetFinder = find.text(newTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Find the leading menu icon button of the audio ListTile
      // and tap on it

      audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new title

      final Text audioTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('importedAudioTitleKey')));

      expect(audioTitleTextWidget.data, newTitle);

      // Verify the presence of Audio title label (only present if the
      // audio was imported)
      expect(find.text('Audio title'), findsOneWidget);

      // Verify the absence of Original video title label
      expect(find.text('Really short video'), findsNothing);

      // Tap the Close button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Verifying that the comment of the audio displays the modified audio title
      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: 'Really short video accessible after renaming',
        audioTitleToVerifyInCommentAddEditDialog: newTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Downl audio chng title', (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the audio sublist ListTile Text widget
      Finder audioListTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the modify audio title popup menu item and tap on
      // it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_modify_audio_title"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Verify that the rename audio file dialog is displayed
      expect(find.byType(AudioModificationDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Modify Audio Title'), findsOneWidget);

      // Verify the dialog comment
      expect(
          find.text(
              'Modify the audio title to allow adjusting its playback order.'),
          findsOneWidget);

      // Verify the button text

      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      TextButton audioModificationTextButton =
          tester.widget<TextButton>(audioModificationButtonFinder);
      expect((audioModificationTextButton.child! as Text).data, 'Modify');

      // Now enter the new title

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      // Retrieve the TextField widget
      final TextField textField = tester.widget<TextField>(textFieldFinder);

      // Verify the initial value of the TextField
      expect(textField.controller!.text, 'morning _ cinematic video');

      const String newTitle = 'Morning cinematic video';
      await tester.enterText(
        textFieldFinder,
        newTitle,
      );

      await tester.pumpAndSettle();

      // Now tap on the Modify button
      await tester.tap(audioModificationButtonFinder);
      await tester.pumpAndSettle();

      // Check the modified audio title in the audio info dialog

      // First, find the audio sublist ListTile Text widget
      // using the new title
      audioListTileTextWidgetFinder = find.text(newTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Find the leading menu icon button of the audio ListTile
      // and tap on it

      audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new title

      final Text audioTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('validVideoTitleKey')));

      expect(audioTitleTextWidget.data, newTitle);

      // Verify the presence of Original video title label (this label
      // is only present for a downloaded audio)
      expect(find.text('Original video title'), findsOneWidget);

      // Verify the absence of Audio title label (this label is only
      // present if the audio was imported)
      expect(find.text('Audio title'), findsNothing);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Verifying that the comment of the audio displays the modified audio title
      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: 'morning _ cinematic accessible after renaming',
        audioTitleToVerifyInCommentAddEditDialog: newTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Downl audio chng title and comments',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle =
          'audio_player_view_2_shorts_test'; // Youtube playlist
      const String audioOneTitle = "morning _ cinematic video";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: '2_youtube_2_local_playlists_integr_test_data',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the "morning _ cinematic video" audio sublist
      // ListTile Text widget
      Finder audioListTileTextWidgetFinder = find.text(audioOneTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audio ListTile
      // "morning _ cinematic video"

      // Find the leading menu icon button of the audio ListTile
      // and tap on it
      Finder audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the modify audio title popup menu item and tap on
      // it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_modify_audio_title"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Now enter the new title

      // Find the TextField using the Key
      final Finder textFieldFinder =
          find.byKey(const Key('audioModificationTextField'));

      const String newTitle = "MODIFIED morning _ cinematic video";
      await tester.enterText(
        textFieldFinder,
        newTitle,
      );
      await tester.pumpAndSettle();

      // Now tap on the Modify button

      final Finder audioModificationButtonFinder =
          find.byKey(const Key('audioModificationButton'));
      await tester.tap(audioModificationButtonFinder);
      await tester.pumpAndSettle();

      // Now verify the playlist audio titles

      List<String>
          audioTitlesSortedDownloadDateDescendingDefaultSortFilterParms = [
        "MODIFIED morning _ cinematic video",
        "Really short video",
      ];

      IntegrationTestUtil.checkAudioOrPlaylistTitlesOrderInListTile(
        tester: tester,
        audioOrPlaylistTitlesOrderedLst:
            audioTitlesSortedDownloadDateDescendingDefaultSortFilterParms,
        firstAudioListTileIndex: 4,
      );

      // Check the modified audio title its audio comment

      // First, find the audio sublist ListTile Text widget
      // using the new title
      audioListTileTextWidgetFinder = find.text(newTitle);

      audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: 'morning _ cinematic accessible after renaming',
        audioTitleToVerifyInCommentAddEditDialog: newTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      audioListTileWidgetFinder = find.ancestor(
        of: audioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Find the leading menu icon button of the audio ListTile
      // and tap on it

      audioListTileLeadingMenuIconButton = find.descendant(
        of: audioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );
      await tester.tap(audioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Verify the audio new title

      final Text audioTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('validVideoTitleKey')));

      expect(audioTitleTextWidget.data, newTitle);

      // Verify the presence of Original video title label (this label
      // is only present for a downloaded audio)
      expect(find.text('Original video title'), findsOneWidget);

      // Verify the absence of Audio title label (this label is only
      // present if the audio was imported)
      expect(find.text('Audio title'), findsNothing);

      // Tap the Ok button to close the audio info dialog
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Verifying that the comment of the audio displays the modified audio title
      await _checkAudioCommentUsingAudioItemMenu(
        tester: tester,
        audioListTileWidgetFinder: audioListTileWidgetFinder,
        expectedCommentTitle: 'morning _ cinematic accessible after renaming',
        audioTitleToVerifyInCommentAddEditDialog: newTitle,
        isAutoRefreshCommentDialogExpected: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('PlaylistCommentListDialog test', () {
    testWidgets(
        '''On empty playlist, opening the playlist audio comments dialog.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
      const String emptyPlaylistTitle = 'Empty'; // Youtube playlist

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'import_audio_file_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the Empty playlist sublist ListTile Text widget
      Finder emptyPlaylistListTileTextWidgetFinder =
          find.text(emptyPlaylistTitle);

      // Then obtain the playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder emptyPlaylistListTileWidgetFinder = find.ancestor(
        of: emptyPlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the Empty  playlist ListTile

      // Find the leading menu icon button of the playlist ListTile
      // and tap on it
      Finder emptyPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: emptyPlaylistListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(emptyPlaylistListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the List comments of playlist audio popup menu
      // item and tap on it
      final Finder popupPlaylistAudioCommentsMenuItem =
          find.byKey(const Key("popup_menu_display_playlist_audio_comments"));

      await tester.tap(popupPlaylistAudioCommentsMenuItem);
      await tester.pumpAndSettle();

      // Verify that the playlist audio comment dialog is displayed
      expect(find.byType(PlaylistCommentListDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Playlist Audio Comments'), findsOneWidget);

      // Verify that the audio comments list of the dialog is empty

      final Finder playlistCommentsLstFinder = find.byKey(const Key(
        'playlistCommentsListKey',
      ));

      // Ensure the list has no child widgets
      expect(
        tester.widget<ListBody>(playlistCommentsLstFinder).children.length,
        0,
      );

      // Tap on Close text button
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Playlist comments color verification. In the playlist comment dialog, verify
           that the audio titles are displayed in the correct color: the current commented audio
           color is white on blue. The partially listened commented audio color is blue. The fully
           listened commented audio color is pink. Finally, the not listened commented audio color
           is white. Verify as well the comments titles color, which is white.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_color_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, open the playlist comment dialog
      Finder playlistCommentListDialogFinder =
          await IntegrationTestUtil.openPlaylistCommentDialog(
        tester: tester,
        playlistTitle: youtubePlaylistTitle,
      );

      final Finder playlistCommentListFinder =
          find.byKey(const Key('playlistCommentsListKey'));

      // Ensure the list has 8 child widgets
      expect(
        tester.widget<ListBody>(playlistCommentListFinder).children.length,
        8,
      );

      // Verify the color of the audio titles in the playlist comment dialog

      await _verifyAudioTitlesColorInPlaylistCommentDialog(
        tester: tester,
        playlistCommentListDialogFinder: playlistCommentListDialogFinder,
      );

      // Verifying the color of comments titles in the playlist comment
      // dialog

      await IntegrationTestUtil.checkAudioTextColor(
        tester: tester,
        enclosingWidgetFinder: playlistCommentListDialogFinder,
        audioTitleOrSubTitle: "Barrau one",
        expectedTitleTextColor: null,
        expectedTitleTextBackgroundColor: null,
      );

      await IntegrationTestUtil.checkAudioTextColor(
        tester: tester,
        enclosingWidgetFinder: playlistCommentListDialogFinder,
        audioTitleOrSubTitle: "One",
        expectedTitleTextColor: null,
        expectedTitleTextBackgroundColor: null,
      );

      await IntegrationTestUtil.checkAudioTextColor(
        tester: tester,
        enclosingWidgetFinder: playlistCommentListDialogFinder,
        audioTitleOrSubTitle: "Comment Jancovici",
        expectedTitleTextColor: null,
        expectedTitleTextBackgroundColor: null,
      );

      await IntegrationTestUtil.checkAudioTextColor(
        tester: tester,
        enclosingWidgetFinder: playlistCommentListDialogFinder,
        audioTitleOrSubTitle: "Start",
        expectedTitleTextColor: null,
        expectedTitleTextBackgroundColor: null,
      );

      // Tap on Close text button
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''With playlist comment menu, manage comments in initially empty playlist. Copy audio
           to the empty playlist, add a comment and then delete it in the audio player view using
           the left appbar 'Audio Comments ...' menu comment delete icon.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
      const String emptyPlaylistTitle = 'Empty'; // Local empty playlist
      const String uncommentedAudioTitle =
          "La surpopulation mondiale par Jancovici et Barrau";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_test',
        selectedPlaylistTitle: emptyPlaylistTitle,
      );

      // First, open the playlist comment dialog
      await IntegrationTestUtil.openPlaylistCommentDialog(
        tester: tester,
        playlistTitle: emptyPlaylistTitle,
      );

      // Now close the comment list dialog
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Copy an uncommented audio from the Youtube playlist to
      // the empty playlist
      await IntegrationTestUtil.copyAudioFromSourceToTargetPlaylist(
        tester: tester,
        sourcePlaylistTitle: youtubePlaylistTitle,
        targetPlaylistTitle: emptyPlaylistTitle,
        audioToCopyTitle: uncommentedAudioTitle, // "La surpopulation mondiale
        //                                           par Jancovici et Barrau"
      );

      // Now we want to tap on the copied uncommented audio in the
      // empty playlist in order to open the AudioPlayerView displaying
      // the audio to be able to add a comment to it.

      // Then, get the ListTile Text widget finder of the uncommented
      // audio copied in the empty playlist and tap on it to open the
      // AudioPlayerView
      final Finder audioTitleNotYetCommentedFinder =
          find.text(uncommentedAudioTitle);
      await tester.tap(audioTitleNotYetCommentedFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Ensure that the comment playlist directory does not exist
      final Directory directory = Directory(
          "kPlaylistDownloadRootPathWindows${path.separator}$emptyPlaylistTitle${path.separator}$kCommentDirName");

      expect(directory.existsSync(), false);

      // Now tap the appbar leading popup menu button which now
      // displays all the usable menu items available on an existing
      // audio. Then, the 'Audio Comments ...' menu item is used to open
      // the comment add list dialog
      await IntegrationTestUtil.typeOnAppbarMenuItem(
        tester: tester,
        appbarMenuKeyStr: 'appbar_popup_menu_audio_comment',
      );

      // Verify that the comment dialog is displayed
      expect(find.text('Comments'), findsOneWidget);

      // Verify that no comment is displayed in the comment list
      final commentWidget = find.byKey(const ValueKey('commentTitleKey'));

      // Assert that no comment widgets are found
      expect(commentWidget, findsNothing);

      // Now tap on the Add comment icon button to open the add
      // edit comment dialog
      await tester
          .tap(find.byKey(const Key('addPositionedCommentIconButtonKey')));
      await tester.pumpAndSettle();

      // Verify style of title TextField and enter title text
      String commentTitle = 'Comment title';
      await IntegrationTestUtil.checkTextFieldStyleAndEnterText(
        tester: tester,
        textFieldKeyStr: 'commentTitleTextField',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        textToEnter: commentTitle,
      );

      // Verify style of comment TextField and enter comment text
      String commentText = 'Comment text';
      String commentContentTextFieldKeyStr = 'commentContentTextField';
      await IntegrationTestUtil.checkTextFieldStyleAndEnterText(
        tester: tester,
        textFieldKeyStr: commentContentTextFieldKeyStr,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        textToEnter: commentText,
      );

      // Verify audio title displayed in the comment dialog
      expect(
        find.text(uncommentedAudioTitle),
        findsOneWidget, // "La surpopulation mondiale par Jancovici
        //                  et Barrau"
      );

      String expectedAudioPlayerViewCurrentAudioPosition = '0:34';

      // Verify the initial comment position displayed in the
      // comment start and end positions in the comment dialog.
      // This position was the audio player view position when
      // the comment dialog was opened.
      String commentStartAndEndInitialPosition =
          expectedAudioPlayerViewCurrentAudioPosition;

      final Finder commentStartTextWidgetFinder =
          find.byKey(const Key('commentStartPositionText')); // 0:34
      final Finder commentEndTextWidgetFinder =
          find.byKey(const Key('commentEndPositionText')); // 0:34

      expect(
        tester.widget<Text>(commentStartTextWidgetFinder).data!,
        commentStartAndEndInitialPosition, // 0:34
      );
      expect(
        tester.widget<Text>(commentEndTextWidgetFinder).data!,
        commentStartAndEndInitialPosition, // 0:34
      );

      // Tap on add text button
      final Finder addOrUpdateCommentTextButton =
          find.byKey(const Key('addOrUpdateCommentTextButton'));
      await tester.tap(addOrUpdateCommentTextButton);
      await tester.pumpAndSettle();

      // Verify that the comment list dialog now displays the
      // added comment

      final Finder commentListDialogFinder =
          find.byKey(const Key('audioCommentsListKey'));

      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentTitle)),
          findsOneWidget);
      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentText)),
          findsOneWidget);

      expect(
          find.descendant(
            of: commentListDialogFinder,
            matching: find.text(expectedAudioPlayerViewCurrentAudioPosition),
          ),
          findsNWidgets(2));
      expect(
          find.descendant(
            of: commentListDialogFinder,
            matching: find.text(frenchDateFormatYy.format(DateTime.now())),
          ),
          findsOneWidget);

      // Now close the comment list dialog
      await tester.tap(find.byKey(const Key('closeDialogTextButton')));
      await tester.pumpAndSettle();

      // Now tap the appbar leading popup menu button which now
      // displays all the usable menu items available on an existing
      // audio. Then, the 'Audio Comments ...' menu item is used to open
      // the comment add list dialog
      await IntegrationTestUtil.typeOnAppbarMenuItem(
        tester: tester,
        appbarMenuKeyStr: 'appbar_popup_menu_audio_comment',
      );

      // Now tap on the delete comment icon button to delete the comment
      await tester.tap(find.byKey(const Key('deleteCommentIconButton')));
      await tester.pumpAndSettle();

      // Verify the delete comment dialog title
      expect(find.text('Delete Comment'), findsOneWidget);

      // Verify the delete comment dialog message
      expect(find.text("Deleting comment \"$commentTitle\"."), findsOneWidget);

      // Confirm the deletion of the comment
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Verify that the comment list dialog now displays no comment
      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentTitle)),
          findsNothing);

      // Now close the comment list dialog
      await tester.tap(find.byKey(const Key('closeDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Delete comment in audio containing only one comment using the playlist
           comment dialog.''', (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_color_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the Youtube playlist audio ListTile Text widget
      Finder youtubePlaylistTitleTileTextWidgetFinder =
          find.text(youtubePlaylistTitle);

      // Then obtain the playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder youtubePlaylistTitleTileWidgetFinder = find.ancestor(
        of: youtubePlaylistTitleTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the youtubePlaylistTitle
      // ListTile

      // Find the leading menu icon button of the audioTitle ListTile
      // and tap on it
      Finder youtubePlaylistTitleTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistTitleTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistTitleTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the 'Playlist Audio Comments ...' popup menu item and
      // tap on it
      final Finder playlistAudioCommentsPopupMenuItem =
          find.byKey(const Key("popup_menu_display_playlist_audio_comments"));

      await tester.tap(playlistAudioCommentsPopupMenuItem);
      await tester.pumpAndSettle();

      // Verify that the playlist audio comment dialog is displayed
      expect(find.byType(PlaylistCommentListDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Playlist Audio Comments'), findsOneWidget);

      // Verify that the audio comments list of the playlist comments
      // dialog has 8 list items

      Finder audioCommentsLstFinder = find.byKey(const Key(
        'playlistCommentsListKey',
      ));

      // Ensure the list has height child widgets
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        8,
      );

      // Now delete the 'Comment Jancovici' comment

      final String commentTitle = 'Comment Jancovici';

      // Find the comment item in the playlist comments list dialog
      final Finder rowWithCommentFinder = find.ancestor(
        of: find.text(commentTitle),
        matching: find.byType(Row), // or whatever container widget is used
      );
      final Finder deleteCommentIconButtonFinder = find
          .descendant(
            of: rowWithCommentFinder,
            matching: find.byIcon(Icons.clear), // or the appropriate icon
          )
          .last; // If there are multiple icons, get the last one
      await tester.tap(deleteCommentIconButtonFinder);
      await tester.pumpAndSettle();

      // Verify the delete comment dialog title
      expect(find.text('Delete Comment'), findsOneWidget);

      // Verify the delete comment dialog message
      expect(find.text("Deleting comment \"$commentTitle\"."), findsOneWidget);

      // Confirm the deletion of the comment
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      final Finder commentListDialogFinder =
          find.byType(PlaylistCommentListDialog);

      // Verify that the comment list dialog doesn't display the
      // deleted comments title
      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentTitle)),
          findsExactly(0));

      // Ensure the list has now six list items. Since the deleted comment
      // was the unique comment of the audio, the audio title is no longer
      // displayed in the playlist comment list dialog, the reason why 2 list
      // items were removed from playlist comments list.
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        6,
      );

      // Now close the comment list dialog
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Delete comment in audio containing two comments using the playlist
                comment dialog. Before deleting the comment, add a new comment to the
                audio which contains one comment.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_color_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the Youtube playlist audio ListTile Text widget
      Finder youtubePlaylistTitleTileTextWidgetFinder =
          find.text(youtubePlaylistTitle);

      // Then obtain the playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder youtubePlaylistTitleTileWidgetFinder = find.ancestor(
        of: youtubePlaylistTitleTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the youtubePlaylistTitle
      // ListTile

      // Find the leading menu icon button of the playlistTitle ListTile
      // and tap on it
      Finder youtubePlaylistTitleTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistTitleTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistTitleTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the 'Playlist Audio Comments ...' popup menu item and
      // tap on it
      Finder playlistAudioCommentsPopupMenuItem =
          find.byKey(const Key("popup_menu_display_playlist_audio_comments"));

      await tester.tap(playlistAudioCommentsPopupMenuItem);
      await tester.pumpAndSettle();

      // Verify that the playlist audio comment dialog is displayed
      expect(find.byType(PlaylistCommentListDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Playlist Audio Comments'), findsOneWidget);

      // Verify that the audio comments list of the playlist comments
      // dialog has 8 list items

      Finder audioCommentsLstFinder = find.byKey(const Key(
        'playlistCommentsListKey',
      ));

      // Ensure the list has height list items
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        8,
      );

      // Now close the comment list dialog
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Now add a new comment to the audio "Jancovici m'explique
      // l’importance des ordres de grandeur face au changement
      // climatique" which contains already one comment.

      const String oneCommentAudioTitle =
          "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

      // Now we want to tap on the one comment audio in the AudioPlayerView
      // displaying the audio to be able to add a new comment to it.

      // GGet the ListTile Text widget finder of the uncommented audio
      // copied in the empty playlist and tap on it to open the
      // AudioPlayerView
      final Finder oneCommentAudioTitleFinder = find.text(oneCommentAudioTitle);
      await tester.tap(oneCommentAudioTitleFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Now tap the appbar leading popup menu button which now
      // displays all the usable menu items available on an existing
      // audio. Then, the 'Audio Comments ...' menu item is used to open
      // the comment add list dialog
      await IntegrationTestUtil.typeOnAppbarMenuItem(
        tester: tester,
        appbarMenuKeyStr: 'appbar_popup_menu_audio_comment',
      );

      // Now tap on the Add comment icon button to open the add edit comment dialog
      await tester
          .tap(find.byKey(const Key('addPositionedCommentIconButtonKey')));
      await tester.pumpAndSettle();

      // Verify style of title TextField and enter title text
      String commentTitle = 'New comment title';
      const String commentText = 'New comment text';

      await IntegrationTestUtil.checkTextFieldStyleAndEnterText(
        tester: tester,
        textFieldKeyStr: 'commentTitleTextField',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        textToEnter: commentTitle,
      );

      // Verify style of comment TextField and enter comment text
      String commentContentTextFieldKeyStr = 'commentContentTextField';
      await IntegrationTestUtil.checkTextFieldStyleAndEnterText(
        tester: tester,
        textFieldKeyStr: commentContentTextFieldKeyStr,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        textToEnter: commentText,
      );

      // Tap on add text button
      final Finder addOrUpdateCommentTextButton =
          find.byKey(const Key('addOrUpdateCommentTextButton'));
      await tester.tap(addOrUpdateCommentTextButton);
      await tester.pumpAndSettle();

      // Now close the comment list dialog
      await tester.tap(find.byKey(const Key('closeDialogTextButton')));
      await tester.pumpAndSettle();

      // Return to the playlist download view
      Finder applicationViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(applicationViewNavButton);
      await tester.pumpAndSettle();

      // Now delete the 'Comment Jancovici' comment

      // First, find the Youtube playlist audio ListTile Text widget
      youtubePlaylistTitleTileTextWidgetFinder =
          find.text(youtubePlaylistTitle);

      // Then obtain the playlist ListTile widget enclosing the Text widget
      // by finding its ancestor
      youtubePlaylistTitleTileWidgetFinder = find.ancestor(
        of: youtubePlaylistTitleTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the youtubePlaylistTitle
      // ListTile

      // Find the leading menu icon button of the playlistTitle ListTile
      // and tap on it
      youtubePlaylistTitleTileLeadingMenuIconButton = find.descendant(
        of: youtubePlaylistTitleTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubePlaylistTitleTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the 'Playlist Audio Comments ...' popup menu item and
      // tap on it
      playlistAudioCommentsPopupMenuItem =
          find.byKey(const Key("popup_menu_display_playlist_audio_comments"));

      await tester.tap(playlistAudioCommentsPopupMenuItem);
      await tester.pumpAndSettle();

      audioCommentsLstFinder = find.byKey(const Key(
        'playlistCommentsListKey',
      ));

      // Ensure the list has nine list items (after adding one comment)
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        9,
      );

      commentTitle = 'Comment Jancovici';

      // Find the comment item in the playlist comments list dialog
      final Finder rowWithCommentFinder = find.ancestor(
        of: find.text(commentTitle),
        matching: find.byType(Row), // or whatever container widget is used
      );
      final Finder deleteCommentIconButtonFinder = find
          .descendant(
            of: rowWithCommentFinder,
            matching: find.byIcon(Icons.clear), // or the appropriate icon
          )
          .last; // If there are multiple icons, get the last one
      await tester.tap(deleteCommentIconButtonFinder);
      await tester.pumpAndSettle();

      // Verify the delete comment dialog title
      expect(find.text('Delete Comment'), findsOneWidget);

      // Verify the delete comment dialog message
      expect(find.text("Deleting comment \"$commentTitle\"."), findsOneWidget);

      // Confirm the deletion of the comment
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      final Finder commentListDialogFinder =
          find.byType(PlaylistCommentListDialog);

      // Verify that the comment list dialog doesn't display the
      // deleted comments title
      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentTitle)),
          findsExactly(0));

      // Ensure the list has now 8 list items. Since the deleted comment
      // was the unique comment of the audio, the audio title is no longer
      // displayed in the playlist comment list dialog, the reason why 2 list
      // items were removed from playlist comments list.
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        8,
      );

      // Now close the comment list dialog
      await tester.tap(
          find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Click on an audio title in the playlist comment dialog in
                   order to open the audio in the audio player view.''',
        (WidgetTester tester) async {
      const String playlistTitle = '1 long music'; // Youtube playlist
      const String playedCommentAudioTitle =
          "Quand Dieu transforme l’épreuve en victoire";
      const String playedCommentAudioTitleDuration =
          "Quand Dieu transforme l’épreuve en victoire\n26:20";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'extract_comments_to_mp3_test',
        selectedPlaylistTitle: playlistTitle,
      );

      // First, open the playlist comment dialog
      await IntegrationTestUtil.openPlaylistCommentDialog(
        tester: tester,
        playlistTitle: playlistTitle,
      );

      // Tap on the first audio title to open it in the audio player view
      await tester.tap(find.text(playedCommentAudioTitle).last);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify audio title displayed in the audio player view
      expect(find.text(playedCommentAudioTitleDuration), findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Click on the SF checkbox of the playlist comment dialog in order
           to remove the impact of the applied playlist sort/filter parameters on
           the audios and their comments listed in the playlist comment dialog.''',
        (WidgetTester tester) async {
      const String playlistTitle = '1 long music'; // Youtube playlist

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'extract_comments_to_mp3_test',
        selectedPlaylistTitle: playlistTitle,
      );

      // Set the 'Dieu' sort/filter text in the playlist download view search text field

      // Type on the Playlists button to hide the playlist view
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.selectSortFilterParmsInDropDownButton(
        tester: tester,
        sortFilterParmsName: 'Dieu',
      );

      // Type on the Playlists button to show the playlist view
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // First, open the playlist comment dialog
      Finder playlistCommentListDialogFinder =
          await IntegrationTestUtil.openPlaylistCommentDialog(
        tester: tester,
        playlistTitle: playlistTitle,
      );

      const String notFilteredAudioTitle =
          "Glorious - Laisse-moi te parler de Jésus #louange";
      const String filteredAudioTitle =
          "Quand Dieu transforme l’épreuve en victoire";

      // Verify audio title displayed in the playlist comment dialog
      expect(
          find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.text(notFilteredAudioTitle),
          ),
          findsNothing);
      expect(
          find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.text(filteredAudioTitle),
          ),
          findsOneWidget);

      // Tap on the SF checkbox to remove the impact of the applied
      // playlist sort/filter parameters on the listed audios and their
      // comments in the playlist comment dialog
      await tester
          .tap(find.byKey(const Key('apply_SF_parms_to_comments_checkbox')));
      await tester.pumpAndSettle();

      // Verify audio titles displayed in the playlist comment dialog
      expect(
          find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.text(notFilteredAudioTitle),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.text(filteredAudioTitle),
          ),
          findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    group('Playing one comment, fully played audio', () {
      testWidgets('''One comment full play color verification. Play one comment
           completely. Then close the playlist comment dialog and reopen it.
           Verify that the played comment color was not changed, which means
           that of the audio position change due to the comment play was
           undone. Verify as well that the current audio change caused by the
           played comment audio was undone as well.''',
          (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "Interview de Chat GPT  - IA, intelligence, philosophie, géopolitique, post-vérité...";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the second
        // audio in order to play it completely
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 1,
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 1,
          audioPositionStr: '1:17:54',
          audioPositionSeconds: 4674,
          audioRemainingDurationStr: '0:00',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: DateTime(2024, 9, 8, 14, 38, 43),
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment pause on partial play color verification. Play one comment
           partially, clicking on pause button after 1.5 seconds. Then close the
           playlist comment dialog and reopen it. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "Interview de Chat GPT  - IA, intelligence, philosophie, géopolitique, post-vérité...";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the fourth
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 1,
          typeOnPauseAfterPlay: true,
          maxPlayDurationSeconds: 1.5,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 1,
          audioPositionStr: '1:17:54',
          audioPositionSeconds: 4674,
          audioRemainingDurationStr: '0:00',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: DateTime(2024, 9, 8, 14, 38, 43),
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment close on partial play color verification. Play one
           comment partially, clicking on close playlist comment dialog button
           after 1.5 seconds. Then reopen the dialog. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "La surpopulation mondiale par Jancovici et Barrau";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the second
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 3,
          typeOnPauseAfterPlay: false,
        );

        // Let the comment be played during 0.25 seconds and then click on the
        // playlist comment dialog close button
        await Future.delayed(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Tap on the 'Toggle List' button to hide the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 2,
          audioPositionStr: '0:00',
          audioPositionSeconds: 0,
          audioRemainingDurationStr: '6:06',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: null,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
    group('Playing one comment, partially played audio', () {
      testWidgets('''One comment partially play color verification. Play comment
           completely. Then close the playlist comment dialog and reopen it.
           Verify that the played comment color was not changed, which means
           that of the audio position change due to the comment play was
           undone. Verify as well that the current audio change caused by the
           played comment audio was undone as well.''',
          (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the third
        // audio in order to play it completely
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 2,
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 3,
          audioPositionStr: '4:09',
          audioPositionSeconds: 311,
          audioRemainingDurationStr: '1:02',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: true,
          audioPausedDateTime: DateTime(2024, 9, 9, 19, 47, 23),
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment pause on partial play color verification. Play one comment
           partially, clicking on pause button after 1.5 seconds. Then close the
           playlist comment dialog and reopen it. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the fourth
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 2,
          typeOnPauseAfterPlay: true,
          maxPlayDurationSeconds: 1.5,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 3,
          audioPositionStr: '4:09',
          audioPositionSeconds: 311,
          audioRemainingDurationStr: '1:02',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: true,
          audioPausedDateTime: DateTime(2024, 9, 9, 19, 47, 23),
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment close on partial play color verification. Play one
           comment partially, clicking on close playlist comment dialog button
           after 1.5 seconds. Then reopen the dialog. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the second
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 2,
          typeOnPauseAfterPlay: false,
        );

        // Let the comment be played during 0.25 seconds and then click on the
        // playlist comment dialog close button
        await Future.delayed(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Tap on the 'Toggle List' button to hide the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 3,
          audioPositionStr: '4:09',
          audioPositionSeconds: 311,
          audioRemainingDurationStr: '1:02',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: true,
          audioPausedDateTime: DateTime(2024, 9, 9, 19, 47, 23),
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
    group('Playing one comment, unplayed audio', () {
      testWidgets('''One comment full play color verification. Play one comment
           completely. Then close the playlist comment dialog and reopen it.
           Verify that the played comment color was not changed, which means
           that of the audio position change due to the comment play was
           undone. Verify as well that the current audio change caused by the
           played comment audio was undone as well.''',
          (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "La surpopulation mondiale par Jancovici et Barrau";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the second
        // audio in order to play it completely
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 3,
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Tap on the 'Toggle List' button to hide the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 2,
          audioPositionStr: '0:00',
          audioPositionSeconds: 0,
          audioRemainingDurationStr: '6:06',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: null,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment pause on partial play color verification. Play one comment
           partially, clicking on pause button after 1.5 seconds. Then close the
           playlist comment dialog and reopen it. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "La surpopulation mondiale par Jancovici et Barrau";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the fourth
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 3,
          typeOnPauseAfterPlay: true,
          maxPlayDurationSeconds: 1.5,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Tap on the 'Toggle List' button to hide the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 2,
          audioPositionStr: '0:00',
          audioPositionSeconds: 0,
          audioRemainingDurationStr: '6:06',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: null,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
      testWidgets(
          '''One comment close on partial play color verification. Play one
           comment partially, clicking on close playlist comment dialog button
           after 1.5 seconds. Then reopen the dialog. Verify that the played comment
           color was not changed, which means that of the audio position
           change due to the comment play was undone. Verify as well that the
           current audio change caused by the played comment audio was undone as
           well.''', (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
        const String playedCommentAudioTitle =
            "La surpopulation mondiale par Jancovici et Barrau";

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_color_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the unique comment of the second
        // audio in order to play it partially (during 1.5 seconds)
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 3,
          typeOnPauseAfterPlay: false,
        );

        // Let the comment be played during 0.25 seconds and then click on the
        // playlist comment dialog close button
        await Future.delayed(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Now, re-open the playlist comment dialog
        playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Verify the color of the audio titles in the playlist comment dialog

        await _verifyAudioTitlesColorInPlaylistCommentDialog(
          tester: tester,
          playlistCommentListDialogFinder: playlistCommentListDialogFinder,
        );

        // Tap on Close text button
        await tester.tap(
            find.byKey(const Key('playlistCommentListCloseDialogTextButton')));
        await tester.pumpAndSettle();

        // Tap on the 'Toggle List' button to hide the playlist list
        await tester.tap(find.byKey(const Key('playlist_toggle_button')));
        await tester.pumpAndSettle();

        // When closing the playlist comment dialog, the played comment audio
        // modification was undone. Verifying that ...
        await _verifyUndoneListenedAudioPosition(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
          playedCommentAudioTitle: playedCommentAudioTitle,
          playableAudioLstAudioIndex: 2,
          audioPositionStr: '0:00',
          audioPositionSeconds: 0,
          audioRemainingDurationStr: '6:06',
          isPlayingOrPausedWithPositionBetweenAudioStartAndEnd: false,
          audioPausedDateTime: null,
        );

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
    group('Playing several comments', () {
      testWidgets(
          '''Partially playing several comments and verifying the update of the play/pause comment
            button. The index of the first comment is 0, the index of the second comment is 3, and 
            index of the last (8th) comment is 21.''',
          (WidgetTester tester) async {
        const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist

        await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
          tester: tester,
          savedTestDataDirName: 'audio_comment_test',
          selectedPlaylistTitle: youtubePlaylistTitle,
        );

        // First, open the playlist comment dialog
        Finder playlistCommentListDialogFinder =
            await IntegrationTestUtil.openPlaylistCommentDialog(
          tester: tester,
          playlistTitle: youtubePlaylistTitle,
        );

        // Find the list of comments in the playlist comment dialog
        final Finder listFinder = find.descendant(
            of: playlistCommentListDialogFinder,
            matching: find.byType(ListBody));

        // Find all the list items GestureDetector's
        final Finder gestureDetectorsFinder = find.descendant(
            // 3 GestureDetector per comment item
            of: listFinder,
            matching: find.byType(GestureDetector));

        // Now tap on the play icon button of the first comment of the second
        // audio in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 3, // First comment of the second audio on IA
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        await tester.pumpAndSettle();

        // Checking the currently played comment icon button

        Finder playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(3);

        // Find the Icon widget inside the IconButton
        Finder iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        Icon iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.pause);

        // Let the comment be played during 0.25 seconds and then click
        // on the play button of the third comment
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, -100), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();
        // Now tap on the play icon button of the third comment of the second
        // audio in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 5, // Third comment of the second audio on IA
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Checking the previously played comment icon button

        await tester.pumpAndSettle();

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(9);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        // Checking the currently played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(5);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.pause);

        // Let the comment be played during 0.25 seconds and then click
        // on the play button of the fourth comment
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Now tap on the play icon button of the second comment of the second
        // audio in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 4, // Second comment of the second audio on IA
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Checking the previously played comment icon button

        await tester.pumpAndSettle();

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(5);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        // Checking the currently played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(4);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.pause);

        // Let the comment be played during 0.25 seconds and then click
        // on the play button of the fourth comment
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, 800), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        // Now tap on the play icon button of the unique comment of the fourth
        // audio in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 0, // first comment of the first audio
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Checking the previously played comment icon button

        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, -800), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(4);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, 800), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        // Checking the currently played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(0);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.pause);

        // Let the comment be played during 0.25 seconds and then click
        // on the play button of the first comment of the fourth audio
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, -1700), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        // Now tap on the play icon button of the first comment of the fourth
        // audio in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 8, // first comment of the fourth audio
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Checking the previously played comment icon button

        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, 1700), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(0);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        await tester.drag(
          find.byType(PlaylistCommentListDialog),
          const Offset(
              0, -1700), // Negative value for vertical drag to scroll down
        );

        await tester.pumpAndSettle();

        // Checking the currently played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(8);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.pause);

        // Let the first comment of the fourth audio be played during 0.25 seconds
        // and then click on the play button of the second comment of the fourth audio
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Now tap on the play icon button of the second comment of the fourth
        // audio (end to end comment) in order to start playing it
        await IntegrationTestUtil.playComment(
          tester: tester,
          gestureDetectorsFinder: gestureDetectorsFinder,
          itemIndex: 9, // second comment of the fourth audio
          typeOnPauseAfterPlay: false,
          maxPlayDurationSeconds: 3,
        );

        // Checking the previously played comment icon button

        await tester.pumpAndSettle();

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(8);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        await tester.pumpAndSettle();

        // Checking the currently played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(9);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Let the second comment of the fourth audio be played during
        // 2.1 seconds since it arrives to the audio end after 2 seconds.
        await Future.delayed(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        // Checking the last played comment icon button

        playIconButtonFinder = find
            .descendant(
              of: gestureDetectorsFinder,
              matching: find.byKey(const Key('playPauseIconButton')),
            )
            .at(9);

        // Find the Icon widget inside the IconButton
        iconFinder = find.descendant(
          of: playIconButtonFinder,
          matching: find.byType(Icon),
        );

        // Now get the Icon widget and check its type
        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.icon, Icons.play_arrow);

        // Purge the test playlist directory so that the created test
        // files are not uploaded to GitHub
        DirUtil.deleteFilesInDirAndSubDirs(
          rootPath: kApplicationPathWindowsTest,
        );
      });
    });
  });
  group('Audio CommentListAddDialog dialog test', () {
    testWidgets('''Delete comment.''', (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio';
      const String audioTitle =
          "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_color_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      // First, find the Youtube playlist audio ListTile Text widget
      Finder audioTitleTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioTitleTileWidgetFinder = find.ancestor(
        of: audioTitleTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audioTitle ListTile

      // Find the leading menu icon button of the audioTitle ListTile
      // and tap on it
      Finder audioTitleTileLeadingMenuIconButton = find.descendant(
        of: audioTitleTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioTitleTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the 'Audio Comments ...' popup menu item and
      // tap on it
      final Finder audioCommentsPopupMenuItem =
          find.byKey(const Key("popup_menu_audio_comment"));

      await tester.tap(audioCommentsPopupMenuItem);
      await tester.pumpAndSettle();

      // Verify that the audio comment dialog is displayed
      expect(find.byType(AutoRefreshCommentDialog), findsOneWidget);

      // Verify the dialog title
      expect(find.text('Comments'), findsOneWidget);

      // Verify that the audio comments list of the dialog has 1 comment
      // item

      Finder audioCommentsLstFinder = find.byKey(const Key(
        'audioCommentsListKey',
      ));

      // Ensure the list has one child widgets
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        1,
      );

      // Now delete the comment item

      // Find the delete icon button of the comment item and tap on it
      final Finder deleteCommentIconButtonFinder = find.descendant(
        of: audioCommentsLstFinder,
        matching: find.byKey(const Key('deleteCommentIconButton')),
      );
      await tester.tap(deleteCommentIconButtonFinder);
      await tester.pumpAndSettle();

      // Verify the delete comment dialog title
      expect(find.text('Delete Comment'), findsOneWidget);

      final String commentTitle = 'Comment Jancovici';

      // Verify the delete comment dialog message
      expect(find.text("Deleting comment \"$commentTitle\"."), findsOneWidget);

      // Confirm the deletion of the comment
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      final Finder commentListDialogFinder = find.byType(CommentListAddDialog);

      // Verify that the comment list dialog now displays no comment
      expect(
          find.descendant(
              of: commentListDialogFinder, matching: find.text(commentTitle)),
          findsNothing);

      // Now close the comment list dialog
      await tester.tap(find.byKey(const Key('closeDialogTextButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Partially playing several single audio comments and verifying the update of the play/pause
          comment button. The index of the first comment is 0, the index of the second comment is 3,
          and index of the last (5th) comment is 12.''',
        (WidgetTester tester) async {
      const String youtubePlaylistTitle = 'S8 audio';

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'audio_comment_test',
        selectedPlaylistTitle: youtubePlaylistTitle,
      );

      const String audioTitle =
          "Interview de Chat GPT  - IA, intelligence, philosophie, géopolitique, post-vérité..."; // Youtube playlist

      // First, find the Youtube playlist audio ListTile Text widget
      Finder audioTitleTileTextWidgetFinder = find.text(audioTitle);

      // Then obtain the audio ListTile widget enclosing the Text widget
      // by finding its ancestor
      Finder audioTitleTileWidgetFinder = find.ancestor(
        of: audioTitleTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now we want to tap the popup menu of the audioTitle ListTile

      // Find the leading menu icon button of the audioTitle ListTile
      // and tap on it
      Finder audioTitleTileLeadingMenuIconButton = find.descendant(
        of: audioTitleTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(audioTitleTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the 'Audio Comments ...' popup menu item and
      // tap on it
      final Finder audioCommentsPopupMenuItem =
          find.byKey(const Key("popup_menu_audio_comment"));

      await tester.tap(audioCommentsPopupMenuItem);
      await tester.pumpAndSettle();

      // Verify that the audio comment dialog is displayed
      expect(find.byType(AutoRefreshCommentDialog), findsOneWidget);

      // Verify that the audio comments list of the dialog has 4 comment
      // item

      Finder audioCommentsLstFinder = find.byKey(const Key(
        'audioCommentsListKey',
      ));

      // Ensure the list has five child widgets
      expect(
        tester.widget<ListBody>(audioCommentsLstFinder).children.length,
        5,
      );

      // Find all the list items GestureDetector's
      final Finder gestureDetectorsFinder = find.descendant(
          // 3 GestureDetector per comment item
          of: audioCommentsLstFinder,
          matching: find.byType(GestureDetector));

      // Now tap on the play icon button of the third audio comment
      // in order to start playing it
      await IntegrationTestUtil.playComment(
        tester: tester,
        gestureDetectorsFinder: gestureDetectorsFinder,
        itemIndex: 2, // Third comment of the audio on IA
        typeOnPauseAfterPlay: false,
        maxPlayDurationSeconds: 3,
      );

      await tester.pumpAndSettle();

      // Checking the currently played comment icon button

      Finder playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(6),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      Finder iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      Icon iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.pause);

      // Let the comment be played during 0.25 seconds and then click
      // on the play button of the fourth comment
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Now tap on the play icon button of the fourth audio comment
      // in order to start playing it
      await IntegrationTestUtil.playComment(
        tester: tester,
        gestureDetectorsFinder: gestureDetectorsFinder,
        itemIndex: 3, // Fourth comment of the audio on IA
        typeOnPauseAfterPlay: false,
        maxPlayDurationSeconds: 3,
      );

      // Checking the previously played comment icon button

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(6),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.play_arrow);

      // Checking the currently played comment icon button

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(9),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.pause);

      // Let the comment be played during 0.25 seconds and then click
      // on the play button of the first comment
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(0, 800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      // Now tap on the play icon button of the first audio comment
      // in order to start playing it
      await IntegrationTestUtil.playComment(
        tester: tester,
        gestureDetectorsFinder: gestureDetectorsFinder,
        itemIndex: 0, // First comment of the audio on IA
        typeOnPauseAfterPlay: false,
        maxPlayDurationSeconds: 3,
      );

      // Checking the previously played comment icon button

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(
            0, -800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(9),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.play_arrow);

      // Checking the currently played comment icon button

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(0, 800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(0),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.pause);

      // Let the comment be played during 0.25 seconds and then click
      // on the play button of the second comment
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Now tap on the play icon button of the second audio comment
      // in order to start playing it
      await IntegrationTestUtil.playComment(
        tester: tester,
        gestureDetectorsFinder: gestureDetectorsFinder,
        itemIndex: 1, // second comment of the IA audio
        typeOnPauseAfterPlay: false,
        maxPlayDurationSeconds: 3,
      );

      // Checking the previously played comment icon button

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(0),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.play_arrow);

      // Checking the currently played comment icon button

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(3),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.pause);

      // Let the comment be played during 0.25 seconds
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(
            0, -800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      // Now tap on the play icon button of the last audio comment
      // (end to end comment) in order to start playing it
      await IntegrationTestUtil.playComment(
        tester: tester,
        gestureDetectorsFinder: gestureDetectorsFinder,
        itemIndex: 4, // last comment of the IA audio
        typeOnPauseAfterPlay: false,
        maxPlayDurationSeconds: 3,
      );

      // Checking the previously played comment icon button

      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(0, 800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(3),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.play_arrow);

      // Let the last comment of the fourth audio be played during
      // 2.1 seconds since it arrives to the audio end after 2 seconds.
      await Future.delayed(const Duration(milliseconds: 2100));
      await tester.pumpAndSettle();

      // Checking the currently played comment icon button

      await tester.drag(
        find.byType(AutoRefreshCommentDialog),
        const Offset(
            0, -800), // Negative value for vertical drag to scroll down
      );

      await tester.pumpAndSettle();

      playIconButtonFinder = find.descendant(
        of: gestureDetectorsFinder.at(12),
        matching: find.byKey(const Key('playPauseIconButton')),
      );

      // Find the Icon widget inside the IconButton
      iconFinder = find.descendant(
        of: playIconButtonFinder,
        matching: find.byType(Icon),
      );

      // Now get the Icon widget and check its type
      iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, Icons.play_arrow);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group(
      '''Check presence or absence of audio download view audio menu items as well
           as presence or absence of audio player view left appbar menu items.''',
      () {
    testWidgets(
        '''Check presence in a Youtube playlist of the downloaded audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String movedAudioTitle = 'audio learn test short video one';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the  downloadedAudio
      // ListTile "audio learn test short video one" to verify the
      // presence or absence of the audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: movedAudioTitle,
        audioType: AudioType.downloaded,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Check absence in a Youtube playlist of the imported audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String importedAudioTitle =
          '231117-002828-morning _ cinematic video 23-07-01';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the imported Audio
      // ListTile "231117-002828-morning _ cinematic video 23-07-01"
      // to verify the presence or absence of the audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: importedAudioTitle,
        audioType: AudioType.imported,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Check absence in a Youtube playlist of the converted audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String convertedAudioTitle = 'tts';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the converted Audio
      // ListTile "tts" to verify the presence or absence of the
      // audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: convertedAudioTitle,
        audioType: AudioType.textToSpeech,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Check presence in a local playlist of the downloaded audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String movedAudioTitle = 'audio learn test short video one';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the 'new_local' playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'new_local',
      );

      // Now we want to tap the popup menu of the downloadedAudio
      // ListTile "audio learn test short video one" to verify the
      // presence or absence of the audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: movedAudioTitle,
        audioType: AudioType.downloaded,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Check absence in a local playlist of the imported audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String importedAudioTitle =
          '231117-002828-morning _ cinematic video 23-07-01';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the 'new_local' playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'new_local',
      );

      // Now we want to tap the popup menu of the imported Audio
      // ListTile "231117-002828-morning _ cinematic video 23-07-01"
      // to verify the presence or absence of the audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: importedAudioTitle,
        audioType: AudioType.imported,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Check absence in a local playlist of the converted audio menu items.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}copy_move_audio_integr_test_data",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String convertedAudioTitle = 'tts';

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // Load the settings from the json file. This is necessary
      // otherwise the ordered playlist titles will remain empty
      // and the playlist list will not be filled with the
      // playlists available in the download app test dir
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the 'new_local' playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: 'new_local',
      );

      // Now we want to tap the popup menu of the converted Audio
      // ListTile "tts" to verify the presence or absence of the
      // audio menu items

      await _checkPresenceOrAbsenceOfAudioMenuItems(
        tester: tester,
        audioTitle: convertedAudioTitle,
        audioType: AudioType.textToSpeech,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });

}

Future<void> _tapPlaylistCheckboxIfNotAlreadyChecked({
  required Finder playlistListTileWidgetFinder,
  required WidgetTester widgetTester,
}) async {
  final Finder youtubePlaylistListTileCheckboxWidgetFinder = find.descendant(
    of: playlistListTileWidgetFinder,
    matching: find.byType(Checkbox),
  );

  // Retrieve the Checkbox widget
  final Checkbox checkbox = widgetTester
      .widget<Checkbox>(youtubePlaylistListTileCheckboxWidgetFinder);

  // Check if the checkbox is checked
  if (checkbox.value == null || !checkbox.value!) {
    // Tap the ListTile Playlist checkbox to select it
    // so that the playlist audio are listed
    await widgetTester.tap(youtubePlaylistListTileCheckboxWidgetFinder);
    await widgetTester.pumpAndSettle();
  }
}

Future<void> _checkPresenceOrAbsenceOfAudioMenuItems({
  required WidgetTester tester,
  required String audioTitle,
  required AudioType audioType,
}) async {
  // First, find the Audio sublist ListTile Text widget
  final Finder sourceAudioListTileTextWidgetFinder = find.text(audioTitle);

  // Then obtain the Audio ListTile widget enclosing the Text widget by
  // finding its ancestor
  final Finder sourceAudioListTileWidgetFinder = find.ancestor(
    of: sourceAudioListTileTextWidgetFinder,
    matching: find.byType(ListTile),
  );

  // Now find the leading menu icon button of the Audio ListTile and tap
  // on it
  final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
    of: sourceAudioListTileWidgetFinder,
    matching: find.byIcon(Icons.menu),
  );

  // Tap the leading menu icon button to open the popup menu
  await tester.tap(sourceAudioListTileLeadingMenuIconButton);
  await tester.pumpAndSettle();

  // Now verify the menu items presence or absence depending on
  // the audio type
  _checkMenuItems(
    audioType: audioType,
  );

  // Close the audio ListTile popup menu by tapping outside
  await tester.tapAt(const Offset(300, 10));
  await tester.pumpAndSettle();

  // Now open the audio player view to check its left appbar
  // menu items
  await tester.tap(sourceAudioListTileTextWidgetFinder);
  await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
    tester: tester,
  );

  // Tap the appbar leading popup menu button
  await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
  await tester.pumpAndSettle();

  // Now verify the menu items presence or absence depending on
  // the audio type
  _checkMenuItems(
    audioType: audioType,
  );
}

void _checkMenuItems({
  required AudioType audioType,
}) {
  // Now verify if the 'Open Youtube Video' menu item is present
  // or absent depending on the audio type

  final Finder openYoutubeVideoMenuItem =
      find.byKey(const Key("popup_menu_open_youtube_video"));

  if (audioType == AudioType.downloaded) {
    expect(openYoutubeVideoMenuItem, findsOneWidget);
  } else {
    expect(openYoutubeVideoMenuItem, findsNothing);
  }

  // Now verify if the 'Copy Youtube Video URL' menu item is present
  // or absent depending on the audio type

  final Finder copyYoutubeVideoUrlMenuItem =
      find.byKey(const Key("popup_copy_youtube_video_url"));

  if (audioType == AudioType.downloaded) {
    expect(copyYoutubeVideoUrlMenuItem, findsOneWidget);
  } else {
    expect(copyYoutubeVideoUrlMenuItem, findsNothing);
  }

  // Now verify if the 'Redownload deleted Audio' menu item is present
  // or absent depending on the audio type

  final Finder redownloadDeletedAudioMenuItem =
      find.byKey(const Key("popup_menu_redownload_delete_audio"));

  if (audioType == AudioType.downloaded) {
    expect(redownloadDeletedAudioMenuItem, findsOneWidget);
  } else {
    expect(redownloadDeletedAudioMenuItem, findsNothing);
  }
}

Playlist _loadPlaylist(String playListOneName) {
  return JsonDataService.loadFromFile(
      jsonPathFileName:
          "$kApplicationPathWindowsTest${path.separator}$playListOneName${path.separator}$playListOneName.json",
      type: Playlist);
}

Playlist _loadPlaylistFromPlaylistsDir(String playListOneName) {
  return JsonDataService.loadFromFile(
      jsonPathFileName:
          "$kPlaylistDownloadRootPathWindowsTest${path.separator}$playListOneName${path.separator}$playListOneName.json",
      type: Playlist);
}

void _modifySelectedPlaylistBeforeStartingApplication({
  required String playlistToUnselectTitle,
  required String playlistToSelectTitle,
}) {
  final initiallySelectedPlaylistPath = path.join(
    kApplicationPathWindowsTest,
    playlistToUnselectTitle,
  );

  final initiallySelectedPlaylistFilePathName = path.join(
    initiallySelectedPlaylistPath,
    '$playlistToUnselectTitle.json',
  );

  // Load playlist from the json file
  Playlist initiallySelectedPlaylist = JsonDataService.loadFromFile(
    jsonPathFileName: initiallySelectedPlaylistFilePathName,
    type: Playlist,
  );

  initiallySelectedPlaylist.isSelected = false;

  JsonDataService.saveToFile(
    model: initiallySelectedPlaylist,
    path: initiallySelectedPlaylistFilePathName,
  );

  final nowSelectedPlaylistPath = path.join(
    kApplicationPathWindowsTest,
    playlistToSelectTitle,
  );

  final nowSelectedPlaylistFilePathName = path.join(
    nowSelectedPlaylistPath,
    '$playlistToSelectTitle.json',
  );

  // Load playlist from the json file
  Playlist nowSelectedPlaylist = JsonDataService.loadFromFile(
    jsonPathFileName: nowSelectedPlaylistFilePathName,
    type: Playlist,
  );

  nowSelectedPlaylist.isSelected = true;

  JsonDataService.saveToFile(
    model: nowSelectedPlaylist,
    path: nowSelectedPlaylistFilePathName,
  );
}

Future<void> _verifyYoutubeSelectedPlaylistButtonsAndCheckbox({
  required WidgetTester tester,
  required bool isPlaylistListDisplayed,
}) async {
  IntegrationTestUtil.validateSearchIconButton(
    tester: tester,
    searchIconButtonState: SearchIconButtonState.disabled,
  );

  if (isPlaylistListDisplayed) {
    IntegrationTestUtil.verifyWidgetIsEnabled(
      tester: tester,
      widgetKeyStr: 'move_up_playlist_button',
    );

    IntegrationTestUtil.verifyWidgetIsEnabled(
      tester: tester,
      widgetKeyStr: 'move_down_playlist_button',
    );
  } else {
    // Verify that the dropdown button is set to the playlist download
    // view 'Title asc' sort/filter parms
    IntegrationTestUtil.checkDropdopwnButtonSelectedTitle(
      tester: tester,
      dropdownButtonSelectedTitle: 'Title asc',
    );
  }

  IntegrationTestUtil.verifyWidgetIsEnabled(
    tester: tester,
    widgetKeyStr: 'download_sel_playlist_button',
  );

  IntegrationTestUtil.verifyWidgetIsEnabled(
    tester: tester,
    widgetKeyStr: 'audio_quality_checkbox',
  );

  IntegrationTestUtil.verifyWidgetIsEnabled(
    tester: tester,
    widgetKeyStr: 'audio_popup_menu_button',
  );
}

Future<void> _verifyLocalSelectedPlaylistButtonsAndCheckbox({
  required WidgetTester tester,
  required bool isPlaylistListDisplayed,
}) async {
  IntegrationTestUtil.validateSearchIconButton(
    tester: tester,
    searchIconButtonState: SearchIconButtonState.disabled,
  );

  if (isPlaylistListDisplayed) {
    IntegrationTestUtil.verifyWidgetIsEnabled(
      tester: tester,
      widgetKeyStr: 'move_up_playlist_button',
    );

    IntegrationTestUtil.verifyWidgetIsEnabled(
      tester: tester,
      widgetKeyStr: 'move_down_playlist_button',
    );
  } else {
    // Verify that the dropdown button is set to the playlist download
    // view 'Title asc' sort/filter parms
    IntegrationTestUtil.checkDropdopwnButtonSelectedTitle(
      tester: tester,
      dropdownButtonSelectedTitle: 'Title asc',
    );
  }

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'download_sel_playlist_button',
  );

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'audio_quality_checkbox',
  );

  IntegrationTestUtil.verifyWidgetIsEnabled(
    tester: tester,
    widgetKeyStr: 'audio_popup_menu_button',
  );
}

Future<void> _verifyUndoneListenedAudioPosition({
  required WidgetTester tester,
  required String playlistTitle,
  required String playedCommentAudioTitle,
  required int playableAudioLstAudioIndex,
  required String audioPositionStr,
  required int audioPositionSeconds,
  required String audioRemainingDurationStr,
  required bool isPlayingOrPausedWithPositionBetweenAudioStartAndEnd,
  required DateTime? audioPausedDateTime,
}) async {
  // Now we want to tap on the previously played commented audio of
  // the playlist in order to open the AudioPlayerView displaying
  // the currently not playing audio

  // First, get the Audio ListTile Text widget finder and tap on it
  final Finder playedCommentAudioListTileTextWidgetFinder =
      find.text(playedCommentAudioTitle);

  await tester.tap(playedCommentAudioListTileTextWidgetFinder);
  await tester.pumpAndSettle(const Duration(milliseconds: 1000));

  // Now verify if the displayed audio position and remaining
  // duration are correct

  Text audioPositionText = tester
      .widget<Text>(find.byKey(const Key('audioPlayerViewAudioPosition')));
  expect(audioPositionText.data, audioPositionStr);

  Text audioRemainingDurationText = tester.widget<Text>(
      find.byKey(const Key('audioPlayerViewAudioRemainingDuration')));
  expect(audioRemainingDurationText.data, audioRemainingDurationStr);

  IntegrationTestUtil.verifyAudioDataElementsUpdatedInPlaylistJsonFile(
    audioPlayerSelectedPlaylistTitle: playlistTitle,
    playableAudioLstAudioIndex: playableAudioLstAudioIndex,
    audioTitle: playedCommentAudioTitle,
    audioPositionSeconds: audioPositionSeconds,
    isPaused: true,
    isPlayingOrPausedWithPositionBetweenAudioStartAndEnd:
        isPlayingOrPausedWithPositionBetweenAudioStartAndEnd,
    audioPausedDateTime: audioPausedDateTime, // "2024-09-08T14:38:43.283816"
  );
}

Future<void> _verifyAudioTitlesColorInPlaylistCommentDialog({
  required WidgetTester tester,
  required Finder playlistCommentListDialogFinder,
}) async {
  await IntegrationTestUtil.checkAudioTextColor(
    tester: tester,
    enclosingWidgetFinder: playlistCommentListDialogFinder,
    audioTitleOrSubTitle:
        "Quand Aurélien Barrau va dans une école de management",
    expectedTitleTextColor:
        IntegrationTestUtil.currentlyPlayingAudioTitleTextColor,
    expectedTitleTextBackgroundColor:
        IntegrationTestUtil.currentlyPlayingAudioTitleTextBackgroundColor,
  );

  await IntegrationTestUtil.checkAudioTextColor(
    tester: tester,
    enclosingWidgetFinder: playlistCommentListDialogFinder,
    audioTitleOrSubTitle:
        "Interview de Chat GPT  - IA, intelligence, philosophie, géopolitique, post-vérité...",
    expectedTitleTextColor: IntegrationTestUtil.fullyPlayedAudioTitleColor,
    expectedTitleTextBackgroundColor: null,
  );

  await IntegrationTestUtil.checkAudioTextColor(
    tester: tester,
    enclosingWidgetFinder: playlistCommentListDialogFinder,
    audioTitleOrSubTitle:
        "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique",
    expectedTitleTextColor:
        IntegrationTestUtil.partiallyPlayedAudioTitleTextdColor,
    expectedTitleTextBackgroundColor: null,
  );

  await IntegrationTestUtil.checkAudioTextColor(
    tester: tester,
    enclosingWidgetFinder: playlistCommentListDialogFinder,
    audioTitleOrSubTitle: "La surpopulation mondiale par Jancovici et Barrau",
    expectedTitleTextColor: IntegrationTestUtil.unplayedAudioTitleTextColor,
    expectedTitleTextBackgroundColor: null,
  );
}

Future<void> _ensureNoButtonIsEnabledSinceNoPlaylistIsSelected(
    WidgetTester tester) async {
  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'move_up_playlist_button',
  );

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'move_down_playlist_button',
  );

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'download_sel_playlist_button',
  );

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'audio_quality_checkbox',
  );

  IntegrationTestUtil.verifyWidgetIsDisabled(
    tester: tester,
    widgetKeyStr: 'audio_popup_menu_button',
  );
}

Future<void> _checkAudioCommentUsingAudioItemMenu({
  required WidgetTester tester,
  required Finder audioListTileWidgetFinder,
  required String expectedCommentTitle,
  int expectedCommentTitleNumber = 1,
  String? notAccessibleCommentTitle,
  String? audioTitleToVerifyInCommentAddEditDialog,
  bool isAutoRefreshCommentDialogExpected = false,
}) async {
  // Find the leading menu icon button of the audio ListTile
  // and tap on it
  final Finder audioListTileLeadingMenuIconButton = find.descendant(
    of: audioListTileWidgetFinder,
    matching: find.byIcon(Icons.menu),
  );

  // Tap the leading menu icon button to open the popup menu
  await tester.tap(audioListTileLeadingMenuIconButton);
  await tester.pumpAndSettle();

  // Now find the audio comments popup menu item and tap on it
  final Finder popupCommentMenuItem =
      find.byKey(const Key("popup_menu_audio_comment"));

  await tester.tap(popupCommentMenuItem);
  await tester.pumpAndSettle();

  // Verify that the comment list is displayed

  if (isAutoRefreshCommentDialogExpected) {
    expect(find.byType(AutoRefreshCommentDialog), findsOneWidget);
  } else {
    expect(find.byType(CommentListAddDialog), findsOneWidget);
  }

  // Verify that the expectedCommentTitle is listed

  Finder commentListDialogFinder;

  if (isAutoRefreshCommentDialogExpected) {
    commentListDialogFinder = find.byType(AutoRefreshCommentDialog);
  } else {
    commentListDialogFinder = find.byType(CommentListAddDialog);
  }

  expect(
      find.descendant(
          of: commentListDialogFinder,
          matching: find.text(expectedCommentTitle)),
      findsNWidgets(expectedCommentTitleNumber));

  // If the notAccessibleCommentTitle is not null, verify that it is
  // not listed
  if (notAccessibleCommentTitle != null) {
    expect(
        find.descendant(
            of: commentListDialogFinder,
            matching: find.text(notAccessibleCommentTitle)),
        findsNothing);
  }

  if (audioTitleToVerifyInCommentAddEditDialog != null) {
    // Tap on the comment title to open the comment add/edit dialog
    await tester.tap(find.text(expectedCommentTitle));
    await tester.pumpAndSettle();

    final Finder commentAddEditDialogFinder = find.byType(CommentAddEditDialog);

    // Verify audio title displayed in the comment add/edit dialog
    expect(
      find.descendant(
          of: commentAddEditDialogFinder,
          matching: find.text(audioTitleToVerifyInCommentAddEditDialog)),
      findsOneWidget,
    );

    // Tap on the cancel button to close the comment add/edit dialog
    await tester.tap(find.byKey(const Key('cancelTextButton')));
    await tester.pumpAndSettle();
  }

  // Close the comment list dialog
  await tester.tap(find.byKey(const Key('closeDialogTextButton')).last);
  await tester.pumpAndSettle();
}

Future<void> _checkAudioCommentInAudioPlayerView({
  required WidgetTester tester,
  required Finder audioListTileWidgetFinder,
  required String expectedCommentTitle,
}) async {
  // Tap on the ListTile to open the audio player view on the
  // passed audio finder
  await tester.tap(audioListTileWidgetFinder);
  await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
    tester: tester,
  );

  // Tap on the comment icon button to open the comment add list
  // dialog
  final Finder commentInkWellButtonFinder = find.byKey(
    const Key('commentsInkWellButton'),
  );

  await tester.tap(commentInkWellButtonFinder);
  await tester.pumpAndSettle();

  // Verify that the expectedCommentTitle is listed

  Finder commentListDialogFinder =
      find.byKey(const Key('audioCommentsListKey'));

  expect(
      find.descendant(
          of: commentListDialogFinder,
          matching: find.text(expectedCommentTitle)),
      findsOneWidget);

  // Close the comment list dialog
  await tester.tap(find.byKey(const Key('closeDialogTextButton')));
  await tester.pumpAndSettle();

  // Tap on the playlist download view button to return to the
  // playlist download view
  final playlistDownloadViewNavButton =
      find.byKey(const ValueKey('playlistDownloadViewIconButton'));
  await tester.tap(playlistDownloadViewNavButton);
  await tester.pumpAndSettle();
}

