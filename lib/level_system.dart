export 'game_level_utils.dart';

import 'dart:math' as math;

import 'package:boombug/game_level_utils.dart';

class DifficultySettings {
  const DifficultySettings({
    required this.levelStart,
    required this.levelEnd,
    required this.stage,
    required this.stageLabel,
    required this.gridSize,
    required this.maxColors,
    required this.pixelDensity,
    required this.bugCount,
    required this.pathComplexity,
    required this.obstacleCount,
    required this.mistakeAllowance,
    required this.optionalTimeLimit,
    required this.timeLimitSeconds,
  });

  final int levelStart;
  final int levelEnd;
  final int stage;
  final String stageLabel;
  final int gridSize;
  final int maxColors;
  final int pixelDensity;
  final int bugCount;
  final int pathComplexity;
  final int obstacleCount;
  final int mistakeAllowance;
  final bool optionalTimeLimit;
  final int timeLimitSeconds;
}

class DifficultyManager {
  static const List<_DifficultyStage> _stages = [
    _DifficultyStage(
      stage: 1,
      label: 'Beginner',
      levelStart: 1,
      levelEnd: 50,
      minGridSize: 12,
      maxGridSize: 12,
      minColors: 3,
      maxColors: 4,
      minPixelDensity: 18,
      maxPixelDensity: 28,
      minBugCount: 1,
      maxBugCount: 3,
      minPathComplexity: 1,
      maxPathComplexity: 2,
      minObstacleCount: 0,
      maxObstacleCount: 1,
      minMistakeAllowance: 4,
      maxMistakeAllowance: 5,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 2,
      label: 'Easy',
      levelStart: 51,
      levelEnd: 100,
      minGridSize: 14,
      maxGridSize: 14,
      minColors: 4,
      maxColors: 4,
      minPixelDensity: 24,
      maxPixelDensity: 32,
      minBugCount: 2,
      maxBugCount: 4,
      minPathComplexity: 2,
      maxPathComplexity: 3,
      minObstacleCount: 0,
      maxObstacleCount: 2,
      minMistakeAllowance: 3,
      maxMistakeAllowance: 4,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 3,
      label: 'Easy+',
      levelStart: 101,
      levelEnd: 150,
      minGridSize: 16,
      maxGridSize: 16,
      minColors: 4,
      maxColors: 5,
      minPixelDensity: 28,
      maxPixelDensity: 38,
      minBugCount: 2,
      maxBugCount: 5,
      minPathComplexity: 2,
      maxPathComplexity: 4,
      minObstacleCount: 1,
      maxObstacleCount: 2,
      minMistakeAllowance: 3,
      maxMistakeAllowance: 4,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 4,
      label: 'Medium',
      levelStart: 151,
      levelEnd: 200,
      minGridSize: 18,
      maxGridSize: 18,
      minColors: 5,
      maxColors: 5,
      minPixelDensity: 34,
      maxPixelDensity: 44,
      minBugCount: 3,
      maxBugCount: 5,
      minPathComplexity: 3,
      maxPathComplexity: 5,
      minObstacleCount: 1,
      maxObstacleCount: 3,
      minMistakeAllowance: 2,
      maxMistakeAllowance: 3,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 5,
      label: 'Medium+',
      levelStart: 201,
      levelEnd: 250,
      minGridSize: 20,
      maxGridSize: 20,
      minColors: 5,
      maxColors: 6,
      minPixelDensity: 38,
      maxPixelDensity: 48,
      minBugCount: 3,
      maxBugCount: 6,
      minPathComplexity: 4,
      maxPathComplexity: 6,
      minObstacleCount: 2,
      maxObstacleCount: 4,
      minMistakeAllowance: 2,
      maxMistakeAllowance: 3,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 6,
      label: 'Hard',
      levelStart: 251,
      levelEnd: 300,
      minGridSize: 22,
      maxGridSize: 22,
      minColors: 6,
      maxColors: 6,
      minPixelDensity: 42,
      maxPixelDensity: 52,
      minBugCount: 4,
      maxBugCount: 7,
      minPathComplexity: 5,
      maxPathComplexity: 7,
      minObstacleCount: 2,
      maxObstacleCount: 5,
      minMistakeAllowance: 2,
      maxMistakeAllowance: 3,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 7,
      label: 'Hard+',
      levelStart: 301,
      levelEnd: 350,
      minGridSize: 24,
      maxGridSize: 24,
      minColors: 6,
      maxColors: 7,
      minPixelDensity: 46,
      maxPixelDensity: 56,
      minBugCount: 5,
      maxBugCount: 8,
      minPathComplexity: 6,
      maxPathComplexity: 8,
      minObstacleCount: 3,
      maxObstacleCount: 6,
      minMistakeAllowance: 1,
      maxMistakeAllowance: 2,
      optionalTimeLimit: false,
    ),
    _DifficultyStage(
      stage: 8,
      label: 'Very Hard',
      levelStart: 351,
      levelEnd: 400,
      minGridSize: 26,
      maxGridSize: 26,
      minColors: 7,
      maxColors: 8,
      minPixelDensity: 50,
      maxPixelDensity: 60,
      minBugCount: 6,
      maxBugCount: 9,
      minPathComplexity: 7,
      maxPathComplexity: 9,
      minObstacleCount: 4,
      maxObstacleCount: 7,
      minMistakeAllowance: 1,
      maxMistakeAllowance: 2,
      optionalTimeLimit: true,
    ),
    _DifficultyStage(
      stage: 9,
      label: 'Expert',
      levelStart: 401,
      levelEnd: 450,
      minGridSize: 28,
      maxGridSize: 30,
      minColors: 8,
      maxColors: 9,
      minPixelDensity: 54,
      maxPixelDensity: 66,
      minBugCount: 7,
      maxBugCount: 10,
      minPathComplexity: 8,
      maxPathComplexity: 10,
      minObstacleCount: 5,
      maxObstacleCount: 8,
      minMistakeAllowance: 1,
      maxMistakeAllowance: 2,
      optionalTimeLimit: true,
    ),
    _DifficultyStage(
      stage: 10,
      label: 'Master',
      levelStart: 451,
      levelEnd: 500,
      minGridSize: 30,
      maxGridSize: 32,
      minColors: 9,
      maxColors: 10,
      minPixelDensity: 58,
      maxPixelDensity: 70,
      minBugCount: 8,
      maxBugCount: 12,
      minPathComplexity: 9,
      maxPathComplexity: 10,
      minObstacleCount: 6,
      maxObstacleCount: 9,
      minMistakeAllowance: 1,
      maxMistakeAllowance: 1,
      optionalTimeLimit: true,
    ),
  ];

  static DifficultySettings forLevel(int levelNumber) {
    final safeLevel = levelNumber.clamp(1, 500);
    final stageIndex = ((safeLevel - 1) ~/ 100).clamp(0, _stages.length - 1);
    final stage = _stages[stageIndex];
    final progress = _progressWithinStage(safeLevel, stage);

    final gridSize = _lerpInt(stage.minGridSize, stage.maxGridSize, progress);
    final maxColors = _lerpInt(stage.minColors, stage.maxColors, progress);
    final pixelDensity = _lerpInt(
      stage.minPixelDensity,
      stage.maxPixelDensity,
      progress,
    );
    final bugCount = _lerpInt(stage.minBugCount, stage.maxBugCount, progress);
    final pathComplexity = _lerpInt(
      stage.minPathComplexity,
      stage.maxPathComplexity,
      progress,
    );
    final obstacleCount = _lerpInt(
      stage.minObstacleCount,
      stage.maxObstacleCount,
      progress,
    );
    final mistakeAllowance = _lerpInt(
      stage.minMistakeAllowance,
      stage.maxMistakeAllowance,
      progress,
    );

    return DifficultySettings(
      levelStart: stage.levelStart,
      levelEnd: stage.levelEnd,
      stage: stage.stage,
      stageLabel: stage.label,
      gridSize: gridSize,
      maxColors: maxColors,
      pixelDensity: pixelDensity,
      bugCount: bugCount,
      pathComplexity: pathComplexity,
      obstacleCount: obstacleCount,
      mistakeAllowance: mistakeAllowance,
      optionalTimeLimit: stage.optionalTimeLimit || safeLevel >= 801,
      timeLimitSeconds: _timeLimitForLevel(safeLevel),
    );
  }

  static double _progressWithinStage(int levelNumber, _DifficultyStage stage) {
    final range = stage.levelEnd - stage.levelStart + 1;
    if (range <= 1) return 1.0;
    return ((levelNumber - stage.levelStart) / (range - 1)).clamp(0.0, 1.0);
  }

  static int _lerpInt(int start, int end, double progress) {
    return ((start + (end - start) * progress)).round();
  }

  static int _timeLimitForLevel(int levelNumber) {
    if (levelNumber < 801) return 0;
    if (levelNumber < 901) return 75 - ((levelNumber - 800) ~/ 10).clamp(0, 20);
    return 55 - ((levelNumber - 900) ~/ 10).clamp(0, 15);
  }
}

class _DifficultyStage {
  const _DifficultyStage({
    required this.stage,
    required this.label,
    required this.levelStart,
    required this.levelEnd,
    required this.minGridSize,
    required this.maxGridSize,
    required this.minColors,
    required this.maxColors,
    required this.minPixelDensity,
    required this.maxPixelDensity,
    required this.minBugCount,
    required this.maxBugCount,
    required this.minPathComplexity,
    required this.maxPathComplexity,
    required this.minObstacleCount,
    required this.maxObstacleCount,
    required this.minMistakeAllowance,
    required this.maxMistakeAllowance,
    required this.optionalTimeLimit,
  });

  final int stage;
  final String label;
  final int levelStart;
  final int levelEnd;
  final int minGridSize;
  final int maxGridSize;
  final int minColors;
  final int maxColors;
  final int minPixelDensity;
  final int maxPixelDensity;
  final int minBugCount;
  final int maxBugCount;
  final int minPathComplexity;
  final int maxPathComplexity;
  final int minObstacleCount;
  final int maxObstacleCount;
  final int minMistakeAllowance;
  final int maxMistakeAllowance;
  final bool optionalTimeLimit;
}

class PixelCell {
  const PixelCell({required this.x, required this.y, required this.colorId});

  final int x;
  final int y;
  final int colorId;
}

class PixelLevel {
  PixelLevel({
    required this.gridColumns,
    required this.gridRows,
    required this.cells,
    required this.sourceImageId,
    required this.seed,
    required this.difficulty,
    this.bugs = const [],
    this.obstacles = const [],
  });

  final int gridColumns;
  final int gridRows;
  final List<PixelCell> cells;
  final int sourceImageId;
  final int seed;
  final DifficultySettings difficulty;
  final List<BugDefinition> bugs;
  final List<BoardPoint> obstacles;
}

class BugDefinition {
  const BugDefinition({
    required this.colorId,
    required this.start,
    required this.path,
    required this.priority,
  });

  final int colorId;
  final BoardPoint start;
  final List<BoardPoint> path;
  final int priority;
}

class LevelValidationResult {
  const LevelValidationResult({required this.isValid, required this.reasons});

  final bool isValid;
  final List<String> reasons;
}

class LevelValidator {
  static LevelValidationResult validate(PixelLevel level) {
    final reasons = <String>[];

    if (level.cells.isEmpty) {
      reasons.add('No pixels were generated for the level.');
    }

    final colorIds = level.cells.map((cell) => cell.colorId).toSet();
    if (colorIds.length < 2) {
      reasons.add('The level does not contain enough distinct color regions.');
    }

    if (level.cells.length < _minimumPixelCount(level.difficulty)) {
      reasons.add('The image is too sparse to remain recognizable.');
    }

    if (level.cells.any((cell) => cell.colorId <= 0 || cell.colorId > 10)) {
      reasons.add('A pixel color is outside the allowed palette range.');
    }

    final reachable = _hasReachableColorRegion(level);
    if (!reachable) {
      reasons.add('No color region can be reached from the spawn area.');
    }

    final bugPathsValid = _allBugPathsAreValid(level);
    if (!bugPathsValid) {
      reasons.add('At least one bug path is invalid.');
    }

    return LevelValidationResult(isValid: reasons.isEmpty, reasons: reasons);
  }

  static int _minimumPixelCount(DifficultySettings difficulty) {
    final densityFactor = difficulty.pixelDensity / 100.0;
    final expected =
        (difficulty.gridSize * difficulty.gridSize * densityFactor * 0.18)
            .round();
    return math.max(12, expected);
  }

  static bool _hasReachableColorRegion(PixelLevel level) {
    final occupied = <BoardPoint>{
      for (final cell in level.cells) BoardPoint(cell.x, cell.y),
    };

    if (level.cells.isEmpty) return false;

    final spawnPoints = <BoardPoint>[];
    final centerX = level.gridColumns ~/ 2;
    for (var offset = 0; offset < level.difficulty.bugCount; offset++) {
      final x = (centerX + offset - (level.difficulty.bugCount ~/ 2)).clamp(
        0,
        level.gridColumns - 1,
      );
      spawnPoints.add(BoardPoint(x, level.gridRows - 1));
    }

    final seen = <BoardPoint>{};
    final queue = List<BoardPoint>.from(spawnPoints);
    for (final point in spawnPoints) {
      seen.add(point);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final step in const [
        BoardPoint(0, -1),
        BoardPoint(1, 0),
        BoardPoint(0, 1),
        BoardPoint(-1, 0),
      ]) {
        final next = BoardPoint(current.x + step.x, current.y + step.y);
        if (next.x < 0 || next.x >= level.gridColumns) continue;
        if (next.y < 0 || next.y >= level.gridRows) continue;
        if (seen.contains(next) || occupied.contains(next)) continue;
        seen.add(next);
        queue.add(next);
      }
    }

    final reachableColorIds = <int>{};
    for (final cell in level.cells) {
      if (!occupied.contains(BoardPoint(cell.x, cell.y))) continue;
      final point = BoardPoint(cell.x, cell.y);
      if (seen.contains(point)) {
        reachableColorIds.add(cell.colorId);
      }
    }

    return reachableColorIds.isNotEmpty;
  }

  static bool _allBugPathsAreValid(PixelLevel level) {
    for (final bug in level.bugs) {
      if (bug.path.isEmpty) return false;
      if (bug.start.x < 0 || bug.start.x >= level.gridColumns) return false;
      if (bug.start.y < 0 || bug.start.y >= level.gridRows) return false;
      for (final point in bug.path) {
        if (point.x < 0 || point.x >= level.gridColumns) return false;
        if (point.y < 0 || point.y >= level.gridRows) return false;
      }
    }
    return true;
  }
}

class LevelManager {
  static PixelLevel generateLevel(int levelNumber) {
    final difficulty = DifficultyManager.forLevel(levelNumber);
    final sourceImageId = ImageLevelGenerator.selectSourceImageId(levelNumber);
    final cells = ImageLevelGenerator.generateProceduralCells(
      levelNumber,
      sourceImageId,
      difficulty,
    );
    final level = PixelLevel(
      gridColumns: difficulty.gridSize,
      gridRows: difficulty.gridSize,
      cells: cells,
      sourceImageId: sourceImageId,
      seed: levelNumber,
      difficulty: difficulty,
      bugs: BugManager.generateBugs(
        level: difficulty,
        levelNumber: levelNumber,
        cells: cells,
      ),
      obstacles: PathGenerator.generateObstacles(
        levelNumber,
        difficulty,
        cells,
      ),
    );

    final validation = LevelValidator.validate(level);
    if (validation.isValid) {
      return level;
    }

    final retry = PixelLevel(
      gridColumns: difficulty.gridSize,
      gridRows: difficulty.gridSize,
      cells: ImageLevelGenerator.generateProceduralCells(
        levelNumber + 1,
        sourceImageId,
        difficulty,
      ),
      sourceImageId: sourceImageId,
      seed: levelNumber + 1,
      difficulty: difficulty,
      bugs: BugManager.generateBugs(
        level: difficulty,
        levelNumber: levelNumber + 1,
        cells: ImageLevelGenerator.generateProceduralCells(
          levelNumber + 1,
          sourceImageId,
          difficulty,
        ),
      ),
      obstacles: PathGenerator.generateObstacles(
        levelNumber + 1,
        difficulty,
        ImageLevelGenerator.generateProceduralCells(
          levelNumber + 1,
          sourceImageId,
          difficulty,
        ),
      ),
    );

    return LevelValidator.validate(retry).isValid ? retry : level;
  }
}

class ImageLevelGenerator {
  static const int sourceImageCount = 25;

  static int selectSourceImageId(int levelNumber) {
    final value =
        math.Random(levelNumber * 7919 + 101).nextInt(sourceImageCount) + 1;
    return value;
  }

  static List<PixelCell> generateProceduralCells(
    int levelNumber,
    int sourceImageId,
    DifficultySettings difficulty,
  ) {
    final random = math.Random(levelNumber * 131 + sourceImageId * 17 + 31);
    final cells = <PixelCell>[];
    final center = difficulty.gridSize ~/ 2;
    final scaleFactor = _imageScaleForLevel(levelNumber, difficulty);
    final radius = (difficulty.gridSize * (0.18 + (scaleFactor * 0.24)))
        .round();
    final colorCount = difficulty.maxColors.clamp(1, 10);

    final minX = (center - radius).clamp(0, difficulty.gridSize - 1);
    final maxX = (center + radius).clamp(0, difficulty.gridSize - 1);
    final minY = (center - radius).clamp(0, difficulty.gridSize - 1);
    final maxY = (center + radius).clamp(0, difficulty.gridSize - 1);

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = math.sqrt((dx * dx) + (dy * dy));
        final silhouette = distance <= radius + (sourceImageId % 3);
        final detailBoost = (difficulty.pixelDensity / 100.0) * 0.9;
        final noise =
            math.sin((x + 1) * (sourceImageId + 1) * 0.48) +
            math.cos((y + 1) * (sourceImageId + 2) * 0.52) +
            random.nextDouble() * (0.9 + detailBoost);

        final shouldEmit =
            silhouette && noise > (-0.7 + (1.0 - scaleFactor) * 0.7);
        if (!shouldEmit) continue;

        final colorId =
            ((x + y + sourceImageId + levelNumber) % colorCount) + 1;
        final densityAdjustment = difficulty.pixelDensity / 100.0;
        final densityThreshold =
            0.4 + scaleFactor * 0.55 + (sourceImageId % 5) * 0.06;
        if (random.nextDouble() > densityAdjustment * densityThreshold) {
          continue;
        }

        cells.add(PixelCell(x: x, y: y, colorId: colorId));
      }
    }

    if (cells.isEmpty) {
      cells.add(PixelCell(x: center, y: center, colorId: 1));
    }

    return cells;
  }

  static double _imageScaleForLevel(
    int levelNumber,
    DifficultySettings difficulty,
  ) {
    final normalized = ((levelNumber - 1) / 999.0).clamp(0.0, 1.0);
    final stageBoost = difficulty.gridSize / 32.0;
    return (normalized * 0.65 + stageBoost * 0.35).clamp(0.2, 1.0);
  }
}

class BugManager {
  static List<BugDefinition> generateBugs({
    required DifficultySettings level,
    required int levelNumber,
    required List<PixelCell> cells,
  }) {
    final random = math.Random(levelNumber * 911 + 17);
    final bugs = <BugDefinition>[];
    final colorIds = cells.map((cell) => cell.colorId).toSet();
    final bugCount = math.min(level.bugCount, math.max(1, colorIds.length));

    for (var index = 0; index < bugCount; index++) {
      final colorId = colorIds.elementAt(index % colorIds.length);
      final start = BoardPoint(
        (random.nextInt(level.gridSize)).clamp(0, level.gridSize - 1),
        level.gridSize - 1,
      );
      final path = <BoardPoint>[
        start,
        BoardPoint(
          (start.x + random.nextInt(3) - 1).clamp(0, level.gridSize - 1),
          (start.y - random.nextInt(level.pathComplexity + 1)).clamp(
            0,
            level.gridSize - 1,
          ),
        ),
      ];
      bugs.add(
        BugDefinition(
          colorId: colorId,
          start: start,
          path: path,
          priority: index,
        ),
      );
    }
    return bugs;
  }
}

class PathGenerator {
  static List<BoardPoint> generateObstacles(
    int levelNumber,
    DifficultySettings difficulty,
    List<PixelCell> cells,
  ) {
    if (difficulty.obstacleCount <= 0) return const [];
    final random = math.Random(levelNumber * 173 + 91);
    final obstacles = <BoardPoint>[];
    for (var index = 0; index < difficulty.obstacleCount; index++) {
      final x = random.nextInt(difficulty.gridSize);
      final y = random.nextInt(difficulty.gridSize);
      if (cells.any((cell) => cell.x == x && cell.y == y)) continue;
      obstacles.add(BoardPoint(x, y));
    }
    return obstacles;
  }
}
