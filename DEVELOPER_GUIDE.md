# DEVELOPER_GUIDE.md — OpenCreate Technical & Contributor Guide

This document contains in-depth technical documentation for engineers, contributors, and automated agents working on the **OpenCreate** codebase.

---

## 1. System Architecture & State Machine

OpenCreate is structured around unidirectional data flow managed by **Riverpod** (`StateNotifierProvider`).

```
                ┌──────────────────────────────────────────────┐
                │               Flutter UI Layer               │
                │ (DrawingCanvas, TopToolbar, BottomToolbar,   │
                │  QuickSliders, LayerPanel, BrushPanel)       │
                └──────────────────────┬───────────────────────┘
                                       │ User Interactions / Gestures
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                            Riverpod Providers                               │
 ├──────────────────────────┬─────────────────────────┬────────────────────────┤
 │     canvasProvider       │      layerProvider      │   activeBrushProvider  │
 │ - Tool state             │ - Layer hierarchy       │ - Active brush preset  │
 │ - Viewport (pan, zoom)   │ - Layer visibility/lock │ - Size, opacity, flow  │
 │ - Committed strokes      │ - Blending modes        │ - Streamline factor    │
 │ - Undo / Redo stacks     │ - Decoded image cache   │ - Eraser restoration   │
 └──────────────────────────┴─────────────────────────┴────────────────────────┘
                                       │
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                            Rendering Engine                                 │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ CanvasPainter: Layer compositing (SaveLayer), software blend modes,         │
 │ stroke geometry, symmetry reflections, and grid overlay.                    │
 └─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         Storage & Export Subsystem                          │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ Hive (Local Database) ──> Project metadata, brushes, settings.              │
 │ ImageUtils             ──> Exporters for PNG, JPEG, SVG Vector, PDF.       │
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Drawing Engine & Stroke Lifecycle

### 2.1 The Stroke Model (`DrawStroke` & `DrawPoint`)
Strokes are represented vectorially in `lib/utils/blend_modes.dart`:
```dart
class DrawPoint {
  final Offset position;
  final double pressure;
  final double size;
  final double opacity;
}

class DrawStroke {
  final List<DrawPoint> points;
  final Color color;
  final String brushId;
  final double brushSize;
  final double brushOpacity;
  final StrokeKind kind; // freehand, line, rectangle, circle, etc.
  final bool isFilled;
  final String? text;
  final double? fontSize;
}
```

### 2.2 Lifecycle of a Stroke
1. **Pointer Down** (`onPointerDown` in `drawing_canvas.dart`):
   - Coordinate mapped from screen coordinates to canvas space via `_screenToCanvas`.
   - Tool verified: if `activeTool == DrawingTool.brush` or `pencil`, ensure active brush is not an eraser. If user previously used eraser, restore `_lastDrawingBrush`.
   - `CanvasNotifier.beginStroke()` initializes a new in-progress stroke list.
2. **Pointer Move** (`onPointerMove`):
   - Streamline stabilization smoothing is applied:
     $$\mathbf{P}_{\text{smoothed}} = \mathbf{P}_{\text{prev}} + (\mathbf{P}_{\text{raw}} - \mathbf{P}_{\text{prev}}) \times (1 - \text{streamline})$$
   - `CanvasNotifier.continueStroke()` appends points to `currentStrokes`.
3. **Pointer Up** (`onPointerUp`):
   - `CanvasNotifier.endStroke()` transfers `currentStrokes` to `committedStrokes[activeLayerId]`.
   - Pushes previous canvas snapshot onto `undoStack` and empties `redoStack`.

---

## 3. Resolving Tool Invariants & The Eraser Bug

### The Problem:
Historically in digital art applications, setting the tool to "Eraser" replaces the active brush with an eraser object whose `BlendMode` is set to `clear`. When a user tapped "Brush", the UI updated `activeTool = brush`, but the brush state still retained the eraser brush model, resulting in invisible strokes.

### The OpenCreate Architecture Solution:
`ActiveBrushNotifier` (`lib/providers/brush_provider.dart`) maintains a private `_lastDrawingBrush`:
```dart
class ActiveBrushNotifier extends StateNotifier<BrushModel> {
  late BrushModel _lastDrawingBrush;

  void selectEraser({bool soft = false}) {
    if (state.type != BrushType.eraser) {
      _lastDrawingBrush = state;
    }
    state = BrushModel.defaults.firstWhere((b) => b.id == (soft ? 'eraser_soft' : 'eraser_1'));
  }

  void restoreDrawingBrush() {
    state = _lastDrawingBrush;
  }
}
```
Whenever the user selects any non-eraser tool (`brush`, `pencil`, `smudge`, `shapes`) in `BottomToolbar` or `DrawingCanvas`, `restoreDrawingBrush()` is invoked automatically. This guarantees normal painting is restored instantly.

---

## 4. Layer Architecture & GPU Texture Caching

Each layer in OpenCreate is represented by `LayerModel` (`lib/models/layer_model.dart`):
- `pixelData`: Optional raw `Uint8List` bytes for imported images or baked raster snapshots.
- `layerImages`: Decoded `ui.Image` cached in `LayerState`.
- `blendMode`: Flutter `BlendMode` mapped from 17 professional blend modes.

During rendering, `CanvasPainter.paint()` renders each layer inside a GPU off-screen layer:
```dart
for (final layer in layers.reversed) {
  if (!layer.isVisible) continue;
  
  canvas.saveLayer(
    Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
    Paint()
      ..blendMode = layer.blendMode.flutterBlendMode
      ..color = Colors.white.withValues(alpha: layer.opacity),
  );

  // 1. Draw decoded background image if this is an image layer
  final layerImg = layerImages[layer.id];
  if (layerImg != null) {
    canvas.drawImageRect(layerImg, srcRect, dstRect, Paint());
  }

  // 2. Draw all vector strokes committed to this layer
  for (final stroke in committedStrokes[layer.id] ?? []) {
    _renderStroke(canvas, stroke, size);
  }

  canvas.restore();
}
```

---

## 5. Multi-Format Exporters (`ImageUtils`)

### 5.1 PNG & JPEG
Rendered via `ui.PictureRecorder` and converted to `ui.Image`. PNG uses lossless `imageToBytes()`. JPEG applies `img.encodeJpg(quality: 92)`.

### 5.2 SVG Vector Export
Serializes stroke models into valid, scalable SVG 1.1 XML:
- Freehand strokes $\rightarrow$ `<path d="M ... L ..." stroke="..." stroke-width="..." stroke-linecap="round"/>`
- Shapes $\rightarrow$ `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polygon>`
- Text $\rightarrow$ `<text font-size="...">`
All strokes maintain exact coordinates, opacity, and color hex values.

### 5.3 PDF Document Export
Uses the `pdf` package (`pw.Document()`). Formats the full-resolution artwork onto exact canvas dimensions, making it suitable for high-DPI printing without raster scaling artifacts.

---

## 6. Layout & Responsiveness Rules

To guarantee zero layout overflow across all mobile screens:
1. **TopToolbar**:
   - Total height: 48dp.
   - Title is conditionally rendered only on devices wider than 480dp (`constraints.maxWidth >= 480`).
   - Action buttons use compact constraints (`BoxConstraints(minWidth: 32, minHeight: 36)`).
   - All secondary actions (Grid, Symmetry, Palm rejection, Stylus-only, Clear, Canvas settings, Import) are placed inside a `PopupMenuButton`.
2. **BottomToolbar**:
   - Total height: 58dp.
   - Nested inside a `SingleChildScrollView(scrollDirection: Axis.horizontal)` with `BouncingScrollPhysics`. It adapts smoothly to any screen width from 320dp phones to 12.9" tablets.
3. **Floating Overlays**:
   - `BrushPanel` and `LayerPanel` enforce dynamic width constraints: `screenW < 340 ? screenW - 20 : 320`, with vertical scroll wrapping to prevent vertical clipping on landscape phones.

---

## 7. Developer Verification Checklist

Before opening a pull request or submitting changes, verify:
```bash
# 1. Run static analysis (must report 0 errors)
flutter analyze

# 2. Build debug APK
flutter build apk --debug

# 3. Test on connected physical device via ADB
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.opencreate.opencreate -c android.intent.category.LAUNCHER 1

# 4. Verify no RenderFlex overflow in adb logcat
adb logcat -d | grep -i "overflowed"
```
