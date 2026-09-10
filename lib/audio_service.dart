import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const _musicAsset = 'music/music_otc.mp3';
  static const _clickAsset = 'music/click.mp3';
  static const _bombAsset = 'music/boomb.mp3';
  static const _winAsset = 'music/win.mp3';
  static const _loseAsset = 'music/lose.mp3';
  static const _putBoxAsset = 'music/putbox.mp3';

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool musicMuted = false;
  bool soundMuted = false;

  Future<void> loadSettings({
    required bool musicMuted,
    required bool soundMuted,
  }) async {
    this.musicMuted = musicMuted;
    this.soundMuted = soundMuted;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playMusic() async {
    if (musicMuted) return;
    if (_musicPlayer.state == PlayerState.playing) return;

    try {
      if (_musicPlayer.state == PlayerState.paused) {
        await _musicPlayer.resume();
        return;
      }

      if (_musicPlayer.state == PlayerState.stopped ||
          _musicPlayer.state == PlayerState.completed) {
        await _musicPlayer.play(AssetSource(_musicAsset));
        return;
      }

      await _musicPlayer.play(AssetSource(_musicAsset));
    } catch (_) {
      await _musicPlayer.play(AssetSource(_musicAsset));
    }
  }

  Future<void> pauseMusic() async {
    if (_musicPlayer.state == PlayerState.playing) {
      await _musicPlayer.pause();
    }
  }

  Future<void> stopMusic() async {
    if (_musicPlayer.state == PlayerState.playing ||
        _musicPlayer.state == PlayerState.paused) {
      await _musicPlayer.stop();
    }
  }

  Future<void> toggleMusic({bool startMusic = true}) async {
    musicMuted = !musicMuted;
    if (musicMuted) {
      await pauseMusic();
    } else if (startMusic) {
      await playMusic();
    }
  }

  Future<void> toggleSound() async {
    soundMuted = !soundMuted;
  }

  Future<void> playSound(AudioEffect effect) async {
    if (soundMuted) return;
    final player = AudioPlayer();
    try {
      await player.play(AssetSource(effect.asset));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {
      await player.dispose();
    }
  }
}

enum AudioEffect {
  click(AudioService._clickAsset),
  bomb(AudioService._bombAsset),
  win(AudioService._winAsset),
  lose(AudioService._loseAsset),
  putBox(AudioService._putBoxAsset);

  const AudioEffect(this.asset);
  final String asset;
}
