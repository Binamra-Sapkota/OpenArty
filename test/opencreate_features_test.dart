import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencreate/models/canvas_model.dart';
import 'package:opencreate/models/history_model.dart';
import 'package:opencreate/models/layer_model.dart';
import 'package:opencreate/providers/brush_provider.dart';
import 'package:opencreate/providers/canvas_provider.dart';
import 'package:opencreate/providers/layer_provider.dart';
import 'package:opencreate/utils/blend_modes.dart';
import 'package:opencreate/utils/image_utils.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Individual Text Layer Tests', () {
    test('LayerModel text fields, isTextLayer, and JSON serialization', () {
      final textLayer = LayerModel(
        id: 'text-1',
        name: 'T: "Hello OpenCreate"',
        layerType: LayerType.text,
        textContent: 'Hello OpenCreate',
        fontSize: 48.0,
        textColor: const Color(0xFF6C63FF),
        isBold: true,
        isItalic: false,
        offsetX: 50.0,
        offsetY: -30.0,
        scale: 1.5,
        rotation: 0.25,
      );

      expect(textLayer.isTextLayer, true);
      expect(textLayer.textContent, 'Hello OpenCreate');
      expect(textLayer.fontSize, 48.0);
      expect(textLayer.textColor, const Color(0xFF6C63FF));
      expect(textLayer.isBold, true);
      expect(textLayer.isItalic, false);

      final json = textLayer.toJson();
      expect(json['layerType'], LayerType.text.index);
      expect(json['textContent'], 'Hello OpenCreate');
      expect(json['fontSize'], 48.0);

      final fromJson = LayerModel.fromJson(json);
      expect(fromJson.id, 'text-1');
      expect(fromJson.isTextLayer, true);
      expect(fromJson.textContent, 'Hello OpenCreate');
      expect(fromJson.fontSize, 48.0);
      expect(fromJson.isBold, true);
      expect(fromJson.isItalic, false);
      expect(fromJson.scale, 1.5);
    });

    test('LayerNotifier addTextLayer, updateTextLayer, moveLayerUp, moveLayerDown', () {
      final initialId = 'base-layer';
      final notifier = LayerNotifier(
        LayerState(
          layers: [
            LayerModel(id: initialId, name: 'Background Layer'),
          ],
          activeLayerId: initialId,
        ),
      );

      // Add text layer
      notifier.addTextLayer(
        'Creative Title',
        fontSize: 50.0,
        color: const Color(0xFFFF5722),
        initialPos: const Offset(540, 200),
        canvasSize: const Size(1080, 1080),
      );

      expect(notifier.state.layers.length, 2);
      final activeLayer = notifier.state.activeLayer!;
      expect(activeLayer.isTextLayer, true);
      expect(activeLayer.textContent, 'Creative Title');
      expect(activeLayer.fontSize, 50.0);
      expect(activeLayer.offsetX, 540 - 540); // 0
      expect(activeLayer.offsetY, 200 - 540); // -340

      // It is placed above base layer (at index 0, so in front)
      expect(notifier.state.layers[0].id, activeLayer.id);
      expect(notifier.state.layers[1].id, initialId);

      // Update text
      notifier.updateTextLayer(
        activeLayer.id,
        text: 'Updated Title',
        fontSize: 60.0,
        isBold: true,
      );
      final updated = notifier.state.layers.firstWhere((l) => l.id == activeLayer.id);
      expect(updated.textContent, 'Updated Title');
      expect(updated.fontSize, 60.0);
      expect(updated.isBold, true);

      // Move Down (placed behind background layer)
      notifier.moveLayerDown(activeLayer.id);
      expect(notifier.state.layers[0].id, initialId);
      expect(notifier.state.layers[1].id, activeLayer.id);

      // Move Up (placed in front again)
      notifier.moveLayerUp(activeLayer.id);
      expect(notifier.state.layers[0].id, activeLayer.id);
      expect(notifier.state.layers[1].id, initialId);

      // Verify restorePreviousLayerIfText switches back to base layer after text placement
      expect(notifier.state.previousLayerIdBeforeTransform, initialId);
      notifier.restorePreviousLayerIfText();
      expect(notifier.state.activeLayerId, initialId);
      expect(notifier.state.previousLayerIdBeforeTransform, isNull);
    });
  });

  group('Adobe Photoshop PSD Export Tests', () {
    test('buildPsdBytes generates valid standard PSD with correct planar RGBA channels', () {
      const width = 120;
      const height = 80;
      final rawRgba = Uint8List(width * height * 4);

      // Fill with test gradient/colors
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = (y * width + x) * 4;
          rawRgba[idx] = (x * 255 ~/ width);      // R
          rawRgba[idx + 1] = (y * 255 ~/ height);  // G
          rawRgba[idx + 2] = 128;                 // B
          rawRgba[idx + 3] = 255;                 // A
        }
      }

      final psdBytes = ImageUtils.buildPsdBytes(width, height, rawRgba);
      expect(psdBytes.isNotEmpty, true);

      // Check header bytes
      expect(psdBytes[0], 0x38); // '8'
      expect(psdBytes[1], 0x42); // 'B'
      expect(psdBytes[2], 0x50); // 'P'
      expect(psdBytes[3], 0x53); // 'S'

      // Verify decodability with standard PsdDecoder
      final decoder = img.PsdDecoder();
      final decoded = decoder.decode(psdBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, width);
      expect(decoded.height, height);
      expect(decoded.numChannels, 4);

      // Check middle pixel color
      final p = decoded.getPixel(60, 40);
      expect(p.b, 128);
      expect(p.a, 255);
    });
  });

  group('Unified History & Cross-Layer Undo/Redo Tests', () {
    test('CanvasHistoryEntry JSON roundtrip preserves all layer and stroke data', () {
      final entry = CanvasHistoryEntry(
        committedStrokes: {
          'layer-1': [
            DrawStroke(
              points: [DrawPoint(position: const Offset(10, 10))],
              color: const Color(0xFFFF0000),
              brushId: 'brush_standard',
              brushSize: 5.0,
              brushOpacity: 1.0,
              layerId: 'layer-1',
            ),
          ],
        },
        layers: [
          LayerModel(id: 'layer-1', name: 'Background Layer'),
          LayerModel(
            id: 'text-layer-1',
            name: 'Text Note',
            layerType: LayerType.text,
            textContent: 'Hello World',
          ),
        ],
        activeLayerId: 'text-layer-1',
      );

      final json = entry.toJson();
      final restored = CanvasHistoryEntry.fromJson(json);

      expect(restored.activeLayerId, 'text-layer-1');
      expect(restored.layers.length, 2);
      expect(restored.layers[1].textContent, 'Hello World');
      expect(restored.committedStrokes['layer-1']!.length, 1);
      expect(restored.committedStrokes['layer-1']!.first.color, const Color(0xFFFF0000));
    });

    test('Undo rewinds across stroke, new layer, text layer, and gradient', () {
      final container = ProviderContainer();
      final canvasNotifier = container.read(canvasProvider.notifier);
      final layerNotifier = container.read(layerProvider.notifier);

      final baseLayerId = container.read(layerProvider).activeLayerId;
      canvasNotifier.initCanvas(const CanvasModel(), baseLayerId);

      // 1. Draw a stroke on base layer
      final brush = container.read(activeBrushProvider);
      canvasNotifier.beginStroke(const Offset(50, 50), brush, Colors.red, 1.0);
      canvasNotifier.endStroke();
      expect(container.read(canvasProvider).committedStrokes[baseLayerId]!.length, 1);
      expect(container.read(canvasProvider).canUndo, true);

      // 2. Add another layer
      layerNotifier.addLayer(name: 'Layer 2');
      expect(container.read(layerProvider).layers.length, 2);
      final layer2Id = container.read(layerProvider).activeLayerId;
      expect(layer2Id, isNot(baseLayerId));

      // 3. Add a text layer
      layerNotifier.addTextLayer('Sample Text');
      expect(container.read(layerProvider).layers.length, 3);
      final textLayerId = container.read(layerProvider).activeLayerId;
      expect(container.read(layerProvider).activeLayer!.isTextLayer, true);

      // 4. Commit gradient
      canvasNotifier.commitGradient(
        const Offset(0, 0),
        const Offset(200, 200),
        Colors.blue,
        Colors.purple,
      );
      expect(container.read(canvasProvider).committedStrokes[textLayerId]!.length, 1);

      // --- Now test step-by-step UNDO ---
      // Undo 1: Reverts gradient
      canvasNotifier.undo();
      expect(container.read(canvasProvider).committedStrokes[textLayerId] ?? [], isEmpty);

      // Undo 2: Reverts text layer
      canvasNotifier.undo();
      expect(container.read(layerProvider).layers.any((l) => l.id == textLayerId), false);
      expect(container.read(layerProvider).layers.length, 2);

      // Undo 3: Reverts Layer 2
      canvasNotifier.undo();
      expect(container.read(layerProvider).layers.any((l) => l.id == layer2Id), false);
      expect(container.read(layerProvider).layers.length, 1);
      expect(container.read(layerProvider).activeLayerId, baseLayerId);

      // Undo 4: Reverts stroke on base layer
      canvasNotifier.undo();
      expect(container.read(canvasProvider).committedStrokes[baseLayerId] ?? [], isEmpty);

      // --- Now test REDO forward ---
      // Redo 1: Stroke restored
      canvasNotifier.redo();
      expect(container.read(canvasProvider).committedStrokes[baseLayerId]!.length, 1);

      // Redo 2: Layer 2 restored
      canvasNotifier.redo();
      expect(container.read(layerProvider).layers.length, 2);

      // Redo 3: Text layer restored
      canvasNotifier.redo();
      expect(container.read(layerProvider).layers.length, 3);
      expect(container.read(layerProvider).layers.any((l) => l.isTextLayer), true);

      // Redo 4: Gradient restored
      canvasNotifier.redo();
      expect(container.read(canvasProvider).committedStrokes[textLayerId]!.length, 1);
    });
  });

  group('Zero-Lag Stroke & Pressure Dynamics Tests', () {
    test('continueStroke drops redundant sub-pixel movements to eliminate lag', () {
      final container = ProviderContainer();
      final canvasNotifier = container.read(canvasProvider.notifier);
      final layerNotifier = container.read(layerProvider.notifier);
      final brush = container.read(activeBrushProvider);

      layerNotifier.addLayer(name: 'Stroke Test Layer');
      final activeLayerId = container.read(layerProvider).activeLayerId;
      canvasNotifier.initCanvas(const CanvasModel(width: 800, height: 600), activeLayerId);

      // Begin stroke at (100, 100)
      canvasNotifier.beginStroke(
        const Offset(100, 100),
        brush,
        Colors.black,
        0.5,
        layerId: activeLayerId,
      );

      // Micro movement (< 1.5px) — should NOT add redundant point
      canvasNotifier.continueStroke(const Offset(100.3, 100.4), brush, 0.5);
      expect(container.read(canvasProvider).currentStrokes.first.points.length, 1);

      // Distinct movement (> 1.5px) — should be added
      canvasNotifier.continueStroke(const Offset(110.0, 105.0), brush, 0.8);
      expect(container.read(canvasProvider).currentStrokes.first.points.length, 2);

      // Check dynamic pressure scaling
      final pt2 = container.read(canvasProvider).currentStrokes.first.points.last;
      expect(pt2.pressure, 0.8);
      expect(pt2.size, brush.size * (0.25 + 0.75 * 0.8));

      canvasNotifier.endStroke();
      final committed = container.read(canvasProvider).committedStrokes[activeLayerId]!;
      expect(committed.length, 1);
      expect(committed.first.points.length, 2);
    });
  });

  group('New Vector Shapes and SVG Export Tests', () {
    test('All new vector shapes commit and export cleanly to SVG', () {
      final container = ProviderContainer();
      final canvasNotifier = container.read(canvasProvider.notifier);
      final layerNotifier = container.read(layerProvider.notifier);

      layerNotifier.addLayer(name: 'Shapes Layer');
      final activeLayerId = container.read(layerProvider).activeLayerId;
      canvasNotifier.initCanvas(const CanvasModel(width: 1000, height: 1000), activeLayerId);

      final testShapes = [
        ShapeType.star,
        ShapeType.polygon,
        ShapeType.diamond,
        ShapeType.heart,
        ShapeType.arrow,
        ShapeType.speechBubble,
        ShapeType.cloud,
      ];

      for (final s in testShapes) {
        canvasNotifier.setShapeType(s);
        canvasNotifier.beginShape(const Offset(50, 50), Colors.purple, 4.0, true);
        canvasNotifier.updateShape(const Offset(250, 250));
        canvasNotifier.commitShape();
      }

      final strokes = container.read(canvasProvider).committedStrokes[activeLayerId]!;
      expect(strokes.length, testShapes.length);

      final svg = ImageUtils.buildSvgContent(
        layers: container.read(layerProvider).layers,
        committedStrokes: container.read(canvasProvider).committedStrokes,
        width: 1000,
        height: 1000,
      );

      expect(svg.contains('<polygon points='), true);
      expect(svg.contains('<path d='), true);
      expect(svg.contains('<rect x='), true);
    });
  });

  group('Auto-Save, Project Persistence & Universal Layer Renaming Tests', () {
    test('renameLayer renames drawing, image, gradient, and text layers properly', () {
      final container = ProviderContainer();
      final layerNotifier = container.read(layerProvider.notifier);

      // 1. Rename default drawing layer
      final layer1Id = container.read(layerProvider).layers.first.id;
      layerNotifier.renameLayer(layer1Id, 'Custom Lineart');
      expect(container.read(layerProvider).layers.first.name, 'Custom Lineart');

      // 2. Add and rename text layer
      layerNotifier.addTextLayer(
        'Title Text',
        color: Colors.blue,
        fontSize: 32.0,
      );
      final textLayer = container.read(layerProvider).layers.firstWhere((l) => l.isTextLayer);
      layerNotifier.renameLayer(textLayer.id, 'My Typography Layer');
      expect(
        container.read(layerProvider).layers.firstWhere((l) => l.id == textLayer.id).name,
        'My Typography Layer',
      );
      expect(
        container.read(layerProvider).layers.firstWhere((l) => l.id == textLayer.id).textContent,
        'Title Text',
      );

      // 3. Add and rename image layer
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      layerNotifier.addImageLayer(dummyBytes);
      final imgLayer = container.read(layerProvider).layers.firstWhere((l) => l.layerType == LayerType.image);
      layerNotifier.renameLayer(imgLayer.id, 'Imported Photo');
      expect(
        container.read(layerProvider).layers.firstWhere((l) => l.id == imgLayer.id).name,
        'Imported Photo',
      );

      // 4. Add and rename gradient layer
      layerNotifier.addLayer();
      final gradLayerId = container.read(layerProvider).activeLayerId;
      layerNotifier.renameLayer(gradLayerId, 'Sunset Gradient Layer');
      expect(
        container.read(layerProvider).layers.firstWhere((l) => l.id == gradLayerId).name,
        'Sunset Gradient Layer',
      );
    });

    test('saveProjectDataSync and saveProjectData persist complete project state to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('openarty_test_save_');
      ImageUtils.appDocPath = tempDir.path;

      final testLayers = [
        LayerModel(id: 'layer-1', name: 'Lineart Layer'),
        LayerModel(
          id: 'text-1',
          name: 'Hero Text',
          layerType: LayerType.text,
          textContent: 'OpenArty Forever',
          fontSize: 40,
        ),
      ];

      final Map<String, List<DrawStroke>> testStrokes = {
        'layer-1': [
          DrawStroke(
            points: [
              const DrawPoint(position: Offset(10, 10), pressure: 1.0),
              const DrawPoint(position: Offset(20, 20), pressure: 1.0),
            ],
            color: Colors.red,
            brushId: 'pencil',
            brushSize: 5.0,
            brushOpacity: 1.0,
            layerId: 'layer-1',
          ),
        ],
      };

      // Test synchronous persistence (for app exit / backgrounding)
      ImageUtils.saveProjectDataSync(
        projectId: 'test_project_sync',
        layers: testLayers,
        committedStrokes: testStrokes,
        activeLayerId: 'text-1',
        canvasWidth: 1920,
        canvasHeight: 1080,
        backgroundColor: Colors.transparent,
      );

      final loadedSync = await ImageUtils.loadProjectData('test_project_sync');
      expect(loadedSync, isNotNull);
      expect(loadedSync!['projectId'], 'test_project_sync');
      expect(loadedSync['activeLayerId'], 'text-1');
      expect(loadedSync['canvasWidth'], 1920);
      expect(loadedSync['canvasHeight'], 1080);
      expect(loadedSync['backgroundColor'], Colors.transparent.toARGB32());
      expect((loadedSync['layers'] as List).length, 2);
      expect((loadedSync['layers'] as List)[0]['name'], 'Lineart Layer');
      expect((loadedSync['layers'] as List)[1]['name'], 'Hero Text');

      // Test async persistence with thumbnail
      await ImageUtils.saveProjectData(
        projectId: 'test_project_async',
        layers: testLayers,
        committedStrokes: testStrokes,
        activeLayerId: 'layer-1',
        canvasWidth: 1080,
        canvasHeight: 1080,
        backgroundColor: Colors.white,
      );

      final loadedAsync = await ImageUtils.loadProjectData('test_project_async');
      expect(loadedAsync, isNotNull);
      expect(loadedAsync!['projectId'], 'test_project_async');
      expect((loadedAsync['layers'] as List).length, 2);

      await tempDir.delete(recursive: true);
    });
  });
}
