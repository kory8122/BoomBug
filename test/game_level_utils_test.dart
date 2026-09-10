import 'package:boombug/game_level_utils.dart';
import 'package:boombug/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boombug/level_system.dart';

void main() {
  test('a color with no open route is not playable', () {
    final occupied = <BoardPoint>{
      for (var x = 0; x < 8; x++)
        for (var y = 0; y < 8; y++)
          if (x == 0 || x == 7 || y == 0 || y == 7) BoardPoint(x, y),
    };
    final colorCells = <BoardPoint>{
      const BoardPoint(3, 3),
      const BoardPoint(3, 4),
      const BoardPoint(4, 3),
      const BoardPoint(4, 4),
    };

    expect(
      hasReachableColor(
        occupied: occupied,
        colorCells: colorCells,
        gridColumns: 8,
        gridRows: 8,
        middleSlotCount: 3,
      ),
      isFalse,
    );
  });

  test('a color with an open route is playable', () {
    final occupied = <BoardPoint>{
      const BoardPoint(0, 0),
      const BoardPoint(0, 1),
      const BoardPoint(0, 2),
      const BoardPoint(1, 2),
      const BoardPoint(2, 2),
      const BoardPoint(2, 1),
      const BoardPoint(2, 0),
      const BoardPoint(1, 0),
    };
    final colorCells = <BoardPoint>{
      const BoardPoint(6, 6),
      const BoardPoint(6, 5),
      const BoardPoint(5, 6),
    };

    expect(
      hasReachableColor(
        occupied: occupied,
        colorCells: colorCells,
        gridColumns: 8,
        gridRows: 8,
        middleSlotCount: 3,
      ),
      isTrue,
    );
  });

  test('difficulty increases smoothly across the 1000-level progression', () {
    final early = DifficultyManager.forLevel(1);
    final mid = DifficultyManager.forLevel(100);
    final late = DifficultyManager.forLevel(500);
    final finalStage = DifficultyManager.forLevel(1000);

    expect(early.gridSize, 12);
    expect(mid.gridSize >= early.gridSize, isTrue);
    expect(late.gridSize >= mid.gridSize, isTrue);
    expect(finalStage.gridSize >= late.gridSize, isTrue);
    expect(finalStage.maxColors >= late.maxColors, isTrue);
    expect(finalStage.bugCount >= late.bugCount, isTrue);
  });

  test('validator marks an unreachable color setup as invalid', () {
    final pixels = <PixelCell>[
      const PixelCell(x: 0, y: 0, colorId: 1),
      const PixelCell(x: 0, y: 1, colorId: 1),
      const PixelCell(x: 1, y: 0, colorId: 1),
      const PixelCell(x: 1, y: 1, colorId: 1),
      const PixelCell(x: 7, y: 7, colorId: 2),
      const PixelCell(x: 7, y: 6, colorId: 2),
      const PixelCell(x: 6, y: 7, colorId: 2),
    ];
    final level = PixelLevel(
      gridColumns: 8,
      gridRows: 8,
      cells: pixels,
      sourceImageId: 1,
      seed: 100,
      difficulty: DifficultyManager.forLevel(100),
    );

    final result = LevelValidator.validate(level);
    expect(result.isValid, isFalse);
    expect(result.reasons.isNotEmpty, isTrue);
  });

  test('slot counts follow the easy, medium, and hard progression', () {
    expect(middleSlotCountForLevel(1), 3);
    expect(middleSlotCountForLevel(79), 3);
    expect(middleSlotCountForLevel(80), 4);
    expect(middleSlotCountForLevel(119), 4);
    expect(middleSlotCountForLevel(120), 5);
    expect(middleSlotCountForLevel(500), 5);
  });

  test('saved selected level is preserved after load', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'progress.level': 123});

    final store = ProgressStore.instance;
    await store.load();

    expect(store.level, 123);
  });
}
