import 'dart:developer';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AudioPlayerService with WidgetsBindingObserver {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static const MethodChannel _ringtoneChannel = MethodChannel('tangzo/order_ringtone');
  static bool _isPlaying = false;
  static bool _initialized = false;

  static Future<void> initAudio() async {
    if (!_initialized) {
      WidgetsBinding.instance.addObserver(AudioPlayerService());
      _initialized = true;
    }

    if (!Platform.isAndroid) {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    }
  }

  static Future<void> playSound(bool isPlay) async {
    try {
      final url = Preferences.getString(Preferences.orderRingtone);
      if (Platform.isAndroid) {
        if (isPlay) {
          if (url.isEmpty) {
            log("PlaySound :: ringtone URL empty");
            return;
          }
          _isPlaying = true;
          log("PlaySound :: START native service");
          await _ringtoneChannel.invokeMethod('start', {
            'url': url,
            'title': 'New order',
            'body': 'Incoming Tangzo order',
          });
        } else {
          _isPlaying = false;
          log("PlaySound :: STOP native service");
          await _ringtoneChannel.invokeMethod('stop');
        }
        return;
      }

      if (isPlay) {
        if (url.isEmpty) {
          log("PlaySound :: ringtone URL empty");
          return;
        }
        _isPlaying = true;
        log("PlaySound :: START");
        await initAudio();
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
      } else {
        _isPlaying = false;
        log("PlaySound :: STOP");
        await _audioPlayer.stop();
      }
    } catch (e) {
      log("Error in playSound: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    log("AppLifecycleState :: $state");
    // Native Android service keeps ringing in background; only re-sync iOS.
    if (!Platform.isAndroid && state == AppLifecycleState.resumed && _isPlaying) {
      await playSound(true);
    }
  }
}
