# AGENTS.md — OpenCreate Architectural Guide for AI Coding Agents

## 1. Project Overview & Philosophy

**OpenCreate** is a completely free, open-source mobile-first digital painting and illustration application built with Flutter and Dart. Its design synthesizes:
- The minimal, intuitive, touch-ergonomic interface of **Autodesk SketchBook** (bottom tool shelf, circular color puck, floating size/opacity quick sliders).
- The advanced creative capabilities of **Procreate** (multi-layer architecture with 17 blend modes, customizable brush engine with streamline stabilization, floating reference images, symmetry guides, and multi-format vector/raster export).

### Non-Negotiable Constraints for Agents
1. **NO AI-Powered Features**: Do not add generative AI, AI auto-fill, neural filters, prompt boxes, or external AI APIs.
2. **NO Proprietary Branding**: OpenCreate is 100% original, clean-room software. Never introduce trademarks, assets, or references implying it is an unofficial or modified version of any commercial product.
3. **Responsive Mobile-First Layout**: Maintain zero layout overflow (`RenderFlex` overflow warnings). All fixed horizontal rows must be constrained or use scrollable containers/overflow menus.
4. **Preserve Documentation Integrity**: Retain all docstrings and comments when modifying code.

---

## 2. Codebase Organization

```
OpenCreate/
├── android/                         # Android native project & Gradle build system
├── assets/                          # App assets & launcher icons
├── lib/
│   ├── main.dart                    # App entry point, Hive initialization, ProviderScope
│   ├── app.dart                     # MaterialApp theme and routing
│   ├── models/
│   │   ├── brush_model.dart         # Brush preset model, BrushType, BrushCategory, Hive adapters
│   │   ├── canvas_model.dart        # CanvasModel (dimensions, DPI, background color)
│   │   ├── layer_model.dart         # LayerModel, LayerBlendMode, and BlendMode mappings
│   │   └── project_model.dart       # ProjectModel (metadata, dimensions, timestamps)
│   ├── providers/
│   │   ├── brush_provider.dart      # ActiveBrushNotifier, BrushListNotifier, DrawingColorNotifier
│   │   ├── canvas_provider.dart     # CanvasNotifier, CanvasState, DrawingTool, ShapeType
│   │   └── layer_provider.dart      # LayerNotifier, LayerState, layer hierarchy management
│   ├── screens/
│   │   ├── gallery_screen.dart      # Artwork gallery, new canvas dialog, storage permissions
│   │   └── canvas_screen.dart       # Main drawing studio layout (Top, Canvas, Sliders, Bottom)
│   ├── utils/
│   │   ├── blend_modes.dart         # DrawStroke, StrokeKind, DrawPoint, BlendModes logic
│   │   └── image_utils.dart         # Exporters (PNG, JPEG, SVG vector, PDF document)
│   └── widgets/
│       ├── canvas/
│       │   ├── canvas_painter.dart  # CustomPainter rendering layers, checkerboard, strokes, shapes
│       │   ├── drawing_canvas.dart  # Multi-touch viewport (zoom, pan, rotate, stroke input)
│       │   ├── quick_sliders.dart   # Floating vertical brush size & opacity sliders on canvas edge
│       │   └── reference_image_widget.dart # Draggable floating reference image overlay
│       ├── color/
│       │   ├── color_wheel.dart     # Circular HSV wheel, sat/val box, alpha slider, swatches
│       │   └── color_picker.dart    # Compact grid swatch picker
│       ├── layers/
│       │   ├── layer_item.dart      # Individual layer row (visibility, lock, blend mode, opacity)
│       │   └── layer_panel.dart     # Floating layer management sheet (reorder, merge, duplicate)
│       └── toolbar/
│           ├── top_toolbar.dart     # Compact responsive top bar (Undo, Redo, Fit, Studio, More)
│           ├── bottom_toolbar.dart  # Mobile bottom tool shelf (Brush, Pencil, Eraser, Smudge, Puck, etc.)
│           └── brush_panel.dart     # Floating Brush Studio (presets, size, opacity, streamline)
├── pubspec.yaml                     # Dependencies (Riverpod, Hive, PDF, Share, ImagePicker)
├── AGENTS.md                        # This document
├── DEVELOPER_GUIDE.md               # Technical manual for human and automated developers
└── README.md                        # User and developer orientation
```

---

## 3. State Management Architecture

OpenCreate utilizes **Riverpod** (`StateNotifierProvider`) for unidirectional reactive state flow.

### Core Providers:
1. **`canvasProvider`** (`lib/providers/canvas_provider.dart`):
   - Holds `CanvasState`: active tool (`DrawingTool`), zoom level, pan offset, rotation angle, committed strokes per layer (`Map<String, List<DrawStroke>>`), active stroke points, undo/redo history stacks, grid toggle, symmetry mode, palm rejection toggle, stylus-only toggle, and floating reference image data (`ReferenceImageData`).
   - Key methods: `beginStroke()`, `continueStroke()`, `endStroke()`, `beginShape()`, `updateShape()`, `commitShape()`, `commitText()`, `commitFill()`, `commitGradient()`, `undo()`, `redo()`, `fitToScreen()`, `setReferenceImage()`.

2. **`layerProvider`** (`lib/providers/layer_provider.dart`):
   - Holds `LayerState`: ordered list of `LayerModel`s, `activeLayerId`, and decoded `ui.Image` cache (`layerImages`).
   - Key methods: `addLayer()`, `addImageLayer(bytes)`, `removeLayer()`, `duplicateLayer()`, `reorderLayer()`, `toggleVisibility()`, `toggleLock()`, `toggleAlphaLock()`, `setOpacity()`, `setBlendMode()`, `mergeLayers()`, `mergeVisible()`.

3. **`activeBrushProvider`** (`lib/providers/brush_provider.dart`):
   - Manages active brush parameters: size, opacity, hardness, spacing, streamline stabilization.
   - **Critical Architectural Invariant**: To prevent the "eraser-to-brush" bug, `ActiveBrushNotifier` preserves `_lastDrawingBrush`. When switching to eraser (`selectEraser()`), the previous brush is saved. When switching back to any drawing tool (`restoreDrawingBrush()`), the non-eraser brush model and blend mode are immediately restored.

4. **`drawingColorProvider`** (`lib/providers/brush_provider.dart`):
   - Manages primary drawing color, secondary background color, color history (last 16 colors), and FG/BG swap.

---

## 4. Coordinate Transformations & Viewport Pipeline

In `lib/widgets/canvas/drawing_canvas.dart`, the canvas is drawn inside an interactive viewport with pinch-to-zoom, two-finger pan, and rotation.

### Transform Pipeline:
1. **Screen Point to Canvas Point** (`_screenToCanvas`):
   ```dart
   // 1. Center alignment offset
   final originX = (screenSize.width - canvasW * zoom) / 2 + pan.dx;
   final originY = (screenSize.height - canvasH * zoom) / 2 + pan.dy;
   
   // 2. Translate relative to canvas center
   var pt = screenPoint - Offset(originX + (canvasW * zoom)/2, originY + (canvasH * zoom)/2);
   
   // 3. Inverse rotate
   if (rotation != 0.0) {
     final cosR = math.cos(-rotation);
     final sinR = math.sin(-rotation);
     pt = Offset(pt.dx * cosR - pt.dy * sinR, pt.dx * sinR + pt.dy * cosR);
   }
   
   // 4. Inverse scale
   pt = pt / zoom + Offset(canvasW / 2, canvasH / 2);
   ```

2. **Pointer Classification**:
   - `PointerDeviceKind.stylus` / `invertedStylus`: Treated with pressure sensitivity. When `stylusOnlyMode` is active, finger touches are ignored for drawing, avoiding palm accidental marks.
   - Scale gestures with `pointerCount >= 2` override drawing to pan, zoom, or rotate canvas smoothly.

---

## 5. Rendering Pipeline (`CanvasPainter`)

Rendering is performed in `lib/widgets/canvas/canvas_painter.dart`:
1. **Clip Boundary**: Canvas clipped to `0, 0, canvasWidth, canvasHeight`.
2. **Transparency Grid**: Checkerboard pattern drawn first.
3. **Background**: Solid color if `canvas.backgroundColor != Colors.transparent`.
4. **Layer Compositing (Bottom to Top)**:
   - For each visible layer:
     - `canvas.saveLayer(rect, Paint()..blendMode = layer.blendMode..color = opacity)`
     - Render layer background image (`layerImages[layer.id]`) if present.
     - Render all committed strokes for this layer.
     - If layer is active, render active in-progress strokes.
     - `canvas.restore()`
5. **Symmetry Mirroring**: If `symmetryMode != SymmetryMode.none`, strokes are reflected across vertical, horizontal, or 8-way radial axes.
6. **Overlay**: Grid lines and symmetry guide lines rendered on top.

---

## 6. Multi-Format Exporters (`ImageUtils`)

OpenCreate provides 4 distinct export pipelines:
- **PNG**: Lossless raster export with transparency via `ui.Image.toByteData(format: png)`.
- **JPEG / JPG**: High-quality compressed photograph format with configurable quality (default 92%) via `image` package.
- **SVG**: True Scalable Vector Graphics output generated by serializing `DrawStroke` models into clean XML path, shape, polygon, and text tags. Compatible with vector editors like Inkscape and Adobe Illustrator.
- **PDF**: Multi-resolution PDF document generated using the `pdf` package, formatting the canvas directly onto full-resolution document pages.

---

## 7. Checklist for Future Modifications
- [ ] Run `flutter analyze` and ensure 0 compilation errors.
- [ ] Verify portrait & landscape views on small screens (<= 360px wide) have NO pixel overflow.
- [ ] Confirm switching back and forth between Brush and Eraser restores normal painting.
- [ ] Test that reference images can be freely moved/scaled without polluting exported artwork.
- [ ] Verify all 4 export formats (PNG, JPEG, SVG, PDF) generate valid files.
