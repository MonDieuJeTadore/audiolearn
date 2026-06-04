import 'dart:convert';
import 'dart:io';

import '../constants.dart';
import '../models/audio.dart';
import '../models/multi_audio_comments.dart';
import '../models/playlist.dart';
import '../models/comment.dart';
import '../models/picture.dart';
import '../models/sort_filter_parameters.dart';
import '../utils/dir_util.dart';
import 'settings_data_service.dart';

typedef FromJsonFunction<T> = T Function(Map<String, dynamic> jsonDataMap);
typedef ToJsonFunction<T> = Map<String, dynamic> Function(T model);

class ClassNotContainedInJsonFileException implements Exception {
  final String _className;
  final String _jsonFilePathName;
  final StackTrace _stackTrace;

  ClassNotContainedInJsonFileException({
    required String className,
    required String jsonFilePathName,
    StackTrace? stackTrace,
  })  : _className = className,
        _jsonFilePathName = jsonFilePathName,
        _stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() {
    return ('Class $_className not stored in $_jsonFilePathName file.\nStack Trace:\n$_stackTrace');
  }
}

class ClassNotSupportedByToJsonDataServiceException implements Exception {
  final String _className;
  final StackTrace _stackTrace;

  ClassNotSupportedByToJsonDataServiceException({
    required String className,
    StackTrace? stackTrace,
  })  : _className = className,
        _stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() {
    return ('Class $_className has no entry in JsonDataService._toJsonFunctionsMap.\nStack Trace:\n$_stackTrace');
  }
}

class ClassNotSupportedByFromJsonDataServiceException implements Exception {
  final String _className;
  final StackTrace _stackTrace;

  ClassNotSupportedByFromJsonDataServiceException({
    required String className,
    StackTrace? stackTrace,
  })  : _className = className,
        _stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() {
    return ('Class $_className has no entry in JsonDataService._fromJsonFunctionsMap.\nStack Trace:\n$_stackTrace');
  }
}

/// Exception thrown when there is a problem in the format of the json
/// file, such as a missing comma, an extra comma, a missing closing
/// bracket, etc.
///
/// This exception is called by AudioDownloadVM.loadExistingPlaylists()
/// and by _AudioExtractorScreenState._loadMultipleAudios().
class ProblemInJsonFileException implements Exception {
  final String _jsonPathFileName;

  ProblemInJsonFileException({
    required String jsonPathFileName,
  }) : _jsonPathFileName = jsonPathFileName;

  @override
  String toString() {
    return (_jsonPathFileName);
  }
}

class JsonDataService {
  // typedef FromJsonFunction<T> = T Function(Map<String, dynamic> jsonDataMap);
  static final Map<Type, FromJsonFunction> _fromJsonFunctionsMap = {
    Audio: (jsonDataMap) => Audio.fromJson(jsonDataMap),
    Playlist: (jsonDataMap) => Playlist.fromJson(jsonDataMap),
    SortingItem: (jsonDataMap) => SortingItem.fromJson(jsonDataMap),
    AudioSortFilterParameters: (jsonDataMap) =>
        AudioSortFilterParameters.fromJson(jsonDataMap),
    Comment: (jsonDataMap) => Comment.fromJson(jsonDataMap),
    Picture: (jsonDataMap) => Picture.fromJson(jsonDataMap),
    MultiAudioComments: (jsonDataMap) =>
        MultiAudioComments.fromJson(jsonDataMap),
  };

  // typedef ToJsonFunction<T> = Map<String, dynamic> Function(T model);
  static final Map<Type, ToJsonFunction> _toJsonFunctionsMap = {
    Audio: (model) => model.toJson(),
    Playlist: (model) => model.toJson(),
    SortingItem: (sortingItem) => sortingItem.toJson(),
    AudioSortFilterParameters: (audioSortFilterParameters) =>
        audioSortFilterParameters.toJson(),
    Comment: (model) => model.toJson(),
    Picture: (model) => model.toJson(),
    MultiAudioComments: (model) => model.toJson(),
  };

  static void saveToFile({
    required dynamic model,
    required String path,
  }) {
    final String jsonStr = encodeJson(model);
    File(path).writeAsStringSync(jsonStr);
  }

  static dynamic loadFromFile({
    required String jsonPathFileName,
    required Type type,
    bool isTest = false,
  }) {
    if (File(jsonPathFileName).existsSync()) {
      final String jsonStr = File(jsonPathFileName).readAsStringSync();

      try {
        return decodeJson(jsonStr, type);
      } on FormatException catch (e) {
        // Calculate line number from the character offset
        final offset = e.offset;
        if (offset != null) {
          final String textBeforeOffset = jsonStr.substring(0, offset);
          final int lineNumber = '\n'.allMatches(textBeforeOffset).length + 1;
          final int lastNewlinePos = textBeforeOffset.lastIndexOf('\n');
          final int columnNumber = offset - lastNewlinePos; // 1-based column
          final String unexpectedChar =
              offset < jsonStr.length ? jsonStr[offset] : 'EOF';

          SettingsDataService settingsDataService = SettingsDataService();

          settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                '${DirUtil.getApplicationPath(isTest: isTest)}${Platform.pathSeparator}$kSettingsFileName',
          );
          Language language = settingsDataService.get(
            settingType: SettingType.language,
            settingSubType: SettingType.language,
          );

          String playlistName = DirUtil.getFileNameWithoutJsonExtension(
            jsonFileName: DirUtil.getFileNameFromPathFileName(
              pathFileName: jsonPathFileName,
            ),
          );
          String message = '';

          if (language == Language.french) {
            message =
                "Erreur de format JSON dans $jsonPathFileName à la ligne ${lineNumber - 1} ou $lineNumber, colonne $columnNumber, caractère inattendu \"$unexpectedChar\".\n\nMessage de l'exception: ${e.message}.\n\nEssayez de trouver le probléme afin de le corriger avant de réexéuter l'opération.\n\nEnsuite, exécutez le menu \"Mettre à jour les fichiers playlist JSON ...\" afin de restaurer la playlist \"$playlistName\".";
          } else {
            message =
                "JSON format error in $jsonPathFileName at line ${lineNumber - 1} or $lineNumber, column $columnNumber, unexpected character \"$unexpectedChar\".\n\nException message: ${e.message}.\n\nTry finding the problem in order to correct it before executing again the operation.\n\nThen execute the \"Update Playlist JSON Files ...\" menu in order to restore the playlist \"$playlistName\".";
          }

          throw ProblemInJsonFileException(
            jsonPathFileName: message,
          );
        }
        // throw ProblemInJsonFileException(
        //   jsonPathFileName:
        //       'JSON format error in $jsonPathFileName: ${e.message}',
        // );
      } on StateError catch (_) {
        throw ProblemInJsonFileException(
          jsonPathFileName: jsonPathFileName,
        );
      } catch (e) {
        throw ClassNotContainedInJsonFileException(
          className: type.toString(),
          jsonFilePathName: jsonPathFileName,
        );
      }
    } else {
      return null;
    }
  }

  static String encodeJson(dynamic data) {
    if (data is List) {
      throw Exception(
          "encodeJson() does not support encoding list's. Use encodeJsonList() instead.");
    } else {
      final type = data.runtimeType;
      final toJsonFunction = _toJsonFunctionsMap[type];
      if (toJsonFunction != null) {
        return jsonEncode(toJsonFunction(data));
      }
    }

    return '';
  }

  static dynamic decodeJson(
    String jsonString,
    Type type,
  ) {
    final fromJsonFunction = _fromJsonFunctionsMap[type];

    if (fromJsonFunction != null) {
      final jsonData = jsonDecode(jsonString);
      if (jsonData is List) {
        throw Exception(
            "decodeJson() does not support decoding list's. Use decodeJsonList() instead.");
      } else {
        return fromJsonFunction(jsonData);
      }
    }

    return null;
  }

  static void saveListToFile({
    required String jsonPathFileName,
    required dynamic data,
  }) {
    String jsonStr = encodeJsonList(data);
    File(jsonPathFileName).writeAsStringSync(jsonStr);
  }

  /// If the json file exists, the list of typed objects it contains is
  /// returned, else, an empty list is returned.
  static List<T> loadListFromFile<T>({
    required String jsonPathFileName,
    required Type type,
    bool isTest = false,
  }) {
    if (File(jsonPathFileName).existsSync()) {
      String jsonStr = File(jsonPathFileName).readAsStringSync();

      if (jsonStr.isEmpty) {
        return [];
      }

      try {
        return decodeJsonList(jsonStr, type);
      } on FormatException catch (e) {
        final offset = e.offset;
        if (offset != null) {
          final String textBeforeOffset = jsonStr.substring(0, offset);
          final int lineNumber = '\n'.allMatches(textBeforeOffset).length + 1;
          final int lastNewlinePos = textBeforeOffset.lastIndexOf('\n');
          final int columnNumber = offset - lastNewlinePos; // 1-based column
          final String unexpectedChar =
              offset < jsonStr.length ? jsonStr[offset] : 'EOF';

          SettingsDataService settingsDataService = SettingsDataService();

          settingsDataService.loadSettingsFromFile(
            settingsJsonPathFileName:
                '${DirUtil.getApplicationPath(isTest: isTest)}${Platform.pathSeparator}$kSettingsFileName',
          );
          Language language = settingsDataService.get(
            settingType: SettingType.language,
            settingSubType: SettingType.language,
          );

          String message = '';

          if (language == Language.french) {
            message =
                "Erreur de format JSON dans $jsonPathFileName à la ligne ${lineNumber - 1} ou $lineNumber, colonne $columnNumber, caractère inattendu \"$unexpectedChar\".\n\nMessage de l'exception: ${e.message}";
          } else {
            message =
                "JSON format error in $jsonPathFileName at line ${lineNumber - 1} or $lineNumber, column $columnNumber, unexpected character \"$unexpectedChar\".\n\nException message: ${e.message}";
          }

          throw ProblemInJsonFileException(
            jsonPathFileName: message,
          );
        }
        throw ProblemInJsonFileException(
          jsonPathFileName:
              'JSON format error in $jsonPathFileName: ${e.message}',
        );
      } on StateError {
        throw ClassNotContainedInJsonFileException(
          className: type.toString(),
          jsonFilePathName: jsonPathFileName,
        );
      }
    } else {
      return [];
    }
  }

  static String encodeJsonList(dynamic data) {
    if (data is List) {
      if (data.isNotEmpty) {
        final type = data.first.runtimeType;
        final toJsonFunction = _toJsonFunctionsMap[type];
        if (toJsonFunction != null) {
          return jsonEncode(data.map((e) => toJsonFunction(e)).toList());
        } else {
          throw ClassNotSupportedByToJsonDataServiceException(
            className: type.toString(),
          );
        }
      }
    } else {
      throw Exception(
          "encodeJsonList() only supports encoding list's. Use encodeJson() instead.");
    }

    return '';
  }

  static List<T> decodeJsonList<T>(
    String jsonString,
    Type type,
  ) {
    final fromJsonFunction = _fromJsonFunctionsMap[type];

    if (fromJsonFunction != null) {
      final jsonData = jsonDecode(jsonString);
      if (jsonData is List) {
        if (jsonData.isNotEmpty) {
          final list = jsonData.map((e) => fromJsonFunction(e)).toList();
          return list.cast<T>(); // Cast the list to the desired type
        } else {
          return <T>[]; // Return an empty list of the desired type
        }
      } else {
        throw Exception(
            "decodeJsonList() only supports decoding list's. Use decodeJson() instead.");
      }
    } else {
      throw ClassNotSupportedByFromJsonDataServiceException(
        className: type.toString(),
      );
    }
  }

  /// print jsonStr in formatted way
  static void printJsonString({
    required String methodName,
    required String jsonStr,
  }) {
    String prettyJson =
        const JsonEncoder.withIndent('  ').convert(json.decode(jsonStr));
    // ignore: avoid_print
    print('$methodName:\n$prettyJson');
  }
}
