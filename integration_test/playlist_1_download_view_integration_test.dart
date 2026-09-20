import 'dart:io';

import 'package:audiolearn/viewmodels/comment_vm.dart';
import 'package:audiolearn/viewmodels/date_format_vm.dart';
import 'package:audiolearn/viewmodels/picture_vm.dart';
import 'package:flutter/material.dart';
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

import '../test/viewmodels/mock_audio_download_vm.dart';
import 'integration_test_util.dart';

void main() {
  // Necessary to avoid FatalFailureException (FatalFailureException: Failed
  // to perform an HTTP request to YouTube due to a fatal failure. In most
  // cases, this error indicates that YouTube most likely changed something,
  // which broke the library.
  // If this issue persists, please report it on the project's GitHub page.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  group('Add or delete Youtube or local Playlist tests', () {
    testWidgets('Youtube playlist audio quality addition and then delete it ',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, youtubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await _checkWarningDialog(
        tester: tester,
        playlistTitle: youtubeNewPlaylistTitle,
        isMusicQuality: false,
        playlistType: PlaylistType.youtube,
        isWarningConfirming: true,
        positionStr: '1',
      );

      // Now tap on the delete button to empty the search text
      // field. The reason is due to using debounce in the
      // YoutubeUrlOrSearchTextField widget. If the text field is not
      // emptied, it avoids that the Youtube playlist addition warning
      // dialog is shown twice when the 'Add playlist button' button is
      // tapped.
      await tester.tap(
        find.byKey(
          const Key('clearPlaylistUrlOrSearchButtonKey'),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the URL TextField was emptied. If is emptied, the
      // displayed warning will displayed twice.
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, '');

      // The list of Playlist's should have one item now
      expect(find.byType(ListTile), findsOneWidget);

      // Check if the added item is displayed correctly
      final PlaylistListItem playlistListItemWidget =
          tester.widget(find.byType(PlaylistListItem).first);
      expect(playlistListItemWidget.playlist.title, youtubeNewPlaylistTitle);

      // Find the ListTile representing the added playlist

      final Finder firstListTileFinder = find.byType(ListTile).first;

      // Retrieve the ListTile widget
      final ListTile firstPlaylistListTile =
          tester.widget<ListTile>(firstListTileFinder);

      // Ensure that the title is a Text widget and check its data
      expect(firstPlaylistListTile.title, isA<Text>());
      expect(
          (firstPlaylistListTile.title as Text).data, youtubeNewPlaylistTitle);

      // Alternatively, find the ListTile by its title
      expect(
          find.descendant(
              of: firstListTileFinder,
              matching: find.text(
                youtubeNewPlaylistTitle,
              )),
          findsOneWidget);

      // Check the saved local playlist values in the json file

      final String newPlaylistPath = path.join(
        kPlaylistDownloadRootPathWindowsTest,
        youtubeNewPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$youtubeNewPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, youtubeNewPlaylistTitle);
      expect(loadedNewPlaylist.id, youtubePlaylistId);
      expect(loadedNewPlaylist.url, youtubePlaylistUrl);
      expect(loadedNewPlaylist.playlistType, PlaylistType.youtube);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(loadedNewPlaylist.audioPlaySpeed, 1.25);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      final settingsPathFileName = path.join(
        kApplicationPathWindowsTest,
        'settings.json',
      );

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: settingsPathFileName);

      // Check that adding a playlist sets the arePlaylistsDisplayed
      // InPlaylistDownloadView to true
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType:
                Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
          ),
          true);

      // Check that the ordered playlist titles list in the settings
      // data service contains the added playlist title
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [youtubeNewPlaylistTitle]);

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Find the leading menu icon button of the Playlist ListTile
      // and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: firstListTileFinder,
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
          'Delete Youtube Playlist "$youtubeNewPlaylistTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check that the ordered playlist titles list in the settings
      // data service is now empty
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          []);

      // Check that the deleted playlist directory no longer exist
      expect(Directory(newPlaylistPath).existsSync(), false);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add with comma titled Youtube playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      const String invalidYoutubePlaylistTitle = 'Johnny Hallyday, songs';

      mockAudioDownloadVM.youtubePlaylistTitle = invalidYoutubePlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, youtubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'The Youtube playlist title "$invalidYoutubePlaylistTitle" can not contain any comma. Please correct the title and retry ...',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Youtube playlist music quality addition and then add it again with same
           URL to verify the displayed warning message.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Set the quality to music
      await tester
          .tap(find.byKey(const Key('playlistQualityConfirmDialogCheckBox')));
      await tester.pumpAndSettle();

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, youtubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await _checkWarningDialog(
        tester: tester,
        playlistTitle: youtubeNewPlaylistTitle,
        isMusicQuality: true,
        playlistType: PlaylistType.youtube,
        isWarningConfirming: true,
        positionStr: '1',
      );

      // Now tap on the delete button to empty the search text
      // field. The reason is due to using debounce in the
      // YoutubeUrlOrSearchTextField widget. If the text field is not
      // emptied, it avoids that the Youtube playlist addition warning
      // dialog is shown twice when the 'Add playlist button' button is
      // tapped.
      await tester.tap(
        find.byKey(
          const Key('clearPlaylistUrlOrSearchButtonKey'),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the URL TextField was emptied. If is emptied, the
      // displayed warning will displayed twice.
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, '');

      // Check the saved Youtube playlist values in the json file

      final String newPlaylistPath = path.join(
        kPlaylistDownloadRootPathWindowsTest,
        youtubeNewPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$youtubeNewPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, youtubeNewPlaylistTitle);
      expect(loadedNewPlaylist.id, youtubePlaylistId);
      expect(loadedNewPlaylist.url, youtubePlaylistUrl);
      expect(loadedNewPlaylist.playlistType, PlaylistType.youtube);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.music);
      expect(loadedNewPlaylist.audioPlaySpeed, 1.0);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      // Check that the ordered playlist titles list in the settings
      // data service contains the added playlist title
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [youtubeNewPlaylistTitle]);

      // Now test adding the same playlist again

      // Enter the new Youtube playlist URL into the url text field.
      // I don't know why, but the next commented code does not work.

      // await tester.enterText(
      //   find.byKey(const Key('youtubeUrlOrSearchTextField'),),
      //   youtubePlaylistUrl,
      // );

      // Solving this problem
      tester
          .widget<TextField>(find.byKey(
            const Key('youtubeUrlOrSearchTextField'),
          ))
          .controller!
          .text = youtubePlaylistUrl;

      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, youtubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playlist "$youtubeNewPlaylistTitle" with this URL "$youtubePlaylistUrl" is already in the playlist list and so won\'t be recreated.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });

    /// The objective of this integration test is to ensure that
    /// the url text field will not be emptied after clicking on
    /// the Cancel button of the add playlist dialog.
    testWidgets(
        '''Open the add playlist dialog to add a Youtube playlist and then
           click on Cancel button''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, youtubePlaylistUrl);

      // Cancel the addition by tapping the Cancel button in the
      // AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogCancelButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is not shown
      expect(find.text('WARNING'), findsNothing);

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // The list of Playlist's should have 0 item
      expect(find.byType(ListTile), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Local playlist music quality addition with empty playlist URL''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Tap the 'Toggle List' button to hide the playlist list. Since
      // when adding a playlist, the list is expanded, we need to hide it
      // in order to ensure the list will be displayed.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Local Playlist');

      // Check that the AlertDialog url Text is not displayed since
      // a local playlist is added with the playlist URL text field
      // empty
      expect(
        find.byKey(const Key('playlistUrlConfirmDialogText')),
        findsNothing,
      );

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Check the value of the AlertDialog local playlist title
      // TextField
      TextField localPlaylistTitleTextField = tester.widget(
          find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')));
      expect(
        localPlaylistTitleTextField.controller!.text,
        localPlaylistTitle,
      );

      // Set the quality to music
      await tester
          .tap(find.byKey(const Key('playlistQualityConfirmDialogCheckBox')));
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is shown
      await _checkWarningDialog(
        tester: tester,
        playlistTitle: localPlaylistTitle,
        isMusicQuality: true,
        playlistType: PlaylistType.local,
        isWarningConfirming: true,
        positionStr: '1',
      );

      // The list of Playlist's should have one item now
      expect(find.byType(ListTile), findsOneWidget);

      // Check if the added item is displayed correctly
      final PlaylistListItem playlistListItemWidget =
          tester.widget(find.byType(PlaylistListItem).first);
      expect(playlistListItemWidget.playlist.title, localPlaylistTitle);

      // Find the ListTile representing the added playlist

      final Finder firstListTileFinder = find.byType(ListTile).first;

      // Retrieve the ListTile widget
      final ListTile firstPlaylistListTile =
          tester.widget<ListTile>(firstListTileFinder);

      // Ensure that the title is a Text widget and check its data
      expect(firstPlaylistListTile.title, isA<Text>());
      expect((firstPlaylistListTile.title as Text).data, localPlaylistTitle);

      // Alternatively, find the ListTile by its title
      expect(
          find.descendant(
              of: firstListTileFinder,
              matching: find.text(
                localPlaylistTitle,
              )),
          findsOneWidget);

      // Check the saved local playlist values in the json file

      final String newPlaylistPath = path.join(
        kPlaylistDownloadRootPathWindowsTest,
        localPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$localPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, localPlaylistTitle);
      expect(loadedNewPlaylist.id, localPlaylistTitle);
      expect(loadedNewPlaylist.url, '');
      expect(loadedNewPlaylist.playlistType, PlaylistType.local);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.music);
      expect(loadedNewPlaylist.audioPlaySpeed, 1.0);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      final settingsPathFileName = path.join(
        kApplicationPathWindowsTest,
        'settings.json',
      );

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: settingsPathFileName);

      // Check that the ordered playlist titles list in the settings
      // data service contains the added playlist title
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [localPlaylistTitle]);

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: firstListTileFinder,
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
          'Delete Local Playlist "$localPlaylistTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check that the ordered playlist titles list in the settings
      // data service is now empty

      // Reload the settings data service from the settings json file
      await settingsDataService.loadSettingsFromFile(
        settingsJsonPathFileName: settingsPathFileName,
      );

      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          ['']); // if loading from the settings json file,
      //            the ordered playlist titles list is never
      //            empty. I don't know why, but it is the same
      //            if loading settings from file in add and delete
      //            Youtube playlist !

      // Check that the deleted playlist directory no longer exist
      expect(Directory(newPlaylistPath).existsSync(), false);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Local playlist audio quality addition with empty playlist URL and then
           delete local playlist''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kDownloadAppTestSavedDataDir${path.separator}settings.json");

      // setting default playlist audio play speed to 1.25 instead of 1.0
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      // saving the settings so that the app creation can access to them
      // as defined above
      settingsDataService.saveSettings();

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Local Playlist');

      // Check that the AlertDialog url Text is not displayed since
      // a local playlist is added with the playlist URL text field
      // empty
      expect(
        find.byKey(const Key('playlistUrlConfirmDialogText')),
        findsNothing,
      );

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Check the value of the AlertDialog local playlist title
      // TextField
      TextField localPlaylistTitleTextField = tester.widget(
          find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')));
      expect(
        localPlaylistTitleTextField.controller!.text,
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is shown
      await _checkWarningDialog(
        tester: tester,
        playlistTitle: localPlaylistTitle,
        isMusicQuality: false,
        playlistType: PlaylistType.local,
        isWarningConfirming: true,
        positionStr: '1',
      );

      // The list of Playlist's should have one item now
      expect(find.byType(ListTile), findsOneWidget);

      // Check if the added item is displayed correctly
      final PlaylistListItem playlistListItemWidget =
          tester.widget(find.byType(PlaylistListItem).first);
      expect(playlistListItemWidget.playlist.title, localPlaylistTitle);

      // Find the ListTile representing the added playlist

      final Finder firstListTileFinder = find.byType(ListTile).first;

      // Retrieve the ListTile widget
      final ListTile firstPlaylistListTile =
          tester.widget<ListTile>(firstListTileFinder);

      // Ensure that the title is a Text widget and check its data
      expect(firstPlaylistListTile.title, isA<Text>());
      expect((firstPlaylistListTile.title as Text).data, localPlaylistTitle);

      // Alternatively, find the ListTile by its title
      expect(
          find.descendant(
              of: firstListTileFinder,
              matching: find.text(
                localPlaylistTitle,
              )),
          findsOneWidget);

      // Check the saved local playlist values in the json file

      final String newPlaylistPath = path.join(
        kPlaylistDownloadRootPathWindowsTest,
        localPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$localPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, localPlaylistTitle);
      expect(loadedNewPlaylist.id, localPlaylistTitle);
      expect(loadedNewPlaylist.url, '');
      expect(loadedNewPlaylist.playlistType, PlaylistType.local);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(loadedNewPlaylist.audioPlaySpeed, 1.25);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      settingsDataService = SettingsDataService(
        isTest: true,
      );

      final settingsPathFileName = path.join(
        kApplicationPathWindowsTest,
        'settings.json',
      );

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: settingsPathFileName);

      // Chek that adding a playlist sets the arePlaylistsDisplayed
      // InPlaylistDownloadView to true
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType:
                Playlists.arePlaylistsDisplayedInPlaylistDownloadView,
          ),
          true);

      // Check that the ordered playlist titles list in the settings
      // data service contains the added playlist title
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [localPlaylistTitle]);

      // Now test deleting the playlist

      // Open the delete playlist dialog by clicking on the 'Delete
      // playlist ...' playlist menu item

      // Now find the leading menu icon button of the Playlist ListTile
      // and tap on it
      final Finder firstPlaylistListTileLeadingMenuIconButton = find.descendant(
        of: firstListTileFinder,
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
          'Delete Local Playlist "$localPlaylistTitle"');

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check that the ordered playlist titles list in the settings
      // data service is now empty

      // Reload the settings data service from the settings json file
      await settingsDataService.loadSettingsFromFile(
        settingsJsonPathFileName: settingsPathFileName,
      );

      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          ['']); // if loading from the settings json file,
      //            the ordered playlist titles list is never
      //            empty. I don't know why, but it is the same
      //            if loading settings from file in add and delete
      //            Youtube playlist !

      // Check that the deleted playlist directory no longer exist
      expect(Directory(newPlaylistPath).existsSync(), false);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Add local playlist with title equal to previously created local
           playlist''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // The list of Playlist's should have one item now
      expect(find.byType(ListTile), findsOneWidget);

      // Check if the added item is displayed correctly
      final PlaylistListItem playlistListItemWidget =
          tester.widget(find.byType(PlaylistListItem).first);
      expect(playlistListItemWidget.playlist.title, localPlaylistTitle);

      // Add a new local playlist with the same title of the first
      // added Youtube playlist

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the same title of the previously created local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Local playlist \"$localPlaylistTitle\" already exists in the playlist list. Therefore, the local playlist with this title won't be created.",
        isWarningConfirming: false,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add local playlist with invalid title containing a comma',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String invalidLocalPlaylistTitle = 'local, with comma';

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        invalidLocalPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "The local playlist title \"$invalidLocalPlaylistTitle\" can not contain any comma. Please correct the title and retry ...",
        isWarningConfirming: false,
      );

      // Correct the invalid title removing the comma
      String correctedLocalPlaylistTitle =
          invalidLocalPlaylistTitle.replaceAll(',', '');
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        correctedLocalPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Ensure the confirm warning dialog is shown
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Local playlist \"$correctedLocalPlaylistTitle\" of spoken quality added at the end of the playlist list at position 1.",
        isWarningConfirming: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add local playlist with title ended by space',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitleWithSpace = 'local with space ';
      const String localPlaylistTitleWithoutSpace = 'local with space';

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitleWithSpace,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Ensure the confirm warning dialog is shown
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Local playlist \"$localPlaylistTitleWithoutSpace\" of spoken quality added at the end of the playlist list at position 1.",
        isWarningConfirming: true,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Add local playlist with title equal to previously created Youtube
           playlist''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')).last);
      await tester.pumpAndSettle();

      // Now tap on the delete button to empty the search text
      // field. The reason is due to using debounce in the
      // YoutubeUrlOrSearchTextField widget. If the text field is not
      // emptied, it avoids that the Youtube playlist addition warning
      // dialog is shown twice when the 'Add playlist button' button is
      // tapped.
      await tester.tap(
        find.byKey(
          const Key('clearPlaylistUrlOrSearchButtonKey'),
        ),
      );
      await tester.pumpAndSettle();

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      const String localPlaylistTitle = 'audio_learn_new_youtube_playlist_test';

      // Enter the same title of the previously created local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Youtube playlist \"$localPlaylistTitle\" already exists in the playlist list. Therefore, the local playlist with this title won't be created.",
        isWarningConfirming: false,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Open the add playlist dialog to add a local playlist and then
           click on Cancel button''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Local Playlist');

      // Check that the AlertDialog url Text is not displayed since
      // a local playlist is added with the playlist URL text field
      // empty
      expect(
        find.byKey(const Key('playlistUrlConfirmDialogText')),
        findsNothing,
      );

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Check the value of the AlertDialog local playlist title
      // TextField
      TextField localPlaylistTitleTextField = tester.widget(
          find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')));
      expect(
        localPlaylistTitleTextField.controller!.text,
        localPlaylistTitle,
      );

      // Set the quality to music
      await tester
          .tap(find.byKey(const Key('playlistQualityConfirmDialogCheckBox')));
      await tester.pumpAndSettle();

      // Cancel the addition by tapping the Cancel button in the
      // AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogCancelButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is not shown
      expect(find.text('WARNING'), findsNothing);

      // The list of Playlist's should have 0 item
      expect(find.byType(ListTile), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Add Youtube and local playlist, download the Youtube playlist
           and restart the app''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      // Adding the Youtube playlist

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        settingsDataService: settingsDataService,
        warningMessageVM: warningMessageVM,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button.
      // If the warning dialog is not closed, tapping on the
      // 'Add playlist button' button will fail
      await tester.tap(find.byKey(const Key('warningDialogOkButton')).last);
      await tester.pumpAndSettle();

      // Now tap on the delete button to empty the search text
      // field. The reason is due to using debounce in the
      // YoutubeUrlOrSearchTextField widget. If the text field is not
      // emptied, it avoids that the Youtube playlist addition warning
      // dialog is shown twice when the 'Add playlist button' button is
      // tapped.
      await tester.tap(
        find.byKey(
          const Key('clearPlaylistUrlOrSearchButtonKey'),
        ),
      );
      await tester.pumpAndSettle();

      // Adding the local playlist

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Tap the first ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // Tap the 'Download All' button to download the selected playlist.
      // This download fails because YoutubeExplode can not access to
      // internet in integration tests in order to download the
      // audios.
      await tester.tap(find.byKey(const Key('download_sel_playlist_button')));
      await tester.pumpAndSettle();

      // Downloading the Youtube playlist audio can not be done in
      // integration tests because YoutubeExplode can not access to
      // internet. Instead, the audio file and the playlist json file
      // including the audio are copied from the test save directory
      // to the download directory

      String newYoutubePlaylistTitle = 'audio_learn_new_youtube_playlist_test';
      DirUtil.copyFileToDirectorySync(
          sourceFilePathName:
              "$kDownloadAppTestSavedDataDir${path.separator}$newYoutubePlaylistTitle${path.separator}$newYoutubePlaylistTitle.json",
          targetDirectoryPath: testPlaylistDir,
          overwriteFileIfExist: true);
      DirUtil.copyFileToDirectorySync(
        sourceFilePathName:
            "$kDownloadAppTestSavedDataDir${path.separator}$newYoutubePlaylistTitle${path.separator}230701-224750-audio learn test short video two 23-06-10.mp3",
        targetDirectoryPath: testPlaylistDir,
      );

      // now close the app and then restart it in order to load the
      // copied youtube playlist

      await IntegrationTestUtil
          .launchIntegrTestAppEnablingInternetAccessWithMock(
        tester: tester,
        audioDownloadVM: audioDownloadVM,
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        warningMessageVM: warningMessageVM,
        audioPlayerVM: audioPlayerVM,
        dateFormatVM: dateFormatVM,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add Youtube playlist with invalid URL containing list=',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        settingsDataService: settingsDataService,
        warningMessageVM: warningMessageVM,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      const String invalidYoutubePlaylistUrl = 'list=invalid';
      // Enter the invalid Youtube playlist URL into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        invalidYoutubePlaylistUrl,
      );

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidYoutubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, invalidYoutubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playlist with invalid URL "$invalidYoutubePlaylistUrl" neither added nor modified.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidYoutubePlaylistUrl);

      // The list of Playlist's should have zero item now
      expect(find.byType(ListTile), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add Youtube playlist with invalid URL',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      const String invalidYoutubePlaylistUrl = 'invalid';

      // Enter the invalid Youtube playlist URL into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        invalidYoutubePlaylistUrl,
      );

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidYoutubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, invalidYoutubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Playlist with invalid URL "$invalidYoutubePlaylistUrl" neither added nor modified.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidYoutubePlaylistUrl);

      // The list of Playlist's should have zero item now
      expect(find.byType(ListTile), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Add private Youtube playlist', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = '';

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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
      );

      const String privateYoutubePlaylistUrl =
          'https://www.youtube.com/playlist?list=PLzwWSJNcZTMRw_Gl0qL60O7TQgYq8DuCu';

      // Enter the private Youtube playlist URL into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        privateYoutubePlaylistUrl,
      );

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, privateYoutubePlaylistUrl);

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Ensure the dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Check the value of the AlertDialog dialog title
      Text alertDialogTitle =
          tester.widget(find.byKey(const Key('playlistConfirmDialogTitleKey')));
      expect(alertDialogTitle.data, 'Add Youtube Playlist');

      // Check the value of the AlertDialog url Text
      Text confirmUrlText =
          tester.widget(find.byKey(const Key('playlistUrlConfirmDialogText')));
      expect(confirmUrlText.data, privateYoutubePlaylistUrl);

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Trying to add a private Youtube playlist is not possible since the audios of a private playlist can not be downloaded. To solve the problem, edit the playlist on Youtube and change its visibility from \"Private\" to \"Unlisted\" or to \"Public\" and then re-add it to the application.",
        isWarningConfirming: false,
      );

      // Ensure the URL TextField was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, privateYoutubePlaylistUrl);

      // The list of Playlist's should have zero item now
      expect(find.byType(ListTile), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Add and download 2 Youtube playlists using audio download VM
                   mock version.''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}simulate_creating_and_downloading_youtube_playlist_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      // Adding the Youtube playlist

      final SettingsDataService settingsDataService = SettingsDataService(
        isTest: true,
      );

      // load settings from file which does not exist. This
      // will ensure that the default playlist root path is set
      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName: "temp\\wrong.json");

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
        mockPlaylistDirectory: kApplicationPathWindowsTest,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
        commentVM: CommentVM(isTest: true),
        pictureVM: PictureVM(
          settingsDataService: settingsDataService,
        ),
        settingsDataService: settingsDataService,
      );

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
        audioDownloadVM: mockAudioDownloadVM,
        settingsDataService: settingsDataService,
        playlistListVM: playlistListVM,
        warningMessageVM: warningMessageVM,
        audioPlayerVM: audioPlayerVM,
        dateFormatVM: dateFormatVM,
      );

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the 'Essai' Youtube playlist URL into the url text field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        'https://youtube.com/playlist?list=PLzwWSJNcZTMSMSrQ7LA0uSn91uZz47JOh&si=-c9fkDSormJfnB4k',
      );
      await tester.pumpAndSettle();

      // Setting fist Youtube playlist title
      mockAudioDownloadVM.youtubePlaylistTitle = 'Essai';

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the Add button in the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Youtube playlist "Essai" of spoken quality added at the end of the playlist list at position 1.',
        isWarningConfirming: true,
      );

      // Tap the first ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // Tap the 'Download Playlist' button to download the selected playlist.
      // This download is simulated by the mock audio download VM
      await tester.tap(find.byKey(const Key('download_sel_playlist_button')));
      await tester.pumpAndSettle();

      // And verify the downloaded playlist audio titles

      List<String> essaiDownloadedAudioTitles = [
        "La Chine a créé l'ARME ULTIME  - Plus PUISSANTE que l'étoilenoire",
        "Les IA ont-elles vraiment atteint l'AGI  Analyse_ Johann Oriel",
      ];

      IntegrationTestUtil.checkAudioOrPlaylistTitlesOrderInListTile(
        tester: tester,
        audioOrPlaylistTitlesOrderedLst: essaiDownloadedAudioTitles,
        firstAudioListTileIndex: 1,
      );

      // Enter the 'audio_player_view_2_shorts_test' Youtube playlist URL
      // into the url text field
      // Enter the new Youtube playlist URL into the url text field.
      // I don't know why, but the next commented code does not work.
      //
      // await tester.enterText(
      //   find.byKey(
      //     const Key('youtubeUrlOrSearchTextField'),
      //   ),
      //   'https://youtube.com/playlist?list=PLzwWSJNcZTMRrOkIdVTkV58wpWIZQCkgd&si=fBu5t1hVFDHThbwy',
      // );
      // await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      //
      // Solving this problem
      tester
              .widget<TextField>(find.byKey(
                const Key('youtubeUrlOrSearchTextField'),
              ))
              .controller!
              .text =
          'https://youtube.com/playlist?list=PLzwWSJNcZTMRrOkIdVTkV58wpWIZQCkgd&si=fBu5t1hVFDHThbwy';
      await tester.pumpAndSettle();

      // Setting second Youtube playlist title
      mockAudioDownloadVM.youtubePlaylistTitle =
          'audio_player_view_2_shorts_test';

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'Youtube playlist "audio_player_view_2_shorts_test" of spoken quality added at the end of the playlist list at position 2.',
        isWarningConfirming: true,
      );

      // Tap the second ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).at(1),
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // Tap the 'Download All' button to download the selected playlist.
      // This download is simulated by the mock audio download VM
      await tester.tap(find.byKey(const Key('download_sel_playlist_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('download_sel_playlist_button')));
      await tester.pumpAndSettle();

      // And verify the downloaded playlist audio titles

      List<String> audioPlayerView2ShortsTestDownloadedaudiotitles = [
        "morning _ cinematic video",
        "Really short video",
      ];

      IntegrationTestUtil.checkAudioOrPlaylistTitlesOrderInListTile(
        tester: tester,
        audioOrPlaylistTitlesOrderedLst:
            audioPlayerView2ShortsTestDownloadedaudiotitles,
        firstAudioListTileIndex: 2,
      );

      // Tap the first ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // And verify the downloaded playlist audio titles

      IntegrationTestUtil.checkAudioOrPlaylistTitlesOrderInListTile(
        tester: tester,
        audioOrPlaylistTitlesOrderedLst: essaiDownloadedAudioTitles,
        firstAudioListTileIndex: 2,
      );

      // Tap the second ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).at(1),
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // And verify the downloaded playlist audio titles

      IntegrationTestUtil.checkAudioOrPlaylistTitlesOrderInListTile(
        tester: tester,
        audioOrPlaylistTitlesOrderedLst:
            audioPlayerView2ShortsTestDownloadedaudiotitles,
        firstAudioListTileIndex: 2,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Delete pictured playlist', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}save_or_delete_playlist_with_pictures",
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

      // Check the ordered playlist titles list in the settings
      // data service before playlist deletion
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'Restore- short - test - playlist',
            'A restaurer',
            'local',
          ]);

      PictureVM pictureVM = PictureVM(
        settingsDataService: settingsDataService,
      );

      // Verify the pictureAudioMap json content before playlist
      // deletion
      IntegrationTestUtil.verifyPictureAudioMapBeforePlaylistDeletion(
        pictureVM: pictureVM,
      );

      // Now test deleting the playlist

      const String playlistToDeleteTitle = 'Restore- short - test - playlist';

      // Tap on the playlist item menu to delete this playlist
      await IntegrationTestUtil.typeOnPlaylistMenuItem(
        tester: tester,
        playlistTitle: playlistToDeleteTitle,
        playlistMenuKeyStr: 'popup_menu_delete_playlist',
        dragToBottom: true,
      );

      // Now verifying the confirm dialog message

      final Text deletePlaylistDialogTitleWidget = tester
          .widget<Text>(find.byKey(const Key('confirmDialogTitleOneKey')));

      expect(deletePlaylistDialogTitleWidget.data,
          'Delete Youtube Playlist "$playlistToDeleteTitle"');

      final Text deletePlaylistDialogMesageWidget = tester
          .widget<Text>(find.byKey(const Key('confirmationDialogMessageKey')));

      expect(deletePlaylistDialogMesageWidget.data,
          "Deleting the playlist and its 3 audios, 2 audio comment(s), 4 audio picture(s) as well as its JSON file and its directory.");

      // Now find the confirm button of the delete playlist confirm
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the ordered playlist titles list in the settings
      // data service after playlist deletion

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");
      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'A restaurer',
            'local',
          ]);

      // Check that the deleted playlist directory no longer exist
      expect(
        Directory(
                '$kPlaylistDownloadRootPathWindowsTest${path.separator}$playlistToDeleteTitle')
            .existsSync(),
        false,
      );

      // Verify the pictureAudioMap json content after playlist
      // deletion
      IntegrationTestUtil.verifyPictureAudioMapAfterPlaylistDeletion(
        pictureVM: pictureVM,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Various Tests', () {
    testWidgets(
        '''Entered a Youtube playlist URL. Then switch to AudioPlayerView
           and then back to PlaylistView''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      await app.main();
      await tester.pumpAndSettle();

      // The playlist list and audio list should exist now but be
      // empty (no ListTile widgets)
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);

      // Enter the new Youtube playlist URL into the url text field.
      // The objective is to test that the url text field will not
      // be emptied after adding a local playlist
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        youtubePlaylistUrl,
      );

      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, youtubePlaylistUrl);

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen

      final appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Now we tap on the PlaylistDownloadView icon button to go
      // back to the PlaylistDownloadView screen

      final playlistDownloadNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadNavButton);
      await tester.pumpAndSettle();

      // Now tap on the delete button to empty the search text
      // field. The reason is due to using debounce in the
      // YoutubeUrlOrSearchTextField widget. If the text field is not
      // emptied, it avoids that the Youtube playlist addition warning
      // dialog is shown twice when the 'Add playlist button' button is
      // tapped.
      await tester.tap(
        find.byKey(
          const Key('clearPlaylistUrlOrSearchButtonKey'),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the URL TextField was emptied. If is emptied, the
      // displayed warning will displayed twice.
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, '');

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });

    /// The objective of this integration test is to ensure that
    /// the url text field will not be emptied after adding a
    /// local playlist, in contrary of what happens after adding
    /// a Youtube playlist.
    testWidgets('Select then unselect local playlist',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      const String localPlaylistTitle = 'audio_learn_local_playlist_test';

      await app.main();
      await tester.pumpAndSettle();

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // The list of Playlist's should have one item now
      expect(find.byType(ListTile), findsOneWidget);

      // Verify that the first ListTile checkbox is not
      // selected
      Checkbox firstListItemCheckbox = tester.widget<Checkbox>(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      expect(firstListItemCheckbox.value, isFalse);

      // Verify that the selected playlist Text is empty
      Text selectedPlaylistTitleText =
          tester.widget(find.byKey(const Key('selectedPlaylistTitleText')));
      expect(selectedPlaylistTitleText.data, '');

      // Check the saved local playlist values in the json file,
      // before the playlist will be selected

      final String newPlaylistPath = path.join(
        kPlaylistDownloadRootPathWindowsTest,
        localPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$localPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, localPlaylistTitle);
      expect(loadedNewPlaylist.id, localPlaylistTitle);
      expect(loadedNewPlaylist.url, '');
      expect(loadedNewPlaylist.playlistType, PlaylistType.local);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      // Tap the first ListTile checkbox to select it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // Verify that the selected playlist TextField contains the
      // title of the selected playlist
      selectedPlaylistTitleText =
          tester.widget(find.byKey(const Key('selectedPlaylistTitleText')));
      expect(
        selectedPlaylistTitleText.data,
        localPlaylistTitle,
      );

      // Check the saved local playlist values in the json file

      // Load playlist from the json file
      Playlist reloadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(reloadedNewPlaylist.title, localPlaylistTitle);
      expect(reloadedNewPlaylist.id, localPlaylistTitle);
      expect(reloadedNewPlaylist.url, '');
      expect(reloadedNewPlaylist.playlistType, PlaylistType.local);
      expect(reloadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(reloadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(reloadedNewPlaylist.playableAudioLst.length, 0);
      expect(reloadedNewPlaylist.isSelected, true);
      expect(reloadedNewPlaylist.downloadPath, newPlaylistPath);

      // Now tap the first ListTile checkbox to unselect it
      await tester.tap(find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byWidgetPredicate((widget) => widget is Checkbox),
      ));
      await tester.pumpAndSettle();

      // Verify that the selected playlist TextField is empty
      selectedPlaylistTitleText =
          tester.widget(find.byKey(const Key('selectedPlaylistTitleText')));
      expect(selectedPlaylistTitleText.data, '');

      // Check the saved local playlist values in the json file

      // Load playlist from the json file
      Playlist rereloadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(rereloadedNewPlaylist.title, localPlaylistTitle);
      expect(rereloadedNewPlaylist.id, localPlaylistTitle);
      expect(rereloadedNewPlaylist.url, '');
      expect(rereloadedNewPlaylist.playlistType, PlaylistType.local);
      expect(rereloadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(rereloadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(rereloadedNewPlaylist.playableAudioLst.length, 0);
      expect(rereloadedNewPlaylist.isSelected, false);
      expect(rereloadedNewPlaylist.downloadPath, newPlaylistPath);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        'Download single video audio in spoken quality with invalid URL',
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

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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

      const String invalidSingleVideoUrl = 'http://invalid';

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Enter the invalid single video URL into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        invalidSingleVideoUrl,
      );
      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidSingleVideoUrl);

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

      // Find the RadioListTile target playlist in which the audio
      // will be downloaded

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
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
          'Confirm target playlist "$localAudioPlaylistTitle" for downloading single video audio in spoken quality.');

      // Now find the ok button of the confirm dialog and tap on it
      await tester.tap(find.byKey(const Key('okButtonKey')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'The URL "$invalidSingleVideoUrl" supposed to point to a unique video is invalid. Therefore, no video has been downloaded.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField containing the invalid single
      // video URL was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidSingleVideoUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Download single video audio in music quality with invalid URL',
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

      // setting default playlist audio play speed to 1.25
      settingsDataService.set(
          settingType: SettingType.playlists,
          settingSubType: Playlists.playSpeed,
          value: 1.25);

      // Since we have to use a mock AudioDownloadVM to add the
      // youtube playlist, we can not use app.main() to start the
      // app because app.main() uses the real AudioDownloadVM
      // and we don't want to make the main.dart file dependent
      // of a mock class. So we have to start the app by hand.

      WarningMessageVM warningMessageVM = WarningMessageVM();
      MockAudioDownloadVM mockAudioDownloadVM = MockAudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );
      mockAudioDownloadVM.youtubePlaylistTitle = youtubeNewPlaylistTitle;

      AudioDownloadVM audioDownloadVM = AudioDownloadVM(
        warningMessageVM: warningMessageVM,
        settingsDataService: settingsDataService,
      );

      // using the mockAudioDownloadVM to add the playlist
      // because YoutubeExplode can not access to internet
      // in integration tests in order to download the playlist
      // and so obtain the playlist title
      PlaylistListVM playlistListVM = PlaylistListVM(
        warningMessageVM: warningMessageVM,
        audioDownloadVM: mockAudioDownloadVM,
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

      const String invalidSingleVideoUrl = 'http://invalid';

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Enter the invalid single video URL into the url text
      // field
      await tester.enterText(
        find.byKey(
          const Key('youtubeUrlOrSearchTextField'),
        ),
        invalidSingleVideoUrl,
      );
      await tester.pumpAndSettle();

      // Ensure the url text field contains the entered url
      TextField urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidSingleVideoUrl);

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

      // Find the RadioListTile target playlist in which the audio
      // will be downloaded

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Set the audio quality to music
      await tester.tap(find.byKey(
          const Key('downloadSingleVideoAudioAtMusicQualityCheckboxKey')));
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
          'Confirm target playlist "$localAudioPlaylistTitle" for downloading single video audio in high-quality music format.');

      // Now find the ok button of the confirm dialog and tap on it
      await tester.tap(find.byKey(const Key('okButtonKey')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            'The URL "$invalidSingleVideoUrl" supposed to point to a unique video is invalid. Therefore, no video has been downloaded.',
        isWarningConfirming: false,
      );

      // Ensure the URL TextField containing the invalid single
      // video URL was not emptied
      urlTextField = tester.widget(find.byKey(
        const Key('youtubeUrlOrSearchTextField'),
      ));
      expect(urlTextField.controller!.text, invalidSingleVideoUrl);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Settings update test', () {
    testWidgets('After moving down a playlist item',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}settings_update_test_initial_audio_data",
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

      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          ['local_music', 'audio_learn_new_youtube_playlist_test']);

      const String localMusicPlaylistTitle = 'local_music';
      const String localAudioPlaylistTitle = 'local_audio';

      await app.main();
      await tester.pumpAndSettle();

      // Tap the 'Toggle List' button to display the playlist list. If the list
      // is not opened, checking that a ListTile with the title of
      // the playlist was added to the list will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // The playlist list displays two items, but the audio
      // list is empty
      expect(find.byType(ListView), findsNWidgets(2));
      expect(find.byType(ListTile), findsNWidgets(2));

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist to add
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        localAudioPlaylistTitle,
      );

      // Check the value of the AlertDialog local playlist title
      // TextField
      TextField localPlaylistTitleTextField = tester.widget(
          find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')));
      expect(
        localPlaylistTitleTextField.controller!.text,
        localAudioPlaylistTitle,
      );

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Ensure the warning dialog is shown
      expect(find.byType(WarningMessageDisplayDialog), findsOneWidget);

      // Check the value of the warning dialog message
      Text warningDialogMessage =
          tester.widget(find.byKey(const Key('warningDialogMessage')));
      expect(warningDialogMessage.data,
          'Local playlist "$localAudioPlaylistTitle" of spoken quality added at the end of the playlist list at position 3.');

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // The list of Playlist's should have three items now
      expect(find.byType(ListTile), findsNWidgets(3));

      // Check if the added item is displayed correctly
      final PlaylistListItem playlistListItemWidget =
          tester.widget(find.byType(PlaylistListItem).first);
      expect(playlistListItemWidget.playlist.title, localMusicPlaylistTitle);

      // Check the saved local playlist values in the json file

      final String newPlaylistPath = path.join(
        kApplicationPathWindowsTest,
        localAudioPlaylistTitle,
      );

      final newPlaylistFilePathName = path.join(
        newPlaylistPath,
        '$localAudioPlaylistTitle.json',
      );

      // Load playlist from the json file
      Playlist loadedNewPlaylist = JsonDataService.loadFromFile(
        jsonPathFileName: newPlaylistFilePathName,
        type: Playlist,
      );

      expect(loadedNewPlaylist.title, localAudioPlaylistTitle);
      expect(loadedNewPlaylist.id, localAudioPlaylistTitle);
      expect(loadedNewPlaylist.url, '');
      expect(loadedNewPlaylist.playlistType, PlaylistType.local);
      expect(loadedNewPlaylist.playlistQuality, PlaylistQuality.voice);
      expect(loadedNewPlaylist.downloadedAudioLst.length, 0);
      expect(loadedNewPlaylist.playableAudioLst.length, 0);
      expect(loadedNewPlaylist.isSelected, false);
      expect(loadedNewPlaylist.downloadPath, newPlaylistPath);

      // reload the settings from the json file to verify it was
      // updated correctly

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'local_music',
            'audio_learn_new_youtube_playlist_test',
            'local_audio',
          ]);

      // now move down the added playlist to the second position
      // in the list

      // Find and select the ListTile to move'
      const String playlistToMoveDownTitle = 'local_audio';

      await _findThenSelectAndTestListTileCheckbox(
        tester: tester,
        itemTextStr: playlistToMoveDownTitle,
      );

      Finder downButtonFinder =
          find.widgetWithIcon(IconButton, Icons.arrow_drop_down);
      IconButton downButton = tester.widget<IconButton>(downButtonFinder);
      expect(downButton.onPressed, isNotNull);

      // Tap the move down button twice
      await tester.tap(downButtonFinder);
      await tester.pump();
      await tester.tap(downButtonFinder);
      await tester.pump();

      // reload the settings from the json file to verify it was
      // updated correctly

      await settingsDataService.loadSettingsFromFile(
          settingsJsonPathFileName:
              "$kApplicationPathWindowsTest${path.separator}$kSettingsFileName");

      expect(
          settingsDataService.get(
            settingType: SettingType.playlists,
            settingSubType: Playlists.orderedTitleLst,
          ),
          [
            'local_music',
            'local_audio',
            'audio_learn_new_youtube_playlist_test',
          ]);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Copy audio test', () {
    testWidgets(
        '''Copy (+ check comment) audio twice. Second copy is refused with
           warning since the audio exist now in the target playlist. The
           same duplicate copy is then performed again, but this time the
           user tap on the cancel button instead of the confirm button. Then
           3rd time copy to another empty target playlist and click on cancel
           button''', (WidgetTester tester) async {
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitleTwo = 'local_audio_playlist_2';
      const String localAudioTargetPlaylistTitleThree = 'local_3';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm dialog message
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source audio still access to its
      // comments

      // First, tap on the source audio ListTile to open the
      // audio player view
      await tester.tap(sourceAudioListTileWidgetFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify that the comment icon button is highlighted. This indiquates
      // that a comment exist for the audio
      IntegrationTestUtil.validateInkWellButton(
        tester: tester,
        inkWellButtonKey: 'commentsInkWellButton',
        expectedIcon: Icons.bookmark_outline_outlined,
        expectedIconColor: Colors.white,
        expectedIconBackgroundColor: kDarkAndLightEnabledIconColor,
      );

      // Now verify that the copied audio can be played

      // Verify the current audio position
      Text audioPositionText = tester
          .widget<Text>(find.byKey(const Key('audioPlayerViewAudioPosition')));
      expect(audioPositionText.data, '0:03');

      Finder audioTitlePositionTextFinder =
          find.text("$copiedAudioTitle\n0:16");
      expect(audioTitlePositionTextFinder, findsOneWidget);

      // Now play then pause the copied audio
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      // Tap on pause button to pause the audio
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // Verify the audio position

      Finder audioPlayerViewAudioPositionFinder =
          find.byKey(const Key('audioPlayerViewAudioPosition'));

      IntegrationTestUtil.verifyPositionBetweenMinMax(
        tester: tester,
        textWidgetFinder: audioPlayerViewAudioPositionFinder,
        minPositionTimeStr: '0:04',
        maxPositionTimeStr: '0:06',
      );

      // Return to the Playlist Download View
      final playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now verifying that the source playlist directory still
      // contains the audio file copied to the target playlist

      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // Verifying that the source playlist directory still
      // contains the audio comment file copied to the target playlist

      List<String> sourcePlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(sourcePlaylistCommentLst, [
        "230628-033811-audio learn test short video one 23-06-10.json",
        "230628-033813-audio learn test short video two 23-06-10.json",
      ]);

      // Verifying that the source playlist directory still
      // contains the audio picture file copied to the target playlist

      List<String> sourcePlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(sourcePlaylistPictureLst, [
        "230628-033811-audio learn test short video one 23-06-10.json",
      ]);

      // And verify that the target playlist directory now
      // contains the audio file copied from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleTwo',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Verify that the target playlist directory now contains
      // the audio comment file copied from the source playlist
      List<String> targetPlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleTwo${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistCommentLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Verify that the target playlist directory now contains
      // the audio picture file copied from the source playlist
      List<String> targetPlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleTwo${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistPictureLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Find the target ListTile Playlist containing the audio copied
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitleTwo,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the display audio info audio copied dialog
      // elements

      // Verify the enclosing playlist title of the copied audio

      final Text enclosingPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('enclosingPlaylistTitleKey')));

      expect(enclosingPlaylistTitleTextWidget.data,
          localAudioTargetPlaylistTitleTwo);

      // Verify the copied from playlist title of the copied audio

      final Text copiedFromPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('copiedFromPlaylistTitleKey')));

      expect(copiedFromPlaylistTitleTextWidget.data,
          youtubeAudioSourcePlaylistTitle);

      // Verify the copied to playlist title of the copied audio

      final Text copiedToPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('copiedToPlaylistTitleKey')));

      expect(copiedToPlaylistTitleTextWidget.data, '');

      // Now find the close button of the audio info dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Now verifying that the target audio can access to its copied
      // comments

      // First, tap on the source audio ListTile to open the
      // audio player view
      await tester.tap(targetAudioListTileWidgetFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify that the comment icon button is highlighted. This indiquates
      // that a comment exist for the audio
      IntegrationTestUtil.validateInkWellButton(
        tester: tester,
        inkWellButtonKey: 'commentsInkWellButton',
        expectedIcon: Icons.bookmark_outline_outlined,
        expectedIconColor: Colors.white,
        expectedIconBackgroundColor: kDarkAndLightEnabledIconColor,
      );

      // Return to the Playlist Download View
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Then, we try to copy a second time the audio already copied
      // to the target playlist in order to verify that a warning is
      // displayed informing that the audio was not copied because it
      // is already present in the target playlist

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\" car il est déjà présent dans cette playlist.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Now, we retry to copy a second time the audio already copied
      // to the target playlist, but instead of clicking on the confirm
      // button, we will click on the cancel button in order to verify
      // that no warning is displayed. This ensure that a previously
      // present bug was solved.

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the cancel button and tap on it
      await tester.tap(find.byKey(const Key('cancelButton')));
      await tester.pumpAndSettle();

      // Check that no warning is displayed
      expect(find.text('AVERTISSEMENT'), findsNothing);

      // Finally redo copying the audio to the other local (local_3)
      // playlist which contains no audio, but finally click on Cancel
      // button.

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleThree),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the cancel button and tap on it
      await tester.tap(find.byKey(const Key('cancelButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source playlist directory still
      // contains the audio file copied to the target playlist
      sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // Verifying that the source playlist directory still
      // contains the audio comment file copied to the target playlist

      sourcePlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(sourcePlaylistCommentLst, [
        "230628-033811-audio learn test short video one 23-06-10.json",
        "230628-033813-audio learn test short video two 23-06-10.json",
      ]);

      // Verifying that the source playlist directory still
      // contains the audio picture file copied to the target playlist

      sourcePlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(sourcePlaylistPictureLst, [
        "230628-033811-audio learn test short video one 23-06-10.json",
      ]);

      // And verify that the target playlist directory does not
      // contains the audio file copied from the source playlist
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, []);

      // Verify that the target playlist directory does not contains
      // the audio comment file copied from the source playlist
      targetPlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistCommentLst, []);

      // Verify that the target playlist directory now contains
      // the audio picture file copied from the source playlist
      targetPlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistPictureLst, []);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy audio and then move it to same target playlist: the move is
           refused with warning since the copied audio now exists in the
           target playlist. Then 3rd time move to another playlist and click
           on cancel button''', (WidgetTester tester) async {
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitleTwo = 'local_audio_playlist_2';
      const String localAudioTargetPlaylistTitleThree = 'local_3';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the value of the Confirm dialog title
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source playlist directory still
      // contains the audio file copied to the target playlist
      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // And verify that the target playlist directory now
      // contains the audio file copied from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleTwo',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Find the target ListTile Playlist containing the audio copied
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitleTwo,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the display audio info audio copied dialog
      // elements

      // Verify the enclosing playlist title of the copied audio

      final Text enclosingPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('enclosingPlaylistTitleKey')));

      expect(enclosingPlaylistTitleTextWidget.data,
          localAudioTargetPlaylistTitleTwo);

      // Verify the copied from playlist title of the copied audio

      final Text copiedFromPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('copiedFromPlaylistTitleKey')));

      expect(copiedFromPlaylistTitleTextWidget.data,
          youtubeAudioSourcePlaylistTitle);

      // Verify the copied to playlist title of the copied audio

      final Text copiedToPlaylistTitleTextWidget = tester
          .widget<Text>(find.byKey(const Key('copiedToPlaylistTitleKey')));

      expect(copiedToPlaylistTitleTextWidget.data, '');

      // Now find the close button of the audio info dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
      await tester.pumpAndSettle();

      // Then, we try to move the audio already copied to the same
      // target playlist in order to verify that a warning is
      // displayed informing that the audio was not moved because it
      // is already present in the target playlist

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\" car il est déjà présent dans cette playlist.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Finally redo moving the audio to the other local (local_3)
      // playlist, but finally click on Cancel button.

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleThree),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the cancel button and tap on it
      await tester.tap(find.byKey(const Key('cancelButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source playlist directory still
      // contains the audio file moved but canceled to the target
      // playlist
      sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // And verify that the target playlist directory does not
      // contains the audio file copied from the source playlist
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, []);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Copy audio not present in the source playlist.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitleTwo = 'local_audio_playlist_2';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Delete the mp3 file of the copied audio in the source playlist
      // so that a warning indicating that the audio is not present in the
      // source playlist is displayed when trying to copy it to the target
      // playlist
      DirUtil.deleteFileIfExist(
        pathFileName:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}230628-033811-audio learn test short video one 23-06-10.mp3',
      );

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleTwo),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the value of the Warning dialog title
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\" car son fichier MP3 n'est pas présent dans la playlist source.",
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Copy audio without selecting the target playlist.''',
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

      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the value of the Warning dialog title
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Aucune playlist sélectionnée pour la copie de l'audio. Sélectionnez une playlist et rééssayez ...",
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy/delete commented audio to target playlist. Copy commented
           audio to target playlist and then delete it from target playlist.
           A warning is displayed informing that the audio has comment(s)
           and that those comments will be deleted. Confirm deletion and
           then move the audio to the same target playlist.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitle = 'local_audio_playlist_2';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source playlist directory still
      // contains the audio file copied to the target playlist
      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // Now verifying that the source playlist directory still
      // contains the comment data of audio file copied to the target
      // playlist
      List<String> sourcePlaylistCommentFileLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(sourcePlaylistCommentFileLst, [
        "230628-033811-audio learn test short video one 23-06-10.json",
        "230628-033813-audio learn test short video two 23-06-10.json",
      ]);

      // And verify that the target playlist directory now
      // contains the audio file copied from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Verify as well that the target playlist directory now contains
      // the comment file of the audio copied from the source playlist
      List<String> targetPlaylistJsonLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistJsonLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Now, we want to delete the audio copied to the target playlist.
      // Since this audio has comments, its deletion will cause a confirm
      // action dialog to be displayed.

      // Find the target ListTile Playlist containing the audio copied
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu delete audio item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_delete_audio"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Since the copied audio contains comment(s), deleting it
      // causes a confirm action dialog to be displayed.
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            "Confirmez la suppression de l'audio commenté \"audio learn test short video one\"",
        confirmActionDialogMessagePossibleLst: [
          "L'audio contient 1 commentaire(s) qui seront également supprimés. Confirmer la suppression ?",
        ],
        closeDialogWithConfirmButton: true,
      );

      // Now verify that the target playlist directory no longer
      // contains the audio file copied from the source playlist
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, []);

      // And verify that the target playlist comment directory no longer
      // contains the audio comment file of the audio copied from the
      // source playlist
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistMp3Lst, []);

      // Then, we move the audio already copied and deleted to the
      // same target playlist to ensure that even it has comment(s),
      // it is moved with no warning since the comments won't be
      // distroyd.

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still contains
      // the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy/delete commented audio to target playlist. Copy commented
           audio to target playlist and then delete it from target playlist.
           A warning is displayed informing that the audio has comment(s)
           and that those comments will be deleted. Confirm deletion and
           then copy again the audio to the same target playlist.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitle = 'local_audio_playlist_2';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Now verifying that the source playlist directory still
      // contains the audio file copied to the target playlist
      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // And verify that the target playlist directory now
      // contains the audio file copied from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Find the target ListTile Playlist containing the audio copied
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu delete audio item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_delete_audio"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Since the copied audio contains comment(s), deleting it
      // causes a confirm action dialog to be displayed.
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            "Confirmez la suppression de l'audio commenté \"audio learn test short video one\"",
        confirmActionDialogMessagePossibleLst: [
          "L'audio contient 1 commentaire(s) qui seront également supprimés. Confirmer la suppression ?",
        ],
        closeDialogWithConfirmButton: true,
      );

      // Now verify that the target playlist directory no longer
      // contains the audio file copied from the source playlist
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, []);

      // Then, we move the audio already copied and deletedto to the
      // same target playlist in ensure it is moved with no warning

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".",
        isWarningConfirming: true,
      );

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy (+ check comment) audio from the Youtube source playlist to
           the local target playlist, then copy it from the target playlist
           to the another target playlist. The purpose of this test is to check
           that the 'Copied from playlist' and 'Copied to playlist' audio info
           fields are correctly updated. The first audio info verification
           checks all the download audio type info dialog fields.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetOnePlaylistTitle = 'local_audio_playlist_2';
      const String localAudioTargetTwoPlaylistTitle = 'local_3';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // *** First copy audio from Youtube source playlist to local
      // target playlist.

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioTargetOnePlaylistTitle),
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

      final Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"audio learn test short video one\" a été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Testing that the audio was copied from the source to the target
      // playlist directory

      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetOnePlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);
      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Now verifying the copied audio info dialog related content
      // in the source Youtube playlist. This verification tests all
      // downloadded audio type fields

      await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        youtubeChannel: 'Jean-Pierre Schnyder',
        originalVideoTitle: copiedAudioTitle,
        videoUploadDate: '10/06/2023',
        audioDownloadDateTimeOne: '28/06/2023 03:38',
        isAudioPlayable: true,
        videoUrl: "https://www.youtube.com/watch?v=v7PWb7f_P8M",
        compactVideoDescription:
            "Jean-Pierre Schnyder\n\nCette vidéo me sert à tester AudioLearn, l'app Android que je développe et dont le code est disponible sur GitHub. ...",
        validVideoTitleOrAudioTitle: copiedAudioTitle,
        audioEnclosingPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        movedFromPlaylistTitle: '',
        movedToPlaylistTitle: '',
        copiedFromPlaylistTitle: '',
        copiedToPlaylistTitle: localAudioTargetOnePlaylistTitle,
        audioDownloadDuration: "0:00:00",
        audioDownloadSpeed: "321.1 Ko/sec",
        audioDuration: '0:00:16.0',
        audioPosition: '0:00:03.3',
        audioState: "En pause",
        lastListenDateTime: '25/08/2024 15:03',
        audioFileName:
            '230628-033811-audio learn test short video one 23-06-10.mp3',
        audioFileSize: '143.7 Ko',
        isMusicQuality: false,
        audioPlaySpeed: '1.5',
        audioVolume: '50.0 %',
        audioCommentNumber: 1,
        language: Language.french,
      );

      // Select the target ListTile Playlist containing the audio moved
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetOnePlaylistTitle,
      );

      // Now verifying the copied audio info dialog related content
      // in the target local playlist

      Finder targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: localAudioTargetOnePlaylistTitle,
        validVideoTitleOrAudioTitle: copiedAudioTitle,
        movedFromPlaylistTitle: '',
        movedToPlaylistTitle: '',
        copiedFromPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        copiedToPlaylistTitle: '',
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // Now verifying that the target audio can access to its copied
      // comments

      // First, tap on the copied audio ListTile to open the
      // audio player view
      await tester.tap(targetAudioListTileWidgetFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify that the comment icon button is highlighted. This indiquates
      // that a comment exist for the audio
      IntegrationTestUtil.validateInkWellButton(
        tester: tester,
        inkWellButtonKey: 'commentsInkWellButton',
        expectedIcon: Icons.bookmark_outline_outlined,
        expectedIconColor: Colors.white,
        expectedIconBackgroundColor: kDarkAndLightEnabledIconColor,
      );

      // *** Then further copy the copied audio from the target local playlist
      // 'local_audio_playlist_2' to a new target local playlist 'local_3'.

      // Return to playlist download view
      Finder playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      radioListTile = find
          .ancestor(
            of: find.text(localAudioTargetTwoPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now find the ok button of the displayed confirm warning
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the copied audio info dialog related content
      // in the source local playlist
      targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: localAudioTargetOnePlaylistTitle,
        validVideoTitleOrAudioTitle: copiedAudioTitle,
        movedFromPlaylistTitle: '',
        movedToPlaylistTitle: '',
        copiedFromPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        copiedToPlaylistTitle: localAudioTargetTwoPlaylistTitle,
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // Now verifying the copied audio info dialog related content
      // in the target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetTwoPlaylistTitle,
      );

      // Now verifying the copied audio info dialog related content
      // in the target local playlist
      targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: localAudioTargetTwoPlaylistTitle,
        validVideoTitleOrAudioTitle: copiedAudioTitle,
        movedFromPlaylistTitle: '',
        movedToPlaylistTitle: '',
        copiedFromPlaylistTitle: localAudioTargetOnePlaylistTitle,
        copiedToPlaylistTitle: '',
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy commented audio which was already manually copied to the target
           playlist directory. Since the audio file exist in the target playlist
           dir, a warning indicating that the audio copy is not performed.
           Verify that the audio comment file itself was not copied to the
           target playlist comment dir since the copy was excluded.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitleThree = 'local_3';
      const String copiedCommentedAudioTitle =
          'audio learn test short video one';
      const String copiedCommentedAudioFileName =
          '230628-033811-audio learn test short video one 23-06-10.mp3';
      const String copiedCommentedAudioCommentFileName =
          '230628-033811-audio learn test short video one 23-06-10.json';

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

      // Manually copy the 'audio learn test short video one.mp3' file
      // to the 'local3' playlist dir.

      String targetPlaylistLocalDir =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree";

      DirUtil.copyFileToDirectorySync(
        sourceFilePathName:
            "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$copiedCommentedAudioFileName",
        targetDirectoryPath: targetPlaylistLocalDir,
      );

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder =
          find.text(copiedCommentedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleThree),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été copié de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_3\" car il est déjà présent dans cette playlist.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Now verify that the audio comment file was not copied to the
      // target playlist comment dir since the copy was excluded
      expect(
        File("$targetPlaylistLocalDir${path.separator}$kCommentDirName${path.separator}$copiedCommentedAudioCommentFileName")
            .existsSync(),
        false,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Copy in new created local playlist an audio whose play speed is set to 
           1.5. Verify that the audio play speed is correctly set in the copied
           audio file''', (WidgetTester tester) async {
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

      const String newLocalAudioTargetPlaylistTitle = 'new_local';
      const String copiedAudioTitle = 'audio learn test short video one';

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

      // Creating new local playlist

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        newLocalAudioTargetPlaylistTitle,
      );
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one", the audio to be copied

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(newLocalAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now find the ok button of the confirm dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Verify that the target playlist directory now
      // contains the audio file copied from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$newLocalAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
        "tts.mp3",
      ]);

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the target ListTile Playlist containing the audio copied
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: newLocalAudioTargetPlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the audio play speed in the displayed audio info
      final Text enclosingPlaylistTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioPlaySpeedKey')));

      expect(enclosingPlaylistTitleTextWidget.data, '1.25');

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Move audio test', () {
    testWidgets(
        '''Move (+ check comment) audio from the Youtube source playlist to
           the local target playlist, then move it back from the target to the
           source playlist, then move it again from source to target, then move
           it again back from the target to the source playlist. The purpose
           of this test is to check that the 'Moved from playlist' and 'Moved
           to playlist' audio info fields are correctly updated.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitle = 'local_audio_playlist_2';
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

      // *** First move audio from Youtube source playlist to local
      // target playlist.

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(movedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      Finder radioListTile = find
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

      // Now verifying the confirm warning dialog message

      final Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"audio learn test short video one\" a été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(selectedPlaylistTitleText.data, youtubeAudioSourcePlaylistTitle);

      // Testing that the audio was moved from the source to the target
      // playlist directory

      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      // Contains only the not moved audio
      expect(sourcePlaylistMp3Lst, [
        "230628-033813-audio learn test short video two 23-06-10.mp3",
        '231117-002828-morning _ cinematic video 23-07-01.mp3',
        'tts.mp3'
      ]);

      // Contains only the moved audio
      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Testing that the audio comment was moved from the source to
      // the target playlist directory

      List<String> sourcePlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      List<String> targetPlaylistCommentLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle${path.separator}$kCommentDirName',
        fileExtension: 'json',
      );

      // Contains only the not moved audio comment
      expect(sourcePlaylistCommentLst,
          ["230628-033813-audio learn test short video two 23-06-10.json"]);

      // Contains only the moved audio comment
      expect(targetPlaylistCommentLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Testing that the audio picture was moved from the source to
      // the target playlist directory

      List<String> sourcePlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      List<String> targetPlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      // Contains only the not moved audio picture
      expect(sourcePlaylistPictureLst, []);

      // Contains only the moved audio picture
      expect(targetPlaylistPictureLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Find the target ListTile Playlist containing the audio moved
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitle,
      );

      // Now verifying the moved audio info dialog related content
      // in the target local playlist

      Finder targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: localAudioTargetPlaylistTitle,
        validVideoTitleOrAudioTitle: movedAudioTitle,
        movedFromPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        movedToPlaylistTitle: '',
        copiedFromPlaylistTitle: '',
        copiedToPlaylistTitle: '',
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // Now verifying that the moved audio can access to its moved
      // comments

      // First, tap on the target audio ListTile to open the
      // audio player view
      await tester.tap(targetAudioListTileWidgetFinder);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify that the comment icon button is highlighted. This indiquates
      // that a comment exist for the audio
      IntegrationTestUtil.validateInkWellButton(
        tester: tester,
        inkWellButtonKey: 'commentsInkWellButton',
        expectedIcon: Icons.bookmark_outline_outlined,
        expectedIconColor: Colors.white,
        expectedIconBackgroundColor: kDarkAndLightEnabledIconColor,
      );

      // Now verify that the moved audio can be played

      // Verify the current audio position
      Text audioPositionText = tester
          .widget<Text>(find.byKey(const Key('audioPlayerViewAudioPosition')));
      expect(audioPositionText.data, '0:05');

      Finder audioTitlePositionTextFinder = find.text("$movedAudioTitle\n0:24");
      expect(audioTitlePositionTextFinder, findsOneWidget);

      // Now play then pause the moved audio
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      // Tap on pause button to pause the audio
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // Verify the audio position

      Finder audioPlayerViewAudioPositionFinder =
          find.byKey(const Key('audioPlayerViewAudioPosition'));

      IntegrationTestUtil.verifyPositionBetweenMinMax(
        tester: tester,
        textWidgetFinder: audioPlayerViewAudioPositionFinder,
        minPositionTimeStr: '0:04',
        maxPositionTimeStr: '0:06',
      );

      // *** Then move back the moved audio from the target local playlist
      // to the Youtube source playlist.

      // Return to playlist download view
      Finder playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Click on playlist toggle button to hide the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder targetAudioListTileTextWidgetFinder = find.text(movedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      radioListTile = find
          .ancestor(
            of: find.text(youtubeAudioSourcePlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now find the ok button of the displayed confirm warning
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the moved audio info dialog related content
      // in the target youtube playlist

      // First, select the Youtube pléaylist ...

      // Find the ListTile Playlist containing the audio removed from
      // the target playlist

      // Click on playlist toggle button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        validVideoTitleOrAudioTitle: movedAudioTitle,
        movedFromPlaylistTitle: localAudioTargetPlaylistTitle,
        movedToPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        copiedFromPlaylistTitle: '',
        copiedToPlaylistTitle: '',
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // *** Then move again the moved audio from the Youtube playlist
      // to the target local playlist.

      // Return to playlist download view
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      sourceAudioListTileTextWidgetFinder = find.text(movedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      radioListTile = find
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

      // Now find the ok button of the displayed confirm warning
      // dialog and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Find the target ListTile Playlist containing the audio moved
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: localAudioTargetPlaylistTitle,
      );

      // Now verifying the moved audio info dialog related content
      // in the target local playlist

      targetAudioListTileWidgetFinder =
          await IntegrationTestUtil.verifyAudioInfoDialog(
        tester: tester,
        audioEnclosingPlaylistTitle: localAudioTargetPlaylistTitle,
        validVideoTitleOrAudioTitle: movedAudioTitle,
        movedFromPlaylistTitle: youtubeAudioSourcePlaylistTitle,
        movedToPlaylistTitle: localAudioTargetPlaylistTitle,
        copiedFromPlaylistTitle: '',
        copiedToPlaylistTitle: '',
        audioDuration: '0:00:24.0',
        language: Language.french,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move downloaded audio from Youtube to local playlist unchecking keep audio
           in source playlist checkbox. This displays a warning indicating that the
           audio reference in the Youtube playlist should be removed otherwise it will
           be downloaded again the next time the user will download this playlist.''',
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

      const String localAudioPlaylistTitle = 'local_audio_playlist_2';
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

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now uncheck the keep audio in source playlist checkbox
      await tester.tap(
          find.byKey(const Key('keepAudioDataInSourcePlaylistCheckboxKey')));
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      final Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"audio learn test short video one\" a été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".\n\nSUPPRIMEZ L'AUDIO \"audio learn test short video one\" DE LA PLAYLIST YOUTUBE \"audio_learn_test_download_2_small_videos\", SINON L'AUDIO SERA TÉLÉCHARGÉ À NOUVEAU LORS DU PROCHAIN TÉLÉCHARGEMENT DE LA PLAYLIST.");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move imported audio from Youtube to local playlist unchecking keep audio
           in source playlist checkbox. Since the audio was not downloaded from the
           Youtube playlist, this doesn't display any warning indicating that the
           audio reference in the Youtube playlist should be removed otherwise it will
           be downloaded again the next time the user will download this playlist.''',
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

      const String localAudioPlaylistTitle = 'local_audio_playlist_2';
      const String movedImportedAudioTitle =
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

      // Now we want to tap the popup menu of the imported Audio ListTile
      // "231117-002828-morning _ cinematic video 23-07-01"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedImportedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now uncheck the keep audio in source playlist checkbox
      await tester.tap(
          find.byKey(const Key('keepAudioDataInSourcePlaylistCheckboxKey')));
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      final Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$movedImportedAudioTitle\" a été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move converted audio from Youtube to local playlist unchecking keep audio
           in source playlist checkbox. Since the audio was not downloaded from the
           Youtube playlist, this doesn't display any warning indicating that the
           audio reference in the Youtube playlist should be removed otherwise it will
           be downloaded again the next time the user will download this playlist.''',
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

      const String localAudioPlaylistTitle = 'local_audio_playlist_2';
      const String movedConvertedAudioTitle = 'tts';

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

      // Now we want to tap the popup menu of the converted Audio ListTile
      // "tts"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedConvertedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now uncheck the keep audio in source playlist checkbox
      await tester.tap(
          find.byKey(const Key('keepAudioDataInSourcePlaylistCheckboxKey')));
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      final Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$movedConvertedAudioTitle\" a été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move audio not present in source playlist unchecking the 'keep
           audio in source playlist' checkbox.''', (WidgetTester tester) async {
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

      const String localAudioPlaylistTitle = 'local_audio_playlist_2';
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

      // Delete the mp3 file of the moved audio in the source playlist
      // so that a warning indicating that the audio is not present in the
      // source playlist is displayed when trying to move it to the target
      // playlist
      DirUtil.deleteFileIfExist(
        pathFileName:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}audio_learn_test_download_2_small_videos${path.separator}230628-033811-audio learn test short video one 23-06-10.mp3',
      );

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now uncheck the keep audio in source playlist checkbox
      await tester.tap(
          find.byKey(const Key('keepAudioDataInSourcePlaylistCheckboxKey')));
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\" car son fichier MP3 n'est pas présent dans la playlist source.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Move audio not present in source playlist without unchecking
           the 'keep audio in source playlist' checkbox.''',
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

      const String localAudioPlaylistTitle = 'local_audio_playlist_2';
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

      // Delete the mp3 file of the moved audio in the source playlist
      // so that a warning indicating that the audio is not present in the
      // source playlist is displayed when trying to move it to the target
      // playlist
      DirUtil.deleteFileIfExist(
        pathFileName:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}audio_learn_test_download_2_small_videos${path.separator}230628-033811-audio learn test short video one 23-06-10.mp3',
      );

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(radioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_audio_playlist_2\" car son fichier MP3 n'est pas présent dans la playlist source.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move audio without selecting the target playlist and unchecking
           the 'keep audio in source playlist' checkbox.''',
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

      // Delete the mp3 file of the moved audio in the source playlist
      // so that a warning indicating that the audio is not present in the
      // source playlist is displayed when trying to move it to the target
      // playlist
      DirUtil.deleteFileIfExist(
        pathFileName:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}audio_learn_test_download_2_small_videos${path.separator}230628-033811-audio learn test short video one 23-06-10.mp3',
      );

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Now uncheck the keep audio in source playlist checkbox
      await tester.tap(
          find.byKey(const Key('keepAudioDataInSourcePlaylistCheckboxKey')));
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the value of the Warning dialog title
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Aucune playlist sélectionnée pour le déplacement de l'audio. Sélectionnez une playlist et rééssayez ...",
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move audio without selecting the target playlist without unchecking
           the 'keep audio in source playlist' checkbox.''',
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

      // Delete the mp3 file of the moved audio in the source playlist
      // so that a warning indicating that the audio is not present in the
      // source playlist is displayed when trying to move it to the target
      // playlist
      DirUtil.deleteFileIfExist(
        pathFileName:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}audio_learn_test_download_2_small_videos${path.separator}230628-033811-audio learn test short video one 23-06-10.mp3',
      );

      // Tap the 'Toggle List' button to show the list of playlist's.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

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

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Check the value of the Warning dialog title
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "Aucune playlist sélectionnée pour le déplacement de l'audio. Sélectionnez une playlist et rééssayez ...",
        warningTitle: 'AVERTISSEMENT',
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move commented audio which was already manually copied to the target
           playlist directory. Since the audio file exist in the target playlist
           dir, a warning indicating that the audio move is not performed.
           Verify that the audio comment file itself was not moved to the
           target playlist comment dir since the move operation was excluded.''',
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetPlaylistTitleThree = 'local_3';
      const String movedCommentedAudioTitle =
          'audio learn test short video one';
      const String movedCommentedAudioFileName =
          '230628-033811-audio learn test short video one 23-06-10.mp3';
      const String movedCommentedAudioCommentFileName =
          '230628-033811-audio learn test short video one 23-06-10.json';

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

      // Manually copy the 'audio learn test short video one.mp3' file
      // to the 'local3' playlist dir.

      String targetPlaylistLocalDir =
          "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetPlaylistTitleThree";

      DirUtil.copyFileToDirectorySync(
        sourceFilePathName:
            "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle${path.separator}$movedCommentedAudioFileName",
        targetDirectoryPath: targetPlaylistLocalDir,
      );

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder =
          find.text(movedCommentedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(localAudioTargetPlaylistTitleThree),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the warning dialog
      await IntegrationTestUtil.verifyAndCloseWarningDialog(
        tester: tester,
        warningDialogMessage:
            "L'audio \"audio learn test short video one\" N'A PAS été déplacé de la playlist Youtube \"audio_learn_test_download_2_small_videos\" vers la playlist locale \"local_3\" car il est déjà présent dans cette playlist.",
        isWarningConfirming: false,
        warningTitle: 'AVERTISSEMENT',
      );

      // Now verify that the audio comment file was not copied to the
      // target playlist comment dir since the copy was excluded
      expect(
        File("$targetPlaylistLocalDir${path.separator}$kCommentDirName${path.separator}$movedCommentedAudioCommentFileName")
            .existsSync(),
        false,
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Move in new created local playlist an audio whose play speed is set to 
           1.5. Verify that the audio play speed is correctly set in the moved
           audio file''', (WidgetTester tester) async {
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

      const String newLocalAudioTargetPlaylistTitle = 'new_local';
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

      // Creating new local playlist

      // Open the add playlist dialog by tapping the add playlist
      // button
      await tester.tap(find.byKey(const Key('addPlaylistButton')));
      await tester.pumpAndSettle();

      // Enter the title of the local playlist
      await tester.enterText(
        find.byKey(const Key('playlistLocalTitleConfirmDialogTextField')),
        newLocalAudioTargetPlaylistTitle,
      );
      await tester.pumpAndSettle();

      // Confirm the addition by tapping the confirmation button in
      // the AlertDialog
      await tester
          .tap(find.byKey(const Key('addPlaylistConfirmDialogAddButton')));
      await tester.pumpAndSettle();

      // Close the warning dialog by tapping on the Ok button
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one", the audio to be moved

      // First, find the Audio sublist ListTile Text widget
      Finder sourceAudioListTileTextWidgetFinder = find.text(movedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      Finder targetPlaylistRadioListTile = find
          .ancestor(
            of: find.text(newLocalAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(targetPlaylistRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now find the ok button of the confirm dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Verify that the target playlist directory now
      // contains the audio file moved from the source playlist
      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$newLocalAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      expect(targetPlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
        "tts.mp3",
      ]);

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the target ListTile Playlist containing the audio moved
      // from the source playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: newLocalAudioTargetPlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder targetAudioListTileTextWidgetFinder =
          find.text(movedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder targetAudioListTileWidgetFinder = find.ancestor(
        of: targetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile and tap
      // on it
      final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
        of: targetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(targetAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_display_audio_info"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the audio play speed in the displayed audio info
      final Text enclosingPlaylistTitleTextWidget =
          tester.widget<Text>(find.byKey(const Key('audioPlaySpeedKey')));

      expect(enclosingPlaylistTitleTextWidget.data, '1.25');

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('Delete copied or moved audio test', () {
    testWidgets('''Delete an audio which was first copied from Youtube to local
           playlist and then was copied from the local playlist to an other
           Youtube playlist. This audio is then 'deleted from playlist as well'
           from the other Youtube playlist with no warning being displayed
           since, as a copied audio, it is not referenced in the Youtube
           playlist.''', (WidgetTester tester) async {
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetSourcePlaylistTitle =
          'local_audio_playlist_2';
      const String copiedAudioTitle = 'audio learn test short video one';
      const String youtubeAudioTargetPlaylistTitle =
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
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // First, set the application language to French
      await IntegrationTestUtil.setApplicationLanguage(
        tester: tester,
        language: Language.french,
      );

      // *** First test part: Copy audio from Youtube to local
      // playlist

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      final Finder popupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(popupCopyMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioTargetSourcePlaylistTitle),
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

      Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$copiedAudioTitle\" a été copié de la playlist Youtube \"$youtubeAudioSourcePlaylistTitle\" vers la playlist locale \"$localAudioTargetSourcePlaylistTitle\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(
        selectedPlaylistTitleText.data,
        youtubeAudioSourcePlaylistTitle,
      );

      // Now verifying the audio was physically copied to the target
      // playlist directory.

      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the Youtube source playlist directory content
      expect(sourcePlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "230628-033813-audio learn test short video two 23-06-10.mp3",
      ]);

      // Verify the local target playlist directory content
      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Now verifying the copied audio informations in the source
      // playlist

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: youtubeAudioSourcePlaylistTitle,
        copiedAudioSourcePlaylistTitle: '',
        copiedAudioTargetPlaylistTitle: localAudioTargetSourcePlaylistTitle,
        movedAudioSourcePlaylistTitle: '',
        movedAudioTargetPlaylistTitle: '',
      );

      // And verifying the copied audio informations in the target
      // playlist

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: localAudioTargetSourcePlaylistTitle,
        copiedAudioSourcePlaylistTitle: youtubeAudioSourcePlaylistTitle,
        copiedAudioTargetPlaylistTitle: '',
        movedAudioSourcePlaylistTitle: '',
        movedAudioTargetPlaylistTitle: '',
      );

      // """ Second test part: Copy audio from local playlist to
      // other Youtube playlist

      // Currently, the local audio target source playlist is selected

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder localSourceAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder localSourceAudioListTileWidgetFinder = find.ancestor(
        of: localSourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder localSourceAudioListTileLeadingMenuIconButton =
          find.descendant(
        of: localSourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localSourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the copy audio popup menu item and tap on it
      final Finder localSourceAudioPopupCopyMenuItem =
          find.byKey(const Key("popup_menu_copy_audio_to_playlist"));

      await tester.tap(localSourceAudioPopupCopyMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be copied

      final Finder secondYoutubeTargetRadioListTile = find
          .ancestor(
            of: find.text(youtubeAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(secondYoutubeTargetRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$copiedAudioTitle\" a été copié de la playlist locale \"$localAudioTargetSourcePlaylistTitle\" vers la playlist Youtube \"$youtubeAudioTargetPlaylistTitle\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(
        selectedPlaylistTitleText.data,
        localAudioTargetSourcePlaylistTitle,
      );

      // Now verifying the audio was physically copied to the target
      // playlist directory.

      sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the local source playlist directory content
      expect(sourcePlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Verify the Youtube target playlist directory content
      expect(targetPlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "231117-002826-Really short video 23-07-01.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
      ]);

      // Verify that the target playlist directory now contains
      // the audio picture file copied from the source playlist

      List<String> targetPlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistPictureLst,
          ["230628-033811-audio learn test short video one 23-06-10.json"]);

      // Now verifying the copied audio informations in the source
      // playlist

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: localAudioTargetSourcePlaylistTitle,
        copiedAudioSourcePlaylistTitle: youtubeAudioSourcePlaylistTitle,
        copiedAudioTargetPlaylistTitle: youtubeAudioTargetPlaylistTitle,
        movedAudioSourcePlaylistTitle: '',
        movedAudioTargetPlaylistTitle: '',
      );

      // And verifying the copied audio informations in the target
      // playlist

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: youtubeAudioTargetPlaylistTitle,
        copiedAudioSourcePlaylistTitle: localAudioTargetSourcePlaylistTitle,
        copiedAudioTargetPlaylistTitle: '',
        movedAudioSourcePlaylistTitle: '',
        movedAudioTargetPlaylistTitle: '',
      );

      // """ Third test part: Delete audio from target Youtube
      // playlist verifying that no warning is displayed since the
      // deleted audio was copied and not downloaded, which ensures
      // that the deleted audio video is not referenced in the
      // Youtube playlist.

      // Now we want to tap again on the popup menu of the Audio
      // ListTile "audio learn test short video one" in order to
      // delete it from playlist aswell

      // First, find the Audio sublist ListTile Text widget
      final Finder youtubeTargetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder youtubeTargetAudioListTileWidgetFinder = find.ancestor(
        of: youtubeTargetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder youtubeTargetAudioListTileLeadingMenuIconButtonFinder =
          find.descendant(
        of: youtubeTargetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubeTargetAudioListTileLeadingMenuIconButtonFinder);
      await tester.pumpAndSettle();

      // Now find the popup menu item and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the confirm action dialog title and message
      // and confirm the deletion
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            "Confirmez la suppression de l'audio \"$copiedAudioTitle\" de la playlist Youtube",
        confirmActionDialogMessagePossibleLst: [
          "Supprimez l'audio \"$copiedAudioTitle\" de la playlist \"$youtubeAudioTargetPlaylistTitle\" définie sur le site Youtube, sinon l'audio sera téléchargé à nouveau lors du prochain téléchargement de la playlist. Ou alors cliquez sur \"Annuler\" et choisissez \"Supprimer l'audio ...\" au lieu de \"Supprimer l'audio de la playlist également ...\". Ainsi, l'audio sera supprimé de la liste des audios jouables, mais restera dans la liste des audios téléchargés, ce qui évitera son retéléchargement.",
        ],
        closeDialogWithConfirmButton: true,
      );

      // Now verifying the deleted audio was physically deleted from
      // the playlist directory.
      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the Youtube target playlist directory content
      expect(targetPlaylistMp3Lst, [
        "231117-002826-Really short video 23-07-01.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
      ]);

      // Verify that the target playlist directory no longer
      // contains the audio picture file copied from the source
      // playlist

      targetPlaylistPictureLst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle${path.separator}$kPictureDirName',
        fileExtension: 'json',
      );

      expect(targetPlaylistPictureLst, []);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Delete an audio which was first moved from Youtube to local
           playlist and then was moved from the local playlist to an other
           Youtube playlist. This audio is then 'deleted from playlist as well'
           from the other Youtube playlist with no warning being displayed
           since, as a copied audio, it is not referenced in the Youtube
           playlist.''', (WidgetTester tester) async {
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

      const String youtubeAudioSourcePlaylistTitle =
          'audio_learn_test_download_2_small_videos';
      const String localAudioTargetSourcePlaylistTitle =
          'local_audio_playlist_2';
      const String copiedAudioTitle = 'audio learn test short video one';
      const String youtubeAudioTargetPlaylistTitle =
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
              "$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$kSettingsFileName");

      await app.main();
      await tester.pumpAndSettle();

      // First, set the application language to French
      await IntegrationTestUtil.setApplicationLanguage(
        tester: tester,
        language: Language.french,
      );

      // *** First test part: Copy audio from Youtube to local
      // playlist

      // Tap the 'Toggle List' button to display the playlist list
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Select the playlist containing the audio to copy to the
      // target local playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubeAudioSourcePlaylistTitle,
      );

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder sourceAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder sourceAudioListTileWidgetFinder = find.ancestor(
        of: sourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder sourceAudioListTileLeadingMenuIconButton = find.descendant(
        of: sourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(sourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      final Finder popupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(popupMoveMenuItem);
      await tester.pumpAndSettle();

      // Check the value of the select one playlist AlertDialog
      // dialog title
      Text alertDialogTitle = tester
          .widget(find.byKey(const Key('playlistOneSelectableDialogTitleKey')));
      expect(alertDialogTitle.data, 'Sélectionnez une playlist');

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder radioListTile = find
          .ancestor(
            of: find.text(localAudioTargetSourcePlaylistTitle),
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

      Text warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$copiedAudioTitle\" a été déplacé de la playlist Youtube \"$youtubeAudioSourcePlaylistTitle\" vers la playlist locale \"$localAudioTargetSourcePlaylistTitle\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      Text selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(
        selectedPlaylistTitleText.data,
        youtubeAudioSourcePlaylistTitle,
      );

      // Now verifying the audio was physically moved to the target
      // playlist directory.

      List<String> sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      List<String> targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the Youtube source playlist directory content
      expect(sourcePlaylistMp3Lst, [
        "230628-033813-audio learn test short video two 23-06-10.mp3",
      ]);

      // Verify the local target playlist directory content
      expect(targetPlaylistMp3Lst,
          ["230628-033811-audio learn test short video one 23-06-10.mp3"]);

      // Now verifying the moved audio informations in the target
      // playlist. In the source playlist, the audio is no longer
      // displayed since it was moved to the target playlist.

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: localAudioTargetSourcePlaylistTitle,
        copiedAudioSourcePlaylistTitle: '',
        copiedAudioTargetPlaylistTitle: '',
        movedAudioSourcePlaylistTitle: youtubeAudioSourcePlaylistTitle,
        movedAudioTargetPlaylistTitle: '',
      );

      // """ Second test part: Move audio from local playlist to
      // other Youtube playlist

      // Currently, the local audio target source playlist is selected

      // Now we want to tap the popup menu of the Audio ListTile
      // "audio learn test short video one"

      // First, find the Audio sublist ListTile Text widget
      final Finder localSourceAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder localSourceAudioListTileWidgetFinder = find.ancestor(
        of: localSourceAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder localSourceAudioListTileLeadingMenuIconButton =
          find.descendant(
        of: localSourceAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(localSourceAudioListTileLeadingMenuIconButton);
      await tester.pumpAndSettle();

      // Now find the move audio popup menu item and tap on it
      final Finder localSourceAudioPopupMoveMenuItem =
          find.byKey(const Key("popup_menu_move_audio_to_playlist"));

      await tester.tap(localSourceAudioPopupMoveMenuItem);
      await tester.pumpAndSettle();

      // Find the RadioListTile target playlist to which the audio
      // will be moved

      final Finder secondYoutubeTargetRadioListTile = find
          .ancestor(
            of: find.text(youtubeAudioTargetPlaylistTitle),
            matching: find.byType(ListTile),
          )
          .last;

      // Tap the target playlist RadioListTile to select it
      await tester.tap(secondYoutubeTargetRadioListTile);
      await tester.pumpAndSettle();

      // Now find the confirm button and tap on it
      await tester.tap(find.byKey(const Key('confirmButton')));
      await tester.pumpAndSettle();

      // Now verifying the confirm warning dialog message

      warningDialogMessageTextWidget =
          tester.widget<Text>(find.byKey(const Key('warningDialogMessage')));

      expect(warningDialogMessageTextWidget.data,
          "L'audio \"$copiedAudioTitle\" a été déplacé de la playlist locale \"$localAudioTargetSourcePlaylistTitle\" vers la playlist Youtube \"$youtubeAudioTargetPlaylistTitle\".");

      // Now find the ok button of the confirm warning dialog
      // and tap on it
      await tester.tap(find.byKey(const Key('warningDialogOkButton')));
      await tester.pumpAndSettle();

      // Now verifying the selected playlist TextField still
      // contains the title of the source playlist

      selectedPlaylistTitleText = tester
          .widget<Text>(find.byKey(const Key('selectedPlaylistTitleText')));

      expect(
          selectedPlaylistTitleText.data, localAudioTargetSourcePlaylistTitle);

      // Now verifying the audio was physically moved to the target
      // playlist directory.

      sourcePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$localAudioTargetSourcePlaylistTitle',
        fileExtension: 'mp3',
      );

      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the local source playlist directory content
      expect(sourcePlaylistMp3Lst, []);

      // Verify the Youtube target playlist directory content
      expect(targetPlaylistMp3Lst, [
        "230628-033811-audio learn test short video one 23-06-10.mp3",
        "231117-002826-Really short video 23-07-01.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
      ]);

      // Now verifying the moved audio informations in the target
      // playlist. In the source playlist, the audio is no longer
      // displayed since it was moved to the target playlist.

      await _verifyAudioInfoDialogElements(
        tester: tester,
        audioTitle: copiedAudioTitle,
        playlistEnclosingAudioTitle: youtubeAudioTargetPlaylistTitle,
        copiedAudioSourcePlaylistTitle: '',
        copiedAudioTargetPlaylistTitle: '',
        movedAudioSourcePlaylistTitle: localAudioTargetSourcePlaylistTitle,
        movedAudioTargetPlaylistTitle: '',
      );

      // """ Third test part: Delete audio from target Youtube
      // playlist verifying that no warning is displayed since the
      // deleted audio was copied and not downloaded, which ensures
      // that the deleted audio video is not referenced in the
      // Youtube playlist.

      // Now we want to tap again on the popup menu of the Audio
      // ListTile "audio learn test short video one" in order to
      // delete it from playlist aswell

      // First, find the Audio sublist ListTile Text widget
      final Finder youtubeTargetAudioListTileTextWidgetFinder =
          find.text(copiedAudioTitle);

      // Then obtain the Audio ListTile widget enclosing the Text widget by
      // finding its ancestor
      final Finder youtubeTargetAudioListTileWidgetFinder = find.ancestor(
        of: youtubeTargetAudioListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the leading menu icon button of the Audio ListTile
      // and tap on it
      final Finder youtubeTargetAudioListTileLeadingMenuIconButtonFinder =
          find.descendant(
        of: youtubeTargetAudioListTileWidgetFinder,
        matching: find.byIcon(Icons.menu),
      );

      // Tap the leading menu icon button to open the popup menu
      await tester.tap(youtubeTargetAudioListTileLeadingMenuIconButtonFinder);
      await tester.pumpAndSettle();

      // Now find the 'Delete audio from playlist as well' popup menu item
      // and tap on it
      final Finder popupDisplayAudioInfoMenuItemFinder =
          find.byKey(const Key("popup_menu_delete_audio_from_playlist_aswell"));

      await tester.tap(popupDisplayAudioInfoMenuItemFinder);
      await tester.pumpAndSettle();

      // Now verifying the confirm action dialog title and message
      // and confirm the deletion
      await IntegrationTestUtil.verifyConfirmActionDialog(
        tester: tester,
        confirmActionDialogTitle:
            "Confirmez la suppression de l'audio \"$copiedAudioTitle\" de la playlist Youtube",
        confirmActionDialogMessagePossibleLst: [
          "Supprimez l'audio \"$copiedAudioTitle\" de la playlist \"$youtubeAudioTargetPlaylistTitle\" définie sur le site Youtube, sinon l'audio sera téléchargé à nouveau lors du prochain téléchargement de la playlist. Ou alors cliquez sur \"Annuler\" et choisissez \"Supprimer l'audio ...\" au lieu de \"Supprimer l'audio de la playlist également ...\". Ainsi, l'audio sera supprimé de la liste des audios jouables, mais restera dans la liste des audios téléchargés, ce qui évitera son retéléchargement.",
        ],
        closeDialogWithConfirmButton: true,
      );

      // Now verifying the deleted audio was physically deleted from
      // the playlist directory. No warning was displayed.

      targetPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath:
            '$kApplicationPathWindowsTest${path.separator}playlists${path.separator}$youtubeAudioTargetPlaylistTitle',
        fileExtension: 'mp3',
      );

      // Verify the Youtube target playlist directory content
      expect(targetPlaylistMp3Lst, [
        "231117-002826-Really short video 23-07-01.mp3",
        "231117-002828-morning _ cinematic video 23-07-01.mp3",
      ]);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
  group('''Executing update playlist JSON files after manually adding or
         deleting playlist directory and deleting audio files in other
         playlists test''', () {
    testWidgets(
        '''Manually delete all audio files in existing playlist and manually
           add a Youtube playlist directory.''', (WidgetTester tester) async {
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

      const String s8AudioYoutubePlaylistTitle = 'S8 audio';

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

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify the current playable
      // audio

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify the displayed current audio title
      expect(
          find.text(
              "3 fois où un économiste m'a ouvert les yeux (Giraud, Lefournier, Porcher)\n16:26"),
          findsOneWidget);

      // And return to the playlist download view
      Finder playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      String s8AudioYoutubePlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$s8AudioYoutubePlaylistTitle';

      List<String> s8AudioYoutubePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: s8AudioYoutubePlaylistPath,
        fileExtension: 'mp3',
      );

      // *** Manually deleting audio files from S8 Audio Youtube
      // playlist directory

      DirUtil.deleteMp3FilesInDir(
        filePath: s8AudioYoutubePlaylistPath,
      );

      // Test that the S8 Audio Youtube playlist is still showing the
      // deleted audio

      for (String audioTitle in s8AudioYoutubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify that current playable
      // audio is still displayed, even if the audio was manually deleted

      appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the displayed current audio title
      expect(
          find.text(
              "3 fois où un économiste m'a ouvert les yeux (Giraud, Lefournier, Porcher)\n16:26"),
          findsOneWidget);

      // And return to the playlist download view
      playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // *** Now, manually add the urgent_actus Youtube playlist directory
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_added_playlist_dir",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Now execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Test that the S8 Audio Youtube playlist is no longer showing the
      // deleted audio

      for (String audioTitle in s8AudioYoutubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois')
            .replaceFirst('antinuke', 'anti-nuke');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsNothing);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify that "No audio
      // selected" is displayed

      appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the no selected audio title is displayed
      expect(find.text("No audio selected"), findsOneWidget);

      // And return to the playlist download view
      playlistDownloadViewNavButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(playlistDownloadViewNavButton);
      await tester.pumpAndSettle();

      // Now test that the manually added urgent_actus Youtube playlist is
      // displayed

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the manually added Youtube
      // playlist

      const String urgentActusyoutubeplaylisttitle = 'urgent_actus';

      // First, find the urgent_actus Youtube playlist ListTile Text widget
      final Finder addedYoutubePlaylistListTileTextWidgetFinder =
          find.text(urgentActusyoutubeplaylisttitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder addedYoutubePlaylistListTileWidgetFinder = find.ancestor(
        of: addedYoutubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: addedYoutubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Test that the audio of the added urgent_actus Youtube playlist
      // are listed

      String urgentActusyoutubeplaylistpath =
          '$kApplicationPathWindowsTest${path.separator}$urgentActusyoutubeplaylisttitle';

      List<String> urgentActusyoutubeplaylistmp3lst =
          DirUtil.listFileNamesInDir(
        directoryPath: urgentActusyoutubeplaylistpath,
        fileExtension: 'mp3',
      );

      for (String audioTitle in urgentActusyoutubeplaylistmp3lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify the current playable
      // audio of the manually added playlist

      appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the displayed current audio title
      expect(
          find.text(
              'Ce qui va vraiment sauver notre espèce par Jancovici et Barrau\n5:11'),
          findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Manually add copied smartphone local playlist directory.',
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

      // Manually add the local 'test' playlist directory which were copied
      // from a smartphone
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_added_smartphone_local_playlist_dir",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Test that the manually added test local smartphone playlist is
      // displayed

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the manually added Youtube
      // playlist

      const String testLocalPlaylistTitle = 'test';

      // First, find the 'test' local playlist ListTile Text widget
      final Finder testLocalPlaylistTileTextWidgetFinder =
          find.text(testLocalPlaylistTitle);

      // Then obtain the 'test' source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder testLocalPlaylistTileWidgetFinder = find.ancestor(
        of: testLocalPlaylistTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Ensure the new playlist has been unselected
      Finder localPlaylistListTileCheckboxWidgetFinder =
          await _ensurePlaylistCheckboxIsNotChecked(
        playlistListTileWidgetFinder: testLocalPlaylistTileWidgetFinder,
        widgetTester: tester,
      );

      await tester.tap(localPlaylistListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Test that the audio of the added 'test' local playlist are
      // listed

      String testLocalPlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$testLocalPlaylistTitle';

      List<String> testLocalPlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: testLocalPlaylistPath,
        fileExtension: 'mp3',
      );

      for (String audioTitle in testLocalPlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d]'), '')
            .replaceAll(RegExp(r'\-\-'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' minutes', '5 minutes');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify the current playable
      // audio of the added playlist

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the displayed current audio title
      expect(
          find.text(
              "Quand les humoristes parlent d'écologie - Thomas VDB, Félix Djhan, Pierre Thévenoux\n4:31"),
          findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('Manually add copied smartphone Youtube playlist directory.',
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

      // Manually add the Youtube 'Youtube_test' playlist directory which
      // were copied from a smartphone
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_added_smartphone_Youtube_playlist_dir",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Test that the manually added Youtube_test Youtube smartphone
      // playlist is displayed

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the manually added Youtube
      // playlist

      const String testYoutubePlaylistTitle = 'Youtube_test';

      // First, find the 'Youtube_test' Youtube playlist ListTile Text
      // widget
      final Finder testYoutubePlaylistTileTextWidgetFinder =
          find.text(testYoutubePlaylistTitle);

      // Then obtain the 'Youtube_test' source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder testYoutubePlaylistTileWidgetFinder = find.ancestor(
        of: testYoutubePlaylistTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Ensure the new playlist has been unselected
      Finder youtubePlaylistListTileCheckboxWidgetFinder =
          await _ensurePlaylistCheckboxIsNotChecked(
        playlistListTileWidgetFinder: testYoutubePlaylistTileWidgetFinder,
        widgetTester: tester,
      );

      // Now, select the playlist
      await tester.tap(youtubePlaylistListTileCheckboxWidgetFinder);
      await tester.pumpAndSettle();

      // Test that the audio of the added 'Youtube_test' Youtube playlist
      // are listed

      String testYoutubePlaylistPath =
          '$kApplicationPathWindowsTest${path.separator}$testYoutubePlaylistTitle';

      List<String> testYoutubePlaylistMp3Lst = DirUtil.listFileNamesInDir(
        directoryPath: testYoutubePlaylistPath,
        fileExtension: 'mp3',
      );

      for (String audioTitle in testYoutubePlaylistMp3Lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d]'), '')
            .replaceAll(RegExp(r'\-\-'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' minutes', '5 minutes');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify the current playable
      // audio of the added playlist

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the displayed current audio title
      expect(
          find.text(
              "5 minutes d'éco-anxiété pour se motiver à bouger (Ringenbach, Janco, Barrau, Servigne)\n5:53"),
          findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Manually delete all application data including the settings.json file
           and then execute update playlist JSON files''',
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

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Obtains all the ListTile widgets present in the playlist
      // download view (2 playlist items + 4 audio items)
      Finder listTilesFinder = find.byType(ListTile);
      expect(listTilesFinder, findsNWidgets(6));

      // Now manually delete all application data including the settings.json
      // file
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Now verify that no more ListItem widget is displayed in the download
      // playlist view
      listTilesFinder = find.byType(ListTile);
      expect(listTilesFinder, findsNWidgets(0));

      // Now we tap on the AudioPlayerView icon button to open
      // AudioPlayerView screen in order to verify that "No audio
      // selected" is displayed

      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // Verify the no selected audio title is displayed
      expect(find.text("No audio selected"), findsOneWidget);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets('''Manually delete Youtube playlist directory after adding it
           manually.''', (WidgetTester tester) async {
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

      // *** Manually add the urgent_actus Youtube playlist directory
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_added_playlist_dir",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Now test that the manually added urgent_actus Youtube playlist is
      // displayed

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the manually added Youtube
      // playlist

      const String urgentActusyoutubeplaylisttitle = 'urgent_actus';

      // First, find the urgent_actus Youtube playlist ListTile Text widget
      final Finder addedYoutubePlaylistListTileTextWidgetFinder =
          find.text(urgentActusyoutubeplaylisttitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder addedYoutubePlaylistListTileWidgetFinder = find.ancestor(
        of: addedYoutubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: addedYoutubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Test that the audio of the added urgent_actus Youtube playlist
      // are listed

      String urgentActusyoutubeplaylistpath =
          '$kApplicationPathWindowsTest${path.separator}$urgentActusyoutubeplaylisttitle';

      List<String> urgentActusyoutubeplaylistmp3lst =
          DirUtil.listFileNamesInDir(
        directoryPath: urgentActusyoutubeplaylistpath,
        fileExtension: 'mp3',
      );

      for (String audioTitle in urgentActusyoutubeplaylistmp3lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now manually delete the urgent_actus playlist directory
      DirUtil.deleteDirAndSubDirsIfExist(
        rootPath: urgentActusyoutubeplaylistpath,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Now test that the manually deleted urgent_actus Youtube playlist is
      // no longer displayed
      expect(find.text(urgentActusyoutubeplaylisttitle), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''Manually delete Youtube playlist directory with playlist expanded
           list closed after adding it manually.''',
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

      // *** Manually add the urgent_actus Youtube playlist directory
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}manually_added_playlist_dir",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Now test that the manually added urgent_actus Youtube playlist is
      // displayed

      // Tap the 'Toggle List' button to show the playlist list. If the
      // list is not opened, checking that a ListTile with the title of
      // the manually added playlist was added to the ListView will fail
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the manually added Youtube
      // playlist

      const String urgentActusyoutubeplaylisttitle = 'urgent_actus';

      // First, find the urgent_actus Youtube playlist ListTile Text widget
      final Finder addedYoutubePlaylistListTileTextWidgetFinder =
          find.text(urgentActusyoutubeplaylisttitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      final Finder addedYoutubePlaylistListTileWidgetFinder = find.ancestor(
        of: addedYoutubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist

      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: addedYoutubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Test that the audio of the added urgent_actus Youtube playlist
      // are listed

      String urgentActusyoutubeplaylistpath =
          '$kApplicationPathWindowsTest${path.separator}$urgentActusyoutubeplaylisttitle';

      List<String> urgentActusyoutubeplaylistmp3lst =
          DirUtil.listFileNamesInDir(
        directoryPath: urgentActusyoutubeplaylistpath,
        fileExtension: 'mp3',
      );

      for (String audioTitle in urgentActusyoutubeplaylistmp3lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Tap the 'Toggle List' button to hide the playlist list.
      // Since the urgent_actus Youtube playlist is selected, the
      // urgent_actus playlist audio list is be displayed in the
      // AudioPlayerView screen and then right popup menu is active.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Verify that the urgent_actus Youtube playlist audio list is
      // still displayed in the AudioPlayerView screen.
      for (String audioTitle in urgentActusyoutubeplaylistmp3lst) {
        audioTitle = audioTitle
            .replaceAll(RegExp(r'[\d\-]'), '')
            .replaceFirst(' .mp', '')
            .replaceFirst(' fois', '3 fois');
        final Finder audioListTileTextWidgetFinder = find.text(audioTitle);

        expect(audioListTileTextWidgetFinder, findsOneWidget);
      }

      // Now manually delete the urgent_actus playlist directory
      DirUtil.deleteDirAndSubDirsIfExist(
        rootPath: urgentActusyoutubeplaylistpath,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Now test that no audio list is displayed in the AudioPlayerView
      // screen since the selected urgent_actus Youtube playlist directory was
      // deleted.
      expect(find.text('Jancovici'), findsNothing);

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
    testWidgets(
        '''With Playlist list displayed, execute update playlist json file
           after deleting all files in app audio dir and verify audio menu
           state. Do the same after re-adding app audio dir files.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String s8AudioYoutubePlaylistTitle = 'S8 audio';

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

      // Tap the 'Toggle List' button to show the playlist list.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the S8 audio Youtube
      // playlist

      // First, find the S8 audio Youtube playlist ListTile Text widget
      final Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(s8AudioYoutubePlaylistTitle);

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

      // Now tap on the audio menu button to open the audio menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // Ensure that the audio menu items are enabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: false,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Now delete all the files in the app audio directory
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Tap once on the appbar leading popup menu button. First tap
      // closes the audio popup menu and the second tap opens the
      // leading popup menu
      await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
      await tester.pumpAndSettle();

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Verify that the audio menu button is disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now restore the app data in the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Ensure that the audio menu button is disabled since the
      // re-added playlist were no longer in the app settings sorted
      // playlist titles and so were added to the application being
      // deselected. This is due to the fact that any playlist added
      // by the update playlist JSON file fumctionality is deselected
      // in order that only one playlist is selected after the update.
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
    testWidgets(
        '''With Playlist list not displayed, execute update playlist json
           file after deleting all files in app audio dir and verify audio
           menu state. Do same after re-adding app audio dir files.''',
        (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String s8AudioYoutubePlaylistTitle = 'S8 audio';

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

      // Tap the 'Toggle List' button to show the playlist list.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the S8 audio Youtube
      // playlist

      // First, find the S8 audio Youtube playlist ListTile Text widget
      final Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(s8AudioYoutubePlaylistTitle);

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

      // Now tap the 'Toggle List' button to hide the playlist list so
      // that only the S8 audio Youtube playlist audio list is displayed
      // in the AudioPlayerView screen FAILS TEST
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now tap on the audio menu button to re-open the audio menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // Ensure that the audio menu items are enabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: false,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Now delete all the files in the app audio directory
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Tap once on the appbar leading popup menu button. First tap
      // closes the audio popup menu and the second tap opens the
      // leading popup menu
      await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
      await tester.pumpAndSettle();

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Verify that the audio menu button is disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now restore the app data in the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Ensure that the audio menu button is disabled since the
      // re-added playlist were no longer in the app settings sorted
      // playlist titles and so were added to the application being
      // deselected. This is due to the fact that any playlist added
      // by the update playlist JSON file fumctionality is deselected
      // in order that only one playlist is selected after the update.
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
    testWidgets(
        '''With Playlist list displayed and selected playlist empty, execute
           update playlist json file after deleting all files in app audio
           dir and verify audio menu state. Do same after re-adding app audio
           dir files.''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_empty_selected_playlist_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String s8AudioYoutubeEmptyPlaylistTitle = 'S8 audio';

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

      // Tap the 'Toggle List' button to show the playlist list.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the S8 audio Youtube
      // playlist

      // First, find the S8 audio Youtube playlist ListTile Text widget
      Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(s8AudioYoutubeEmptyPlaylistTitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      Finder youtubePlaylistListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Now find the Checkbox widget located in the playlist ListTile
      // and tap on it to select the playlist
      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: youtubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // Now tap on the audio menu button to open the audio menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // Ensure that the audio menu items are disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Now delete all the files in the app audio directory
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Tap once on the appbar leading popup menu button. First tap
      // closes the audio popup menu and the second tap opens the
      // leading popup menu
      await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
      await tester.pumpAndSettle();

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Verify that the audio menu button is disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now restore the app data in the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_empty_selected_playlist_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // First, find the S8 audio Youtube playlist ListTile Text widget
      youtubePlaylistListTileTextWidgetFinder =
          find.text(s8AudioYoutubeEmptyPlaylistTitle);

      // Then obtain the Youtube source playlist ListTile widget
      // enclosing the Text widget by finding its ancestor
      youtubePlaylistListTileWidgetFinder = find.ancestor(
        of: youtubePlaylistListTileTextWidgetFinder,
        matching: find.byType(ListTile),
      );

      // Select the S8 audio Youtube playlist
      await _tapPlaylistCheckboxIfNotAlreadyChecked(
        playlistListTileWidgetFinder: youtubePlaylistListTileWidgetFinder,
        widgetTester: tester,
      );

      // open the popup menu again
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // Ensure that the audio menu items are now enabled
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
    testWidgets('''With Playlist list not displayed and selected playlist empty,
           execute update playlist json file after deleting all files in
           app audio dir and verify audio menu state. Do same after re-adding
           app audio dir files.''', (WidgetTester tester) async {
      // Purge the test playlist directory if it exists so that the
      // playlist list is empty
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Copy the test initial audio data to the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_empty_selected_playlist_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      const String s8AudioYoutubeEmptyPlaylistTitle = 'S8 audio';

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

      // Tap the 'Toggle List' button to show the playlist list.
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Find the ListTile Playlist containing the S8 audio Youtube
      // playlist

      // First, find the S8 audio Youtube playlist ListTile Text widget
      final Finder youtubePlaylistListTileTextWidgetFinder =
          find.text(s8AudioYoutubeEmptyPlaylistTitle);

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

      // Now tap the 'Toggle List' button to hide the playlist list so
      // that only the S8 audio Youtube playlist audio list is displayed
      // in the AudioPlayerView screen FAILS TEST
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // Now tap on the audio menu button to re-open the audio menu
      await tester.tap(find.byKey(const Key('audio_popup_menu_button')));
      await tester.pumpAndSettle();

      // Ensure that the audio menu items are disabled
      await IntegrationTestUtil.verifyTwoFirstAudioMenuItemsState(
        tester: tester,
        isFirstAudioMenuItemDisabled: true,
        audioLearnAppViewType: AudioLearnAppViewType.playlistDownloadView,
      );

      // Now delete all the files in the app audio directory
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );

      // Tap once on the appbar leading popup menu button. First tap
      // closes the audio popup menu and the second tap opens the
      // leading popup menu
      await tester.tap(find.byKey(const Key('appBarLeadingPopupMenuWidget')));
      await tester.pumpAndSettle();

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Verify that the audio menu button is disabled
      IntegrationTestUtil.verifyWidgetIsDisabled(
        tester: tester,
        widgetKeyStr: 'audio_popup_menu_button',
      );

      // Now restore the app data in the app dir
      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}sort_and_filter_audio_dialog_empty_selected_playlist_widget_test",
        destinationRootPath: kApplicationPathWindowsTest,
      );

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Verify that the audio menu button is disabled
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
    testWidgets('''After copying playlist json file over the playlist json
                   file of an existing playlist. In the copied playlist json
                   file, the current or past playable audio is different. This
                   test demonstrates that after executing the update playlist
                   JSON file menu item, the current playlist audio displayed
                   in the audio player screen corresponds to the current audio
                   defined in the copied playlist JSON file.''',
        (WidgetTester tester) async {
      const String emptyPlaylistTitle = 'Empty'; // Youtube playlist
      const String youtubePlaylistTitle = 'S8 audio'; // Youtube playlist
      const String firstDownloadedAudioTitle =
          "La surpopulation mondiale par Jancovici et Barrau";
      const String secondDownloadedAudioTitle =
          "Jancovici m'explique l’importance des ordres de grandeur face au changement climatique";

      await IntegrationTestUtil.initializeApplicationAndSelectPlaylist(
        tester: tester,
        savedTestDataDirName: 'update_playlist_json_file',
        selectedPlaylistTitle: emptyPlaylistTitle,
      );

      // Select the 'S8 audio' playlist

      await IntegrationTestUtil.selectPlaylist(
        tester: tester,
        playlistToSelectTitle: youtubePlaylistTitle,
      );

      // Now tap on playlist download view playlist button to close the
      // playlist list so that all the 'S8 audio' audio are displayed
      await tester.tap(find.byKey(const Key('playlist_toggle_button')));
      await tester.pumpAndSettle();

      // First, get the ListTile Text widget finder of the audio to be
      // selected and tap on it. This switches to the AudioPlayerView
      // and sets the playlist current or past playable audio index to 0
      await tester.tap(find.text(firstDownloadedAudioTitle));
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify the displayed audio title (La surpopulation mondiale par
      // Jancovici et Barrau)

      Finder audioPlayerViewAudioTitleFinder =
          find.byKey(const Key('audioPlayerViewCurrentAudioTitle'));
      String audioTitleWithDurationString =
          tester.widget<Text>(audioPlayerViewAudioTitleFinder).data!;

      String expectedAudioAndDurationTitle = "$firstDownloadedAudioTitle\n7:38";

      // Now, manually copy the 'S8 audio' Youtube playlist directory,
      // but first delete the dir, otherwise the playlist JSON file
      // will not be updated.

      String playlistS8audioDir =
          "$kApplicationPathWindowsTest${path.separator}S8 audio";

      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: playlistS8audioDir,
      );

      DirUtil.copyFilesFromDirAndSubDirsToDirectory(
        sourceRootPath:
            "$kDownloadAppTestSavedDataDir${path.separator}update_playlist_json_file${path.separator}S8 audio",
        destinationRootPath: playlistS8audioDir,
      );

      // Then return to playlist download view in order to execute
      // the playlist JSON files update
      Finder appScreenNavigationButton =
          find.byKey(const ValueKey('playlistDownloadViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await tester.pumpAndSettle();

      // *** Execute Updating playlist JSON file menu item
      await IntegrationTestUtil.executeUpdatePlaylistJsonFiles(
        tester: tester,
      );

      // Go to audio player view in order to verify the current playable
      // audio of the selected Youtube playlist
      appScreenNavigationButton =
          find.byKey(const ValueKey('audioPlayerViewIconButton'));
      await tester.tap(appScreenNavigationButton);
      await IntegrationTestUtil.pumpAndSettleDueToAudioPlayers(
        tester: tester,
      );

      // Verify the displayed audio title (Jancovici m'explique l’importance
      // des ordres de grandeur face au changement climatique)

      audioPlayerViewAudioTitleFinder =
          find.byKey(const Key('audioPlayerViewCurrentAudioTitle'));
      audioTitleWithDurationString =
          tester.widget<Text>(audioPlayerViewAudioTitleFinder).data!;

      expectedAudioAndDurationTitle = "$secondDownloadedAudioTitle\n5:11";

      expect(
        audioTitleWithDurationString,
        expectedAudioAndDurationTitle,
        reason:
            "The actual audio title and duration $audioTitleWithDurationString displayed in the AudioPlayerView screen isn't the expected value $expectedAudioAndDurationTitle.",
      );

      // Purge the test playlist directory so that the created test
      // files are not uploaded to GitHub
      DirUtil.deleteFilesInDirAndSubDirs(
        rootPath: kApplicationPathWindowsTest,
      );
    });
  });
}



Future<void> _checkWarningDialog({
  required WidgetTester tester,
  required String playlistTitle,
  required bool isMusicQuality,
  required PlaylistType playlistType,
  required String positionStr,
  bool findLast = false,
  bool isWarningConfirming = false,
}) async {
  // Ensure the warning dialog is shown
  expect(find.byType(WarningMessageDisplayDialog), findsOneWidget);

  // Check the value of the warning dialog title

  if (isWarningConfirming) {
    if (!findLast) {
      Text warningDialogTitle =
          tester.widget(find.byKey(const Key('warningDialogTitle')));
      expect(warningDialogTitle.data, 'CONFIRMATION');
    } else {
      // If findLast is true, the warning dialog title should be empty
      Text warningDialogTitle =
          tester.widget(find.byKey(const Key('warningDialogTitle')).last);
      expect(warningDialogTitle.data, 'CONFIRMATION');
    }
  } else {
    if (!findLast) {
      Text warningDialogTitle =
          tester.widget(find.byKey(const Key('warningDialogTitle')));
      expect(warningDialogTitle.data, 'WARNING');
    } else {
      // If findLast is true, the warning dialog title should be empty
      Text warningDialogTitle =
          tester.widget(find.byKey(const Key('warningDialogTitle')).last);
      expect(warningDialogTitle.data, 'WARNING');
    }
  }

  // Check the value of the warning dialog message
  Text warningDialogMessage;

  if (!findLast) {
    warningDialogMessage =
        tester.widget(find.byKey(const Key('warningDialogMessage')));
  } else {
    // If findLast is true, the warning dialog message should be the last one
    warningDialogMessage =
        tester.widget(find.byKey(const Key('warningDialogMessage')).last);
  }

  if (playlistType == PlaylistType.youtube) {
    expect(warningDialogMessage.data,
        'Youtube playlist "$playlistTitle" of ${isMusicQuality ? 'musical' : 'spoken'} quality added at the end of the playlist list at position $positionStr.');
  } else {
    expect(warningDialogMessage.data,
        'Local playlist "$playlistTitle" of ${isMusicQuality ? 'musical' : 'spoken'} quality added at the end of the playlist list at position $positionStr.');
  }

  // Close the warning dialog by tapping on the Ok button
  if (!findLast) {
    await tester.tap(find.byKey(const Key('warningDialogOkButton')));
    await tester.pumpAndSettle();
  } else {
    // If findLast is true, close the warning dialog by tapping on the last Ok button
    await tester.tap(find.byKey(const Key('warningDialogOkButton')).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('warningDialogOkButton')));
    await tester.pumpAndSettle();
  }
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

Future<Finder> _ensurePlaylistCheckboxIsNotChecked({
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

  // Check that the checkbox is not checked
  expect((checkbox.value == null || !checkbox.value!), true);

  return youtubePlaylistListTileCheckboxWidgetFinder;
}

Future<void> _findThenSelectAndTestListTileCheckbox({
  required WidgetTester tester,
  required String itemTextStr,
}) async {
  Finder listItemTileFinder = find.widgetWithText(ListTile, itemTextStr);

  // Find the Checkbox widget inside the ListTile
  Finder checkboxFinder = find.descendant(
    of: listItemTileFinder,
    matching: find.byType(Checkbox),
  );

  // Assert that the checkbox is not selected
  expect(tester.widget<Checkbox>(checkboxFinder).value, false);

  // now tap the item checkbox
  await tester.tap(find.descendant(
    of: listItemTileFinder,
    matching: find.byWidgetPredicate((widget) => widget is Checkbox),
  ));
  await tester.pump();

  // Find the Checkbox widget inside the ListTile

  listItemTileFinder = find.widgetWithText(ListTile, itemTextStr);

  checkboxFinder = find.descendant(
    of: listItemTileFinder,
    matching: find.byType(Checkbox),
  );

  expect(tester.widget<Checkbox>(checkboxFinder).value, true);
}

/// Verifies the elements of the audio info dialog.
///
/// {tester} is the WidgetTester
///
/// {audioTitle} is the title of the audio the method verifies
/// the elements of the audio info dialog
///
/// {playlistEnclosingAudioTitle} is the title of the playlist
/// enclosing the audio
///
/// {copiedAudioSourcePlaylistTitle} is the title of the playlist
/// from which the audio was copied
///
/// {copiedAudioTargetPlaylistTitle} is the title of the playlist
/// to which the audio was copied
///
/// {movedAudioSourcePlaylistTitle} is the title of the playlist
/// from which the audio was moved
///
/// {movedAudioTargetPlaylistTitle} is the title of the playlist
/// to which the audio was moved
Future<void> _verifyAudioInfoDialogElements({
  required WidgetTester tester,
  required String audioTitle,
  required String playlistEnclosingAudioTitle,
  required String copiedAudioSourcePlaylistTitle,
  required String copiedAudioTargetPlaylistTitle,
  required String movedAudioSourcePlaylistTitle,
  required String movedAudioTargetPlaylistTitle,
}) async {
  // Find the target ListTile Playlist containing the audio copied
  // from the source playlist

  // First, find the Playlist ListTile Text widget
  final Finder targetPlaylistListTileTextWidgetFinder =
      find.text(playlistEnclosingAudioTitle);

  // Then obtain the Playlist ListTile widget enclosing the Text widget
  // by finding its ancestor
  final Finder targetPlaylistListTileWidgetFinder = find.ancestor(
    of: targetPlaylistListTileTextWidgetFinder,
    matching: find.byType(ListTile),
  );

  // Now find the Checkbox widget located in the Playlist ListTile
  // and tap on it to select the playlist
  final Finder targetPlaylistListTileCheckboxWidgetFinder = find.descendant(
    of: targetPlaylistListTileWidgetFinder,
    matching: find.byType(Checkbox),
  );

  final checkboxWidget =
      tester.widget<Checkbox>(targetPlaylistListTileCheckboxWidgetFinder);

  if (!checkboxWidget.value!) {
    await tester.tap(targetPlaylistListTileCheckboxWidgetFinder);
    await tester.pumpAndSettle();
  }

  // Now we want to tap the popup menu of the Audio ListTile
  // "audio learn test short video one"

  // First, find the Audio sublist ListTile Text widget
  final Finder targetAudioListTileTextWidgetFinder = find.text(audioTitle);

  // Then obtain the Audio ListTile widget enclosing the Text widget by
  // finding its ancestor
  final Finder targetAudioListTileWidgetFinder = find.ancestor(
    of: targetAudioListTileTextWidgetFinder,
    matching: find.byType(ListTile),
  );

  // Now find the leading menu icon button of the Audio ListTile and tap
  // on it
  final Finder targetAudioListTileLeadingMenuIconButton = find.descendant(
    of: targetAudioListTileWidgetFinder,
    matching: find.byIcon(Icons.menu),
  );

  // Tap the leading menu icon button to open the popup menu
  await tester.tap(targetAudioListTileLeadingMenuIconButton);
  await tester.pumpAndSettle();

  // Now find the popup menu item and tap on it
  Finder popupDisplayAudioInfoMenuItemFinder =
      find.byKey(const Key("popup_menu_display_audio_info"));

  await tester.tap(popupDisplayAudioInfoMenuItemFinder);
  await tester.pumpAndSettle();

  // Now verifying the display audio info audio copied dialog
  // elements

  // Verify the audio channel name

  Text youtubeChannelTextWidget =
      tester.widget<Text>(find.byKey(const Key('youtubeChannelKey')));

  expect(youtubeChannelTextWidget.data, "Jean-Pierre Schnyder");

  // Verify the enclosing playlist title of the copied audio

  Text enclosingPlaylistTitleTextWidget =
      tester.widget<Text>(find.byKey(const Key('enclosingPlaylistTitleKey')));

  expect(enclosingPlaylistTitleTextWidget.data, playlistEnclosingAudioTitle);

  // Verify the copied from playlist title of the copied audio

  Text copiedFromPlaylistTitleTextWidget =
      tester.widget<Text>(find.byKey(const Key('copiedFromPlaylistTitleKey')));

  expect(
      copiedFromPlaylistTitleTextWidget.data, copiedAudioSourcePlaylistTitle);

  // Verify the copied to playlist title of the copied audio

  Text copiedToPlaylistTitleTextWidget =
      tester.widget<Text>(find.byKey(const Key('copiedToPlaylistTitleKey')));

  expect(copiedToPlaylistTitleTextWidget.data, copiedAudioTargetPlaylistTitle);

  // Verify the moved from playlist title of the copied audio

  Text movedFromPlaylistTitleTextWidget =
      tester.widget<Text>(find.byKey(const Key('movedFromPlaylistTitleKey')));

  expect(movedFromPlaylistTitleTextWidget.data, movedAudioSourcePlaylistTitle);

  // Verify the moved to playlist title of the copied audio

  Text movedToPlaylistTitleTextWidget =
      tester.widget<Text>(find.byKey(const Key('movedToPlaylistTitleKey')));

  expect(movedToPlaylistTitleTextWidget.data, movedAudioTargetPlaylistTitle);

  // Now find the close button of the audio info dialog
  // and tap on it
  await tester.tap(find.byKey(const Key('audio_info_close_button_key')));
  await tester.pumpAndSettle();
}
