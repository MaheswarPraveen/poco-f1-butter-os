import os
import re

file_path = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\debian-butteros\shell\shell.html"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Ensure rails are RETRACTED by default (railsOpen = false)
text = re.sub(r'let railsOpen\s*=\s*true;', 'let railsOpen = false;', text)
text = re.sub(r'var railsOpen\s*=\s*true;', 'var railsOpen = false;', text)

# Ensure rail CSS defaults to retracted off-screen
rail_css_fix = """
    .icon-rail {
      position: absolute;
      top: 0;
      bottom: 0;
      width: var(--rail-width);
      background: var(--rail-bg);
      backdrop-filter: none !important;
      -webkit-backdrop-filter: none !important;
      z-index: 60;
      overflow: hidden;
      cursor: grab;
      touch-action: none;
      transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
      will-change: transform;
    }

    .rail-left {
      left: 0;
      border-right: 0.5px solid var(--rail-border);
      transform: translateX(-100%); /* Retracted off-screen by default */
    }

    .rail-right {
      right: 0;
      border-left: 0.5px solid var(--rail-border);
      transform: translateX(100%); /* Retracted off-screen by default */
    }

    .screen.rails-active .rail-left {
      transform: translateX(0);
    }

    .screen.rails-active .rail-right {
      transform: translateX(0);
    }
"""
text = re.sub(r'\.icon-rail\s*\{[\s\S]*?\.rail-right\.retracted\s*\{[^}]*\}', rail_css_fix, text)

# 2. Make home canvas and dock full width without clipping
home_canvas_fix = """
    .home-canvas {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 0 16px;
      box-sizing: border-box;
      pointer-events: auto;
      z-index: 10;
      transition: opacity 0.3s ease, transform 0.3s ease;
    }

    .system-chip {
      font-size: 8.5px;
      font-weight: 600;
      letter-spacing: 0.12em;
      color: rgba(222, 176, 86, 0.7);
      background: rgba(222, 176, 86, 0.08);
      border: 0.5px solid rgba(222, 176, 86, 0.22);
      padding: 3px 10px;
      border-radius: 10px;
      margin-top: 8px;
      white-space: nowrap;
    }

    .home-browser-tab {
      position: absolute;
      bottom: 110px;
      width: calc(100vw - 48px);
      max-width: 320px;
      height: 42px;
      background: linear-gradient(135deg, rgba(18, 17, 16, 0.40) 0%, rgba(8, 8, 10, 0.32) 100%);
      border: 0.5px solid rgba(222, 176, 86, 0.25);
      border-radius: 21px;
      display: flex;
      align-items: center;
      padding: 0 14px;
      gap: 10px;
      cursor: pointer;
      z-index: 15;
    }

    .home-permanent-dock {
      position: absolute;
      bottom: 24px;
      width: calc(100vw - 32px);
      max-width: 340px;
      height: 72px;
      display: flex;
      align-items: center;
      justify-content: space-around;
      background: rgba(14, 13, 11, 0.65);
      border: 0.5px solid rgba(222, 176, 86, 0.25);
      border-radius: 24px;
      padding: 0 8px;
      box-sizing: border-box;
      z-index: 20;
    }
"""
text = re.sub(r'\.home-canvas\s*\{[\s\S]*?\.home-permanent-dock\s*\{[^}]*\}', home_canvas_fix, text)

# 3. Clean CSS hover separation: only fine mouse gets hover, touch uses active
touch_hover_css = """
/* Separation: Mouse Hover vs Touch Press */
@media (hover: hover) and (pointer: fine) {
  .app-icon-slot:hover .app-icon-glyph,
  .dock-app-slot:hover .dock-icon-glyph {
    color: var(--accent-active);
    transform: translateY(-2px) scale(1.12);
  }
}

.dock-app-slot:active .dock-icon-glyph,
.app-icon-slot:active .app-icon-glyph {
  transform: scale(0.90);
  color: var(--accent-active);
  transition: transform 0.08s ease;
}
"""
text = text.replace('/* ButterOS Luxury Quick Dock */', touch_hover_css + '\n    /* ButterOS Luxury Quick Dock */')

# 4. Remove e.preventDefault() on pointerdown in rails
text = text.replace("railLeft.addEventListener('pointerdown', (e) => {\n        activeTarget = 'rail-left';\n        initRailDrag(e, 'rail-left');\n      });",
                    "railLeft.addEventListener('pointerdown', (e) => {\n        activeTarget = 'rail-left';\n        initRailDrag(e, 'rail-left');\n      });")
text = re.sub(r'function initRailDrag\(e, target\) \{([\s\S]*?)e\.preventDefault\(\);', r'function initRailDrag(e, target) {\1/* e.preventDefault() removed to preserve click stream */', text)

# 5. Guard screen.addEventListener('pointerdown') so it never hijacks dock icon clicks
dock_guard = """      screen.addEventListener('pointerdown', (e) => {
        // Guard: Do not intercept taps on actionable controls
        if (e.target && e.target.closest && e.target.closest('.dock-app-slot, .app-icon-slot, #butterosEventPill, #butterosEventDrawer, #homeBrowserTab, button, .interactive')) {
          return;
        }"""
text = re.sub(r'screen\.addEventListener\(\'pointerdown\',\s*\(e\)\s*=>\s*\{', dock_guard, text, count=1)

# 6. Update updateClock() to dynamically format live Date & Time
live_clock_js = """      // Live Clock & Dynamic Date Formatting
      function updateClock() {
        const now = new Date();
        const hrs = String(now.getHours()).padStart(2, '0');
        const mins = String(now.getMinutes()).padStart(2, '0');
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
        const dayName = days[now.getDay()];
        const monthName = months[now.getMonth()];
        const dayNum = now.getDate();

        const clockEl = document.getElementById('clockDisplay');
        if (clockEl) clockEl.textContent = `${hrs}:${mins}`;
        const statusEl = document.getElementById('statusTime');
        if (statusEl) statusEl.textContent = `${hrs}:${mins}`;
        const dateEl = document.getElementById('dateDisplay');
        if (dateEl) dateEl.textContent = `${dayName}, ${monthName} ${dayNum}`;
        const shadeClock = document.getElementById('shadeClock');
        if (shadeClock) shadeClock.textContent = `${hrs}:${mins}`;
      }
      setInterval(updateClock, 1000);
      updateClock();"""
text = re.sub(r'// Live Clock[\s\S]*?setInterval\(updateClock,\s*1000\);\s*updateClock\(\);', live_clock_js, text)

# 7. Inject Event Inspector HUD before </body>
hud_markup = """
  <!-- ====================================================
       BUTTEROS LIVE EVENT INSPECTOR HUD
       ==================================================== -->
  <style>
    #butterosEventPill {
      position: fixed;
      top: 5px;
      left: 50%;
      transform: translateX(-50%);
      z-index: 999999;
      height: 22px;
      padding: 0 10px;
      background: rgba(18, 16, 12, 0.94);
      border: 1px solid rgba(222, 176, 86, 0.45);
      border-radius: 11px;
      display: flex;
      align-items: center;
      gap: 6px;
      font-family: monospace;
      font-size: 9.5px;
      color: #deb056;
      cursor: pointer;
      pointer-events: auto !important;
    }
    #butterosEventPill .hud-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #00ff88;
      box-shadow: 0 0 6px #00ff88;
    }
    #butterosEventPill .hud-dot.down { background: #ffaa00; box-shadow: 0 0 6px #ffaa00; }
    #butterosEventPill .hud-dot.click { background: #00e5ff; box-shadow: 0 0 8px #00e5ff; }

    #butterosEventDrawer {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 340px;
      max-height: 48vh;
      background: rgba(10, 9, 8, 0.98);
      border-top: 1px solid rgba(222, 176, 86, 0.35);
      border-top-left-radius: 18px;
      border-top-right-radius: 18px;
      z-index: 999998;
      display: flex;
      flex-direction: column;
      box-shadow: 0 -8px 32px rgba(0, 0, 0, 0.9);
      transform: translateY(105%);
      transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      pointer-events: auto !important;
      font-family: monospace;
    }
    #butterosEventDrawer.open { transform: translateY(0); }

    .hud-header {
      height: 36px;
      padding: 0 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid rgba(222, 176, 86, 0.18);
      background: rgba(222, 176, 86, 0.05);
    }
    .hud-title { font-size: 10.5px; font-weight: 700; color: #deb056; }
    .hud-actions { display: flex; gap: 6px; }
    .hud-btn {
      background: rgba(222, 176, 86, 0.15);
      border: 1px solid rgba(222, 176, 86, 0.3);
      color: #fff;
      border-radius: 4px;
      padding: 2px 7px;
      font-size: 9.5px;
      cursor: pointer;
    }
    .hud-sequence-strip {
      padding: 5px 10px;
      background: rgba(0,0,0,0.5);
      border-bottom: 1px solid rgba(255,255,255,0.06);
      display: flex;
      align-items: center;
      gap: 5px;
      overflow-x: auto;
      font-size: 9.5px;
    }
    .hud-seq-badge { padding: 2px 5px; border-radius: 3px; font-weight: 600; white-space: nowrap; }
    .hud-logs {
      flex: 1;
      overflow-y: auto;
      padding: 5px 8px;
      display: flex;
      flex-direction: column-reverse;
      gap: 3px;
    }
    .hud-entry {
      display: grid;
      grid-template-columns: 74px 44px 80px 1fr 40px;
      align-items: center;
      gap: 4px;
      padding: 2px 5px;
      border-radius: 3px;
      background: rgba(255, 255, 255, 0.02);
      font-size: 9px;
      border-left: 3px solid transparent;
    }
    .hud-entry.ev-pointerdown, .hud-entry.ev-touchstart { border-left-color: #ffaa00; }
    .hud-entry.ev-pointerup, .hud-entry.ev-touchend { border-left-color: #00e5ff; }
    .hud-entry.ev-click { border-left-color: #00ff88; background: rgba(0, 255, 136, 0.1); }
  </style>

  <div id="butterosEventPill">
    <div class="hud-dot" id="hudDot"></div>
    <span id="hudPillText">EVENT HUD</span>
  </div>

  <div id="butterosEventDrawer">
    <div class="hud-header">
      <div class="hud-title">ButterOS Event Telemetry</div>
      <div class="hud-actions">
        <button class="hud-btn" id="btnHudClear">Clear</button>
        <button class="hud-btn" id="btnHudClose">✕</button>
      </div>
    </div>
    <div class="hud-sequence-strip" id="hudSeqStrip">
      <span style="color:#777">Tap screen to inspect event sequence</span>
    </div>
    <div class="hud-logs" id="hudLogs"></div>
  </div>

  <script>
  (function initEventHUD() {
    const pill = document.getElementById('butterosEventPill');
    const drawer = document.getElementById('butterosEventDrawer');
    const dot = document.getElementById('hudDot');
    const pillText = document.getElementById('hudPillText');
    const logsEl = document.getElementById('hudLogs');
    const seqStrip = document.getElementById('hudSeqStrip');
    const btnClear = document.getElementById('btnHudClear');
    const btnClose = document.getElementById('btnHudClose');

    let seq = [];

    pill.addEventListener('click', (e) => { e.stopPropagation(); drawer.classList.toggle('open'); });
    btnClose.addEventListener('click', (e) => { e.stopPropagation(); drawer.classList.remove('open'); });
    btnClear.addEventListener('click', (e) => { e.stopPropagation(); logsEl.innerHTML = ''; seqStrip.innerHTML = ''; seq = []; });

    const EV_LIST = ['touchstart', 'touchend', 'pointerdown', 'pointerup', 'pointercancel', 'click'];
    EV_LIST.forEach(evType => {
      window.addEventListener(evType, (e) => {
        if (e.target && (e.target.closest('#butterosEventDrawer') || e.target.closest('#butterosEventPill'))) return;

        if (evType === 'pointerdown' || evType === 'touchstart') dot.className = 'hud-dot down';
        else if (evType === 'click') dot.className = 'hud-dot click';
        else if (evType === 'pointerup' || evType === 'touchend') dot.className = 'hud-dot';

        const pType = e.pointerType || (evType.startsWith('touch') ? 'touch' : 'mouse');
        pillText.textContent = `${evType} (${pType})`;

        // Sequence
        if (evType === 'pointerdown' || evType === 'touchstart') {
          if (seq.length > 5 || Date.now() - (seq.last || 0) > 1000) seq = [];
        }
        seq.last = Date.now();
        seq.push(evType);
        seqStrip.innerHTML = seq.map(s => `<span class="hud-seq-badge" style="background:#222;color:#deb056">${s}</span>`).join(' ➔ ');

        let cx = 0, cy = 0;
        if (e.touches && e.touches.length > 0) { cx = Math.round(e.touches[0].clientX); cy = Math.round(e.touches[0].clientY); }
        else if (e.clientX !== undefined) { cx = Math.round(e.clientX); cy = Math.round(e.clientY); }

        let tStr = e.target.tagName.toLowerCase();
        if (e.target.id) tStr += '#' + e.target.id;
        else if (e.target.className && typeof e.target.className === 'string') tStr += '.' + e.target.className.split(' ')[0];

        const row = document.createElement('div');
        row.className = `hud-entry ev-${evType}`;
        row.innerHTML = `
          <div><b style="color:#deb056">${evType}</b></div>
          <div>${pType}</div>
          <div style="color:#f8df9e">${cx},${cy}</div>
          <div style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${tStr}</div>
          <div>${e.defaultPrevented ? '<span style="color:#f44">PRV</span>' : '<span style="color:#4f4">OK</span>'}</div>
        `;
        logsEl.appendChild(row);
        if (logsEl.children.length > 30) logsEl.removeChild(logsEl.firstChild);
      }, { capture: true, passive: false });
    });
  })();
  </script>
"""

text = text.replace('</body>', hud_markup + '\n</body>')

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"Patched shell.html successfully! Wrote {len(text)} bytes.")
