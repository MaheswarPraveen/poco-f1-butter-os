# Implementation Plan: Option 1 - Active App Windows, Core Apps & Gesture Multitasking

This plan details how to implement **Option 1**: transforming ButterOS from an app launcher prototype into a complete, interactive mobile operating system with full-screen application windows, real functional core apps (Terminal, Settings, Camera, Browser), bottom gesture navigation, and a 3D multitasking app switcher.

---

## Architecture Overview

```mermaid
flowchart TD
    Launcher["ButterOS Launcher (Home / Rails / Drawer)"]
    AppTap["Tap App Icon (Dock, Rails, Drawer)"]
    ZoomAnimation["Liquid Zoom-Up Window Transition (320ms Spring)"]
    AppWindow["Full-Screen App Window (.app-window)"]
    GestureBar["Bottom Home Gesture Bar (.home-gesture-pill)"]
    
    Launcher -->|Tap Icon| AppTap
    AppTap -->|Calculate Icon Coordinates| ZoomAnimation
    ZoomAnimation -->|Mount Active App| AppWindow
    AppWindow -->|Listen for Bottom Swipes| GestureBar
    
    GestureBar -->|Flick Up (dy < -60px)| DismissHome["Dismiss to Home (Shrink back)"]
    DismissHome --> Launcher
    
    GestureBar -->|Swipe Up & Hold (dy < -40px, > 200ms)| AppSwitcher["3D Recents App Switcher"]
    AppSwitcher -->|Swipe Up Card| KillApp["Kill App"]
    AppSwitcher -->|Tap Card| SwitchApp["Switch to App Window"]
    AppSwitcher -->|Tap Empty Area| DismissHome
    SwitchApp --> AppWindow
```

---

## User Review Required

> [!IMPORTANT]
> **Poco F1 Hardware Safe Areas**: The app window respects the $28\text{px}$ physical notch height at the top ($x = 86\dots 274\text{px}$) and provides $24\text{px}$ bottom clearance for the floating Home Gesture Pill. The physical screen horns display time and battery status continuously while inside apps.

> [!NOTE]
> **Zero Heavy Emulation**: All apps run with 60 FPS GPU acceleration directly in the ButterOS shell pipeline. When running on your phone via LAN, the Camera app accesses your phone's real physical camera hardware via `getUserMedia`.

---

## Proposed Changes

### Component 1: Application Window Container & Lifecycle (`.app-viewport`)

#### [MODIFY] [`shell_prototype.html`](file:///C:/Users/xczma/.gemini/antigravity/scratch/poco-f1-butter-os/shell_prototype.html)

1. **App Viewport Container**:
   - Add `.app-viewport` layer with `z-index: 80`, sitting above the wallpaper and launcher but beneath the top notch Dynamic Island and status horns.
   - Rounded corners matching the Poco F1 chassis (`border-radius: 34px`).
   - Liquid transition: `transform 0.32s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.25s ease, border-radius 0.32s ease`.
2. **App Window Stack & Manager**:
   - `openApp(appKey)`: Checks if app is in active memory. Animates open from the clicked icon's position (`getBoundingClientRect()`).
   - `closeActiveApp()`: Animates the window shrinking back into the home launcher, un-dimming the wallpaper.
   - `activeAppId`: Tracks currently focused app.
   - `runningApps`: Array of running app state objects for the multitasking switcher.

---

### Component 2: Four Interactive Core Applications

#### 1. Interactive Terminal (`com.butteros.terminal`)
- Monospace smoked glass CLI shell (`font-family: 'JetBrains Mono', 'Fira Code', monospace; background: rgba(10, 9, 8, 0.94)`).
- Realistic prompt: `butter@beryllium:~$ `.
- Quick-action hardware chips:
  - `neofetch`: Renders custom ButterOS ASCII banner, Snapdragon 845 specs, Adreno 630 GPU, Linux 6.8 mainline kernel.
  - `free -m`: Displays 6GB LPDDR4X memory layout.
  - `uname -a`: Prints system identification.
  - `uptime`: Real-time session counter.
  - `sensors`: Battery temperature, voltage, charging state.
- Interactive input: Type custom commands with physical keyboard or tap quick chips.

#### 2. System Settings (`com.butteros.settings`)
- Luxury horology styled grouped card layout with 18k champagne gold accents.
- **Display & Wallpaper**:
  - Live Black Hole Speed slider ($0.1\times$ to $3.0\times$).
  - Color Theme switcher (18k Champagne Gold, Titanium Silver, Obsidian Platinum).
- **Physical Notch Controller**:
  - Toggle between **Physical Device Mode** (notch simulated overlay hidden for real Poco F1) and **Desktop Simulator Mode** (visual notch overlay visible on laptop).
- **Device & Kernel Info**:
  - Xiaomi Pocophone F1 (`beryllium`), Qualcomm Snapdragon 845 (8 cores: 4x Kryo 385 Gold @ 2.8GHz, 4x Silver @ 1.8GHz), Mesa Turnip / Freedreno Adreno 630.

#### 3. Real Camera Viewfinder (`com.butteros.camera`)
- Viewfinder utilizing `navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } })`.
- Live real-time video stream filling the screen behind the Poco F1 notch.
- Shutter button with tactile white screen flash animation.
- Flip camera toggle (front/back lens switch).

#### 4. Butter Web Browser (`com.butteros.browser`)
- Minimalist address bar with SSL padlock and URL input.
- Quick navigation shortcuts: Debian ARM64, GitHub, Hacker News, Wikipedia.
- Embedded fast reader frame.

---

### Component 3: Gesture Navigation & 3D Multitasking App Switcher

1. **Floating Home Gesture Pill (`.home-gesture-pill`)**:
   - Sleek $120\text{px} \times 4.5\text{px}$ pill bar centered at the bottom ($10\text{px}$ above bezel).
   - Touch events tracked via `touchstart`, `touchmove`, `touchend`.
   - **Gesture A (Flick Up, $dy < -55\text{px}$)**: Smoothly dismisses the active app back to the Homepage.
   - **Gesture B (Swipe Up & Hold, $dy < -35\text{px}$ held for $> 180\text{ms}$)**: Launches the **3D App Switcher**.
2. **3D Recents Carousel (`.app-switcher`)**:
   - Displays running apps as floating miniature cards in a horizontal 3D perspective stream.
   - Swipe horizontally to select an app.
   - Flick a card UP to close/kill that app.
   - Tap outside or flick down to return to Homepage.

---

## Verification Plan

### Automated / Syntax Verification
- Run Node.js script extraction and AST syntax verification on `shell_prototype.html` to guarantee zero syntax or runtime parse errors.

### Manual Verification on Xiaomi Poco F1 (via LAN `http://10.165.255.182:8080`)
1. **Launch App**: Tap the **Terminal** dock icon $\rightarrow$ verify smooth liquid scale-up into full screen.
2. **Run Commands**: Tap `neofetch` and `free -m` $\rightarrow$ verify accurate Snapdragon 845 hardware specs printed in terminal.
3. **Settings Controls**: Open **Settings**, move the Wallpaper Speed slider $\rightarrow$ verify black hole shader speed changes in real-time.
4. **Camera Viewfinder**: Open **Camera** $\rightarrow$ verify camera permissions and live video feed inside Poco F1 notch horns.
5. **Gesture Home Navigation**: Swipe up from bottom home pill $\rightarrow$ verify app smoothly shrinks back to home.
6. **Multitasking Switcher**: Swipe up and hold from bottom pill $\rightarrow$ verify 3D recents carousel appears, allowing app switching and flick-up kill.
