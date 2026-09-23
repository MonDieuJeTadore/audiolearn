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

class YtDlpProgress {
  final double percent;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;

  const YtDlpProgress({
    required this.percent,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
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
    void Function(YtDlpProgress progress)? onProgress,
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
    void Function(YtDlpProgress progress)? onProgress,
  }) async {
    final String outputTemplate =
        '$targetDirectory${Platform.pathSeparator}$temporaryBaseFileName.%(ext)s';
    final List<String> arguments = [
      '--newline',
      '--progress-template',
      'download:PROGRESS|%(progress._percent_str)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s',
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
    final RegExp destinationRegExp =
        RegExp(r'\[download\] Destination:\s+(.+)$');

    final StreamSubscription<dynamic> stdoutSubscription = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(
      (String line) {
        completeOutput.writeln(line);
        if (line.startsWith('PROGRESS|')) {
          final List<String> parts = line.split('|');

          if (parts.length >= 6) {
            final double percent = double.tryParse(
                  parts[1].replaceAll('%', '').trim(),
                ) ??
                0.0;

            final int downloadedBytes = int.tryParse(parts[2].trim()) ?? 0;

            final int? totalBytes = int.tryParse(parts[3].trim());

            final int? totalBytesEstimate = int.tryParse(parts[4].trim());

            final double speedBytesPerSecond =
                double.tryParse(parts[5].trim()) ?? 0.0;

            onProgress?.call(
              YtDlpProgress(
                percent: percent,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes ?? totalBytesEstimate ?? 0,
                speedBytesPerSecond: speedBytesPerSecond,
              ),
            );
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
    void Function(YtDlpProgress progress)? onProgress,
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
        downloadedFilePath: response['downloadedFilePath']?.toString(),
        output: response['output']?.toString() ?? '',
      );
    } on PlatformException catch (e) {
      return YtDlpDownloadResult(
        success: false,
        downloadedFilePath: null,
        output: '${e.code}: ${e.message}\n${e.details ?? ''}',
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
