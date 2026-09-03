import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class YtDlpDownloadResult {
  final bool success;
  final String? downloadedFilePath;
  final String output;

  const YtDlpDownloadResult({
    required this.success,
    required this.downloadedFilePath,
    required this.output,
  });
}

class YtDlpPlaylistVideo {
  final String id;
  final String title;
  final String url;

  const YtDlpPlaylistVideo({
    required this.id,
    required this.title,
    required this.url,
  });
}

class YtDlpService {
  static const MethodChannel _androidChannel =
      MethodChannel('audiolearn/yt_dlp');

  static String get executablePath {
    // yt-dlp.exe is located in the directory which contains audiolearn.exe
    return "C:${Platform.pathSeparator}Program Files${Platform.pathSeparator}audiolearn${Platform.pathSeparator}yt-dlp.exe";
  }

  static Future<List<YtDlpPlaylistVideo>> getPlaylistVideos({
    required String playlistUrl,
  }) async {
    if (Platform.isWindows) {
      return _getPlaylistVideosWindows(
        playlistUrl: playlistUrl,
      );
    }

    if (Platform.isAndroid) {
      return _getPlaylistVideosAndroid(
        playlistUrl: playlistUrl,
      );
    }

    throw UnsupportedError(
      'yt-dlp is not supported on this platform.',
    );
  }

  static Future<List<YtDlpPlaylistVideo>> _getPlaylistVideosWindows({
    required String playlistUrl,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'This yt-dlp implementation currently supports Windows only.',
      );
    }

    final List<String> arguments = [
      '--flat-playlist',
      '--dump-single-json',
      '--no-warnings',
      playlistUrl,
    ];

    final ProcessResult result = await Process.run(
      executablePath,
      arguments,
      runInShell: false,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Unable to retrieve YouTube playlist with yt-dlp.\n'
        '${result.stderr}',
      );
    }

    final dynamic decoded = jsonDecode(result.stdout.toString());

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid playlist JSON returned by yt-dlp.',
      );
    }

    final dynamic entriesValue = decoded['entries'];

    if (entriesValue is! List) {
      return [];
    }

    final List<YtDlpPlaylistVideo> videos = [];

    for (final dynamic entry in entriesValue) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final String id = entry['id']?.toString() ?? '';

      if (id.isEmpty) {
        continue;
      }

      final String title = entry['title']?.toString() ?? '';
      final String url = 'https://www.youtube.com/watch?v=$id';

      videos.add(
        YtDlpPlaylistVideo(
          id: id,
          title: title,
          url: url,
        ),
      );
    }

    return videos;
  }

  static Future<List<YtDlpPlaylistVideo>> _getPlaylistVideosAndroid({
    required String playlistUrl,
  }) async {
    try {
      final List<dynamic>? result =
          await _androidChannel.invokeMethod<List<dynamic>>(
        'getPlaylistVideos',
        {
          'playlistUrl': playlistUrl,
        },
      );

      if (result == null) {
        return [];
      }

      final List<YtDlpPlaylistVideo> videos = [];

      for (final dynamic item in result) {
        if (item is! Map) {
          continue;
        }

        final String id = item['id']?.toString() ?? '';

        if (id.isEmpty) {
          continue;
        }

        final String title = item['title']?.toString() ?? '';
        final String url =
            item['url']?.toString() ?? 'https://www.youtube.com/watch?v=$id';

        videos.add(
          YtDlpPlaylistVideo(
            id: id,
            title: title,
            url: url,
          ),
        );
      }

      return videos;
    } on PlatformException catch (e) {
      throw Exception(
        'Unable to retrieve YouTube playlist on Android.\n'
        'Code: ${e.code}\n'
        'Message: ${e.message}\n'
        'Details: ${e.details}',
      );
    }
  }

  /// Downloads the best available audio stream without converting it.
  ///
  /// On Windows, [ytDlpExecutablePath] can be either "yt-dlp"
  /// when yt-dlp is available in PATH, or an absolute path to yt-dlp.exe.
  static Future<YtDlpDownloadResult> downloadAudio({
    required String videoUrl,
    required String targetDirectory,
    required String temporaryBaseFileName,
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isWindows) {
      return _downloadAudioWindows(
        videoUrl: videoUrl,
        targetDirectory: targetDirectory,
        temporaryBaseFileName: temporaryBaseFileName,
        onProgress: onProgress,
      );
    }

    if (Platform.isAndroid) {
      return _downloadAudioAndroid(
        videoUrl: videoUrl,
        targetDirectory: targetDirectory,
        temporaryBaseFileName: temporaryBaseFileName,
        onProgress: onProgress,
      );
    }

    throw UnsupportedError(
      'yt-dlp is not supported on this platform.',
    );
  }

  static Future<YtDlpDownloadResult> _downloadAudioWindows({
    required String videoUrl,
    required String targetDirectory,
    required String temporaryBaseFileName,
    void Function(double progress)? onProgress,
  }) async {
    final String outputTemplate =
        '$targetDirectory${Platform.pathSeparator}$temporaryBaseFileName.%(ext)s';
    final List<String> arguments = [
      '--newline',
      '--no-playlist',
      // Download the best available audio-only stream.
      '-f',
      'bestaudio/best',
      '--output',
      outputTemplate,
      videoUrl,
    ];

    final Process process = await Process.start(
      executablePath,
      arguments,
      runInShell: false,
    );

    final StringBuffer completeOutput = StringBuffer();
    String? downloadedFilePath;
    final RegExp progressRegExp = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%');
    final RegExp destinationRegExp =
        RegExp(r'\[download\] Destination:\s+(.+)$');

    final StreamSubscription<dynamic> stdoutSubscription = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(
      (String line) {
        completeOutput.writeln(line);
        final Match? progressMatch = progressRegExp.firstMatch(line);

        if (progressMatch != null) {
          final double? progress =
              double.tryParse(progressMatch.group(1) ?? '');

          if (progress != null) {
            onProgress?.call(progress);
          }
        }

        final Match? destinationMatch = destinationRegExp.firstMatch(line);

        if (destinationMatch != null) {
          downloadedFilePath = destinationMatch.group(1)?.trim();
        }
      },
    );

    final StreamSubscription<dynamic> stderrSubscription = process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(
      (String line) {
        completeOutput.writeln(line);
      },
    );

    final int exitCode = await process.exitCode;

    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();

    if (exitCode != 0) {
      return YtDlpDownloadResult(
        success: false,
        downloadedFilePath: null,
        output: completeOutput.toString(),
      );
    }

    // yt-dlp does not always print "Destination" depending on the
    // selected format, therefore locate the generated file if needed.
    downloadedFilePath ??= _findDownloadedFile(
      targetDirectory: targetDirectory,
      temporaryBaseFileName: temporaryBaseFileName,
    );

    return YtDlpDownloadResult(
      success: downloadedFilePath != null,
      downloadedFilePath: downloadedFilePath,
      output: completeOutput.toString(),
    );
  }

  static Future<YtDlpDownloadResult> _downloadAudioAndroid({
    required String videoUrl,
    required String targetDirectory,
    required String temporaryBaseFileName,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final Map<dynamic, dynamic>? response =
          await _androidChannel.invokeMethod<Map<dynamic, dynamic>>(
        'downloadAudio',
        {
          'videoUrl': videoUrl,
          'targetDirectory': targetDirectory,
          'temporaryBaseFileName': temporaryBaseFileName,
        },
      );

      if (response == null) {
        return const YtDlpDownloadResult(
          success: false,
          downloadedFilePath: null,
          output: 'No response received from Android yt-dlp.',
        );
      }

      return YtDlpDownloadResult(
        success: response['success'] == true,
        downloadedFilePath: response['downloadedFilePath'] as String?,
        output: response['output']?.toString() ?? '',
      );
    } catch (e) {
      return YtDlpDownloadResult(
        success: false,
        downloadedFilePath: null,
        output: e.toString(),
      );
    }
  }

  static String? _findDownloadedFile({
    required String targetDirectory,
    required String temporaryBaseFileName,
  }) {
    final Directory directory = Directory(targetDirectory);

    if (!directory.existsSync()) {
      return null;
    }

    final List<FileSystemEntity> matchingFiles = directory
        .listSync()
        .where(
          (FileSystemEntity entity) =>
              entity is File &&
              entity.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('$temporaryBaseFileName.'),
        )
        .toList();

    if (matchingFiles.isEmpty) {
      return null;
    }

    return matchingFiles.first.path;
  }
}
