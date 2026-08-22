import 'dart:async';
import 'dart:math' show Random, atan2, pi;
import 'dart:ui' as ui;

import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/widgets/animated_image_button.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:boombug/progress_store.dart';
import 'package:boombug/rewarded_ad_service.dart';
import 'package:boombug/widgets/refill_hearts_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _GameTool { bomb, plus, target }

class Game extends StatefulWidget {
  const Game({super.key});

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with WidgetsBindingObserver {
  static const int _gridColumns = 36;
  static const int _gridRows = 27;
  static const int _animalCount = 22;
  static const int _maxToolUses = 5;

  int currentLevel = 50;
  int currentAnimalId = 1;
  int? previousAnimalId;
  final int totalLevels = 1000;
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
  String? _levelLoadError;
  int _levelLoadToken = 0;
  Timer? _gameTimer;
  Timer? _heartTimer;
  final ProgressStore _progress = ProgressStore.instance;
  final RewardedAdService _rewardedAds = RewardedAdService();

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
    if (!mounted) return;
    setState(() {
      currentLevel = _progress.level;
      _coins = _progress.coins;
      _hearts = _progress.hearts;
      _startLevel();
    });
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _progress.refresh().then((_) {
      if (!mounted) return;
      setState(() {
        _hearts = _progress.hearts;
      });
    });
  }

  void _startLevel() {
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
    _activeTool = null;
    _levelLoadError = null;
    _middleSlotCount = 3;
    _loadAnimalLevel(animalId, loadToken);
  }

  void _toggleGameMenu() {
    _playClick();
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
    _playClick();
    setState(() {
      _isMenuVisible = true;
      _isMenuOpen = true;
    });
  }

  void _restartFromMenu() {
    if (_hearts <= 0) return;
    _playClick();
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

  void _retryLevel() {
    if (_hearts <= 0) return;
    _playClick();
    setState(() {
      _progress.hearts = _hearts;
      _progress.consumeHeart();
      _hearts = _progress.hearts;
      _startLevel();
    });
    _saveProgress();
  }

  void _playClick() {
    if (!_isSoundMuted) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _toggleSound() {
    final wasMuted = _isSoundMuted;
    setState(() => _isSoundMuted = !_isSoundMuted);
    if (wasMuted) _playClick();
  }

  void _toggleMusic() {
    _playClick();
    setState(() => _isMusicMuted = !_isMusicMuted);
  }

  int _selectAnimalId() {
    currentAnimalId = ((currentLevel - 1) % _animalCount) + 1;
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
      return;
    }
    setState(() => _activeTool = tool);
  }

  Future<void> _showToolPurchase(_GameTool tool) async {
    final price = _toolPrice(tool);
    final currentUses = _toolUses[tool] ?? 0;
    final availableUses = _maxToolUses - currentUses;
    if (availableUses <= 0) return;
    final selectedUses = await showDialog<int>(
      context: context,
      builder: (context) {
        var quantity = 1;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF4E2B78),
            insetPadding: const EdgeInsets.symmetric(horizontal: 64),
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            actionsPadding: const EdgeInsets.only(bottom: 12),
            actionsAlignment: MainAxisAlignment.center,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFFFC700), width: 3),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFC700),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFFFFC700),
                    overlayColor: const Color(0x33FFC700),
                    valueIndicatorColor: const Color(0xFFFF7A00),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$quantity uses - ${price * quantity} coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Slider(
                        value: quantity.toDouble(),
                        min: 1,
                        max: availableUses.toDouble(),
                        divisions: availableUses > 1 ? availableUses - 1 : null,
                        label: '$quantity',
                        onChanged: (value) {
                          setDialogState(() => quantity = value.round());
                        },
                      ),
                      Text(
                        'Choose 1-$availableUses uses',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFFFC700), width: 2),
                ),
                onPressed: _coins >= price * quantity
                    ? () => Navigator.pop(context, quantity)
                    : null,
                child: const Text('BUY'),
              ),
            ],
          ),
        );
      },
    );
    if (selectedUses == null || !mounted) return;
    final totalPrice = price * selectedUses;
    if (_coins < totalPrice) return;
    setState(() {
      _coins -= totalPrice;
      _toolUses[tool] = (currentUses + selectedUses).clamp(0, _maxToolUses);
    });
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    _progress
      ..level = currentLevel
      ..coins = _coins
      ..hearts = _hearts;
    await _progress.save();
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
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading ad...'),
          ],
        ),
      ),
    );
    final completed = await _rewardedAds.watchAds(3);
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
    if (tool == null || _isGameLost || _pixels.isEmpty) return;
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
          (pixel.column - column).abs() <= 1 &&
          (pixel.row - row).abs() <= 1;
    }).toList();
    if (pixels.isEmpty) return;
    setState(() {
      for (final pixel in pixels) {
        _destroyPixel(pixel);
      }
      _toolUses[_GameTool.bomb] = _toolUses[_GameTool.bomb]! - 1;
      _activeTool = null;
    });
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
      for (final pixel in _pixels.where((pixel) => pixel.color == color)) {
        _destroyPixel(pixel);
      }
      _activeBugs.removeWhere((bug) => bug.color == color);
      for (final batch in _availableBatches.where(
        (batch) => batch.color == color,
      )) {
        batch.releasedBugs = batch.totalBugs;
      }
      for (var index = 0; index < _selectedSlots.length; index++) {
        if (_selectedSlots[index]?.color == color) _selectedSlots[index] = null;
      }
      _availableBatches.removeWhere((batch) => batch.color == color);
      _toolUses[_GameTool.target] = _toolUses[_GameTool.target]! - 1;
      _activeTool = null;
    });
  }

  void _destroyPixel(_PixelData pixel) {
    if (pixel.destroyed) return;
    pixel.destroyed = true;
    pixel.targeted = false;
    _occupiedCells.remove(_GridPoint(pixel.column, pixel.row));
    _colorStats[pixel.color]?.destroyedPixels++;
  }

  Future<void> _loadAnimalLevel(int animalId, int loadToken) async {
    try {
      final pixels = await _generateAnimalFromAsset(animalId);
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
        _levelLoadError = null;
      });
    } catch (error) {
      if (!mounted || loadToken != _levelLoadToken) return;
      debugPrint('Unable to load assets/animals/$animalId.png: $error');
      setState(() {
        _levelLoadError = 'Image $animalId is unavailable';
      });
    }
  }

  Future<List<_PixelData>> _generateAnimalFromAsset(int animalId) async {
    final imageData = await rootBundle.load('assets/animals/$animalId.png');

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
    final bugsPerBox = level <= 100
        ? 30
        : level <= 500
        ? 18
        : 10;
    for (final entry in _colorStats.entries) {
      final totalBugs = entry.value.originalPixels;
      final batchCount = totalBugs < bugsPerBox
          ? 1
          : (totalBugs / bugsPerBox).ceil();
      final baseBatchSize = totalBugs ~/ batchCount;
      var extraBugs = totalBugs % batchCount;
      for (var index = 0; index < batchCount; index++) {
        final batchSize = baseBatchSize + (extraBugs-- > 0 ? 1 : 0);
        batches.add(_BugBatch(color: entry.key, totalBugs: batchSize));
      }
    }
    batches.shuffle(random);
    return batches;
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
    });
  }

  void _spawnBugs(_BugBatch batch) {
    if (batch.remainingBugs == 0) {
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
    final candidates =
        _pixels
            .where(
              (pixel) =>
                  !pixel.destroyed &&
                  !pixel.targeted &&
                  pixel.color == batch.color,
            )
            .toList()
          ..sort((first, second) {
            final rowOrder = first.row.compareTo(second.row);
            return rowOrder != 0
                ? rowOrder
                : first.column.compareTo(second.column);
          });
    if (batch.remainingBugs > 0) {
      _PixelData? target;
      List<_GridPoint>? route;
      for (final candidate in candidates) {
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
    if (batch.remainingBugs == 0) return false;

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
    for (final pixel in _pixels) {
      if (!pixel.destroyed &&
          !pixel.targeted &&
          pixel.color == batch.color &&
          _routeToPixel(pixel, reachableRoutes) != null) {
        return true;
      }
    }
    return false;
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
    if (_isGameLost || _isMenuVisible) return;

    var shouldAdvanceLevel = false;
    var shouldLoseLevel = false;
    var hasChanges = false;
    var shouldSaveProgress = false;

    for (final batch in _selectedSlots.whereType<_BugBatch>().toList()) {
      final cooldown = (_spawnCooldowns[batch] ?? 0) - 0.016;
      // Hide slot immediately when all bugs are released (remainingBugs == 0)
      if (batch.remainingBugs == 0) {
        _selectedSlots[_selectedSlots.indexOf(batch)] = null;
        _spawnCooldowns.remove(batch);
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

        final travelDuration = (bug.route!.length - 1) * 0.18;
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
        bug.progress += 0.016 / 0.18;
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
          _coins += 40;
          currentLevel = currentLevel < totalLevels ? currentLevel + 1 : 1;
          _startLevel();
          shouldSaveProgress = true;
        } else if (shouldLoseLevel) {
          _progress.hearts = _hearts;
          _progress.consumeHeart();
          _hearts = _progress.hearts;
          _isGameLost = true;
          _activeTool = null;
          shouldSaveProgress = true;
        }
      });
    }
    if (shouldSaveProgress) _saveProgress();
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF245B82), Color(0xFF102F50)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFFC700),
                              width: 3,
                            ),
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
                          child: Text(
                            'LEVEL $currentLevel',
                            style: const TextStyle(
                              color: Color(0xFFFFC700),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF7A4100),
                                  offset: Offset(1, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedImageButton(
                          width: 45,
                          height: 45,
                          imagePath: 'assets/icons/Setting_icon.png',
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
                                    if (_isGameLost)
                                      Center(
                                        child: IconButton(
                                          iconSize: 42,
                                          color: Colors.white,
                                          tooltip: _hearts > 0
                                              ? 'Retry level - 1 heart'
                                              : 'No hearts remaining',
                                          icon: const Icon(Icons.refresh),
                                          onPressed: _hearts > 0
                                              ? _retryLevel
                                              : null,
                                        ),
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
                              return DragTarget<_BugBatch>(
                                onWillAcceptWithDetails: (details) =>
                                    batch == null && _activeTool == null,
                                onAcceptWithDetails: (details) =>
                                    _selectBatchAt(details.data, index),
                                builder: (context, candidates, rejected) {
                                  return _AnimatedBatchBox(
                                    isBeating:
                                        batch != null && batch.activeBugs > 0,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: _slotDecoration(
                                        color,
                                        active:
                                            color != null ||
                                            candidates.isNotEmpty,
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
                                },
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
                                    ? Draggable<_BugBatch>(
                                        data: batch,
                                        feedback: _BatchDragFeedback(
                                          color: color,
                                          remainingBugs: batch.remainingBugs,
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.35,
                                          child: box,
                                        ),
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
                          'assets/icons/boom_icon.png',
                        ),
                        _buildToolButton(
                          _GameTool.plus,
                          'assets/icons/plus_icon.png',
                        ),
                        _buildToolButton(
                          _GameTool.target,
                          'assets/icons/strick_icon.png',
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
                                      icon: _isSoundMuted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                      onPressed: _toggleSound,
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
          ],
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

class _PixelData {
  _PixelData({required this.column, required this.row, required this.color});

  final int column;
  final int row;
  Color color;
  bool destroyed = false;
  bool targeted = false;
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
      _paintBoomPixel(
        canvas,
        Rect.fromLTWH(
          pixel.column * pixelWidth,
          pixel.row * pixelHeight,
          pixelWidth + 1.5,
          pixelHeight + 1.5,
        ),
        pixel.color,
      );
    }
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
    const bugSize = 18.0; // Reduced from 28
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

class _BatchDragFeedback extends StatelessWidget {
  const _BatchDragFeedback({required this.color, required this.remainingBugs});

  final Color? color;
  final int remainingBugs;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? const Color(0xFF79421F);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
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
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              offset: Offset(0, 3),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$remainingBugs',
          style: TextStyle(
            color: fill.computeLuminance() > 0.6 ? Colors.black : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
