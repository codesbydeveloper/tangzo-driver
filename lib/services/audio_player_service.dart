import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/widgets.dart';

class AudioPlayerService with WidgetsBindingObserver {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static bool _isPlaying = false;

  static Future<void> initAudio() async {
    WidgetsBinding.instance.addObserver(AudioPlayerService());

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  static Future<void> playSound(bool isPlay) async {
    try {
      if (isPlay) {
        _isPlaying = true;

        log("PlaySound :: START");

        await _audioPlayer.stop();

        await _audioPlayer.play(
          UrlSource(
            Preferences.getString(Preferences.orderRingtone),
          ),
        );
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

    if (state == AppLifecycleState.resumed) {
      // Re-start sound after app comes foreground
      if (_isPlaying) {
        await _audioPlayer.stop();

        await _audioPlayer.play(
          UrlSource(
            Preferences.getString(Preferences.orderRingtone),
          ),
        );
      }
    }
  }
}
