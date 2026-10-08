import os
import re

src = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\android-launcher\assets\shell.html"
dst = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\debian-butteros\shell\shell.html"

with open(src, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Remove .header-bar in HTML
text = re.sub(r'<div class="header-bar">[\s\S]*?</div>\s*</div>\s*(?=<!-- Phone Chassis -->)', '', text)
if '<div class="header-bar">' in text:
    text = re.sub(r'<div class="header-bar">[\s\S]*?</div>', '', text)

# 2. Remove .waterdrop-notch in HTML
text = re.sub(r'<!-- Poco F1 Physical Hardware Notch Cutout[\s\S]*?<div class="waterdrop-notch" id="hardwareNotch">[\s\S]*?</div>\s*</div>', '', text)
if 'id="hardwareNotch"' in text:
    text = re.sub(r'<div class="waterdrop-notch" id="hardwareNotch">[\s\S]*?</div>\s*</div>', '', text)

# 3. Remove .rails-drawer-hint-pill in HTML
text = re.sub(r'<!-- Sleek Drawer Expansion Cue[\s\S]*?</div>', '', text)
if 'id="railsDrawerHint"' in text:
    text = re.sub(r'<div class="rails-drawer-hint-pill"[\s\S]*?</div>', '', text)

# 4. Remove .gesture-hint-card in HTML
text = re.sub(r'<div class="gesture-hint-card">[\s\S]*?</div>', '', text)

# 5. Remove .control-deck in HTML
text = re.sub(r'<!-- Quick Control Deck -->[\s\S]*?<div class="control-deck">[\s\S]*?</div>', '', text)
if 'class="control-deck"' in text:
    text = re.sub(r'<div class="control-deck">[\s\S]*?</div>', '', text)

# 6. Guard JavaScript button event listeners
text = text.replace("document.getElementById('btnOpenDrawer').onclick = toggleDrawer;", 
                    "const _bOD = document.getElementById('btnOpenDrawer'); if (_bOD) { _bOD.onclick = toggleDrawer; }")
text = text.replace("document.getElementById('btnToggleRails').onclick = toggleBothRails;", 
                    "const _bTR = document.getElementById('btnToggleRails'); if (_bTR) { _bTR.onclick = toggleBothRails; }")
text = text.replace("document.getElementById('btnOpenArcLeft').onclick = toggleArcLeft;", 
                    "const _bOAL = document.getElementById('btnOpenArcLeft'); if (_bOAL) { _bOAL.onclick = toggleArcLeft; }")
text = text.replace("document.getElementById('btnOpenArcRight').onclick = toggleArcRight;", 
                    "const _bOAR = document.getElementById('btnOpenArcRight'); if (_bOAR) { _bOAR.onclick = toggleArcRight; }")

# 7. Update BUTTEROS_NOTIFS
clean_notifs = """const BUTTEROS_NOTIFS = [
        {
          id: 'sys-1',
          app: 'System',
          iconClass: 'icon-sys',
          time: 'Just now',
          title: 'ButterOS Ready',
          body: 'Debian 13 Trixie running natively on Qualcomm SDM845.',
          actionLabel: 'Details',
          blocked: false
        },
        {
          id: 'msg-1',
          app: 'Messages',
          iconClass: 'icon-msg',
          time: '10m ago',
          title: 'Alex Rivera',
          body: 'Hey, are you free for a call this evening?',
          actionLabel: 'Reply',
          blocked: false
        },
        {
          id: 'bat-1',
          app: 'Battery',
          iconClass: 'icon-sys',
          time: '35m ago',
          title: '100% Fully Charged',
          body: 'Operating on balanced energy-aware scheduler profile.',
          actionLabel: 'Power',
          blocked: false
        },
        {
          id: 'mus-1',
          app: 'Music',
          iconClass: 'icon-git',
          time: '1h ago',
          title: 'Now Playing',
          body: 'Midnight City — M83',
          actionLabel: 'Pause',
          blocked: false
        }
      ];"""
text = re.sub(r'const BUTTEROS_NOTIFS = \[[\s\S]*?\];', clean_notifs, text)

# 8. Ensure CSS overrides at end of style tag are 100% full screen
css_replacement = """    /* ====================================================
       POCO F1 NATIVE FULL-SCREEN DISPLAY ADAPTATION
       ==================================================== */
    html, body {
      width: 100vw !important;
      height: 100vh !important;
      padding: 0 !important;
      margin: 0 !important;
      overflow: hidden !important;
      background: #000000 !important;
      user-select: none !important;
      -webkit-user-select: none !important;
    }

    .viewport-wrapper {
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      padding: 0 !important;
      margin: 0 !important;
      overflow: hidden !important;
      justify-content: flex-start !important;
      align-items: stretch !important;
      background: #000000 !important;
    }

    .header-bar, .control-deck, .rails-drawer-hint-pill, .gesture-hint-card {
      display: none !important;
    }

    .device-chassis {
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      border-radius: 0 !important;
      padding: 0 !important;
      margin: 0 !important;
      background: #000000 !important;
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
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      border-radius: 0 !important;
      border: none !important;
      background: var(--screen-bg) !important;
      overflow: hidden !important;
    }

    /* Precision Status Bar Horns flanking hardware notch (depth: 34px) */
    .status-bar {
      height: 34px !important;
      padding-top: 4px !important;
    }

    .status-horn-left {
      width: 110px !important;
      height: 34px !important;
      padding-left: 14px !important;
    }

    .status-horn-right {
      width: 110px !important;
      height: 34px !important;
      padding-right: 14px !important;
    }

    /* GPU Performance: Hardware Compositing & Strip Dynamic Box-Shadows */
    .rail-left, .rail-right {
      will-change: transform !important;
      contain: layout style !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.9) !important;
    }

    .quarter-circle-left, .quarter-circle-right {
      will-change: transform, opacity !important;
      contain: layout style !important;
      box-shadow: none !important;
    }

    .polar-tile-block {
      transition: filter 0.12s ease !important;
    }"""

text = re.sub(r'/\* ====================================================\s*POCO F1 NATIVE LAUNCHER DISPLAY ADAPTATION[\s\S]*?\.polar-tile-block\s*\{\s*transition:\s*filter 0\.12s ease !important;\s*\}', css_replacement, text)

os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(text)

print(f"Patched successfully! Wrote {len(text)} bytes to {dst}")
