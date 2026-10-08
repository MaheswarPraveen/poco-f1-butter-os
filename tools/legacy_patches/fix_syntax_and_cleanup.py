import os
import re
import subprocess

html_path = r"C:\Users\xczma\.gemini\antigravity\scratch\poco-f1-butter-os\debian-butteros\shell\shell.html"

with open(html_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Remove the syntax error fragment:
# From "const tileIconSvg = SVG_ICONS[tile.glyph]" up to and including the redundant "svgEl.appendChild(hubBtn);\n      }"
fragment_pattern = r'buildRotaryDial\(svgArcRight, false\);\s*const tileIconSvg = SVG_ICONS\[tile\.glyph\][\s\S]*?svgEl\.appendChild\(hubBtn\);\s*\}'
if re.search(fragment_pattern, text):
    text = re.sub(fragment_pattern, 'buildRotaryDial(svgArcRight, false);', text)
    print("Cleaned up orphaned buildRotaryDial fragment!")
else:
    print("Warning: fragment_pattern not matched directly, attempting line-based cleanup")
    lines = text.split('\n')
    # find lines
    start_idx = -1
    end_idx = -1
    for i, l in enumerate(lines):
        if 'const tileIconSvg = SVG_ICONS[tile.glyph]' in l and start_idx == -1 and i > 2900:
            start_idx = i
        if start_idx != -1 and 'renderPolarGrid(svgArcLeft, true);' in l:
            end_idx = i - 1
            break
    if start_idx != -1 and end_idx != -1:
        print(f"Removing lines {start_idx+1} to {end_idx+1}")
        del lines[start_idx:end_idx+1]
        text = '\n'.join(lines)

# 2. Remove the system chip ("SDM845 • BERYLLIUM • ADRENO 630")
text = re.sub(r'<div class="system-chip"[^>]*>[\s\S]*?</div>', '', text)
text = re.sub(r'\.system-chip\s*\{[^}]*\}', '', text)
print("Removed system-chip completely from HTML and CSS!")

# 3. Add zero-latency pointerup + click handlers for dock slots
dock_tap_code = """      // Permanent Dock Icons Click & Touch Tap -> Instant Native App Launch
      document.querySelectorAll('.dock-app-slot').forEach(slot => {
        let tapStartY = 0;
        let tapStartX = 0;

        slot.addEventListener('pointerdown', (e) => {
          e.stopPropagation();
          tapStartX = e.clientX;
          tapStartY = e.clientY;
        }, { passive: true });

        const launchSlot = (e) => {
          if (e) { e.stopPropagation(); }
          const appKey = slot.getAttribute('data-app') || 'terminal';
          const app = MASTER_APP_CATALOG.find(a => a.key === appKey) || { key: appKey, name: slot.getAttribute('title') || 'App' };
          slot.style.transform = 'scale(0.85)';
          setTimeout(() => { slot.style.transform = ''; }, 160);
          triggerHaptic(20);
          executeNativeApp(app);
        };

        slot.addEventListener('pointerup', (e) => {
          if (e.button === 0) {
            const dist = Math.hypot(e.clientX - tapStartX, e.clientY - tapStartY);
            if (dist < 15) {
              launchSlot(e);
            }
          }
        });

        slot.onclick = launchSlot;
      });"""

text = re.sub(r'// Permanent Dock Icons Click[\s\S]*?executeNativeApp\(app\);\s*\}\s*;\s*\}\);', dock_tap_code, text)

with open(html_path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"Updated shell.html successfully! Total length: {len(text)}")
