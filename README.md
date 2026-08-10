# BoomBug 🐛💥

A browser-based pixel-art game where bugs crawl across a canvas and explode to paint pixels.

## How to Play

1. Open `index.html` in any modern browser.
2. Bugs automatically crawl around the pixel canvas.
3. **Click a bug once** to select it (a dashed ring and boom-radius preview appear).
4. **Click the selected bug again**, press **Space**, or click **💥 Boom Selected** to trigger a boom.
5. The boom paints all *target* pixels within a 2-cell radius with the bug's color — then the bug disappears.
6. **Fill all target pixels** (the smiley face outline) to win!

## Controls

| Action | How |
|---|---|
| Select bug | Click the bug |
| Boom selected bug | Space / second click / Boom button |
| Add a new bug (+2 booms) | ➕ Add Bug button |
| Restart | 🔄 Reset button |

## Rules

- You start with **3 bugs** and **10 booms**.
- Each added bug costs nothing but gives +2 extra booms.
- Maximum **6 bugs** on screen at once.
- The game is won when every target pixel (shown as dark grid cells) is painted.

## Files

| File | Purpose |
|---|---|
| `index.html` | Game shell & HUD |
| `style.css` | Dark-theme styles |
| `game.js` | Game engine (bugs, canvas, boom logic) |
