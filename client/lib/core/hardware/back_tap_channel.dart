import 'package:flutter/services.dart';

typedef HardwareTriggerCallback = void Function();

class BackTapChannel {
  static const String channelName = 'com.wisplit/hardware_trigger';
  static const MethodChannel _channel = MethodChannel(channelName);

  static HardwareTriggerCallback? _onTrigger;
  static bool _initialized = false;

  /// Initializes the hardware trigger listener.
  static void initialize({required HardwareTriggerCallback onTrigger}) {
    _onTrigger = onTrigger;

    if (!_initialized) {
      _channel.setMethodCallHandler(_methodCallHandler);
      _initialized = true;
    }
  }

  /// Sends updated gesture configuration to native Android service
  static Future<void> updateConfig({
    required String gesture,
    required String sensitivity,
  }) async {
    try {
      await _channel.invokeMethod('updateTriggerConfig', {
        'gesture': gesture,
        'sensitivity': sensitivity,
      });
    } catch (_) {}
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'onHardwareTrigger':
      case 'onBackDoubleTap':
        _onTrigger?.call();
        return true;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  static void dispose() {
    _channel.setMethodCallHandler(null);
    _onTrigger = null;
    _initialized = false;
  }
}
