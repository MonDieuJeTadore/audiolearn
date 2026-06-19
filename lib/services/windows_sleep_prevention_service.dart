import 'dart:ffi';
import 'dart:io';

/// Windows API constants for SetThreadExecutionState
const int _esContinuous = 0x80000000;
const int _esSystemRequired = 0x00000001;

typedef _SetThreadExecutionStateNative = Uint32 Function(Uint32 esFlags);
typedef _SetThreadExecutionStateDart = int Function(int esFlags);

/// Service to prevent Windows from sleeping during audio playback.
/// Uses SetThreadExecutionState Win32 API — no registry/settings changes needed.
/// Windows automatically restores normal sleep behavior when the flag is cleared.
class WindowsSleepPreventionService {
  static _SetThreadExecutionStateDart? _setThreadExecutionState;
  static bool _isInitialized = false;

  static void _initialize() {
    if (_isInitialized || !Platform.isWindows) return;

    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      _setThreadExecutionState = kernel32
          .lookupFunction<_SetThreadExecutionStateNative,
              _SetThreadExecutionStateDart>('SetThreadExecutionState');
      _isInitialized = true;
    } catch (e) {
      // Silently fail — sleep prevention is a nice-to-have
    }
  }

  /// Call when audio starts playing. Prevents system sleep.
  /// Does nothing on non-Windows platforms.
  static void preventSleep() {
    if (!Platform.isWindows) return;
    _initialize();
    _setThreadExecutionState?.call(
      _esContinuous | _esSystemRequired,
    );
  }

  /// Call when audio is paused/stopped or app closes.
  /// Restores normal Windows sleep behavior.
  static void allowSleep() {
    if (!Platform.isWindows) return;
    _initialize();
    _setThreadExecutionState?.call(_esContinuous);
  }
}