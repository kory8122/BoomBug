class BoardPoint {
  const BoardPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

int middleSlotCountForLevel(int level) {
  if (isHardLevel(level)) return 4;
  return 3;
}

bool isHardLevel(int level) {
  final block = (level - 1) ~/ 10;
  final position = (level - 1) % 10;
  if (block.isEven) return position == 7;
  return position == 3 || position == 7;
}

bool hasReachableColor({
  required Set<BoardPoint> occupied,
  required Set<BoardPoint> colorCells,
  required int gridColumns,
  required int gridRows,
  required int middleSlotCount,
}) {
  if (colorCells.isEmpty) return false;

  final queue = <BoardPoint>[];
  final visited = <BoardPoint>{};

  final center = gridColumns ~/ 2;
  for (var index = 0; index < middleSlotCount; index++) {
    final offset = index - ((middleSlotCount - 1) / 2).round();
    final spawnX = (center + offset * 2).clamp(0, gridColumns - 1);
    final start = BoardPoint(spawnX, gridRows + 1);
    queue.add(start);
    visited.add(start);
  }

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    if (colorCells.contains(current)) {
      return true;
    }

    final deltas = const [
      BoardPoint(0, -1),
      BoardPoint(1, 0),
      BoardPoint(0, 1),
      BoardPoint(-1, 0),
    ];

    for (final delta in deltas) {
      final next = BoardPoint(current.x + delta.x, current.y + delta.y);
      if (visited.contains(next)) continue;
      if (next.x < 0 || next.x >= gridColumns) continue;
      if (next.y >= gridRows && next.y <= gridRows + 2) {
        visited.add(next);
        queue.add(next);
        continue;
      }
      if (next.y < 0 || next.y >= gridRows) continue;
      if (occupied.contains(next)) continue;
      visited.add(next);
      queue.add(next);
    }
  }

  return false;
}
