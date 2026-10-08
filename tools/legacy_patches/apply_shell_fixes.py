import os

file_path = os.path.join('debian-butteros', 'shell', 'shell.html')
with open(file_path, 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Status Bar z-index -> 600
t1 = """    /* Status Bar: Clean Dual Horns Flanking Physical Notch (Zero Pixels Over Notch) */
    .status-bar {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 28px;
      z-index: 100;"""
r1 = """    /* Status Bar: Clean Dual Horns Flanking Physical Notch (Zero Pixels Over Notch) */
    .status-bar {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 28px;
      z-index: 600;"""
assert t1 in c, "Target 1 not found"
c = c.replace(t1, r1, 1)

# 2. Island Wing z-index -> 605
t2 = """      transition: transform 0.42s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.20s ease;
      z-index: 105;
      cursor: pointer;"""
r2 = """      transition: transform 0.42s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.20s ease;
      z-index: 605;
      cursor: pointer;"""
assert t2 in c, "Target 2 not found"
c = c.replace(t2, r2, 1)

# 3. Toast z-index -> 950
t3 = """      transition: opacity 0.2s ease, transform 0.2s ease;
      z-index: 110;
      white-space: nowrap;"""
r3 = """      transition: opacity 0.2s ease, transform 0.2s ease;
      z-index: 950;
      white-space: nowrap;"""
assert t3 in c, "Target 3 not found"
c = c.replace(t3, r3, 1)

# 4. Browser in openAppModal
t4 = """      } else if (app.key === 'browser' || app.key === 'help') {
        const targetUrl = app.key === 'help' ? 'https://wiki.postmarketos.org/wiki/Xiaomi_Poco_F1_(xiaomi-beryllium)' : 'https://duckduckgo.com';
        body.innerHTML = `
          <div class="app-card">
            <div class="app-card-title">Chromium Web Engine</div>
            <div class="app-card-row"><span>Status:</span><b style="color:#5af78e;">Wayland Window Launched</b></div>
            <div class="app-card-row"><span>Target:</span><span style="font-size:11px;color:#deb056;">${targetUrl}</span></div>
          </div>
          <div style="display:flex;gap:8px;">
            <button class="term-run-btn" style="padding:10px;flex:1;" onclick="fetch('http://127.0.0.1:9090/launch?cmd=chromium --new-window ${targetUrl}').catch(()=>{});showToast('Chromium Opened');">Open Window</button>
            <button class="term-pill" style="padding:10px;" onclick="closeAppModal()">Close</button>
          </div>
        `;"""

r4 = """      } else if (app.key === 'browser' || app.key === 'help') {
        const defaultUrl = app.key === 'help' ? 'https://wiki.postmarketos.org/wiki/Xiaomi_Poco_F1_(xiaomi-beryllium)' : 'https://duckduckgo.com';
        body.innerHTML = `
          <div style="display:flex;flex-direction:column;height:100%;min-height:480px;gap:8px;">
            <div style="display:flex;gap:6px;align-items:center;">
              <input type="text" id="browserUrlInput" value="${defaultUrl}" placeholder="Search or type URL..." style="flex:1;background:#141416;border:0.5px solid rgba(222,176,86,0.35);color:#fff;padding:8px 12px;border-radius:8px;font-size:12px;outline:none;" onkeydown="if(event.key==='Enter')loadBrowserUrl()">
              <button class="term-run-btn" style="padding:8px 14px;font-size:12px;" onclick="loadBrowserUrl()">Go</button>
            </div>
            <div style="display:flex;gap:6px;overflow-x:auto;padding-bottom:4px;scrollbar-width:none;">
              <span class="term-pill" style="cursor:pointer;" onclick="setBrowserUrl('https://duckduckgo.com')">DuckDuckGo</span>
              <span class="term-pill" style="cursor:pointer;" onclick="setBrowserUrl('https://en.m.wikipedia.org')">Wikipedia</span>
              <span class="term-pill" style="cursor:pointer;" onclick="setBrowserUrl('https://news.ycombinator.com')">Hacker News</span>
              <span class="term-pill" style="cursor:pointer;" onclick="setBrowserUrl('https://m.youtube.com')">YouTube</span>
              <span class="term-pill" style="cursor:pointer;" onclick="setBrowserUrl('https://wiki.postmarketos.org/wiki/Xiaomi_Poco_F1_(xiaomi-beryllium)')">Poco F1 Guide</span>
            </div>
            <div style="position:relative;flex:1;min-height:360px;border-radius:10px;overflow:hidden;border:0.5px solid rgba(255,255,255,0.08);background:#09090b;">
              <iframe id="browserFrame" src="${defaultUrl}" style="width:100%;height:100%;min-height:360px;border:none;background:#fff;" sandbox="allow-scripts allow-same-origin allow-forms allow-popups"></iframe>
            </div>
            <div style="display:flex;gap:8px;align-items:center;justify-content:space-between;padding-top:4px;">
              <span style="font-size:10px;color:rgba(255,255,255,0.4);">Swipe edge inward to exit</span>
              <button class="term-pill" style="padding:6px 10px;font-size:10px;" onclick="launchStandaloneMobileChromium()">Launch Standalone Mobile Chrome</button>
            </div>
          </div>
        `;
        window.loadBrowserUrl = function() {
          const inp = document.getElementById('browserUrlInput');
          const frame = document.getElementById('browserFrame');
          if (!inp || !frame) return;
          let val = inp.value.trim();
          if (!val) return;
          if (!val.startsWith('http://') && !val.startsWith('https://')) {
            if (val.includes('.') && !val.includes(' ')) {
              val = 'https://' + val;
            } else {
              val = 'https://duckduckgo.com/?q=' + encodeURIComponent(val);
            }
          }
          inp.value = val;
          frame.src = val;
        };
        window.setBrowserUrl = function(url) {
          const inp = document.getElementById('browserUrlInput');
          if (inp) inp.value = url;
          window.loadBrowserUrl();
        };
        window.launchStandaloneMobileChromium = function() {
          const url = (document.getElementById('browserUrlInput')?.value || defaultUrl).trim();
          const mobileUa = "Mozilla/5.0 (Linux; Android 14; POCOPHONE F1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36";
          const cmd = 'chromium --ozone-platform=wayland --enable-features=UseOzonePlatform --user-agent=\\"' + mobileUa + '\\" --enable-viewport --force-device-scale-factor=2.75 --app=\\"' + url + '\\"';
          fetch('http://127.0.0.1:9090/launch?cmd=' + encodeURIComponent(cmd)).catch(()=>{});
          showToast('Mobile Chromium Window Launched');
        };"""
assert t4 in c, "Target 4 not found"
c = c.replace(t4, r4, 1)

# 5. Remove automatic external launch from executeNativeApp
t5 = """      try {
        if (app.key === 'browser') {
          fetch('http://127.0.0.1:9090/launch?cmd=' + encodeURIComponent('chromium --new-window')).catch(() => {});
        } else if (app.key === 'camera') {
          fetch('http://127.0.0.1:9090/launch?cmd=megapixels').catch(() => {});
        }
      } catch(e) {}"""
r5 = """      try {
        if (app.key === 'camera') {
          fetch('http://127.0.0.1:9090/launch?cmd=megapixels').catch(() => {});
        }
      } catch(e) {}"""
assert t5 in c, "Target 5 not found"
c = c.replace(t5, r5, 1)

# 6. MASTER_APP_CATALOG browser command
t6 = """        { key: 'browser',   name: 'Chromium',     cmd: 'chromium --new-window',                 baseFreq: 100 },"""
r6 = """        { key: 'browser',   name: 'Browser',      cmd: 'chromium --ozone-platform=wayland --enable-features=UseOzonePlatform --user-agent=\\"Mozilla/5.0 (Linux; Android 14; POCOPHONE F1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36\\" --enable-viewport --force-device-scale-factor=2.75 https://duckduckgo.com', baseFreq: 100 },"""
assert t6 in c, "Target 6 not found"
c = c.replace(t6, r6, 1)

# 7. Screen click dismiss order
t7 = """      // Close panels on background tap or return to home page
      screen.addEventListener('click', (e) => {
        // Prevent accidental dismiss immediately after gesture opens arc or notification center
        if (Date.now() - arcOpenedTimestamp < 650) return;
        if (document.getElementById('butterAppModal')?.classList.contains('open')) return;
        if (Date.now() - notifOpenedTimestamp < 650) return;"""

r7 = """      // Close panels on background tap or return to home page
      screen.addEventListener('click', (e) => {
        // Prevent accidental dismiss immediately after gesture opens arc or notification center
        if (Date.now() - arcOpenedTimestamp < 650) return;
        if (Date.now() - notifOpenedTimestamp < 650) return;

        // Dismiss notification center or quick settings if open over an app
        if (notifModal.classList.contains('open') && !notifModal.contains(e.target) && e.target.id !== 'btnOpenNotifs') {
          closeNotifModal();
          return;
        }
        if (arcLeft.classList.contains('open') && !arcLeft.contains(e.target) && !cornerIndicatorLeft.contains(e.target) && e.target.id !== 'btnOpenArcLeft') {
          closeArcLeft();
          return;
        }
        if (arcRight.classList.contains('open') && !arcRight.contains(e.target) && !cornerIndicatorRight.contains(e.target) && e.target.id !== 'btnOpenArcRight') {
          closeArcRight();
          return;
        }

        if (document.getElementById('butterAppModal')?.classList.contains('open')) return;"""
assert t7 in c, "Target 7 not found"
c = c.replace(t7, r7, 1)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(c)

print("debian-butteros/shell/shell.html successfully updated!")
