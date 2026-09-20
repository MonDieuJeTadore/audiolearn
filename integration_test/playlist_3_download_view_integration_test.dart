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
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import 'package:audiolearn/viewmodels/audio_player_vm.dart';
import 'package:audiolearn/constants.dart';
import 'package:audiolearn/models/playlist.dart';
import 'package:audiolearn/services/json_data_service.dart';
import 'package:audiolearn/viewmodels/audio_download_vm.dart';
import 'package:audiolearn/viewmodels/playlist_list_vm.dart';
import 'package:audiolearn/viewmodels/warning_message_vm.dart';
import 'package:audiolearn/views/widgets/warning_message_display_dialog.dart';
import 'package:audiolearn/views/widgets/playlist_list_item.dart';
import 'package:audiolearn/services/settings_data_service.dart';
import 'package:audiolearn/utils/dir_util.dart';
import 'package:audiolearn/main.dart' as app;

import '../test/viewmodels/custom_mock_youtube_explode.dart';
import '../test/viewmodels/mock_audio_download_vm.dart';
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

  const String youtubePlaylistId = 'PLzwWSJNcZTMTSAE8iabVB6BCAfFGHHfah';
  const String youtubePlaylistUrl =
      'https://youtube.com/playlist?list=$youtubePlaylistId';
  // url used in integration_test/audio_download_vm_integration_test.dart
  // which works:
  // 'https://youtube.com/playlist?list=PLzwWSJNcZTMRB9ILve6fEIS_OHGrV5R2o';
  const String youtubeNewPlaylistTitle =
      'audio_learn_new_youtube_playlist_test';

  const String testPlaylistDir =
      '$kApplicationPathWindowsTest\\audio_learn_new_youtube_playlist_test';
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

}
