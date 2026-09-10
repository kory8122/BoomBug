import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show Random, atan2, pi, sin;
import 'dart:ui' as ui;

import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/Screen/game_splashscreen.dart';
import 'package:boombug/game_level_utils.dart';
import 'package:boombug/widgets/animated_image_button.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:boombug/progress_store.dart';
import 'package:boombug/audio_service.dart';
import 'package:boombug/rewarded_ad_service.dart';
import 'package:boombug/widgets/refill_hearts_dialog.dart';
import 'package:boombug/widgets/ad_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _GameTool { bomb, plus, target }

enum _PixelEffect { bomb, target }

class Game extends StatefulWidget {
  const Game({super.key, this.isTutorial = false});

  final bool isTutorial;

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with WidgetsBindingObserver {
  static const int _gridColumns = 36;
  static const int _gridRows = 27;
  static const int _easyAnimalCount = 35;
  static const int _hardAnimalCount = 10;
  static const int _maxToolUses = 5;
  static const int _maxActiveBugs = 72;
  static const double _bugTravelSecondsPerStep = 0.12;
  static const double _bugReturnSeconds = 0.12;

  int currentLevel = 1;
  int currentAnimalId = 1;
  int? previousAnimalId;
  final int totalLevels = 500;
  final List<_PixelData> _pixels = [];
  final Set<_GridPoint> _occupiedCells = {};
  final List<_BugData> _activeBugs = [];
  final List<_BugBatch?> _selectedSlots = List<_BugBatch?>.filled(5, null);
  final List<_BugBatch> _availableBatches = [];
  final Map<Color, _ColorStats> _colorStats = {};
  final Map<_BugBatch, double> _spawnCooldowns = {};
  int _middleSlotCount = 3;
  int _coins = 1000;
  int _hearts = 5;
  final Map<_GameTool, int> _toolUses = {
    _GameTool.bomb: 1,
    _GameTool.plus: 1,
    _GameTool.target: 1,
  };
  _GameTool? _activeTool;
  bool _isMenuOpen = false;
  bool _isMenuVisible = false;
  bool _isSoundMuted = false;
  bool _isMusicMuted = false;
  bool _isGameLost = false;
  bool _isLevelComplete = false;
  bool _isResultDialogOpen = false;
  bool _pixelEffectActive = false;
  bool _isLeavingTutorial = false;
  int _tutorialBoxesSelected = 0;
  String? _levelLoadError;
  int _levelLoadToken = 0;
  Timer? _gameTimer;
  Timer? _heartTimer;
  final ProgressStore _progress = ProgressStore.instance;
  final RewardedAdService _rewardedAds = RewardedAdService();
  final AudioService _audio = AudioService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress.addListener(_onProgressChanged);
    _initializeProgress();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _advanceGame);
    _heartTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _progress.refreshRecharge().then((_) {
        if (mounted) setState(() => _hearts = _progress.hearts);
      });
    });
  }

  Future<void> _initializeProgress() async {
    await _progress.load();
    await _audio.loadSettings(
      musicMuted: _progress.musicMuted,
      soundMuted: _progress.soundMuted,
    );
    if (!mounted) return;
    await _audio.playMusic();
    setState(() {
      currentLevel = widget.isTutorial ? 1 : _progress.level;
      _coins = _progress.coins;
      _hearts = _progress.hearts;
      _isSoundMuted = _audio.soundMuted;
      _isMusicMuted = _audio.musicMuted;
      _toolUses[_GameTool.bomb] = _progress.bombUses;
      _toolUses[_GameTool.plus] = _progress.plusUses;
      _toolUses[_GameTool.target] = _progress.targetUses;
      if (widget.isTutorial) {
        _startTutorial();
      } else {
        _startLevel();
      }
    });
  }

  void _startTutorial() {
    _pixels
      ..clear()
      ..addAll(_tutorialPixels());
    _occupiedCells
      ..clear()
      ..addAll(_pixels.map((pixel) => _GridPoint(pixel.column, pixel.row)));
    _colorStats
      ..clear()
      ..addEntries(
        _countPixelsByColor(_pixels).entries.map(
          (entry) => MapEntry(
            entry.key,
            _ColorStats(originalPixels: entry.value, originalBugs: entry.value),
          ),
        ),
      );
    _availableBatches
      ..clear()
      ..addAll(_createBatches(1));
    _balanceQueue();
  }

  List<_PixelData> _tutorialPixels() {
    const pattern = [
      '000111111000',
      '001111111100',
      '011001100110',
      '110111111011',
      '110111111011',
      '011001100110',
      '001111111100',
      '000111111000',
    ];
    final pixels = <_PixelData>[];
    for (var row = 0; row < pattern.length; row++) {
      for (var column = 0; column < pattern[row].length; column++) {
        if (pattern[row][column] == '1') {
          pixels.add(
            _PixelData(
              column: column + 12,
              row: row + 9,
              color: column < 6
                  ? const Color(0xFFFFC700)
                  : const Color(0xFF2D7CFF),
            ),
          );
        }
      }
    }
    return pixels;
  }

  void _onProgressChanged() {
    if (!mounted) return;
    if (_coins == _progress.coins &&
        _hearts == _progress.hearts &&
        currentLevel == _progress.level) {
      return;
    }
    setState(() {
      _coins = _progress.coins;
      _hearts = _progress.hearts;
      currentLevel = _progress.level;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _heartTimer?.cancel();
    _progress.removeListener(_onProgressChanged);
    _audio.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_audio.musicMuted) {
        _audio.playMusic();
      }
      _progress.refresh().then((_) {
        if (!mounted) return;
        setState(() {
          _hearts = _progress.hearts;
        });
      });
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audio.pauseMusic();
    }
  }

  void _startLevel() {
    unawaited(_audio.playMusic());
    final animalId = _selectAnimalId();
    final loadToken = ++_levelLoadToken;

    _pixels.clear();
    _occupiedCells.clear();
    _activeBugs.clear();
    _selectedSlots.fillRange(0, _selectedSlots.length, null);
    _availableBatches.clear();
    _spawnCooldowns.clear();
    _colorStats.clear();
    _isGameLost = false;
    _isLevelComplete = false;
    _activeTool = null;
    _levelLoadError = null;
    _middleSlotCount = middleSlotCountForLevel(currentLevel);
    _loadAnimalLevel(animalId, loadToken, isHardLevel(currentLevel));
  }

  void _toggleGameMenu() {
    if (_isMenuOpen) {
      setState(() => _isMenuOpen = false);
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (!mounted || _isMenuOpen) return;
        setState(() => _isMenuVisible = false);
      });
      return;
    }
    setState(() {
      _isMenuVisible = true;
      _isMenuOpen = true;
    });
  }

  void _openGameMenu() {
    if (_isMenuOpen) return;
    setState(() {
      _isMenuVisible = true;
      _isMenuOpen = true;
    });
  }

  void _restartFromMenu() {
    if (_hearts <= 0) return;
    setState(() {
      _progress.hearts = _hearts;
      _progress.consumeHeart();
      _hearts = _progress.hearts;
      _isMenuOpen = false;
      _isMenuVisible = false;
      _startLevel();
    });
    _saveProgress();
  }

  Future<void> _retryLevel() async {
    if (_hearts <= 0) return;
    setState(() {
      _startLevel();
    });
    await _audio.playMusic();
    await _saveProgress();
  }

  Future<void> _toggleSound() async {
    await _audio.toggleSound();
    if (!mounted) return;
    setState(() {
      _isSoundMuted = _audio.soundMuted;
      _progress.soundMuted = _audio.soundMuted;
    });
    await _progress.save();
  }

  Future<void> _toggleMusic() async {
    await _audio.toggleMusic();
    if (!mounted) return;
    setState(() {
      _isMusicMuted = _audio.musicMuted;
      _progress.musicMuted = _audio.musicMuted;
    });
    await _progress.save();
  }

  int _selectAnimalId() {
    final hardLevel = isHardLevel(currentLevel);
    final imageCount = hardLevel ? _hardAnimalCount : _easyAnimalCount;
    final previousImages = Iterable<int>.generate(currentLevel - 1, (index) {
      return isHardLevel(index + 1) ? 1 : 0;
    }).where((value) => value == (hardLevel ? 1 : 0)).length;
    final step = hardLevel ? 3 : 17;
    currentAnimalId = ((previousImages * step) % imageCount) + 1;
    previousAnimalId = currentAnimalId;
    return currentAnimalId;
  }

  int _unlockLevel(_GameTool tool) {
    return switch (tool) {
      _GameTool.bomb => 12,
      _GameTool.plus => 24,
      _GameTool.target => 36,
    };
  }

  int _toolPrice(_GameTool tool) {
    return switch (tool) {
      _GameTool.bomb => 200,
      _GameTool.plus => 350,
      _GameTool.target => 500,
    };
  }

  void _pressTool(_GameTool tool) {
    final unlockLevel = _unlockLevel(tool);
    if (currentLevel < unlockLevel) {
      return;
    }
    if ((_toolUses[tool] ?? 0) == 0) {
      _showToolPurchase(tool);
      return;
    }
    if (tool == _GameTool.plus) {
      if (_middleSlotCount >= _selectedSlots.length) return;
      setState(() {
        _middleSlotCount++;
        _toolUses[tool] = _toolUses[tool]! - 1;
      });
      _saveProgress();
      return;
    }
    setState(() => _activeTool = tool);
  }

  Future<void> _showToolPurchase(_GameTool tool) async {
    final price = _toolPrice(tool);
    final currentUses = _toolUses[tool] ?? 0;
    final availableUses = _maxToolUses - currentUses;
    if (availableUses <= 0) return;
    final purchase = await showGeneralDialog<_ToolPurchaseResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Buy tool uses',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ToolPurchaseDialog(
          price: price,
          availableUses: availableUses,
          coins: _coins,
          showWatchAd: Platform.isAndroid,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
    if (purchase == null || !mounted) return;
    if (purchase.watchAd) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AdLoadingDialog(),
      );
      final completed = await _rewardedAds.watchAds(1);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The ad was not completed. No tool use added.'),
          ),
        );
        return;
      }
      setState(() {
        _toolUses[tool] = (currentUses + 1).clamp(0, _maxToolUses);
      });
      await _saveProgress();
      return;
    }

    final totalPrice = price * purchase.quantity;
    if (_coins < totalPrice) return;
    setState(() {
      _coins -= totalPrice;
      _toolUses[tool] = (currentUses + purchase.quantity).clamp(
        0,
        _maxToolUses,
      );
    });
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    _progress
      ..level = currentLevel
      ..coins = _coins
      ..hearts = _hearts
      ..bombUses = _toolUses[_GameTool.bomb] ?? 0
      ..plusUses = _toolUses[_GameTool.plus] ?? 0
      ..targetUses = _toolUses[_GameTool.target] ?? 0;
    await _progress.save();
  }

  Future<void> _showLevelCompleteDialog() async {
    if (widget.isTutorial) {
      await _showTutorialCompleteDialog();
      return;
    }
    if (_isResultDialogOpen) return;
    _isResultDialogOpen = true;
    final action = await showGeneralDialog<_LevelCompleteAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Level complete',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelCompleteDialog(
          level: currentLevel,
          showDoubleReward: Platform.isAndroid,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
    _isResultDialogOpen = false;
    if (action == null || !mounted) return;

    var reward = 40;
    if (action == _LevelCompleteAction.doubleReward) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AdLoadingDialog(),
      );
      final completed = await _rewardedAds.watchAds(1);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (completed) {
        reward = 80;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The ad was not completed. Reward remains 40 coins.'),
          ),
        );
      }
    }
    await _finishLevel(reward);
  }

  Future<void> _showLevelLostDialog() async {
    if (_isResultDialogOpen) return;
    _isResultDialogOpen = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Level lost',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelLostDialog(
          canRetry: _hearts > 0,
          onRetry: () {
            Navigator.pop(context);
            _retryLevel();
          },
          onMenu: () {
            Navigator.pop(context);
            Navigator.of(this.context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
    _isResultDialogOpen = false;
  }

  Future<void> _finishLevel(int reward) async {
    if (!mounted) return;
    setState(() {
      _coins += reward;
      currentLevel = currentLevel < totalLevels ? currentLevel + 1 : 1;
    });
    await _saveProgress();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameSplashScreen()),
    );
  }

  Future<void> _leaveTutorial() async {
    if (_isLeavingTutorial || !mounted) return;
    _isLeavingTutorial = true;
    _progress
      ..tutorialCompleted = true
      ..level = 1
      ..coins += 150;
    await _progress.save();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen()));
  }

  Future<void> _showTutorialCompleteDialog() async {
    if (_isResultDialogOpen) return;
    _isResultDialogOpen = true;
    final action = await showGeneralDialog<_LevelCompleteAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tutorial complete',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LevelCompleteDialog(
          level: 1,
          reward: 150,
          showDoubleReward: false,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
    _isResultDialogOpen = false;
    if (action != null && mounted) await _leaveTutorial();
  }

  Future<void> _showHeartRefill() async {
    if (_hearts != 0) return;
    final action = await showRefillHeartsDialog(context);
    if (action == null || !mounted) return;
    if (action == RefillHeartsAction.buyWithCoins) {
      if (_coins < 250) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need 250 coins to refill hearts.')),
        );
        return;
      }
      setState(() {
        _coins -= 250;
        _progress.coins = _coins;
        _progress.refillHearts();
        _hearts = _progress.hearts;
        _isGameLost = false;
        _startLevel();
      });
      await _saveProgress();
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdLoadingDialog(),
    );
    final completed = await _rewardedAds.watchAds(1, useTestAd: true);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The ad was not completed. No hearts added.'),
        ),
      );
      return;
    }
    setState(() {
      _progress.refillHearts();
      _hearts = _progress.hearts;
      _isGameLost = false;
      _startLevel();
    });
    await _saveProgress();
  }

  void _handleBoardTap(Offset localPosition, Size boardSize) {
    final tool = _activeTool;
    if (tool == null || _pixelEffectActive || _isGameLost || _pixels.isEmpty) {
      return;
    }
    final column = (localPosition.dx / boardSize.width * _gridColumns)
        .floor()
        .clamp(0, _gridColumns - 1);
    final row = (localPosition.dy / boardSize.height * _gridRows).floor().clamp(
      0,
      _gridRows - 1,
    );
    if (tool == _GameTool.bomb) {
      _useBombAt(column, row);
    } else {
      _useTargetAt(column, row);
    }
  }

  void _useBombAt(int column, int row) {
    final pixels = _pixels.where((pixel) {
      return !pixel.destroyed &&
          (pixel.column - column).abs() <= 2 &&
          (pixel.row - row).abs() <= 2;
    }).toList();
    if (pixels.isEmpty) return;
    _audio.playSound(AudioEffect.bomb);
    setState(() {
      for (final pixel in pixels) {
        pixel.effect = _PixelEffect.bomb;
        pixel.effectProgress = 0;
        pixel.effectOrigin = _GridPoint(column, row);
      }
      _toolUses[_GameTool.bomb] = _toolUses[_GameTool.bomb]! - 1;
      _activeTool = null;
      _pixelEffectActive = true;
    });
    _saveProgress();
  }

  void _useTargetAt(int column, int row) {
    final selectedPixel = _pixels.cast<_PixelData?>().firstWhere(
      (pixel) =>
          pixel != null &&
          !pixel.destroyed &&
          pixel.column == column &&
          pixel.row == row,
      orElse: () => null,
    );
    if (selectedPixel == null) return;
    final color = selectedPixel.color;
    setState(() {
      for (final pixel in _pixels.where(
        (pixel) => !pixel.destroyed && pixel.color == color,
      )) {
        pixel.effect = _PixelEffect.target;
        pixel.effectProgress = 0;
      }
      _toolUses[_GameTool.target] = _toolUses[_GameTool.target]! - 1;
      _activeTool = null;
      _pixelEffectActive = true;
    });
    _saveProgress();
  }

  bool _advancePixelEffects() {
    var hasEffects = false;
    for (final pixel in _pixels) {
      if (pixel.effect == null) continue;
      pixel.effectProgress += 0.016 / 0.48;
      hasEffects = true;
      if (pixel.effectProgress < 1) continue;

      if (pixel.effect == _PixelEffect.target) {
        _activeBugs.removeWhere((bug) => bug.color == pixel.color);
        for (final batch in _availableBatches.where(
          (batch) => batch.color == pixel.color,
        )) {
          batch.releasedBugs = batch.totalBugs;
        }
        for (var index = 0; index < _selectedSlots.length; index++) {
          if (_selectedSlots[index]?.color == pixel.color) {
            _selectedSlots[index] = null;
          }
        }
        _availableBatches.removeWhere((batch) => batch.color == pixel.color);
      }
      _destroyPixel(pixel);
      pixel.effect = null;
      pixel.effectProgress = 0;
    }
    if (hasEffects) {
      _pixelEffectActive = _pixels.any((pixel) => pixel.effect != null);
    }
    return hasEffects;
  }

  void _destroyPixel(_PixelData pixel) {
    if (pixel.destroyed) return;
    pixel.destroyed = true;
    pixel.targeted = false;
    _occupiedCells.remove(_GridPoint(pixel.column, pixel.row));
    _colorStats[pixel.color]?.destroyedPixels++;
  }

  Future<void> _loadAnimalLevel(
    int animalId,
    int loadToken,
    bool hardLevel,
  ) async {
    try {
      final pixels = await _generateAnimalFromAsset(animalId, hardLevel);
      if (!mounted || loadToken != _levelLoadToken) return;

      setState(() {
        _pixels.addAll(pixels);
        _occupiedCells.addAll(
          pixels.map((pixel) => _GridPoint(pixel.column, pixel.row)),
        );
        _colorStats.addEntries(
          _countPixelsByColor(_pixels).entries.map(
            (entry) => MapEntry(
              entry.key,
              _ColorStats(
                originalPixels: entry.value,
                originalBugs: entry.value,
              ),
            ),
          ),
        );
        final batches = _createBatches(currentLevel);
        _availableBatches.addAll(batches);
        _balanceQueue();
        _levelLoadError = null;
      });
    } catch (error) {
      if (!mounted || loadToken != _levelLoadToken) return;
      final folder = hardLevel ? 'hard' : 'easy';
      debugPrint('Unable to load assets/animals/$folder/$animalId.png: $error');
      setState(() {
        _levelLoadError = 'Image $animalId is unavailable';
      });
    }
  }

  Future<List<_PixelData>> _generateAnimalFromAsset(
    int animalId,
    bool hardLevel,
  ) async {
    final folder = hardLevel ? 'hard' : 'easy';
    final imageData = await rootBundle.load(
      'assets/animals/$folder/$animalId.png',
    );

    final codec = await ui.instantiateImageCodec(
      imageData.buffer.asUint8List(),
      targetWidth: _gridColumns,
      targetHeight: _gridRows,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    if (bytes == null) {
      throw StateError('The animal image could not be decoded.');
    }

    return _pixelsFromImage(bytes, _gridColumns, _gridRows);
  }

  List<_PixelData> _pixelsFromImage(
    ByteData bytes,
    int gridColumns,
    int gridRows,
  ) {
    final pixels = <_PixelData>[];
    final backgroundColor = _detectBackgroundColor(
      bytes,
      gridColumns,
      gridRows,
    );
    for (var row = 0; row < gridRows; row++) {
      for (var column = 0; column < gridColumns; column++) {
        final offset = (row * gridColumns + column) * 4;
        final alpha = bytes.getUint8(offset + 3);
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        if (alpha < 64 ||
            _matchesBackground(backgroundColor, red, green, blue)) {
          continue;
        }
        final color = Color.fromARGB(255, red, green, blue);
        pixels.add(_PixelData(column: column, row: row, color: color));
      }
    }
    return _normalizePixelColors(pixels);
  }

  List<_PixelData> _normalizePixelColors(List<_PixelData> pixels) {
    // Progressive color complexity based on level
    // Early levels: aggressive color reduction (basic)
    // Later levels: more color details preserved
    final closeColorDistance = _getColorDistanceThreshold();
    final palette = <Color>[];
    final counts = <Color, int>{};

    for (final pixel in pixels) {
      Color? matchingColor;
      for (final color in palette) {
        if (_colorDistance(
              color,
              (pixel.color.r * 255).round(),
              (pixel.color.g * 255).round(),
              (pixel.color.b * 255).round(),
            ) <=
            closeColorDistance) {
          matchingColor = color;
          break;
        }
      }
      final normalizedColor = matchingColor ?? pixel.color;
      if (matchingColor == null) palette.add(normalizedColor);
      counts[normalizedColor] = (counts[normalizedColor] ?? 0) + 1;
      pixel.color = normalizedColor;
    }

    while (counts.length > 1) {
      final smallEntry = counts.entries
          .where((entry) => entry.value < 10)
          .fold<MapEntry<Color, int>?>(
            null,
            (smallest, entry) =>
                smallest == null || entry.value < smallest.value
                ? entry
                : smallest,
          );
      if (smallEntry == null) break;

      final targetColor = counts.keys
          .where((color) => color != smallEntry.key)
          .reduce((closest, color) {
            final closestDistance = _colorDistance(
              closest,
              (smallEntry.key.r * 255).round(),
              (smallEntry.key.g * 255).round(),
              (smallEntry.key.b * 255).round(),
            );
            final colorDistance = _colorDistance(
              color,
              (smallEntry.key.r * 255).round(),
              (smallEntry.key.g * 255).round(),
              (smallEntry.key.b * 255).round(),
            );
            return colorDistance < closestDistance ? color : closest;
          });

      for (final pixel in pixels) {
        if (pixel.color == smallEntry.key) pixel.color = targetColor;
      }
      counts[targetColor] = counts[targetColor]! + smallEntry.value;
      counts.remove(smallEntry.key);
    }
    return pixels;
  }

  int _getColorDistanceThreshold() {
    // Difficulty comes from color boxes, not pixel resolution.
    if (currentLevel <= 100) {
      return 1600; // Early levels: fewer color boxes
    } else if (currentLevel <= 500) {
      return 800; // Mid levels: more color boxes
    } else {
      return 300; // Late levels: fine color boxes
    }
  }

  Color? _detectBackgroundColor(ByteData bytes, int width, int height) {
    final cornerOffsets = [
      0,
      width - 1,
      (height - 1) * width,
      width * height - 1,
    ].map((pixelIndex) => pixelIndex * 4).toList();
    if (cornerOffsets.any((offset) => bytes.getUint8(offset + 3) < 64)) {
      return null;
    }

    final background = Color.fromARGB(
      255,
      bytes.getUint8(cornerOffsets.first),
      bytes.getUint8(cornerOffsets.first + 1),
      bytes.getUint8(cornerOffsets.first + 2),
    );
    final hasUniformCorners = cornerOffsets.skip(1).every((offset) {
      return _colorDistance(
            background,
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          ) <=
          1200;
    });
    return hasUniformCorners ? background : null;
  }

  bool _matchesBackground(Color? background, int red, int green, int blue) {
    return background != null &&
        _colorDistance(background, red, green, blue) <= 1200;
  }

  int _colorDistance(Color color, int red, int green, int blue) {
    final redDifference = (color.r * 255).round() - red;
    final greenDifference = (color.g * 255).round() - green;
    final blueDifference = (color.b * 255).round() - blue;
    return redDifference * redDifference +
        greenDifference * greenDifference +
        blueDifference * blueDifference;
  }

  Map<Color, int> _countPixelsByColor(Iterable<_PixelData> pixels) {
    final counts = <Color, int>{};
    for (final pixel in pixels) {
      counts[pixel.color] = (counts[pixel.color] ?? 0) + 1;
    }
    return counts;
  }

  List<_BugBatch> _createBatches(int level) {
    final random = Random(level * 4231);
    final batches = <_BugBatch>[];
    for (final entry in _colorStats.entries) {
      final totalBugs = entry.value.originalPixels;
      final regionCount = _connectedRegionCount(entry.key);
      final maxBugsPerBox = regionCount >= 4
          ? 15
          : regionCount >= 2
          ? 20
          : 25;
      var remainingBugs = totalBugs;
      while (remainingBugs > 0) {
        final maxSize = remainingBugs.clamp(1, maxBugsPerBox);
        final minSize = remainingBugs > maxBugsPerBox ? 2 : 1;
        final batchSize = minSize == maxSize
            ? minSize
            : minSize + random.nextInt(maxSize - minSize + 1);
        batches.add(_BugBatch(color: entry.key, totalBugs: batchSize));
        remainingBugs -= batchSize;
      }
    }

    batches.shuffle(random);
    return batches;
  }

  int _connectedRegionCount(Color color) {
    final colorPoints = {
      for (final pixel in _pixels.where((pixel) => pixel.color == color))
        _GridPoint(pixel.column, pixel.row),
    };
    var regions = 0;
    final remaining = Set<_GridPoint>.from(colorPoints);
    const directions = [
      _GridPoint(0, -1),
      _GridPoint(1, 0),
      _GridPoint(0, 1),
      _GridPoint(-1, 0),
    ];
    while (remaining.isNotEmpty) {
      regions++;
      final queue = <_GridPoint>[remaining.first];
      remaining.remove(queue.first);
      for (var index = 0; index < queue.length; index++) {
        final current = queue[index];
        for (final direction in directions) {
          final neighbor = _GridPoint(
            current.column + direction.column,
            current.row + direction.row,
          );
          if (remaining.remove(neighbor)) queue.add(neighbor);
        }
      }
    }
    return regions;
  }

  void _selectBatchAt(_BugBatch batch, int slotIndex) {
    if (_activeTool != null ||
        slotIndex == -1 ||
        !_availableBatches.contains(batch) ||
        _isGameLost) {
      return;
    }

    if (slotIndex >= _middleSlotCount || _selectedSlots[slotIndex] != null) {
      return;
    }

    setState(() {
      _availableBatches.remove(batch);
      _selectedSlots[slotIndex] = batch;
      _spawnCooldowns[batch] = 0;
      _balanceQueue();
    });
  }

  void _selectNextBatch(_BugBatch batch) {
    final slotIndex = _selectedSlots
        .take(_middleSlotCount)
        .toList()
        .indexWhere((slot) => slot == null);
    if (slotIndex == -1) return;
    _selectBatchAt(batch, slotIndex);
    if (widget.isTutorial && _tutorialBoxesSelected < 3) {
      setState(() => _tutorialBoxesSelected++);
    }
  }

  void _balanceQueue() {
    if (_availableBatches.length <= _middleSlotCount) return;

    final visibleCount = _middleSlotCount.clamp(0, _availableBatches.length);
    final visible = _availableBatches.take(visibleCount).toList();
    final hasValidVisible = visible.any(_hasPlayableBatch);
    if (!hasValidVisible) {
      final hiddenValidIndex = _availableBatches
          .skip(visibleCount)
          .toList()
          .indexWhere(_hasPlayableBatch);
      if (hiddenValidIndex >= 0) {
        final batch = _availableBatches.removeAt(
          visibleCount + hiddenValidIndex,
        );
        _availableBatches.insert(0, batch);
        visible[0] = batch;
      }
    }

    final hasBlockedVisible = visible.any((batch) => !_hasPlayableBatch(batch));
    if (hasBlockedVisible) return;

    final hiddenBlockedIndex = _availableBatches
        .skip(visibleCount)
        .toList()
        .indexWhere((batch) => !_hasPlayableBatch(batch));
    if (hiddenBlockedIndex < 0) return;

    final batch = _availableBatches.removeAt(visibleCount + hiddenBlockedIndex);
    final visibleSwapIndex = visibleCount - 1;
    final swappedBatch = _availableBatches[visibleSwapIndex];
    _availableBatches[visibleSwapIndex] = batch;
    _availableBatches.add(swappedBatch);
  }

  bool _hasPlayableBatch(_BugBatch batch) {
    if (batch.remainingBugs <= 0) return false;
    final remainingPixels = _pixels.where(
      (pixel) =>
          !pixel.destroyed && !pixel.targeted && pixel.color == batch.color,
    );
    if (remainingPixels.length < batch.remainingBugs) return false;
    return _hasEnoughReachablePixelsFromAnyOpenSlot(batch);
  }

  bool _hasEnoughReachablePixelsFromAnyOpenSlot(_BugBatch batch) {
    for (var slotIndex = 0; slotIndex < _middleSlotCount; slotIndex++) {
      if (_selectedSlots[slotIndex] == null &&
          _reachableColorCountFromSlot(batch.color, slotIndex) >=
              batch.remainingBugs) {
        return true;
      }
    }
    return false;
  }

  int _reachableColorCountFromSlot(Color color, int slotIndex) {
    const boardWidth = 400.0;
    const slotWidth = 50.0;
    const slotMargin = 4.0;
    final slotCenter =
        boardWidth / 2 +
        (slotIndex - (_middleSlotCount - 1) / 2) * (slotWidth + slotMargin * 2);
    final source = _GridPoint(
      (slotCenter / boardWidth * _gridColumns - 0.5).round(),
      _gridRows + 2,
    );
    final reachableRoutes = _findReachableRoutes(source);
    return _pixels
        .where(
          (pixel) =>
              !pixel.destroyed &&
              !pixel.targeted &&
              pixel.color == color &&
              _routeToPixel(pixel, reachableRoutes) != null,
        )
        .length;
  }

  void _spawnBugs(_BugBatch batch) {
    if (batch.remainingBugs == 0 || _activeBugs.length >= _maxActiveBugs) {
      return;
    }

    final slotIndex = _selectedSlots.indexOf(batch);
    const boardWidth = 400.0;
    const slotWidth = 50.0;
    const slotMargin = 4.0;
    final slotCenter =
        boardWidth / 2 +
        (slotIndex - (_middleSlotCount - 1) / 2) * (slotWidth + slotMargin * 2);
    final source = _GridPoint(
      (slotCenter / boardWidth * _gridColumns - 0.5).round(),
      _gridRows + 2,
    );
    final reachableRoutes = _findReachableRoutes(source);
    final candidates = _pixels
        .where(
          (pixel) =>
              !pixel.destroyed && !pixel.targeted && pixel.color == batch.color,
        )
        .toList();

    final orderedCandidates = candidates
      ..sort((first, second) {
        final firstRoute = _routeToPixel(first, reachableRoutes);
        final secondRoute = _routeToPixel(second, reachableRoutes);

        final firstScore = firstRoute == null
            ? double.infinity
            : firstRoute.length.toDouble();
        final secondScore = secondRoute == null
            ? double.infinity
            : secondRoute.length.toDouble();

        final firstDistance =
            ((first.column - source.column).abs() +
            (first.row - source.row).abs());
        final secondDistance =
            ((second.column - source.column).abs() +
            (second.row - source.row).abs());

        if (firstScore != secondScore) {
          return firstScore.compareTo(secondScore);
        }
        if (firstDistance != secondDistance) {
          return firstDistance.compareTo(secondDistance);
        }
        final rowOrder = first.row.compareTo(second.row);
        if (rowOrder != 0) return rowOrder;
        return first.column.compareTo(second.column);
      });

    if (batch.remainingBugs > 0) {
      _PixelData? target;
      List<_GridPoint>? route;
      for (final candidate in orderedCandidates) {
        if (candidate.destroyed || candidate.targeted) continue;
        final candidateRoute = _routeToPixel(candidate, reachableRoutes);
        if (candidateRoute != null) {
          target = candidate;
          route = candidateRoute;
          break;
        }
      }
      if (target == null || route == null) {
        // A box finishes only after its remaining pixels were destroyed.
        if (candidates.isEmpty) {
          batch.releasedBugs = batch.totalBugs;
        }
        return;
      }

      final targets = <_PixelData>[target];
      target.targeted = true;
      batch.releasedBugs++;
      _colorStats[batch.color]?.releasedBugs++;
      _activeBugs.add(
        _BugData(
          color: batch.color,
          batch: batch,
          targets: targets,
          source: source,
          route: route,
        ),
      );
    }
  }

  bool _hasReachableTarget(_BugBatch batch) {
    final slotIndex = _selectedSlots.indexOf(batch);
    return batch.remainingBugs > 0 &&
        slotIndex >= 0 &&
        _reachableColorCountFromSlot(batch.color, slotIndex) >=
            batch.remainingBugs;
  }

  Map<_GridPoint, List<_GridPoint>> _findReachableRoutes(_GridPoint start) {
    final queue = <_GridPoint>[start];
    var queueIndex = 0;
    final previous = <_GridPoint, _GridPoint?>{start: null};
    const directions = [
      _GridPoint(0, -1),
      _GridPoint(1, 0),
      _GridPoint(0, 1),
      _GridPoint(-1, 0),
    ];

    while (queueIndex < queue.length) {
      final current = queue[queueIndex++];
      for (final direction in directions) {
        final next = _GridPoint(
          current.column + direction.column,
          current.row + direction.row,
        );
        if (previous.containsKey(next) || !_canBugWalk(next)) continue;
        previous[next] = current;
        queue.add(next);
      }
    }

    final routes = <_GridPoint, List<_GridPoint>>{};
    for (final point in previous.keys) {
      final route = <_GridPoint>[];
      _GridPoint? step = point;
      while (step != null) {
        route.add(step);
        step = previous[step];
      }
      routes[point] = route.reversed.toList();
    }
    return routes;
  }

  List<_GridPoint>? _routeToPixel(
    _PixelData pixel,
    Map<_GridPoint, List<_GridPoint>> reachableRoutes,
  ) {
    const directions = [
      _GridPoint(0, -1),
      _GridPoint(1, 0),
      _GridPoint(0, 1),
      _GridPoint(-1, 0),
    ];
    final target = _GridPoint(pixel.column, pixel.row);
    for (final direction in directions) {
      final approach = _GridPoint(
        target.column + direction.column,
        target.row + direction.row,
      );
      final route = reachableRoutes[approach];
      if (route != null) return [...route, target];
    }
    return null;
  }

  bool _canBugWalk(_GridPoint point) {
    if (point.row >= _gridRows && point.row <= _gridRows + 2) {
      return point.column >= 0 && point.column < _gridColumns;
    }
    if (point.column < 0 ||
        point.column >= _gridColumns ||
        point.row < 0 ||
        point.row >= _gridRows) {
      return false;
    }
    return !_occupiedCells.contains(point);
  }

  void _advanceGame(Timer timer) {
    if (_isGameLost || _isLevelComplete || _isMenuVisible) return;

    var shouldAdvanceLevel = false;
    var shouldLoseLevel = false;
    var shouldShowLevelComplete = false;
    var shouldShowLevelLost = false;
    var hasChanges = false;
    var shouldSaveProgress = false;

    hasChanges = _advancePixelEffects();

    for (final batch in _selectedSlots.whereType<_BugBatch>().toList()) {
      final cooldown = (_spawnCooldowns[batch] ?? 0) - 0.016;
      // Keep the slot visible until every released bug reaches its pixel.
      if (batch.remainingBugs == 0 && batch.activeBugs == 0) {
        final slotIndex = _selectedSlots.indexOf(batch);
        _selectedSlots[slotIndex] = null;
        _spawnCooldowns.remove(batch);
        _balanceQueue();
        hasChanges = true;
      } else if (cooldown <= 0) {
        _spawnBugs(batch);
        _spawnCooldowns[batch] = 0.16;
        hasChanges = true;
      } else {
        _spawnCooldowns[batch] = cooldown;
      }
    }

    for (final bug in _activeBugs) {
      if (bug.state == _BugState.outbound) {
        if (bug.route == null) continue;

        final travelDuration =
            (bug.route!.length - 1) * _bugTravelSecondsPerStep;
        bug.progress += 0.016 / travelDuration.clamp(0.18, 3.0);
        hasChanges = true;
        if (bug.progress < 1) continue;

        for (final target in bug.targets) {
          if (target.destroyed) continue;
          target.destroyed = true;
          _occupiedCells.remove(_GridPoint(target.column, target.row));
          _colorStats[target.color]?.destroyedPixels++;
        }
        bug.state = _BugState.exploding;
        bug.progress = 0;
      } else {
        bug.progress += 0.016 / _bugReturnSeconds;
        hasChanges = true;
        if (bug.progress >= 1) {
          bug.hasReturned = true;
          _colorStats[bug.color]?.completedBugs++;
          bug.batch.completedBugs++;
        }
      }
    }
    _activeBugs.removeWhere((bug) => bug.hasReturned);

    if (_pixels.isNotEmpty &&
        _pixels.every((pixel) => pixel.destroyed) &&
        _activeBugs.isEmpty) {
      shouldAdvanceLevel = true;
    }

    final selectedBatches = _selectedSlots
        .take(_middleSlotCount)
        .whereType<_BugBatch>();
    final hasReachableSelectedBatch = selectedBatches.any(_hasReachableTarget);
    if (!shouldAdvanceLevel &&
        !_selectedSlots.take(_middleSlotCount).contains(null) &&
        !hasReachableSelectedBatch &&
        (_activeBugs.isEmpty ||
            _activeBugs.every((bug) => bug.route == null))) {
      shouldLoseLevel = true;
    }

    if (hasChanges || shouldAdvanceLevel || shouldLoseLevel) {
      setState(() {
        if (shouldAdvanceLevel) {
          _isLevelComplete = true;
          _activeTool = null;
          shouldShowLevelComplete = true;
          _audio.playSound(AudioEffect.win);
        } else if (shouldLoseLevel) {
          _progress.hearts = _hearts;
          _progress.consumeHeart();
          _hearts = _progress.hearts;
          _isGameLost = true;
          _activeTool = null;
          shouldShowLevelLost = true;
          _audio.stopMusic();
          _audio.playSound(AudioEffect.lose);
          shouldSaveProgress = true;
        }
      });
    }
    if (shouldSaveProgress) _saveProgress();
    if (shouldShowLevelComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelCompleteDialog();
      });
    } else if (shouldShowLevelLost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelLostDialog();
      });
    }
  }

  BoxDecoration _boardDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      border: Border.all(color: Colors.white, width: 4),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          offset: Offset(5, 5),
          blurRadius: 0,
        ),
      ],
    );
  }

  BoxDecoration _slotDecoration(Color? color, {required bool active}) {
    final fill = color ?? const Color(0xFF79421F);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(fill, Colors.white, 0.18)!,
          fill,
          Color.lerp(fill, Colors.black, 0.12)!,
        ],
      ),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
      boxShadow: [
        const BoxShadow(
          color: Color(0x55000000),
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
        if (!active)
          const BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        if (active)
          BoxShadow(
            color: fill.withValues(alpha: 0.55),
            blurRadius: 8,
            spreadRadius: 1,
          ),
      ],
    );
  }

  Widget _buildToolButton(_GameTool tool, String imagePath) {
    final unlocked = currentLevel >= _unlockLevel(tool);
    final uses = _toolUses[tool] ?? 0;
    final isActive = _activeTool == tool;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActiveToolPulse(
          isActive: isActive,
          child: Stack(
            children: [
              AnimatedImageButton(
                width: 50,
                height: 50,
                imagePath: imagePath,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(16),
                onPressed: () => _pressTool(tool),
              ),
              if (!unlocked)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          unlocked ? 'x$uses' : 'Level ${_unlockLevel(tool)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/GamePLayBG.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isMenuVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleGameMenu,
                  child: Container(color: Colors.black.withValues(alpha: 0.68)),
                ),
              ),
            SafeArea(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomIconButton(
                          size: 30,
                          width: 40,
                          height: 40,
                          icon: Icons.arrow_back,
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const MenuScreen(),
                              ),
                            );
                          },
                        ),
                        if (!widget.isTutorial)
                          Text(
                            'Level $currentLevel',
                            style: const TextStyle(
                              color: Color(0xFFFFD521),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFE52B18),
                                  blurRadius: 14,
                                ),
                                Shadow(
                                  color: Color(0xFF9F220F),
                                  offset: Offset(0, 3),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        AnimatedImageButton(
                          width: 45,
                          height: 45,
                          imagePath: 'assets/Icons/Setting_icon.png',
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(16),
                          onPressed: _openGameMenu,
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 0,
                    right: 15,
                    left: 15,
                    bottom: 300,
                    child: Center(
                      child: Container(
                        width: 400,
                        height: 300,
                        decoration: _boardDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _handleBoardTap(
                                  details.localPosition,
                                  constraints.biggest,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    RepaintBoundary(
                                      child: CustomPaint(
                                        size: constraints.biggest,
                                        painter: _BoardPixelsPainter(
                                          pixels: _pixels,
                                          columns: _gridColumns,
                                          rows: _gridRows,
                                        ),
                                      ),
                                    ),
                                    for (final bug in _activeBugs)
                                      _MovingBug(
                                        bug: bug,
                                        boardSize: constraints.biggest,
                                      ),
                                    if (_levelLoadError != null)
                                      Center(
                                        child: Text(
                                          _levelLoadError!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 265,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: _activeTool != null,
                        child: Opacity(
                          opacity: _activeTool != null ? 0.45 : 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_middleSlotCount, (index) {
                              final batch = _selectedSlots[index];
                              final color = batch?.color;
                              return _AnimatedBatchBox(
                                isBeating:
                                    batch != null && batch.activeBugs > 0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 50,
                                  height: 50,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: _slotDecoration(
                                    color,
                                    active: color != null,
                                  ),
                                  child: batch == null
                                      ? null
                                      : Center(
                                          child: Text(
                                            '${batch.remainingBugs}',
                                            style: TextStyle(
                                              color:
                                                  color!.computeLuminance() >
                                                      0.6
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: _activeTool != null,
                        child: Opacity(
                          opacity: _activeTool != null ? 0.45 : 1,
                          child: SizedBox(
                            width: 194,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: List.generate(5, (index) {
                                final batch = index < _availableBatches.length
                                    ? _availableBatches[index]
                                    : null;
                                final color = batch?.color;
                                final isQueueFront = batch != null && index < 3;
                                final box = _AnimatedBatchBox(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: 50,
                                    height: 50,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: _slotDecoration(
                                      isQueueFront
                                          ? color
                                          : color?.withValues(alpha: 0.45),
                                      active: isQueueFront,
                                    ),
                                    child: batch == null
                                        ? null
                                        : Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  '${batch.remainingBugs}',
                                                  style: TextStyle(
                                                    color:
                                                        color!.computeLuminance() >
                                                            0.6
                                                        ? Colors.black
                                                        : Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (!isQueueFront)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0x66000000,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                                );
                                return isQueueFront
                                    ? GestureDetector(
                                        onTap: () => _selectNextBatch(batch),
                                        child: box,
                                      )
                                    : box;
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 50,
                    right: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildToolButton(
                          _GameTool.bomb,
                          'assets/Icons/boom_icon.png',
                        ),
                        _buildToolButton(
                          _GameTool.plus,
                          'assets/Icons/plus_icon.png',
                        ),
                        _buildToolButton(
                          _GameTool.target,
                          'assets/Icons/strick_icon.png',
                        ),
                      ],
                    ),
                  ),
                  if (_isMenuVisible)
                    Positioned.fill(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -MediaQuery.of(context).padding.top,
                            left: 0,
                            right: 0,
                            bottom: -MediaQuery.of(context).padding.bottom,
                            child: GestureDetector(
                              onTap: _toggleGameMenu,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.68),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: _MenuSlideIn(
                              begin: const Offset(-1.4, 0),
                              reverse: !_isMenuOpen,
                              child: CustomIconButton(
                                size: 26,
                                width: 48,
                                height: 48,
                                icon: Icons.close,
                                onPressed: _toggleGameMenu,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 18,
                            right: 16,
                            child: _MenuSlideIn(
                              begin: const Offset(1.4, 0),
                              reverse: !_isMenuOpen,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: _hearts == 0
                                        ? _showHeartRefill
                                        : null,
                                    child: _MenuStat(
                                      icon: Icons.favorite,
                                      value: _hearts == 0
                                          ? '0  ${_progress.rechargeTimeLabel ?? '0:00'}'
                                          : '$_hearts',
                                      color: const Color(0xFFFF5D5D),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  _MenuStat(
                                    icon: Icons.monetization_on,
                                    value: '$_coins',
                                    color: const Color(0xFFFFC700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            bottom: 24,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MenuSlideIn(
                                  begin: const Offset(1.4, 0),
                                  reverse: !_isMenuOpen,
                                  child: Tooltip(
                                    message: _hearts > 0
                                        ? 'Restart level - 1 heart'
                                        : 'No hearts remaining',
                                    child: CustomIconButton(
                                      size: 26,
                                      width: 52,
                                      height: 52,
                                      icon: Icons.refresh,
                                      onPressed: _hearts > 0
                                          ? _restartFromMenu
                                          : () {},
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _MenuSlideIn(
                                  begin: const Offset(1.4, 0),
                                  reverse: !_isMenuOpen,
                                  child: Tooltip(
                                    message: _isSoundMuted
                                        ? 'Turn sound on'
                                        : 'Mute sound effects',
                                    child: CustomIconButton(
                                      size: 26,
                                      width: 52,
                                      height: 52,
                                      icon: Icons.volume_up,
                                      onPressed: _toggleSound,
                                      child: Text(
                                        'FX',
                                        style: TextStyle(
                                          color: _isSoundMuted
                                              ? Colors.white54
                                              : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _MenuSlideIn(
                                  begin: const Offset(1.4, 0),
                                  reverse: !_isMenuOpen,
                                  child: Tooltip(
                                    message: _isMusicMuted
                                        ? 'Turn music on'
                                        : 'Mute music',
                                    child: CustomIconButton(
                                      size: 26,
                                      width: 52,
                                      height: 52,
                                      icon: _isMusicMuted
                                          ? Icons.music_off
                                          : Icons.music_note,
                                      onPressed: _toggleMusic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.isTutorial && _tutorialBoxesSelected == 0) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: _TutorialFocusOverlay(
                    bottomInset: MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 220,
                child: const IgnorePointer(child: _TutorialHand()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _LevelCompleteAction { collect, doubleReward }

class _LevelCompleteDialog extends StatelessWidget {
  const _LevelCompleteDialog({
    required this.level,
    this.reward = 40,
    required this.showDoubleReward,
  });

  final int level;
  final int reward;
  final bool showDoubleReward;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _CompletionContent(
        level: level,
        reward: reward,
        showDoubleReward: showDoubleReward,
        onDoubleReward: () =>
            Navigator.pop(context, _LevelCompleteAction.doubleReward),
        onCollect: () => Navigator.pop(context, _LevelCompleteAction.collect),
      ),
    );
  }
}

class _LevelLostDialog extends StatelessWidget {
  const _LevelLostDialog({
    required this.canRetry,
    required this.onRetry,
    required this.onMenu,
  });

  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _LossContent(canRetry: canRetry, onRetry: onRetry, onMenu: onMenu),
    );
  }
}

class _LossContent extends StatelessWidget {
  const _LossContent({
    required this.canRetry,
    required this.onRetry,
    required this.onMenu,
  });

  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 285,
          child: Column(
            children: [
              const Text(
                'Level\nLost!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF5C70),
                  fontSize: 34,
                  height: 0.96,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xFFE52B18), blurRadius: 18),
                    Shadow(
                      color: Color(0xFF9F220F),
                      offset: Offset(0, 4),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                canRetry ? 'Try again!' : 'No hearts left',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 3),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 38),
              const Icon(
                Icons.favorite,
                color: Color(0xFFFF4F68),
                size: 92,
                shadows: [Shadow(color: Color(0xAAFF2448), blurRadius: 18)],
              ),
              const SizedBox(height: 2),
              Text(
                canRetry ? '1 HEART USED' : 'WAIT FOR HEARTS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 4),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (canRetry) ...[
          _ResultButton(
            label: 'RETRY LEVEL',
            color: const Color(0xFF55D83B),
            onPressed: onRetry,
          ),
          const SizedBox(height: 8),
        ],
        _ResultButton(
          label: 'BACK TO MENU',
          color: const Color(0xFFFFA51F),
          onPressed: onMenu,
        ),
      ],
    );
  }
}

class _ResultButton extends StatefulWidget {
  const _ResultButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ResultButton> createState() => _ResultButtonState();
}

class _ResultButtonState extends State<_ResultButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 54,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.65, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              AudioService.instance.playSound(AudioEffect.click);
              widget.onPressed();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF06A),
                    Color(0xFFFFC928),
                    Color(0xFFE5A900),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFE979), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 6,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF4D2C70),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolPurchaseResult {
  const _ToolPurchaseResult.buy(this.quantity) : watchAd = false;

  const _ToolPurchaseResult.watchAd() : quantity = 0, watchAd = true;

  final int quantity;
  final bool watchAd;
}

class _ToolPurchaseDialog extends StatefulWidget {
  const _ToolPurchaseDialog({
    required this.price,
    required this.availableUses,
    required this.coins,
    required this.showWatchAd,
  });

  final int price;
  final int availableUses;
  final int coins;
  final bool showWatchAd;

  @override
  State<_ToolPurchaseDialog> createState() => _ToolPurchaseDialogState();
}

class _ToolPurchaseDialogState extends State<_ToolPurchaseDialog> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.price * quantity;
    final canBuy = widget.coins >= totalPrice;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8E5BC7), Color(0xFF5B348F)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFD83D), width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 25,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'BUY TOOL USES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$quantity ${quantity == 1 ? 'use' : 'uses'} for $totalPrice coins',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE9DFFF),
                  ),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFD83D),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFFFFF06A),
                    overlayColor: const Color(0x33FFC700),
                    valueIndicatorColor: const Color(0xFFE5A900),
                  ),
                  child: Slider(
                    value: quantity.toDouble(),
                    min: 1,
                    max: widget.availableUses.toDouble(),
                    divisions: widget.availableUses > 1
                        ? widget.availableUses - 1
                        : null,
                    label: '$quantity',
                    onChanged: (value) {
                      setState(() => quantity = value.round());
                    },
                  ),
                ),
                Text(
                  'Choose 1-${widget.availableUses} uses',
                  style: const TextStyle(color: Color(0xFFE9DFFF)),
                ),
                const SizedBox(height: 18),
                _ToolPurchaseButton(
                  enabled: canBuy,
                  label: 'BUY  •  $totalPrice COINS',
                  onPressed: canBuy
                      ? () => Navigator.pop(
                          context,
                          _ToolPurchaseResult.buy(quantity),
                        )
                      : null,
                ),
                if (widget.showWatchAd) ...[
                  const SizedBox(height: 10),
                  _ToolPurchaseButton(
                    enabled: true,
                    label: 'WATCH AD  •  +1 USE',
                    onPressed: () => Navigator.pop(
                      context,
                      const _ToolPurchaseResult.watchAd(),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    AudioService.instance.playSound(AudioEffect.click);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'MAYBE LATER',
                    style: TextStyle(
                      color: Color(0xFFDCCCF0),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: -7,
            top: -12,
            child: GestureDetector(
              onTap: () {
                AudioService.instance.playSound(AudioEffect.click);
                Navigator.pop(context);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF06A), Color(0xFFE0AF00)],
                  ),
                  border: Border.all(color: const Color(0xFF9D7200), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF573400),
                  size: 23,
                ),
              ),
            ),
          ),
          const Positioned(left: -15, top: 45, child: _PurchaseCoin()),
          const Positioned(right: -13, bottom: 100, child: _PurchaseCoin()),
        ],
      ),
    );
  }
}

class _ToolPurchaseButton extends StatelessWidget {
  const _ToolPurchaseButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed == null
              ? null
              : () {
                  AudioService.instance.playSound(AudioEffect.click);
                  onPressed!();
                },
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF06A),
                    Color(0xFFFFC928),
                    Color(0xFFE5A900),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFE979), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 6,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFF553178),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF4D2C70),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseCoin extends StatelessWidget {
  const _PurchaseCoin();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.15,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF16A), Color(0xFFFFC21F), Color(0xFFE09A00)],
          ),
          border: Border.all(color: const Color(0xFFB77900), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '\$',
            style: TextStyle(
              color: Color(0xFF9A6200),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveToolPulse extends StatefulWidget {
  const _ActiveToolPulse({required this.isActive, required this.child});

  final bool isActive;
  final Widget child;

  @override
  State<_ActiveToolPulse> createState() => _ActiveToolPulseState();
}

class _ActiveToolPulseState extends State<_ActiveToolPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant _ActiveToolPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + (_controller.value * 0.08),
          child: child,
        );
      },
    );
  }
}

class _CompletionContent extends StatelessWidget {
  const _CompletionContent({
    required this.level,
    required this.reward,
    required this.showDoubleReward,
    required this.onDoubleReward,
    required this.onCollect,
  });

  final int level;
  final int reward;
  final bool showDoubleReward;
  final VoidCallback onDoubleReward;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 285,
          child: Column(
            children: [
              Text(
                'Level\nComplete!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD521),
                  fontSize: 34,
                  height: 0.96,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xFFE52B18), blurRadius: 18),
                    Shadow(
                      color: Color(0xFF9F220F),
                      offset: Offset(0, 4),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 3),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 38),
              const _RewardCoin(size: 92),
              const SizedBox(height: 2),
              Text(
                '$reward',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 4),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (showDoubleReward) ...[
          _ResultButton(
            label: 'x2 Coins',
            color: const Color(0xFFFFA51F),
            onPressed: onDoubleReward,
          ),
          const SizedBox(height: 8),
        ],
        _ResultButton(
          label: 'Continue',
          color: const Color(0xFF55D83B),
          onPressed: onCollect,
        ),
      ],
    );
  }
}

class _RewardCoin extends StatelessWidget {
  const _RewardCoin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF36A), Color(0xFFFFB800), Color(0xFFE77700)],
        ),
        border: Border.all(color: const Color(0xFFFFF1A5), width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0xAAFFB300), blurRadius: 18),
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, 7),
            blurRadius: 3,
          ),
        ],
      ),
      child: Icon(
        Icons.monetization_on,
        color: const Color(0xFFFFD21C),
        size: size * 0.55,
        shadows: const [
          Shadow(color: Color(0xFFE57900), offset: Offset(0, 3), blurRadius: 1),
        ],
      ),
    );
  }
}

class _MenuStat extends StatelessWidget {
  const _MenuStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8CF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC700), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFF7A00),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0xFF174A9C),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3A2A5E),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSlideIn extends StatefulWidget {
  const _MenuSlideIn({
    required this.begin,
    required this.reverse,
    required this.child,
  });

  final Offset begin;
  final bool reverse;
  final Widget child;

  @override
  State<_MenuSlideIn> createState() => _MenuSlideInState();
}

class _MenuSlideInState extends State<_MenuSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _position = Tween<Offset>(
      begin: widget.begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _MenuSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reverse != widget.reverse) {
      if (widget.reverse) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _position, child: widget.child);
  }
}

class _TutorialHand extends StatefulWidget {
  const _TutorialHand();

  @override
  State<_TutorialHand> createState() => _TutorialHandState();
}

class _TutorialFocusOverlay extends StatelessWidget {
  const _TutorialFocusOverlay({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TutorialFocusPainter(bottomInset: bottomInset),
    );
  }
}

class _TutorialFocusPainter extends CustomPainter {
  const _TutorialFocusPainter({required this.bottomInset});

  final double bottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final focusCenter = Offset(
      size.width / 2 - 64,
      size.height - bottomInset - 213,
    );
    final focusCircle = Rect.fromCircle(center: focusCenter, radius: 36);
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(focusCircle);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );
    canvas.drawCircle(
      focusCenter,
      36,
      Paint()
        ..color = const Color(0xFFFFC700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TutorialHandState extends State<_TutorialHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(-78, progress * 10),
          child: child,
        );
      },
      child: Align(
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: 3.141592653589793,
          child: Icon(
            Icons.touch_app,
            size: 54,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 5,
                offset: Offset(2, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelData {
  _PixelData({required this.column, required this.row, required this.color});

  final int column;
  final int row;
  Color color;
  bool destroyed = false;
  bool targeted = false;
  _PixelEffect? effect;
  double effectProgress = 0;
  _GridPoint? effectOrigin;
}

class _BugData {
  _BugData({
    required this.color,
    required this.batch,
    required this.targets,
    required this.source,
    required this.route,
  });

  final Color color;
  final _BugBatch batch;
  final List<_PixelData> targets;
  _PixelData get target => targets.first;
  final _GridPoint source;
  List<_GridPoint>? route;
  double progress = 0;
  _BugState state = _BugState.outbound;
  bool hasReturned = false;
}

enum _BugState { outbound, exploding }

class _BugBatch {
  _BugBatch({required this.color, required this.totalBugs});

  final Color color;
  final int totalBugs;
  int releasedBugs = 0;
  int completedBugs = 0;

  int get remainingBugs => totalBugs - releasedBugs;
  int get activeBugs => releasedBugs - completedBugs;
}

class _GridPoint {
  const _GridPoint(this.column, this.row);

  final int column;
  final int row;

  @override
  bool operator ==(Object other) {
    return other is _GridPoint && other.column == column && other.row == row;
  }

  @override
  int get hashCode => Object.hash(column, row);
}

class _ColorStats {
  _ColorStats({required this.originalPixels, required this.originalBugs});

  final int originalPixels;
  final int originalBugs;
  int releasedBugs = 0;
  int destroyedPixels = 0;
  int completedBugs = 0;

  int get remainingBugs => originalBugs - releasedBugs;
  int get activeBugs => releasedBugs - completedBugs;
  int get remainingPixels => originalPixels - destroyedPixels;
}

class BoomPixel extends StatelessWidget {
  const BoomPixel({
    super.key,
    required this.color,
    this.size = 20,
    this.destroyed = false,
  });

  final Color color;
  final double size;
  final bool destroyed;

  @override
  Widget build(BuildContext context) {
    if (destroyed) {
      return SizedBox(width: size, height: size);
    }

    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final light = Color.lerp(color, Colors.white, 0.25)!;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BoomPixelPainter(color: color, dark: dark, light: light),
      ),
    );
  }
}

class _BoardPixelsPainter extends CustomPainter {
  _BoardPixelsPainter({
    required this.pixels,
    required this.columns,
    required this.rows,
  });

  final List<_PixelData> pixels;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelWidth = size.width / columns;
    final pixelHeight = size.height / rows;
    for (final pixel in pixels) {
      if (pixel.destroyed) continue;
      final rect = Rect.fromLTWH(
        pixel.column * pixelWidth,
        pixel.row * pixelHeight,
        pixelWidth + 1.5,
        pixelHeight + 1.5,
      );
      _paintAnimatedPixel(canvas, rect, pixel, pixelWidth, pixelHeight);
    }
  }

  void _paintAnimatedPixel(
    Canvas canvas,
    Rect rect,
    _PixelData pixel,
    double pixelWidth,
    double pixelHeight,
  ) {
    final effect = pixel.effect;
    if (effect == null) {
      _paintBoomPixel(canvas, rect, pixel.color);
      return;
    }

    final progress = pixel.effectProgress.clamp(0.0, 1.0);
    canvas.save();
    if (effect == _PixelEffect.bomb) {
      final origin = pixel.effectOrigin;
      final horizontalDirection = origin == null
          ? 0.0
          : (pixel.column - origin.column).sign.toDouble();
      final offset = Offset(
        horizontalDirection * pixelWidth * 1.8 * progress,
        pixelHeight * (2.0 * progress + 3.0 * progress * progress),
      );
      canvas.translate(offset.dx, offset.dy);
      _paintBoomPixel(
        canvas,
        rect,
        pixel.color.withValues(alpha: 1 - progress * 0.65),
      );
    } else {
      final angle =
          sin(progress * pi * 8 + pixel.column) * 0.14 * (1 - progress);
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(angle);
      canvas.scale(1 - progress * 0.18);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      _paintBoomPixel(
        canvas,
        rect,
        pixel.color.withValues(alpha: 1 - progress),
      );
      final shardPaint = Paint()
        ..color = pixel.color.withValues(alpha: 1 - progress)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final center = rect.center;
      final shardDistance = rect.shortestSide * (0.6 + progress * 1.8);
      for (var index = 0; index < 4; index++) {
        final direction = index.isEven ? 1.0 : -1.0;
        canvas.drawLine(
          center,
          center +
              Offset(
                direction * shardDistance * (index + 1) / 2,
                (index - 1.5) * shardDistance / 2,
              ),
          shardPaint,
        );
      }
    }
    canvas.restore();
  }

  void _paintBoomPixel(Canvas canvas, Rect rect, Color color) {
    final shortestSide = rect.shortestSide;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final light = Color.lerp(color, Colors.white, 0.25)!;
    canvas.drawRect(rect, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + shortestSide * 0.18,
        rect.top + shortestSide * 0.14,
        rect.width - shortestSide * 0.43,
        shortestSide * 0.1,
      ),
      Paint()..color = light,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + shortestSide * 0.2,
        rect.bottom - shortestSide * 0.2,
        rect.width - shortestSide * 0.4,
        shortestSide * 0.08,
      ),
      Paint()..color = dark.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPixelsPainter oldDelegate) => true;
}

class _BoomPixelPainter extends CustomPainter {
  _BoomPixelPainter({
    required this.color,
    required this.dark,
    required this.light,
  });

  final Color color;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width;
    final outlinePaint = Paint()..color = dark;
    final bodyPaint = Paint()..color = color;
    final highlightPaint = Paint()..color = light;
    final shadowPaint = Paint()..color = dark.withValues(alpha: 0.45);

    canvas.drawPath(
      Path()
        ..moveTo(pixelSize * 0.12, 0)
        ..lineTo(pixelSize * 0.88, 0)
        ..lineTo(pixelSize, pixelSize * 0.12)
        ..lineTo(pixelSize, pixelSize * 0.88)
        ..lineTo(pixelSize * 0.88, pixelSize)
        ..lineTo(pixelSize * 0.12, pixelSize)
        ..lineTo(0, pixelSize * 0.88)
        ..lineTo(0, pixelSize * 0.12)
        ..close(),
      outlinePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pixelSize * 0.15, pixelSize * 0.08)
        ..lineTo(pixelSize * 0.85, pixelSize * 0.08)
        ..lineTo(pixelSize * 0.92, pixelSize * 0.15)
        ..lineTo(pixelSize * 0.92, pixelSize * 0.85)
        ..lineTo(pixelSize * 0.85, pixelSize * 0.92)
        ..lineTo(pixelSize * 0.15, pixelSize * 0.92)
        ..lineTo(pixelSize * 0.08, pixelSize * 0.85)
        ..lineTo(pixelSize * 0.08, pixelSize * 0.15)
        ..close(),
      bodyPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pixelSize * 0.18, pixelSize * 0.14)
        ..lineTo(pixelSize * 0.75, pixelSize * 0.14)
        ..lineTo(pixelSize * 0.70, pixelSize * 0.21)
        ..lineTo(pixelSize * 0.20, pixelSize * 0.21)
        ..close(),
      highlightPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pixelSize * 0.20, pixelSize * 0.80)
        ..lineTo(pixelSize * 0.82, pixelSize * 0.80)
        ..lineTo(pixelSize * 0.76, pixelSize * 0.87)
        ..lineTo(pixelSize * 0.22, pixelSize * 0.87)
        ..close(),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BoomPixelPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dark != dark ||
        oldDelegate.light != light;
  }
}

class _MovingBug extends StatelessWidget {
  const _MovingBug({required this.bug, required this.boardSize});

  final _BugData bug;
  final Size boardSize;

  @override
  Widget build(BuildContext context) {
    final route = bug.route;
    final isExploding = bug.state == _BugState.exploding;
    final position = isExploding
        ? _toBoardOffset(
            _GridPoint(bug.target.column, bug.target.row),
            boardSize,
          )
        : route == null
        ? _toBoardOffset(bug.source, boardSize)
        : _positionOnRoute(route, bug.progress, boardSize);
    final angle = route == null ? 0.0 : _routeAngle(route, bug.progress);
    const bugSize = 15.0;
    const bugRadius = bugSize / 2;

    return Positioned(
      left: position.dx - bugRadius,
      top: position.dy - bugRadius,
      child: isExploding
          ? _BugExplosion(color: bug.color, progress: bug.progress)
          : Transform.rotate(
              angle: angle,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(bug.color, BlendMode.srcIn),
                child: Image.asset(
                  'assets/bugs/BugN.png',
                  width: bugSize,
                  height: bugSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }

  double _routeAngle(List<_GridPoint> route, double progress) {
    if (route.length < 2) return 0;
    final segmentProgress = progress.clamp(0.0, 1.0) * (route.length - 1);
    final segment = segmentProgress.floor().clamp(0, route.length - 2);
    final current = route[segment];
    final next = route[segment + 1];
    return atan2(next.row - current.row, next.column - current.column) + pi / 2;
  }

  Offset _positionOnRoute(
    List<_GridPoint> route,
    double progress,
    Size boardSize,
  ) {
    if (route.length == 1) return _toBoardOffset(route.first, boardSize);
    final segmentProgress = progress.clamp(0.0, 1.0) * (route.length - 1);
    final segment = segmentProgress.floor().clamp(0, route.length - 2);
    final withinSegment = segmentProgress - segment;
    return Offset.lerp(
      _toBoardOffset(route[segment], boardSize),
      _toBoardOffset(route[segment + 1], boardSize),
      withinSegment,
    )!;
  }

  Offset _toBoardOffset(_GridPoint point, Size boardSize) {
    return Offset(
      (point.column + 0.5) / _GameState._gridColumns * boardSize.width,
      (point.row + 0.5) / _GameState._gridRows * boardSize.height,
    );
  }
}

class _BugExplosion extends StatelessWidget {
  const _BugExplosion({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    const bugSize = 18.0; // Match the reduced bug size
    final explosionSize = 8 + progress.clamp(0.0, 1.0) * 12;
    return SizedBox(
      width: bugSize,
      height: bugSize,
      child: Center(
        child: Container(
          width: explosionSize,
          height: explosionSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 1 - progress.clamp(0.0, 1.0)),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _AnimatedBatchBox extends StatefulWidget {
  const _AnimatedBatchBox({required this.child, this.isBeating = false});

  final Widget child;
  final bool isBeating;

  @override
  State<_AnimatedBatchBox> createState() => _AnimatedBatchBoxState();
}

class _AnimatedBatchBoxState extends State<_AnimatedBatchBox>
    with TickerProviderStateMixin {
  late final AnimationController _squeezeController;
  late final AnimationController _beatController;

  @override
  void initState() {
    super.initState();
    _squeezeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _beatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _updateBeatAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBatchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBeating != widget.isBeating) {
      _updateBeatAnimation();
    }
  }

  void _updateBeatAnimation() {
    if (widget.isBeating) {
      _beatController.repeat(reverse: true);
    } else {
      _beatController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _squeezeController.dispose();
    _beatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_squeezeController, _beatController]),
      child: widget.child,
      builder: (context, child) {
        final squeeze = Tween<double>(begin: 0.68, end: 1).evaluate(
          CurvedAnimation(parent: _squeezeController, curve: Curves.elasticOut),
        );
        final beat = 1 + (_beatController.value * 0.08);
        return Transform.scale(scale: squeeze * beat, child: child);
      },
    );
  }
}
