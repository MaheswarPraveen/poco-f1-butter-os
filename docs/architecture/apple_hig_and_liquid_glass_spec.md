# ButterOS Design System: Apple HIG & Liquid Glass Specification

- **Date**: `2026-09-24`
- **Research Topic**: Apple Human Interface Guidelines (HIG), iOS 17/18 Liquid Glass & Spring Physics
- **Applied Project**: `poco-f1-butter-os`

---

## 🎨 1. Aesthetic Foundation & Liquid Glass Materials

During the design phase on September 24, 2026, research into Apple's Human Interface Guidelines and Liquid Glass specifications established the visual identity for the ButterOS Mobile Shell:

* **Smoked Glass Translucency**:
  - CSS Backdrop Filters: `backdrop-filter: blur(28px) saturate(180%)`
  - Base Rail Transparency: `rgba(10, 9, 8, 0.94)` (90% smoked glass)
  - Card Surfaces: `rgba(14, 12, 10, 0.94)`
* **18k Champagne & Matte Gold Accents**:
  - Primary Accent: `#deb056` (18k Satin Brushed Gold)
  - Active / Highlight: `#f8df9e` (Luminous Champagne Gold)
  - Deep Bronze: `#825e24` (Burnished Antique Bronze)
  - Zero Neon Bloom: Eliminating harsh cyber glow in favor of subtle reflective specular hairlines (`rgba(222, 176, 86, 0.30)`).

---

## ⚡ 2. Interaction Physics: Spring Dampers & Physical Detents

Apple HIG spring animation parameters were adapted for mobile touchscreen interaction:

1. **Spring Dynamics Formula**:
   \[
   F = -k(x - x_0) - c \cdot v
   \]
   Where $k$ is the spring stiffness and $c$ is the damping coefficient.

2. **Dual Flank Rails & Detent**:
   - Continuous 40-application vertical conveyor docked on left/right edges (88px wide).
   - Inward swipe mechanics:
     - Short inward flick: Snaps and holds on rail.
     - Physical Detent: Requires a deliberate pause and overcoming threshold drag resistance before expanding into the full A-Z App Drawer.
     - Fast swipe past the screen midline: Skips directly into the App Drawer.

3. **3D Rolodex Spatial Notification Deck**:
   - Notifications stacked along the Z-axis with perspective depth:
     `transform: perspective(600px) translate3d(0, y, z) rotateX(deg)`
   - Swiping dismisses along the natural tangential curve rather than linear Cartesian translation.

---

## 🖐️ 3. Gesture System Mapping (`lisgd`)

* **Edge Swipes (Left/Right)**: Global Back navigation (`butteros-gesture back`).
* **Bottom Edge (Short Flick Up)**: Home (`wlrctl toplevel focus title:'Poco F1 ButterOS Shell'`).
* **Bottom Edge (Long Pull Up)**: Recent Apps / Multitasking overview.
* **Two-Finger Swipe Up**: Toggle virtual keyboard (`squeekboard` / `wvkbd-mobintl`).
* **Top Edge Swipe Down**: Notification Center and Status Tray.
* **Bottom Corner Swipes**: Quick Settings circular arc overlays.
