// BoomBug game
// Bugs crawl across a pixel canvas. Press Space or click a bug to BOOM it,
// painting nearby pixels. Fill all target pixels to complete the image.

(function () {
  'use strict';

  // ── Config ────────────────────────────────────────────────────────────────
  const COLS = 20;
  const ROWS = 20;
  const CELL = 24;          // px per cell
  const TICK_MS = 180;      // bug movement interval
  const BOOM_RADIUS = 2;    // cells painted in each direction on boom
  const MAX_BUGS = 6;
  const INITIAL_BUGS = 3;
  const INITIAL_BOOMS = 10;

  // Target pixel image (1 = must be painted, 0 = background).
  // 20×20 smiley-face pattern.
  const TARGET = [
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0],
    [0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0],
    [0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
    [0,0,1,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,0,0],
    [0,0,1,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,0,0],
    [0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
    [0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
    [0,0,1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0],
    [0,0,1,0,0,1,0,0,0,0,0,0,0,1,0,0,0,1,0,0],
    [0,0,1,0,0,0,1,1,1,1,1,1,1,0,0,0,0,1,0,0],
    [0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
    [0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0],
    [0,0,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  ];

  // Palette: bugs cycle through these colors when they boom
  const COLORS = ['#e94560','#4ecca3','#f5a623','#a855f7','#38bdf8','#fb923c'];

  // ── State ─────────────────────────────────────────────────────────────────
  let bugs = [];
  let painted = [];   // 2D array of color strings or null
  let boomCount = INITIAL_BOOMS;
  let selectedBug = null;
  let gameWon = false;
  let tickTimer = null;
  let colorIdx = 0;

  // ── Canvas setup ──────────────────────────────────────────────────────────
  const gameCanvas = document.getElementById('game-canvas');
  const overlay    = document.getElementById('overlay-canvas');
  const gctx       = gameCanvas.getContext('2d');
  const octx       = overlay.getContext('2d');
  const W = COLS * CELL;
  const H = ROWS * CELL;
  gameCanvas.width  = overlay.width  = W;
  gameCanvas.height = overlay.height = H;

  // ── Bug factory ───────────────────────────────────────────────────────────
  function makeBug(color) {
    return {
      x: Math.floor(Math.random() * COLS),
      y: Math.floor(Math.random() * ROWS),
      color: color || COLORS[colorIdx++ % COLORS.length],
      dir: randomDir(),
      id: Math.random(),
    };
  }

  function randomDir() {
    const dirs = [{dx:1,dy:0},{dx:-1,dy:0},{dx:0,dy:1},{dx:0,dy:-1}];
    return dirs[Math.floor(Math.random() * dirs.length)];
  }

  // Precompute constant derived from the static TARGET array.
  const TOTAL_TARGET = TARGET.flat().reduce((s, v) => s + v, 0);

  // ── Init ──────────────────────────────────────────────────────────────────
  function init() {
    painted = Array.from({length: ROWS}, () => Array(COLS).fill(null));
    bugs = [];
    boomCount = INITIAL_BOOMS;
    selectedBug = null;
    gameWon = false;
    colorIdx = 0;
    document.getElementById('message').classList.add('hidden');

    for (let i = 0; i < INITIAL_BUGS; i++) bugs.push(makeBug());
    updateHUD();
    drawAll();
    startTick();
  }

  // ── Tick ──────────────────────────────────────────────────────────────────
  function startTick() {
    if (tickTimer) clearInterval(tickTimer);
    tickTimer = setInterval(tick, TICK_MS);
  }

  function tick() {
    if (gameWon) return;
    bugs.forEach(bug => moveBug(bug));
    drawAll();
  }

  function moveBug(bug) {
    // Randomly change direction with 20% probability
    if (Math.random() < 0.2) bug.dir = randomDir();
    let nx = bug.x + bug.dir.dx;
    let ny = bug.y + bug.dir.dy;
    // Bounce off walls
    if (nx < 0 || nx >= COLS) { bug.dir.dx *= -1; nx = bug.x + bug.dir.dx; }
    if (ny < 0 || ny >= ROWS) { bug.dir.dy *= -1; ny = bug.y + bug.dir.dy; }
    bug.x = Math.max(0, Math.min(COLS - 1, nx));
    bug.y = Math.max(0, Math.min(ROWS - 1, ny));
  }

  // ── Boom ──────────────────────────────────────────────────────────────────
  function boom(bug) {
    if (boomCount <= 0 || gameWon) return;
    boomCount--;
    const color = bug.color;

    // Paint all target cells within BOOM_RADIUS of the bug
    for (let dy = -BOOM_RADIUS; dy <= BOOM_RADIUS; dy++) {
      for (let dx = -BOOM_RADIUS; dx <= BOOM_RADIUS; dx++) {
        const cx = bug.x + dx;
        const cy = bug.y + dy;
        if (cx < 0 || cx >= COLS || cy < 0 || cy >= ROWS) continue;
        if (TARGET[cy][cx] === 1) {
          painted[cy][cx] = color;
        }
      }
    }

    // Boom animation
    boomFlash(bug.x, bug.y, color);

    // Remove bug after boom
    bugs = bugs.filter(b => b !== bug);
    if (selectedBug === bug) selectedBug = null;

    updateHUD();
    drawAll();
    checkWin();
  }

  function boomFlash(cx, cy, color) {
    const px = cx * CELL + CELL / 2;
    const py = cy * CELL + CELL / 2;
    let r = 0;
    const maxR = (BOOM_RADIUS + 0.5) * CELL;
    const step = () => {
      octx.clearRect(0, 0, W, H);
      r += CELL * 0.35;
      octx.beginPath();
      octx.arc(px, py, r, 0, Math.PI * 2);
      octx.fillStyle = color + '55';
      octx.fill();
      octx.strokeStyle = color;
      octx.lineWidth = 2;
      octx.stroke();
      if (r < maxR) requestAnimationFrame(step);
      else { octx.clearRect(0, 0, W, H); drawOverlay(); }
    };
    requestAnimationFrame(step);
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  function drawAll() {
    drawGrid();
    drawOverlay();
  }

  function drawGrid() {
    gctx.clearRect(0, 0, W, H);

    for (let row = 0; row < ROWS; row++) {
      for (let col = 0; col < COLS; col++) {
        const x = col * CELL;
        const y = row * CELL;
        const isTarget = TARGET[row][col] === 1;
        const paintColor = painted[row][col];

        // Background
        gctx.fillStyle = '#0d1117';
        gctx.fillRect(x, y, CELL, CELL);

        // Target cell hint (dim)
        if (isTarget && !paintColor) {
          gctx.fillStyle = '#1f2937';
          gctx.fillRect(x + 1, y + 1, CELL - 2, CELL - 2);
        }

        // Painted cell
        if (paintColor) {
          gctx.fillStyle = paintColor;
          gctx.fillRect(x + 1, y + 1, CELL - 2, CELL - 2);
        }

        // Grid lines
        gctx.strokeStyle = '#1e293b';
        gctx.lineWidth = 0.5;
        gctx.strokeRect(x, y, CELL, CELL);
      }
    }
  }

  function drawOverlay() {
    octx.clearRect(0, 0, W, H);
    bugs.forEach(bug => drawBug(bug));
    if (selectedBug) drawSelector(selectedBug);
  }

  function drawBug(bug) {
    const cx = bug.x * CELL + CELL / 2;
    const cy = bug.y * CELL + CELL / 2;
    const r  = CELL * 0.38;
    // Body
    octx.beginPath();
    octx.arc(cx, cy, r, 0, Math.PI * 2);
    octx.fillStyle = bug.color;
    octx.fill();
    // Eyes
    const eyeOff = r * 0.35;
    [[-eyeOff, -eyeOff * 0.6], [eyeOff, -eyeOff * 0.6]].forEach(([ex, ey]) => {
      octx.beginPath();
      octx.arc(cx + ex, cy + ey, r * 0.22, 0, Math.PI * 2);
      octx.fillStyle = '#fff';
      octx.fill();
    });
    // Antennae
    octx.strokeStyle = bug.color;
    octx.lineWidth = 1.5;
    [[-r * 0.4, -r], [r * 0.4, -r]].forEach(([ax, ay]) => {
      octx.beginPath();
      octx.moveTo(cx + ax * 0.6, cy - r * 0.6);
      octx.lineTo(cx + ax, cy + ay);
      octx.stroke();
    });
  }

  function drawSelector(bug) {
    const cx = bug.x * CELL + CELL / 2;
    const cy = bug.y * CELL + CELL / 2;
    octx.beginPath();
    octx.arc(cx, cy, CELL * 0.48, 0, Math.PI * 2);
    octx.strokeStyle = '#fff';
    octx.lineWidth = 2;
    octx.setLineDash([4, 3]);
    octx.stroke();
    octx.setLineDash([]);
    // Boom radius indicator
    const rx = (bug.x - BOOM_RADIUS) * CELL;
    const ry = (bug.y - BOOM_RADIUS) * CELL;
    const rw = (BOOM_RADIUS * 2 + 1) * CELL;
    octx.strokeStyle = '#ffffff44';
    octx.lineWidth = 1;
    octx.strokeRect(rx, ry, rw, rw);
  }

  // ── HUD ───────────────────────────────────────────────────────────────────
  function updateHUD() {
    document.getElementById('bug-count').textContent = bugs.length;
    document.getElementById('boom-count').textContent = boomCount;
    const paintedCount = painted.flat().filter(v => v !== null).length;
    document.getElementById('painted-count').textContent = paintedCount;
    document.getElementById('total-count').textContent = TOTAL_TARGET;
  }

  // ── Win check ─────────────────────────────────────────────────────────────
  function checkWin() {
    const allPainted = TARGET.every((row, r) =>
      row.every((cell, c) => cell === 0 || painted[r][c] !== null)
    );
    if (allPainted) {
      gameWon = true;
      clearInterval(tickTimer);
      document.getElementById('message').classList.remove('hidden');
    }
  }

  // ── Input ─────────────────────────────────────────────────────────────────
  function onCanvasClick(e) {
    const rect = overlay.getBoundingClientRect();
    const scaleX = W / rect.width;
    const scaleY = H / rect.height;
    const mx = (e.clientX - rect.left) * scaleX;
    const my = (e.clientY - rect.top)  * scaleY;
    const col = Math.floor(mx / CELL);
    const row = Math.floor(my / CELL);

    // Find bug at clicked cell
    const hit = bugs.find(b => b.x === col && b.y === row);
    if (hit) {
      if (selectedBug === hit) {
        boom(hit);
      } else {
        selectedBug = hit;
        drawAll();
      }
    } else {
      selectedBug = null;
      drawAll();
    }
  }

  document.addEventListener('keydown', e => {
    if (e.code === 'Space' || e.key === ' ') {
      e.preventDefault();
      if (selectedBug) boom(selectedBug);
    }
  });

  document.getElementById('btn-add-bug').addEventListener('click', () => {
    if (bugs.length < MAX_BUGS) {
      bugs.push(makeBug());
      boomCount += 2;
      updateHUD();
      drawAll();
    }
  });

  document.getElementById('btn-boom').addEventListener('click', () => {
    if (selectedBug) boom(selectedBug);
  });

  document.getElementById('btn-reset').addEventListener('click', () => {
    clearInterval(tickTimer);
    init();
  });

  // Register the canvas click listener once, outside of init().
  overlay.style.pointerEvents = 'auto';
  overlay.addEventListener('click', onCanvasClick);

  // ── Start ─────────────────────────────────────────────────────────────────
  init();
})();
