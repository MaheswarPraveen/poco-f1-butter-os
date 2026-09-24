"""
ButterOS Native Shell Builder v2 — 4 Surgical Strikes
A. Nuke all backdrop-filter blur → opaque smoked glass
B. Fix rails-to-drawer gesture (simplified threshold)
C. Add true free-wheel inertia for arc revolving
D. Frequency-sorted rails + A-Z drawer
"""
import os, re

html_path = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\shell_prototype.html"
target_path = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\android-launcher\assets\shell.html"

with open(html_path, "r", encoding="utf-8") as f:
    content = f.read()

# ============================================================
# STRIKE A: Nuke ALL backdrop-filter blur → opaque backgrounds
# ============================================================
# Remove every backdrop-filter line (both prefixed and unprefixed)
content = re.sub(r'^\s*-?webkit-?backdrop-filter:[^;]+;\s*$', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*backdrop-filter:[^;]+;\s*$', '', content, flags=re.MULTILINE)

# ============================================================
# Native fullscreen CSS overrides (replaces device chassis with real screen)
# ============================================================
native_css = """
    /* ====================================================
       NATIVE ANDROID POCO F1 FULLSCREEN ADAPTATION
       Zero blur. Zero box-shadow on animated elements. Pure GPU perf.
       ==================================================== */
    html, body {
      width: 100vw !important;
      height: 100vh !important;
      padding: 0 !important;
      margin: 0 !important;
      overflow: hidden !important;
      background: #020203 !important;
    }

    .viewport-wrapper {
      width: 100vw !important;
      height: 100vh !important;
      padding: 0 !important;
      margin: 0 !important;
      justify-content: flex-start !important;
      align-items: stretch !important;
    }

    .header-bar {
      display: none !important;
    }

    .device-chassis {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      border-radius: 0 !important;
      padding: 0 !important;
      margin: 0 !important;
      background: #020203 !important;
      box-shadow: none !important;
      border: none !important;
    }

    .device-chassis::before {
      display: none !important;
    }

    .waterdrop-notch {
      display: none !important;
    }

    .screen {
      width: 100vw !important;
      height: 100vh !important;
      border-radius: 0 !important;
      border: none !important;
    }

    .status-bar {
      height: 36px !important;
      padding-top: 4px !important;
    }

    .status-horn-left {
      width: 110px !important;
      height: 36px !important;
      padding-left: 14px !important;
    }

    .status-horn-right {
      width: 110px !important;
      height: 36px !important;
      padding-right: 14px !important;
    }

    /* PERF: Kill all box-shadow on animated/interactive elements */
    .rail-left, .rail-right,
    .quarter-circle-left, .quarter-circle-right,
    .drawer-top-handle,
    .dock-app-slot,
    .app-icon-slot,
    .polar-tile-block,
    .home-canvas,
    .spatial-notif-card {
      box-shadow: none !important;
    }

    /* PERF: Force hardware compositing on key layers */
    .rail-left, .rail-right {
      will-change: transform !important;
      contain: layout style paint !important;
    }

    .quarter-circle-left, .quarter-circle-right {
      will-change: transform, opacity !important;
    }

    /* PERF: Reduce transition complexity */
    .polar-tile-block {
      transition: transform 0.12s ease !important;
    }

    .tile-sector-path {
      transition: fill 0.15s ease !important;
    }
"""

content = content.replace("</style>", native_css + "\n  </style>")

# ============================================================
# STRIKE B + C + D: JavaScript fixes
# ============================================================

bridge_js = """
      // ====================================================
      // NATIVE HARDWARE HAPTIC BRIDGE
      // ====================================================
      function triggerHaptic(ms) {
        ms = ms || 15;
        if (window.ButterOS && window.ButterOS.vibrate) {
          try { window.ButterOS.vibrate(ms); } catch(e) {}
        } else if (navigator.vibrate) {
          try { navigator.vibrate(ms); } catch(e) {}
        }
      }

      // ====================================================
      // FREQUENCY TRACKING ENGINE (localStorage persistence)
      // ====================================================
      var _appFreqKey = 'butteros_app_freq';
      function getAppFreqs() {
        try {
          var d = localStorage.getItem(_appFreqKey);
          return d ? JSON.parse(d) : {};
        } catch(e) { return {}; }
      }
      function bumpAppFreq(appKey) {
        try {
          var f = getAppFreqs();
          f[appKey] = (f[appKey] || 0) + 1;
          localStorage.setItem(_appFreqKey, JSON.stringify(f));
        } catch(e) {}
      }

      // Android Hardware Back Gesture Handler
      window.handleAndroidBack = function() {
        var anyOpen = (typeof railsOpen !== 'undefined' && railsOpen) ||
                      (typeof drawerOpen !== 'undefined' && drawerOpen) ||
                      (typeof arcLeft !== 'undefined' && arcLeft && arcLeft.classList.contains('open')) ||
                      (typeof arcRight !== 'undefined' && arcRight && arcRight.classList.contains('open')) ||
                      (typeof notifModal !== 'undefined' && notifModal && notifModal.classList.contains('open'));
        if (anyOpen) {
          if (typeof drawerOpen !== 'undefined' && drawerOpen && typeof dismissDrawerToHome === 'function') dismissDrawerToHome(true);
          if (typeof railsOpen !== 'undefined' && railsOpen && typeof closeBothRails === 'function') closeBothRails();
          if (typeof closeArcLeft === 'function') closeArcLeft();
          if (typeof closeArcRight === 'function') closeArcRight();
          if (typeof closeNotifModal === 'function') closeNotifModal();
          triggerHaptic(12);
        }
      };
"""

content = content.replace("<script>", "<script>\n" + bridge_js, 1)

# ============================================================
# Replace navigator.vibrate calls with triggerHaptic
# ============================================================
content = re.sub(
    r'try\s*\{\s*if\s*\(navigator\.vibrate\)\s*navigator\.vibrate\((\d+)\);\s*\}\s*catch\(.*?\)\s*\{\}',
    r'triggerHaptic(\1)',
    content
)

# ============================================================
# STRIKE B: Fix rails-to-drawer gesture
# The issue: touchY >= rect.height - 88 check is too restrictive on full screen
# and the middle zone check requires touchY >= rect.height * 0.35 which may
# not fire properly. We need to also allow the entire middle area when rails
# are open to trigger rails-to-drawer-swipe.
# Also lower the swipe threshold from -32 to -28 for rails->drawer.
# ============================================================

# Lower the rails-to-drawer threshold from -32px to -22px
content = content.replace(
    "if (activeTarget === 'rails-to-drawer-swipe') {\n"
    "          if (currentDragY < -32) {\n"
    "            openDrawer();",
    "if (activeTarget === 'rails-to-drawer-swipe') {\n"
    "          if (currentDragY < -22) {\n"
    "            openDrawer();"
)

# Also lower the home-to-rails threshold from -26 to -20
content = content.replace(
    "if (activeTarget === 'home-to-rails-swipe') {\n"
    "          if (currentDragY < -26) {\n"
    "            openBothRails();",
    "if (activeTarget === 'home-to-rails-swipe') {\n"
    "          if (currentDragY < -20) {\n"
    "            openBothRails();"
)

# Lower the down-to-home threshold from 32 to 22
content = content.replace(
    "} else if (currentDragY > 32) {\n"
    "            closeBothRails();",
    "} else if (currentDragY > 22) {\n"
    "            closeBothRails();"
)

# Expand the middle zone detection: allow rails-to-drawer from ANYWHERE
# on screen when rails are open (not just bottom 88px or > 35% height)
old_middle_zone = """        // When Rails are open: dragging in the middle allows swiping up to App Drawer or down to Home
        if (railsOpen && !drawerOpen && touchY >= rect.height * 0.35 && touchX > 88 && touchX < (rect.width - 88)) {
          isDragging = true;
          hasDragged = false;
          activeTarget = 'rails-to-drawer-swipe';
          startX = e.clientX; startY = e.clientY;
          currentDragX = 0; currentDragY = 0;
          return;
        }"""

new_middle_zone = """        // When Rails are open: dragging ANYWHERE in the middle zone (between rails) allows swiping up to App Drawer or down to Home
        if (railsOpen && !drawerOpen && touchX > 60 && touchX < (rect.width - 60)) {
          isDragging = true;
          hasDragged = false;
          activeTarget = 'rails-to-drawer-swipe';
          startX = e.clientX; startY = e.clientY;
          currentDragX = 0; currentDragY = 0;
          return;
        }"""

content = content.replace(old_middle_zone, new_middle_zone)

# ============================================================
# STRIKE C: Add free-wheel inertia for arc revolving
# Currently when you release the arc dial it just stops dead.
# We need to track angular velocity and spin with friction on release.
# ============================================================

# Add angular velocity tracking variables after the kinetic vars
old_kinetic_vars = """      let kineticLastY = 0;
      let kineticLastTime = 0;
      let kineticScrollVel = 0; // px / ms
      let kineticRafId = null;"""

new_kinetic_vars = """      let kineticLastY = 0;
      let kineticLastTime = 0;
      let kineticScrollVel = 0; // px / ms
      let kineticRafId = null;

      // Arc revolving angular velocity tracking
      let arcLastTheta = 0;
      let arcLastTime = 0;
      let arcAngularVel = 0; // deg / ms
      let arcInertiaRafId = null;

      function stopArcInertia() {
        if (arcInertiaRafId) {
          cancelAnimationFrame(arcInertiaRafId);
          arcInertiaRafId = null;
        }
        arcAngularVel = 0;
      }

      function startArcInertia(side) {
        stopArcInertia();
        var vel = Math.max(-6, Math.min(6, arcAngularVel * 16.6)); // deg/frame
        var friction = 0.955;

        function step() {
          vel *= friction;
          if (Math.abs(vel) < 0.08) {
            stopArcInertia();
            return;
          }
          if (side === 'left') {
            revolverAngleLeft += vel;
            renderPolarGrid(svgArcLeft, true);
          } else {
            revolverAngleRight += vel;
            renderPolarGrid(svgArcRight, false);
          }
          arcInertiaRafId = requestAnimationFrame(step);
        }
        arcInertiaRafId = requestAnimationFrame(step);
      }"""

content = content.replace(old_kinetic_vars, new_kinetic_vars)

# Track angular velocity during arc drag
# In the arc-left revolve block, add velocity tracking
old_arc_left_revolve = """          // Otherwise, revolve the dial along the angular arc!
          if (Math.abs(deltaTheta) > 1.5 || isRevolving) {
            isRevolving = true;
            hasDragged = true;
            revolverAngleLeft = arcBaseRevolver + deltaTheta;
            renderPolarGrid(svgArcLeft, true);
          }
          return;"""

new_arc_left_revolve = """          // Otherwise, revolve the dial along the angular arc!
          if (Math.abs(deltaTheta) > 1.5 || isRevolving) {
            isRevolving = true;
            hasDragged = true;
            revolverAngleLeft = arcBaseRevolver + deltaTheta;
            renderPolarGrid(svgArcLeft, true);
            // Track angular velocity for free-wheel inertia
            var nowArc = performance.now();
            var dtArc = nowArc - arcLastTime;
            if (dtArc > 0 && dtArc < 100) {
              arcAngularVel = arcAngularVel * 0.3 + ((currentTheta - arcLastTheta) / dtArc) * 0.7;
            }
            arcLastTheta = currentTheta;
            arcLastTime = nowArc;
          }
          return;"""

content = content.replace(old_arc_left_revolve, new_arc_left_revolve)

# Same for arc-right
old_arc_right_revolve = """          if (Math.abs(deltaTheta) > 1.5 || isRevolving) {
            isRevolving = true;
            hasDragged = true;
            revolverAngleRight = arcBaseRevolver + deltaTheta;
            renderPolarGrid(svgArcRight, false);
          }
          return;"""

new_arc_right_revolve = """          if (Math.abs(deltaTheta) > 1.5 || isRevolving) {
            isRevolving = true;
            hasDragged = true;
            revolverAngleRight = arcBaseRevolver + deltaTheta;
            renderPolarGrid(svgArcRight, false);
            // Track angular velocity for free-wheel inertia
            var nowArc = performance.now();
            var dtArc = nowArc - arcLastTime;
            if (dtArc > 0 && dtArc < 100) {
              arcAngularVel = arcAngularVel * 0.3 + ((currentTheta - arcLastTheta) / dtArc) * 0.7;
            }
            arcLastTheta = currentTheta;
            arcLastTime = nowArc;
          }
          return;"""

content = content.replace(old_arc_right_revolve, new_arc_right_revolve)

# Add inertia launch on arc release (endDrag)
old_arc_end_left = """        if (activeTarget === 'arc-left') {
          if (!isRevolving) {
            const pushBackY = (e && peakDragY) ? (e.clientY - peakDragY) : currentDragY;
            if (currentDragY > 12 || pushBackY > 15) {
              closeArcLeft();
            }
          }
          isRevolving = false;"""

new_arc_end_left = """        if (activeTarget === 'arc-left') {
          if (!isRevolving) {
            const pushBackY = (e && peakDragY) ? (e.clientY - peakDragY) : currentDragY;
            if (currentDragY > 12 || pushBackY > 15) {
              closeArcLeft();
            }
          } else if (Math.abs(arcAngularVel) > 0.02) {
            startArcInertia('left');
          }
          isRevolving = false;"""

content = content.replace(old_arc_end_left, new_arc_end_left)

old_arc_end_right = """        } else if (activeTarget === 'arc-right') {
          if (!isRevolving) {
            const pushBackY = (e && peakDragY) ? (e.clientY - peakDragY) : currentDragY;
            if (currentDragY > 12 || pushBackY > 15) {
              closeArcRight();
            }
          }
          isRevolving = false;"""

new_arc_end_right = """        } else if (activeTarget === 'arc-right') {
          if (!isRevolving) {
            const pushBackY = (e && peakDragY) ? (e.clientY - peakDragY) : currentDragY;
            if (currentDragY > 12 || pushBackY > 15) {
              closeArcRight();
            }
          } else if (Math.abs(arcAngularVel) > 0.02) {
            startArcInertia('right');
          }
          isRevolving = false;"""

content = content.replace(old_arc_end_right, new_arc_end_right)

# Initialize arc velocity tracking on arc pointerdown
old_arc_left_pointerdown_end = """        arcStartTheta = Math.atan2(330 - localY, localX) * (180 / Math.PI);
        arcBaseRevolver = revolverAngleLeft;
      });"""

new_arc_left_pointerdown_end = """        arcStartTheta = Math.atan2(330 - localY, localX) * (180 / Math.PI);
        arcBaseRevolver = revolverAngleLeft;
        stopArcInertia();
        arcLastTheta = arcStartTheta;
        arcLastTime = performance.now();
        arcAngularVel = 0;
      });"""

content = content.replace(old_arc_left_pointerdown_end, new_arc_left_pointerdown_end, 1)

old_arc_right_pointerdown_end = """        arcStartTheta = Math.atan2(330 - localY, 330 - localX) * (180 / Math.PI);
        arcBaseRevolver = revolverAngleRight;
      });

      // Mouse wheel support"""

new_arc_right_pointerdown_end = """        arcStartTheta = Math.atan2(330 - localY, 330 - localX) * (180 / Math.PI);
        arcBaseRevolver = revolverAngleRight;
        stopArcInertia();
        arcLastTheta = arcStartTheta;
        arcLastTime = performance.now();
        arcAngularVel = 0;
      });

      // Mouse wheel support"""

content = content.replace(old_arc_right_pointerdown_end, new_arc_right_pointerdown_end, 1)

# Also initialize in the inline arc pointerdown within the screen handler (lines 3378-3382 and 3392-3396)
old_inline_arc_left = """          arcStartTheta = Math.atan2(330 - localY, localX) * (180 / Math.PI);
          arcBaseRevolver = revolverAngleLeft;
          return;"""

new_inline_arc_left = """          arcStartTheta = Math.atan2(330 - localY, localX) * (180 / Math.PI);
          arcBaseRevolver = revolverAngleLeft;
          stopArcInertia();
          arcLastTheta = arcStartTheta;
          arcLastTime = performance.now();
          arcAngularVel = 0;
          return;"""

content = content.replace(old_inline_arc_left, new_inline_arc_left, 1)

old_inline_arc_right = """          arcStartTheta = Math.atan2(330 - localY, 330 - localX) * (180 / Math.PI);
          arcBaseRevolver = revolverAngleRight;
          return;"""

new_inline_arc_right = """          arcStartTheta = Math.atan2(330 - localY, 330 - localX) * (180 / Math.PI);
          arcBaseRevolver = revolverAngleRight;
          stopArcInertia();
          arcLastTheta = arcStartTheta;
          arcLastTime = performance.now();
          arcAngularVel = 0;
          return;"""

content = content.replace(old_inline_arc_right, new_inline_arc_right, 1)

# ============================================================
# STRIKE D: Frequency-sorted rails + A-Z drawer
# Replace the ALL_APPS definition to sort by frequency for rails
# and keep alphabetical for drawer
# ============================================================

old_all_apps_block = """      const ALL_APPS = [
        // Left Rail slots (0..19)
        { key: 'terminal', name: 'Terminal' },
        { key: 'files', name: 'Files' },
        { key: 'browser', name: 'Web' },
        { key: 'settings', name: 'Settings' },
        { key: 'notes', name: 'Notes' },
        { key: 'camera', name: 'Camera' },
        { key: 'music', name: 'Music' },
        { key: 'monitor', name: 'Monitor' },
        { key: 'chat', name: 'Chat' },
        { key: 'packages', name: 'Packages' },
        { key: 'gallery', name: 'Gallery' },
        { key: 'calc', name: 'Calculator' },
        { key: 'clock', name: 'Clock' },
        { key: 'code', name: 'Code IDE' },
        { key: 'maps', name: 'Maps' },
        { key: 'battery', name: 'Power' },
        { key: 'wifi', name: 'Network' },
        { key: 'hotspot', name: 'Modem' },
        { key: 'torch', name: 'Torch' },
        { key: 'sound', name: 'Audio' },

        // Right Rail slots (20..39)
        { key: 'mail', name: 'Mail' },
        { key: 'calendar', name: 'Calendar' },
        { key: 'weather', name: 'Weather' },
        { key: 'contacts', name: 'Contacts' },
        { key: 'video', name: 'Video' },
        { key: 'mic', name: 'Recorder' },
        { key: 'shield', name: 'Security' },
        { key: 'disk', name: 'Disks' },
        { key: 'tasks', name: 'Tasks' },
        { key: 'pdf', name: 'PDF Reader' },
        { key: 'cpu', name: 'CPU Tweaks' },
        { key: 'bluetooth', name: 'Bluetooth' },
        { key: 'radio', name: 'Radio' },
        { key: 'download', name: 'Downloads' },
        { key: 'font', name: 'Fonts' },
        { key: 'game', name: 'Games' },
        { key: 'usb', name: 'USB Host' },
        { key: 'search', name: 'Finder' },
        { key: 'wayland', name: 'Wayland' },
        { key: 'help', name: 'Help' }
      ];"""

new_all_apps_block = """      // Master app catalog (unsorted)
      const _MASTER_APPS = [
        { key: 'terminal', name: 'Terminal' },
        { key: 'files', name: 'Files' },
        { key: 'browser', name: 'Web' },
        { key: 'settings', name: 'Settings' },
        { key: 'notes', name: 'Notes' },
        { key: 'camera', name: 'Camera' },
        { key: 'music', name: 'Music' },
        { key: 'monitor', name: 'Monitor' },
        { key: 'chat', name: 'Chat' },
        { key: 'packages', name: 'Packages' },
        { key: 'gallery', name: 'Gallery' },
        { key: 'calc', name: 'Calculator' },
        { key: 'clock', name: 'Clock' },
        { key: 'code', name: 'Code IDE' },
        { key: 'maps', name: 'Maps' },
        { key: 'battery', name: 'Power' },
        { key: 'wifi', name: 'Network' },
        { key: 'hotspot', name: 'Modem' },
        { key: 'torch', name: 'Torch' },
        { key: 'sound', name: 'Audio' },
        { key: 'mail', name: 'Mail' },
        { key: 'calendar', name: 'Calendar' },
        { key: 'weather', name: 'Weather' },
        { key: 'contacts', name: 'Contacts' },
        { key: 'video', name: 'Video' },
        { key: 'mic', name: 'Recorder' },
        { key: 'shield', name: 'Security' },
        { key: 'disk', name: 'Disks' },
        { key: 'tasks', name: 'Tasks' },
        { key: 'pdf', name: 'PDF Reader' },
        { key: 'cpu', name: 'CPU Tweaks' },
        { key: 'bluetooth', name: 'Bluetooth' },
        { key: 'radio', name: 'Radio' },
        { key: 'download', name: 'Downloads' },
        { key: 'font', name: 'Fonts' },
        { key: 'game', name: 'Games' },
        { key: 'usb', name: 'USB Host' },
        { key: 'search', name: 'Finder' },
        { key: 'wayland', name: 'Wayland' },
        { key: 'help', name: 'Help' }
      ];

      // RAILS: Sort by frequency (most-used first). Sensible defaults for first launch.
      const _defaultFreq = {
        'browser': 50, 'camera': 45, 'settings': 40, 'files': 38,
        'gallery': 35, 'music': 33, 'chat': 30, 'terminal': 28,
        'contacts': 25, 'mail': 23, 'calendar': 20, 'maps': 18,
        'clock': 16, 'calc': 14, 'video': 12, 'notes': 10,
        'weather': 8, 'download': 6, 'bluetooth': 4, 'wifi': 3
      };
      const _freqs = getAppFreqs();
      function _getFreq(key) {
        return (_freqs[key] || 0) + (_defaultFreq[key] || 0);
      }

      // ALL_APPS sorted by frequency for RAILS conveyor belt
      const ALL_APPS = _MASTER_APPS.slice().sort(function(a, b) {
        return _getFreq(b.key) - _getFreq(a.key);
      });

      // DRAWER_APPS sorted A-Z for the app drawer grid
      const DRAWER_APPS = _MASTER_APPS.slice().sort(function(a, b) {
        return a.name.localeCompare(b.name);
      });"""

content = content.replace(old_all_apps_block, new_all_apps_block)

# ============================================================
# Boost kinetic inertia for rails conveyor (less friction, higher cap)
# ============================================================
content = content.replace(
    "let vel = Math.max(-28, Math.min(28, initialVelocity * 16.6)); // px/frame\n"
    "        const friction = 0.958; // silky watch rotor deceleration",
    "let vel = Math.max(-40, Math.min(40, initialVelocity * 18)); // px/frame — boosted\n"
    "        const friction = 0.968; // smoother longer coast"
)

# Lower the stop threshold
content = content.replace(
    "if (Math.abs(vel) < 0.2) {\n"
    "             stopKineticInertia();",
    "if (Math.abs(vel) < 0.12) {\n"
    "             stopKineticInertia();"
)

# Lower the velocity gate for kinetic launch
content = content.replace(
    "if (Math.abs(kineticScrollVel) > 0.12) {\n"
    "            startKineticInertia(activeTarget, kineticScrollVel);",
    "if (Math.abs(kineticScrollVel) > 0.06) {\n"
    "            startKineticInertia(activeTarget, kineticScrollVel);"
)

# ============================================================
# Enhance dock icons to launch native Android apps
# ============================================================
old_dock_click = """      // Permanent Dock Icons Click -> Open respective app with spring animation & Dynamic Island
      document.querySelectorAll('.dock-app-slot').forEach(slot => {
        slot.onclick = (e) => {
          e.stopPropagation();
          const appName = slot.getAttribute('title') || 'App';
          const appKey = slot.getAttribute('data-app') || 'terminal';
          slot.style.transform = 'scale(0.85)';
          setTimeout(() => { slot.style.transform = ''; }, 160);
          triggerIsland(appName, 'Opening...', SVG_ICONS[appKey] || SVG_ICONS.terminal);
        };
      });"""

new_dock_click = """      // Permanent Dock Icons Click -> Launch Native Android Intent
      document.querySelectorAll('.dock-app-slot').forEach(slot => {
        slot.onclick = (e) => {
          e.stopPropagation();
          const appName = slot.getAttribute('title') || 'App';
          const appKey = slot.getAttribute('data-app') || 'terminal';
          slot.style.transform = 'scale(0.85)';
          setTimeout(() => { slot.style.transform = ''; }, 160);
          triggerHaptic(20);
          bumpAppFreq(appKey);
          triggerIsland(appName, 'Opening...', SVG_ICONS[appKey] || SVG_ICONS.terminal);
          if (window.ButterOS) {
            if (appKey === 'camera') { try { window.ButterOS.openCamera(); return; } catch(err) {} }
            else if (appKey === 'browser') { try { window.ButterOS.launchApp('com.android.chrome'); return; } catch(err) {} }
            else if (appKey === 'settings') { try { window.ButterOS.openSettings(); return; } catch(err) {} }
            else if (appKey === 'phone' || appKey === 'dialer') { try { window.ButterOS.openDialer(); return; } catch(err) {} }
            else if (appKey === 'terminal') { try { window.ButterOS.launchApp('com.termux'); return; } catch(err) {} }
          }
        };
      });"""

content = content.replace(old_dock_click, new_dock_click)

# ============================================================
# Enhance Home Browser Tab to launch Chrome
# ============================================================
old_browser_tab = """      // Home Browser Tab Click -> Open Butter Web
      document.getElementById('homeBrowserTab').onclick = (e) => {
        e.stopPropagation();
        const tab = document.getElementById('homeBrowserTab');
        tab.style.transform = 'scale(0.95)';
        setTimeout(() => { tab.style.transform = ''; }, 160);
        triggerIsland('Butter Web', 'Opening Web URL...', SVG_ICONS.browser);
      };"""

new_browser_tab = """      // Home Browser Tab Click -> Open Chrome
      document.getElementById('homeBrowserTab').onclick = (e) => {
        e.stopPropagation();
        const tab = document.getElementById('homeBrowserTab');
        tab.style.transform = 'scale(0.95)';
        setTimeout(() => { tab.style.transform = ''; }, 160);
        triggerHaptic(18);
        bumpAppFreq('browser');
        triggerIsland('Butter Web', 'Opening Web...', SVG_ICONS.browser);
        if (window.ButterOS && window.ButterOS.launchApp) {
          try { window.ButterOS.launchApp('com.android.chrome'); } catch(err) {}
        }
      };"""

content = content.replace(old_browser_tab, new_browser_tab)

# ============================================================
# Enhance app drawer icon clicks to launch native apps + frequency tracking
# ============================================================
old_drawer_click = """        slot.onclick = (e) => {
          if (hasDragged) return;
          e.stopPropagation();
          slot.style.transform += ' scale(0.86)';
          setTimeout(() => { if (drawerOpen) renderConveyor(); }, 150);
          const glyphSvg = SVG_ICONS[app.key] || SVG_ICONS.terminal;
          triggerIsland(app.name, 'Opening...', glyphSvg);
          if (drawerOpen) {
            setTimeout(() => { if (drawerOpen) dismissDrawerToHome(true); }, 250);
          }
        };"""

new_drawer_click = """        slot.onclick = (e) => {
          if (hasDragged) return;
          e.stopPropagation();
          slot.style.transform += ' scale(0.86)';
          setTimeout(() => { if (drawerOpen) renderConveyor(); }, 150);
          triggerHaptic(20);
          bumpAppFreq(app.key);
          const glyphSvg = SVG_ICONS[app.key] || SVG_ICONS.terminal;
          triggerIsland(app.name, 'Opening...', glyphSvg);
          if (window.ButterOS) {
            if (app.key === 'camera') { try { window.ButterOS.openCamera(); } catch(err) {} }
            else if (app.key === 'settings') { try { window.ButterOS.openSettings(); } catch(err) {} }
            else if (app.key === 'browser') { try { window.ButterOS.launchApp('com.android.chrome'); } catch(err) {} }
            else if (app.key === 'calc') { try { window.ButterOS.launchApp('com.google.android.calculator'); } catch(err) {} }
            else if (app.key === 'clock') { try { window.ButterOS.launchApp('com.google.android.deskclock'); } catch(err) {} }
            else if (app.key === 'calendar') { try { window.ButterOS.launchApp('com.google.android.calendar'); } catch(err) {} }
            else if (app.key === 'gallery') { try { window.ButterOS.launchApp('com.google.android.apps.photos'); } catch(err) {} }
            else if (app.key === 'mail') { try { window.ButterOS.launchApp('com.google.android.gm'); } catch(err) {} }
            else if (app.key === 'maps') { try { window.ButterOS.launchApp('com.google.android.apps.maps'); } catch(err) {} }
            else if (app.key === 'music') { try { window.ButterOS.launchApp('com.google.android.apps.youtube.music'); } catch(err) {} }
            else if (app.key === 'video') { try { window.ButterOS.launchApp('com.google.android.youtube'); } catch(err) {} }
            else if (app.key === 'files') { try { window.ButterOS.launchApp('com.google.android.documentsui'); } catch(err) {} }
            else if (app.key === 'terminal') { try { window.ButterOS.launchApp('com.termux'); } catch(err) {} }
            else if (app.key === 'contacts') { try { window.ButterOS.launchApp('com.google.android.contacts'); } catch(err) {} }
            else if (app.key === 'weather') { try { window.ButterOS.launchApp('com.google.android.apps.weather'); } catch(err) {} }
          }
          if (drawerOpen) {
            setTimeout(() => { if (drawerOpen) dismissDrawerToHome(true); }, 250);
          }
        };"""

content = content.replace(old_drawer_click, new_drawer_click)

# ============================================================
# WRITE OUTPUT
# ============================================================
os.makedirs(os.path.dirname(target_path), exist_ok=True)
with open(target_path, "w", encoding="utf-8") as f:
    f.write(content)

# Verify blur removal
blur_count = content.count('backdrop-filter')
print(f"Native shell v2 created: {target_path}")
print(f"Size: {len(content)} bytes")
print(f"Remaining backdrop-filter occurrences: {blur_count}")
print(f"triggerHaptic calls: {content.count('triggerHaptic')}")
print(f"bumpAppFreq calls: {content.count('bumpAppFreq')}")
print(f"startArcInertia calls: {content.count('startArcInertia')}")
