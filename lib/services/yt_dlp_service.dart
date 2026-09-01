import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class YtDlpService {
  static String get executablePath {
    // yt-dlp.exe is located in the directory which contains audiolearn.exe
    return "C:${Platform.pathSeparator}Program Files${Platform.pathSeparator}audiolearn${Platform.pathSeparator}yt-dlp.exe";
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
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'This yt-dlp implementation currently supports Windows only.',
      );
    }

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
