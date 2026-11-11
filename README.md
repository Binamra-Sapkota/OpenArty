# OpenArty 🎨

[![Release](https://img.shields.io/badge/Release-v1.1-blue.svg)](https://github.com/Binamra-Sapkota/OpenArty/releases)
[![Direct APK Download](https://img.shields.io/badge/Download-Direct%20APK-brightgreen.svg?logo=android)](https://github.com/Binamra-Sapkota/OpenArty/releases/download/v1.1/app-release.apk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20(API%2021%2B)-success.svg)](https://flutter.dev)

> **[Direct APK Download Link: Click Here to Download OpenArty v1.1 APK](https://github.com/Binamra-Sapkota/OpenArty/releases/download/v1.1/app-release.apk)**

**OpenArty** is a completely free, lightweight, privacy-focused, open-source digital painting, sketch, and vector illustration app built with Flutter. It combines the ergonomic, minimal touch interface of **Autodesk SketchBook** with the powerful multi-layer, blending mode, and vector styling capabilities of **Procreate**.

Designed specifically for smartphones, foldables, and tablets, OpenArty is engineered for zero-lag drawing, rich artistic control, and total user privacy.

---

## 📥 Direct APK Download

You can download and install the latest release directly onto any Android device:

- **Direct Download**: **[OpenArty v1.1 Release APK](https://github.com/Binamra-Sapkota/OpenArty/releases/download/v1.1/app-release.apk)**
- **All Releases & Source**: [GitHub Releases Page](https://github.com/Binamra-Sapkota/OpenArty/releases)

---

## ✨ Key Features

### ⚡ Smooth Continuous Strokes & Zero-Lag Drawing Engine
- **SketchBook-Style Smooth Continuous Splines**: Freehand strokes are rendered as seamless, continuous quadratic Bezier paths with no dotted joined-line artifacts.
- **Sub-Pixel Distance Optimization**: Continuous brush strokes remain fluid and responsive without lagging or dropping frames, even when painting uninterrupted for hours.
- **Pre-Cached Vector Rendering**: In-memory path caching guarantees smooth 60fps / 120Hz display refresh on mobile screens.
- **Lightweight Footprint**: Highly optimized bundle with zero bloat and near-instant cold startup time.

### ✍️ Stylus & Dynamic Pressure Sensitivity
- **Hardware Stylus Pressure**: Dynamic hardware pressure sensing for Samsung S-Pen, Apple Pencil, USI styluses, and Wacom-compatible active pens.
- **Clean Consistent Touch Linework**: Touch and finger drawing produces clean, uniform strokes without velocity jitter or joint bead artifacts.
- **Pressure Dynamics Switch**: Easily toggle dynamic pressure scaling on or off directly in the Brush Studio.

### 🖌️ Versatile Brush Studio
- **Curated Presets**: HB Pencil, Technical Pencil, Hard Round Brush, Soft Airbrush, Marker, Calligraphy Ink Pen, Watercolor, Charcoal, Oil Pastel, Smudge Tool, Precision Eraser, and Soft Eraser.
- **Deep Parameter Control**: Customize Brush Size (1px – 500px), Opacity (1% – 100%), Hardness, Spacing, and Streamline Stabilization.
- **Streamline Stabilization**: Built-in jitter cancellation algorithm for silky-smooth linework.
- **Seamless Brush-to-Eraser Switching**: Switch back and forth between drawing tools and the eraser with automatic state restoration.

### 🎚️ Top-Docked Movable Quick-Sliders with Keyboard Input
- **Top-Docked Movable Pill Bar**: Brush size and opacity sliders are docked at the top of the canvas in a compact horizontal pill bar with a drag handle to position anywhere.
- **Numeric Keyboard Direct Input**: Tap the size (`24px ⌨`) or opacity (`100% ⌨`) chips to enter precise values via your mobile keyboard.

### 🎨 Rectangular Color Studio & Swatches
- **Rectangular Color Selector**: Large Saturation-Value 2D gradient box with draggable crosshair, rainbow Hue spectrum slider, and checkerboard Alpha transparency slider.
- **Hex & RGB Direct Input**: Tap to view and edit exact Hex codes or RGB sliders via mobile keyboard.
- **Color History & Swatches**: 12 curated default swatches + automatic 16-color recent palette history.
- **Foreground / Background Color Swapping**: Instant two-color toggling for shading and inking.
- **Interactive Eyedropper**: Sample color directly from any layer, stroke, or imported image.

### 📑 Multi-Layer Studio & Universal Renaming
- **Unlimited Layers**: Create, duplicate, reorder, delete, hide/show, and rename layers.
- **Universal Layer Renaming**: Rename any layer at any time—including standard brush, gradient, image, and text layers.
- **17 Blending Modes**: Normal, Multiply, Screen, Overlay, Darken, Lighten, Color Dodge, Color Burn, Hard Light, Soft Light, Difference, Exclusion, and more.
- **Layer Locks**: Per-layer Alpha Lock and Editing Lock to protect critical linework.
- **Merge Operations**: Merge down and merge all visible layers into a single composite layer.

### 📐 13 Vector & Geometric Shapes
Draw crisp vector shapes with either outline stroke or solid fill:
- **Rectangle**
- **Rounded Rectangle**
- **Circle**
- **Ellipse**
- **Straight Line**
- **Triangle**
- **Star (5-Point)**
- **Hexagon / Polygon**
- **Diamond / Rhombus**
- **Heart**
- **Arrow**
- **Speech Bubble**
- **Cloud**

### 🔤 Dedicated Text Layers & Live Transform
- **Independent Text Layers**: Add customizable typography with font size, color, bold, and italic styles.
- **Move & Transform Tool**: Move, reposition, and scale text and image layers dynamically. Re-edit text anytime.

### 🎨 Customizable Gradients & Flood Fill Bucket
- **Customizable Gradients**: Create linear and radial gradients with customizable colors and transparency across multiple layers.
- **Flood Fill Bucket**: Fill enclosed contours or entire layers with tolerance control.

### 💾 8-Second Auto-Save, Exit Protection & "Save Project"
- **Continuous 8-Second Auto-Save**: Your artwork automatically persists every 8 seconds.
- **Accidental Exit Protection**: If you mistakenly quit or switch apps while drawing, synchronous file write immediately flushes changes to storage so no strokes or layers are ever lost.
- **Dedicated "Save Project to Gallery" Option**: Tap the Save icon or option in the top toolbar to name or rename your artwork with your mobile keyboard and reopen it anytime from the Gallery.
- **Universal Layer Renaming**: Rename any layer (drawing, image, gradient, or text) easily using your mobile keyboard via direct tap or layer option menu.
- **Persistent Cross-Session Undo/Redo**: Undo and redo history across strokes, layers, text, and gradients is preserved across app sessions.

### 🏁 Transparent Canvas & Background Colors
- **Canvas Background Selection**: Choose between Transparent, White, Black, or Cream background when creating new canvases.
- **High-Contrast Black Grid**: Crisp, clear black grid lines for precision drawing and layout alignment.

### 🖼️ Floating Reference Image Overlay
- Import reference images from device storage without baking them into your artwork.
- Drag, reposition, scale, adjust opacity, minimize, or dismiss the reference card independently of canvas zoom and pan.

### 📤 Multi-Format Export Suite
Export your creations with a single tap into professional raster and vector formats:
1. **PNG Image (`.png`)**: Lossless raster export with full alpha transparency.
2. **JPEG Image (`.jpg`)**: High-quality photographic compressed export.
3. **SVG Vector (`.svg`)**: Scalable Vector Graphics markup serializing all vector paths, shapes, polygons, and text for editing in Inkscape, Figma, or Adobe Illustrator.
4. **PDF Document (`.pdf`)**: Multi-resolution print-ready document formatted to canvas dimensions.
5. **Adobe Photoshop PSD (`.psd`)**: Multi-channel Photoshop document with planar RGBA color channels compatible with Adobe Photoshop, Clip Studio Paint, and GIMP.

---

## 🔒 100% Clean-Room & Privacy First

- **NO Ads & NO Trackers**: Zero telemetry, advertising SDKs, analytics tracking, or proprietary third-party spyware.
- **NO Generative AI**: Clean, human-centric illustration tool without external AI APIs or algorithmic prompt generation.
- **100% Offline**: All operations, files, and project databases are stored locally on your device via Hive and local storage.

---

## 🚀 Getting Started for Developers

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10+ or higher, Dart 3.0+)
- Android SDK (API 21+ supported, compileSdk 34+)
- JDK 17

### Building and Running

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Binamra-Sapkota/OpenArty.git
   cd OpenArty
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on a connected device:**
   ```bash
   flutter run
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```

---

## 📱 Hardware & Platform Support

- **Android**: Android 5.0 (Lollipop) through Android 16 (API 36).
- **Tablets & Foldables**: Responsive layout that dynamically adjusts toolbar items and hides/expands panels based on available screen width.
- **Stylus Input**: Supports Samsung S-Pen, active USI pens, and capacitive touch styluses.

---

## 📄 License

OpenArty is released under the **MIT License**. You are free to inspect, modify, fork, and distribute this software.

