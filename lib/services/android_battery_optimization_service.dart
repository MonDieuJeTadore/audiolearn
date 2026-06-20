import 'dart:io';
import 'package:flutter/services.dart';

/// Service to request Android battery optimization exemption.
/// This is the programmatic equivalent of manually setting
/// "Non restreinte" in Android battery settings.
class AndroidBatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel(
    'com.audiolearn/battery_optimization',
  );

  /// Returns true if the app is already exempt from battery optimization.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod('isIgnoringBatteryOptimizations');
    } catch (e) {
      return false;
    }
  }

  /// Opens the system dialog asking the user to exempt this app.
  /// Should be called once, e.g. on first launch or first audio play.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      // Silently fail
    }
  }

  /// Call when audio starts playing.
  static Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (e) {
      // Silently fail
    }
  }

  /// Call when audio is paused or stopped.
  static Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (e) {
      // Silently fail
    }
  }
}
