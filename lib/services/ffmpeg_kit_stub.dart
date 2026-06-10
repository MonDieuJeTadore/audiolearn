// Stub for Windows/Desktop - replaces ffmpeg_kit_flutter_new
// These classes are never called on Windows (Platform.isAndroid guards all usage)

class FFmpegKit {
  static Future<_FakeSession> execute(String cmd) async => _FakeSession();
}

class FFprobeKit {
  static Future<_FakeProbeSession> getMediaInformation(String path) async =>
      _FakeProbeSession();

  static void getMediaInformationAsync(
    String path,
    Function(dynamic) callback,
  ) {
    callback(_FakeProbeSession());
  }
}

class ReturnCode {
  static bool isSuccess(dynamic rc) => false;
}

class FFmpegSession {
  Future<dynamic> getReturnCode() async => null;
  Future<String?> getAllLogsAsString() async => null;
}

class _FakeSession {
  Future<dynamic> getReturnCode() async => null;
  Future<String?> getAllLogsAsString() async => null;
}

class _FakeProbeSession {
  dynamic getMediaInformation() => null;
}
