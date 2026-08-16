import 'dart:async';
import 'dart:math' show Random, atan2, pi;
import 'dart:ui' as ui;

import 'package:boombug/Screen/Menu.dart';
import 'package:boombug/widgets/animated_image_button.dart';
import 'package:boombug/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Game extends StatefulWidget {
  const Game({super.key});

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> {
  static const int _gridColumns = 36;
  static const int _gridRows = 27;
  static const int _maximumActiveBugs = 15;

  int currentLevel = 1;
  int currentAnimalId = 1;
  int? previousAnimalId;
  final int totalLevels = 5;
  final Random _animalRandom = Random();
  final List<_PixelData> _pixels = [];
  final Set<_GridPoint> _occupiedCells = {};
  final List<_BugData> _activeBugs = [];
  final List<_BugBatch?> _selectedSlots = List<_BugBatch?>.filled(5, null);
  final List<_BugBatch> _availableBatches = [];
  final Map<Color, _ColorStats> _colorStats = {};
  final Map<_BugBatch, double> _spawnCooldowns = {};
  int _middleSlotCount = 3;
  bool _isGameLost = false;
  String? _levelLoadError;
  int _levelLoadToken = 0;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _startLevel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _advanceGame);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
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
    _levelLoadError = null;
    _middleSlotCount = 3 + ((currentLevel - 1) % 3);
    _loadAnimalLevel(animalId, loadToken);
  }

  int _selectAnimalId() {
    currentAnimalId = _animalRandom.nextInt(3) + 1;
    previousAnimalId = currentAnimalId;
    return currentAnimalId;
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
        _availableBatches.addAll(_createBatches(currentLevel));
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
    return pixels;
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
    final redDifference = color.r.toInt() - red;
    final greenDifference = color.g.toInt() - green;
    final blueDifference = color.b.toInt() - blue;
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
      var quantityLeft = entry.value.originalBugs;
      final largestBatch = 6 + level.clamp(1, 5);
      while (quantityLeft > 0) {
        final batchSize = quantityLeft <= largestBatch
            ? quantityLeft
            : 4 + random.nextInt(largestBatch - 3);
        batches.add(_BugBatch(color: entry.key, totalBugs: batchSize));
        quantityLeft -= batchSize;
      }
    }
    batches.shuffle(random);
    return batches;
  }

  void _selectBatch(_BugBatch batch) {
    final slotIndex = _selectedSlots
        .take(_middleSlotCount)
        .toList()
        .indexOf(null);
    if (slotIndex == -1 || !_availableBatches.contains(batch) || _isGameLost) {
      return;
    }

    setState(() {
      _availableBatches.remove(batch);
      _selectedSlots[slotIndex] = batch;
      _spawnCooldowns[batch] = 0;
    });
  }

  void _spawnBug(_BugBatch batch) {
    final stats = _colorStats[batch.color];
    final target = _pixels.where((pixel) {
      return !pixel.destroyed && !pixel.targeted && pixel.color == batch.color;
    }).firstOrNull;
    if (stats == null || batch.remainingBugs == 0 || target == null) return;

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
    target.targeted = true;
    batch.releasedBugs++;
    stats.releasedBugs++;
    _activeBugs.add(
      _BugData(
        color: batch.color,
        batch: batch,
        target: target,
        source: source,
        route: _findRoute(target, source),
      ),
    );
  }

  List<_GridPoint>? _findRoute(_PixelData target, _GridPoint start) {
    return _findRouteTo(_GridPoint(target.column, target.row), start);
  }

  List<_GridPoint>? _findRouteTo(_GridPoint destination, _GridPoint start) {
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
      if (current == destination) {
        final route = <_GridPoint>[];
        _GridPoint? step = current;
        while (step != null) {
          route.add(step);
          step = previous[step];
        }
        return route.reversed.toList();
      }

      for (final direction in directions) {
        final next = _GridPoint(
          current.column + direction.column,
          current.row + direction.row,
        );
        if (previous.containsKey(next) || !_canBugEnter(next, destination)) {
          continue;
        }
        previous[next] = current;
        queue.add(next);
      }
    }
    return null;
  }

  bool _canBugEnter(_GridPoint point, _GridPoint destination) {
    if (point == destination) return true;
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
    if (_isGameLost) return;

    var shouldAdvanceLevel = false;
    var shouldLoseLevel = false;
    var hasChanges = false;

    for (final batch in _selectedSlots.whereType<_BugBatch>().toList()) {
      final cooldown = (_spawnCooldowns[batch] ?? 0) - 0.016;
      if (batch.remainingBugs == 0 && batch.activeBugs == 0) {
        _selectedSlots[_selectedSlots.indexOf(batch)] = null;
        _spawnCooldowns.remove(batch);
        hasChanges = true;
      } else if (cooldown <= 0 && _activeBugs.length < _maximumActiveBugs) {
        _spawnBug(batch);
        _spawnCooldowns[batch] = 0.16;
        hasChanges = true;
      } else {
        _spawnCooldowns[batch] = cooldown;
      }
    }

    for (final bug in _activeBugs) {
      if (bug.state == _BugState.outbound) {
        bug.route ??= _findRoute(bug.target, bug.source);
        if (bug.route == null) continue;

        final travelDuration = (bug.route!.length - 1) * 0.12;
        bug.progress += 0.016 / travelDuration.clamp(0.12, 2.0);
        hasChanges = true;
        if (bug.progress < 1) continue;

        if (!bug.target.destroyed) {
          bug.target.destroyed = true;
          _occupiedCells.remove(_GridPoint(bug.target.column, bug.target.row));
          _colorStats[bug.color]!.destroyedPixels++;
        }
        bug.state = _BugState.exploding;
        bug.progress = 0;
      } else {
        bug.progress += 0.016 / 0.18;
        hasChanges = true;
        if (bug.progress >= 1) {
          bug.hasReturned = true;
          _colorStats[bug.color]!.completedBugs++;
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

    if (!shouldAdvanceLevel &&
        !_selectedSlots.take(_middleSlotCount).contains(null) &&
        _activeBugs.isNotEmpty &&
        _activeBugs.every((bug) => bug.route == null)) {
      shouldLoseLevel = true;
    }

    if (hasChanges || shouldAdvanceLevel || shouldLoseLevel) {
      setState(() {
        if (shouldAdvanceLevel) {
          currentLevel = currentLevel < totalLevels ? currentLevel + 1 : 1;
          _startLevel();
        } else if (shouldLoseLevel) {
          _isGameLost = true;
        }
      });
    }
  }

  BoxDecoration _boardDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.82),
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
        child: SafeArea(
          child: Stack(
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
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        );
                      },
                    ),
                    Row(
                      children: [
                        Text(
                          'Level: $currentLevel',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Selected animal: $currentAnimalId',
                          child: Container(
                            width: 42,
                            height: 42,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Image.asset(
                              'assets/animals/$currentAnimalId.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.red,
                                  size: 22,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedImageButton(
                      width: 45,
                      height: 45,
                      imagePath: 'assets/icons/menu_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
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
                                  tooltip: 'Retry level',
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => setState(_startLevel),
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
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 260,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_middleSlotCount, (index) {
                      final batch = _selectedSlots[index];
                      final color = batch?.color;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                    color: color!.computeLuminance() > 0.6
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      );
                    }),
                  ),
                ),
              ),
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
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
                        return GestureDetector(
                          onTap: !isQueueFront
                              ? null
                              : () => _selectBatch(batch),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            batch.color,
                                            BlendMode.srcIn,
                                          ),
                                          child: Image.asset(
                                            'assets/bugs/white.png',
                                            width: 34,
                                            height: 34,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Text(
                                          '${batch.remainingBugs}',
                                          style: TextStyle(
                                            color:
                                                color!.computeLuminance() > 0.6
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!isQueueFront)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0x66000000),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 340,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF24150F),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: const Color(0xFF9B5B2A),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x9900173A),
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
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
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/boom_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/plus_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                    AnimatedImageButton(
                      width: 50,
                      height: 50,

                      imagePath: 'assets/icons/strick_icon.png',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {},
                    ),
                  ],
                ),
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
  final Color color;
  bool destroyed = false;
  bool targeted = false;
}

class _BugData {
  _BugData({
    required this.color,
    required this.batch,
    required this.target,
    required this.source,
    required this.route,
  });

  final Color color;
  final _BugBatch batch;
  final _PixelData target;
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
          pixelWidth + 0.5,
          pixelHeight + 0.5,
        ),
        pixel.color,
      );
    }
  }

  void _paintBoomPixel(Canvas canvas, Rect rect, Color color) {
    final shortestSide = rect.shortestSide;
    final cornerRadius = Radius.circular(shortestSide * 0.14);
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final light = Color.lerp(color, Colors.white, 0.25)!;
    final outline = RRect.fromRectAndRadius(rect, cornerRadius);
    final body = RRect.fromRectAndRadius(
      rect.deflate(shortestSide * 0.08),
      Radius.circular(shortestSide * 0.1),
    );
    canvas.drawRRect(outline, Paint()..color = dark);
    canvas.drawRRect(body, Paint()..color = color);
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

    return Positioned(
      left: position.dx - 14,
      top: position.dy - 14,
      child: isExploding
          ? _BugExplosion(color: bug.color, progress: bug.progress)
          : Transform.rotate(
              angle: angle,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(bug.color, BlendMode.srcIn),
                child: Image.asset(
                  'assets/bugs/white.png',
                  width: 28,
                  height: 28,
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
    final size = 12 + progress.clamp(0.0, 1.0) * 18;
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 1 - progress.clamp(0.0, 1.0)),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }
}
