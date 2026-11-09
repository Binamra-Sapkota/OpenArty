# OpenCreate 🎨

**OpenCreate** is a free, lightweight, open-source mobile digital art and illustration application built with Flutter. It blends the intuitive, touch-first ergonomics of **Autodesk SketchBook** with the powerful layer, brush, and vector illustration toolset of **Procreate**.

Designed from the ground up for smartphones and tablets, OpenCreate prioritizes the canvas, minimizes distraction, and puts professional-grade drawing tools directly at your fingertips.

---

## ✨ Key Features

### 🖌️ Versatile Brush Studio
- **Curated Presets**: HB Pencil, Technical Pencil, Hard Round Brush, Soft Airbrush, Marker, Calligraphy Ink Pen, Watercolor, Charcoal, Oil Pastel, Smudge Tool, Precision Eraser, and Soft Eraser.
- **Deep Parameter Control**: Customize Brush Size (1px – 500px), Opacity, Flow, Hardness, Spacing, and Streamline Stabilization.
- **Smooth Input Smoothing**: Integrated streamline stabilization algorithm that eliminates hand jitter for silky-smooth inking.
- **Stylus & Pressure Sensitivity**: Full hardware pressure support for active styluses (S-Pen, Apple Pencil, USI styluses) with pressure-varying size and opacity.
- **Seamless Brush-to-Eraser Switching**: Switch effortlessly between brushes and erasers without tool lockups.

### 🎚️ Floating Canvas Quick-Sliders
- Floating vertical size and opacity sliders docked cleanly to the screen margin (SketchBook / Procreate style).
- Real-time visual feedback pill displaying the exact pixel size and opacity with live swatch previews while dragging.

### 🎨 Circular HSV Color System
- **Hue Sweep Ring & Saturation/Value Box**: Pinpoint any color with full precision.
- **Quick Swatches & Color History**: 12 curated default swatches plus an automatic 16-color recent palette history.
- **Foreground / Secondary Color Swapping**: Instant two-color toggling for shading and inking workflows.
- **Alpha Transparency Slider & Hex Input**: Complete opacity management with live Hexadecimal display.
- **Interactive Eyedropper**: Sample colors directly from any vector stroke or imported layer on the canvas.

### 📑 Multi-Layer Studio
- **Unlimited Layers**: Create, duplicate, reorder, delete, and rename layers.
- **17 Blending Modes**: Normal, Multiply, Screen, Overlay, Darken, Lighten, Color Dodge, Color Burn, Hard Light, Soft Light, Difference, Exclusion, and more.
- **Independent Layer Opacity & Locks**: Per-layer alpha lock and editing lock to protect in-progress linework.
- **Layer Operations**: Merge down and merge all visible layers into a single composite layer.

### 📐 Vector Shapes, Text & Gradients
- **Geometric Shapes**: Draw crisp Rectangles, Rounded Rectangles, Circles, Ellipses, Straight Lines, and Triangles with optional solid fill.
- **Typography Engine**: Place customizable text directly onto the canvas with full font size control.
- **Gradient Tools**: Generate linear and radial gradients with smooth color transitions.
- **Flood Fill Bucket**: Instantly fill enclosed areas or entire layers.

### 🖼️ Floating Reference Image Overlay
- Import reference images from device storage without baking them into your artwork.
- Drag, reposition, scale, adjust opacity, minimize, or dismiss the reference card independently of canvas zoom and pan.

### 🪞 Precision Guides & Ergonomics
- **Symmetry Guides**: Vertical mirror, horizontal mirror, and 8-way radial symmetry for mandalas and concept art.
- **Canvas Alignment Grid**: Subtle overlay grid for architectural and perspective drawing.
- **Palm Rejection & Stylus-Only Mode**: Filter out capacitive finger touches when using an active stylus.
- **Smooth Canvas Navigation**: Natural pinch-to-zoom (up to 50x magnification), two-finger pan, and free canvas rotation with instant "Fit to Screen" reset.

### 📤 Multi-Format Export & Sharing
Export your creations with a single tap in any standard creative format:
1. **PNG Image (`.png`)**: Lossless raster export with full alpha transparency support.
2. **JPEG Image (`.jpg`)**: Optimized photographic export with 92% high quality.
3. **SVG Vector (`.svg`)**: Scalable Vector Graphics markup serializing all vector paths, shapes, polygons, and text for seamless editing in Inkscape, Figma, or Adobe Illustrator.
4. **PDF Document (`.pdf`)**: Print-ready document formatted to exact canvas dimensions.

---

## 🔒 100% Clean-Room & Privacy First

- **NO Ads & NO Trackers**: Zero telemetry, advertising SDKs, analytics tracking, or proprietary third-party spyware.
- **NO Generative AI**: Clean human-centric illustration tool without algorithmic prompt generators or synthetic auto-fill.
- **100% Offline**: All operations, files, and project databases are stored locally on your device via Hive and local storage.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10+ or higher, Dart 3.0+)
- Android SDK (API 21+ supported, compileSdk 34+)
- JDK 17

### Building and Running

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/OpenCreate.git
   cd OpenCreate
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on a connected mobile device or emulator:**
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

OpenCreate is released under the **MIT License**. You are free to inspect, modify, fork, and distribute this software.
