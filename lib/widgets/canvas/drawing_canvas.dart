import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../models/brush_model.dart';
import '../../models/layer_model.dart';
import '../../providers/brush_provider.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/gradient_provider.dart';
import '../../providers/layer_provider.dart';
import '../../utils/blend_modes.dart';
import 'canvas_painter.dart';

class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({super.key});

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  double _currentPressure = 1.0;
  DateTime? _lastPointerTime;
  Offset? _lastPointerCanvasPos;
  double _simulatedPressure = 0.7;

  double _baseZoom = 1.0;
  Offset _basePan = Offset.zero;
  double _baseRotation = 0.0;
  Offset _baseFocalPoint = Offset.zero;

  // Layer transform gesture tracking
  double _baseLayerScale = 1.0;
  double _baseLayerRotation = 0.0;
  Offset _baseLayerOffset = Offset.zero;
  bool _isScalingCorner = false;
  double _initialTouchDist = 0.0;
  double _initialLayerScale = 1.0;

  bool _isGesturing = false;
  int _activePointers = 0;
  Offset? _lastDragPos;
  Offset? _gradientStart;
  Offset? _gradientCurrent;

  double _resolvePressure(PointerEvent event, Offset canvasPos) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    // 1. Hardware Stylus Pressure (S-Pen, USI active pen, Apple Pencil)
    if (isStylus &&
        event.pressureMin < event.pressureMax &&
        event.pressure > 0.0) {
      final range = event.pressureMax - event.pressureMin;
      final normalized = range > 0
          ? ((event.pressure - event.pressureMin) / range)
          : event.pressure;
      return normalized.clamp(0.05, 1.0);
    }

    // Direct hardware pressure if reported by active stylus
    if (isStylus && event.pressure > 0.0 && event.pressure != 1.0) {
      return event.pressure.clamp(0.05, 1.0);
    }

    // Standard touch/finger input: solid, smooth, consistent line (SketchBook style)
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final layerState = ref.watch(layerProvider);
    final brush = ref.watch(activeBrushProvider);
    final color = ref.watch(drawingColorProvider);
    final brushList = ref.watch(brushListProvider);
    final gradientConfig = ref.watch(gradientConfigProvider);

    final brushMap = {for (final b in brushList) b.id: b};

    // Decode any pending layer image data
    for (final layer in layerState.layers) {
      if (layer.pixelData != null && layerState.layerImages[layer.id] == null) {
        ui.decodeImageFromList(layer.pixelData!, (img) {
          ref.read(layerProvider.notifier).updateLayerImage(layer.id, img);
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _baseFocalPoint = details.focalPoint;
            if (canvasState.activeTool == DrawingTool.transform) {
              final l = layerState.activeLayer;
              if (l != null) {
                _baseLayerScale = l.scale;
                _baseLayerRotation = l.rotation;
                _baseLayerOffset = Offset(l.offsetX, l.offsetY);
              }
            } else if (details.pointerCount >= 2) {
              _isGesturing = true;
              ref.read(canvasProvider.notifier).cancelCurrentStroke();
              _baseZoom = canvasState.zoomLevel;
              _basePan = canvasState.panOffset;
              _baseRotation = canvasState.rotation;
            }
          },
          onScaleUpdate: (details) {
            if (canvasState.activeTool == DrawingTool.transform) {
              final l = layerState.activeLayer;
              if (l != null && details.pointerCount >= 2) {
                _isGesturing = true;
                final newScale =
                    (_baseLayerScale * details.scale).clamp(0.05, 30.0);
                final newRot = _baseLayerRotation + details.rotation;
                final panDelta = (details.focalPoint - _baseFocalPoint) /
                    canvasState.zoomLevel;
                var delta = panDelta;
                if (canvasState.rotation != 0.0) {
                  final cosR = math.cos(-canvasState.rotation);
                  final sinR = math.sin(-canvasState.rotation);
                  delta = Offset(delta.dx * cosR - delta.dy * sinR,
                      delta.dx * sinR + delta.dy * cosR);
                }
                ref.read(layerProvider.notifier).updateLayerTransform(
                      l.id,
                      scale: newScale,
                      rotation: newRot,
                      offsetX: _baseLayerOffset.dx + delta.dx,
                      offsetY: _baseLayerOffset.dy + delta.dy,
                    );
              }
            } else if (details.pointerCount >= 2) {
              _isGesturing = true;
              ref.read(canvasProvider.notifier).cancelCurrentStroke();
              final newZoom = (_baseZoom * details.scale).clamp(0.05, 50.0);
              final newPan =
                  _basePan + (details.focalPoint - _baseFocalPoint);
              final newRotation = _baseRotation + details.rotation;

              ref.read(canvasProvider.notifier).setZoom(newZoom);
              ref.read(canvasProvider.notifier).setPan(newPan);
              ref.read(canvasProvider.notifier).setRotation(newRotation);
            }
          },
          onScaleEnd: (details) {
            _isGesturing = false;
            _activePointers = 0;
          },
          child: Listener(
            onPointerDown: (event) {
              _activePointers++;
              if (_activePointers >= 2 || _isGesturing || event.buttons == kSecondaryButton) {
                ref.read(canvasProvider.notifier).cancelCurrentStroke();
                return;
              }

              // Palm rejection / stylus mode
              final isStylus = event.kind == PointerDeviceKind.stylus ||
                  event.kind == PointerDeviceKind.invertedStylus;
              if (canvasState.stylusOnlyMode && !isStylus) return;

              final localPos = _screenToCanvas(
                event.localPosition,
                canvasState,
                constraints,
              );
              if (localPos == null) return;
              _lastDragPos = localPos;
              _currentPressure = _resolvePressure(event, localPos);

              final canvasNotifier = ref.read(canvasProvider.notifier);
              final activeTool = canvasState.activeTool;
              final activeLayerId = layerState.activeLayerId;

              if (activeTool == DrawingTool.brush ||
                  activeTool == DrawingTool.pencil ||
                  activeTool == DrawingTool.eraser ||
                  activeTool == DrawingTool.smudge) {
                BrushModel strokeBrush = brush;
                if (activeTool == DrawingTool.eraser) {
                  strokeBrush = brush.copyWith(
                    type: BrushType.eraser,
                    id: 'eraser_1',
                    name: 'Eraser',
                  );
                } else if (brush.type == BrushType.eraser) {
                  // User switched to drawing tool; restore drawing brush
                  ref.read(activeBrushProvider.notifier).restoreDrawingBrush();
                  strokeBrush =
                      ref.read(activeBrushProvider.notifier).lastDrawingBrush;
                }

                canvasNotifier.beginStroke(
                  localPos,
                  strokeBrush,
                  color,
                  _currentPressure,
                  layerId: activeLayerId,
                );
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.beginShape(
                  localPos,
                  color,
                  canvasState.shapeStrokeWidth,
                  canvasState.isShapeFilled,
                );
              } else if (activeTool == DrawingTool.gradient) {
                setState(() {
                  _gradientStart = localPos;
                  _gradientCurrent = localPos;
                });
              } else if (activeTool == DrawingTool.eyedropper) {
                _sampleColor(localPos, layerState, canvasState);
              } else if (activeTool == DrawingTool.transform) {
                canvasNotifier.recordSnapshot();
                final l = layerState.activeLayer;
                if (l != null) {
                  final canvasW = canvasState.canvas.width.toDouble();
                  final canvasH = canvasState.canvas.height.toDouble();
                  final layerImg = layerState.layerImages[l.id];

                  double naturalW = canvasW;
                  double naturalH = canvasH;
                  if (l.isTextLayer) {
                    final text = l.textContent ?? '';
                    final textStyle = TextStyle(
                      fontSize: l.fontSize ?? 36.0,
                      fontWeight: l.isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: l.isItalic ? FontStyle.italic : FontStyle.normal,
                    );
                    final tp = TextPainter(
                      text: TextSpan(
                          text: text.isNotEmpty ? text : 'Text',
                          style: textStyle),
                      textDirection: TextDirection.ltr,
                    )..layout();
                    naturalW = math.max(60.0, tp.width + 24.0);
                    naturalH = math.max(40.0, tp.height + 24.0);
                  } else if (layerImg != null) {
                    final imgAspect = layerImg.width / layerImg.height;
                    final canvasAspect = canvasW / canvasH;
                    if (imgAspect > canvasAspect) {
                      naturalW = canvasW;
                      naturalH = canvasW / imgAspect;
                    } else {
                      naturalH = canvasH;
                      naturalW = canvasH * imgAspect;
                    }
                  }

                  final center = Offset(
                      canvasW / 2 + l.offsetX, canvasH / 2 + l.offsetY);
                  final touchDist = (localPos - center).distance;
                  final cornerDist = math.sqrt(
                      math.pow(naturalW * l.scale / 2, 2) +
                          math.pow(naturalH * l.scale / 2, 2));

                  if ((touchDist - cornerDist).abs() <
                      50.0 / canvasState.zoomLevel) {
                    _isScalingCorner = true;
                    _initialTouchDist = math.max(10.0, touchDist);
                    _initialLayerScale = l.scale;
                  } else {
                    _isScalingCorner = false;
                  }
                }
              }
            },
            onPointerMove: (event) {
              if (_activePointers >= 2 || _isGesturing) {
                ref.read(canvasProvider.notifier).cancelCurrentStroke();
                return;
              }

              final isStylus = event.kind == PointerDeviceKind.stylus ||
                  event.kind == PointerDeviceKind.invertedStylus;
              if (canvasState.stylusOnlyMode && !isStylus) return;

              final localPos = _screenToCanvas(
                event.localPosition,
                canvasState,
                constraints,
              );
              if (localPos == null) return;
              _currentPressure = _resolvePressure(event, localPos);

              final activeTool = canvasState.activeTool;
              final canvasNotifier = ref.read(canvasProvider.notifier);

              if (activeTool == DrawingTool.brush ||
                  activeTool == DrawingTool.pencil ||
                  activeTool == DrawingTool.eraser ||
                  activeTool == DrawingTool.smudge) {
                BrushModel strokeBrush = brush;
                if (activeTool == DrawingTool.eraser) {
                  strokeBrush = brush.copyWith(
                    type: BrushType.eraser,
                    id: 'eraser_1',
                  );
                } else if (brush.type == BrushType.eraser) {
                  strokeBrush =
                      ref.read(activeBrushProvider.notifier).lastDrawingBrush;
                }
                canvasNotifier.continueStroke(
                  localPos,
                  strokeBrush,
                  _currentPressure,
                );
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.updateShape(localPos);
              } else if (activeTool == DrawingTool.transform &&
                  _lastDragPos != null) {
                final delta = localPos - _lastDragPos!;
                _lastDragPos = localPos;
                final l = layerState.activeLayer;
                if (l != null && !_isGesturing) {
                  if (_isScalingCorner && _initialTouchDist > 0) {
                    final canvasW = canvasState.canvas.width.toDouble();
                    final canvasH = canvasState.canvas.height.toDouble();
                    final center = Offset(
                        canvasW / 2 + l.offsetX, canvasH / 2 + l.offsetY);
                    final currentDist = (localPos - center).distance;
                    final scaleFactor = currentDist / _initialTouchDist;
                    ref.read(layerProvider.notifier).updateLayerTransform(
                          l.id,
                          scale: (_initialLayerScale * scaleFactor)
                              .clamp(0.05, 30.0),
                        );
                  } else {
                    ref.read(layerProvider.notifier).updateLayerTransform(
                          l.id,
                          offsetX: l.offsetX + delta.dx,
                          offsetY: l.offsetY + delta.dy,
                        );
                  }
                }
              } else if (activeTool == DrawingTool.gradient &&
                  _gradientStart != null) {
                setState(() {
                  _gradientCurrent = localPos;
                });
              } else if (activeTool == DrawingTool.eyedropper) {
                _sampleColor(localPos, layerState, canvasState);
              }
            },
            onPointerUp: (event) {
              _isScalingCorner = false;
              _initialTouchDist = 0.0;
              _lastPointerTime = null;
              _lastPointerCanvasPos = null;
              _simulatedPressure = 0.7;
              _activePointers = math.max(0, _activePointers - 1);
              if (_activePointers == 0) {
                _isGesturing = false;
              }

              if (_isGesturing) {
                ref.read(canvasProvider.notifier).cancelCurrentStroke();
                _lastDragPos = null;
                _gradientStart = null;
                _gradientCurrent = null;
                return;
              }

              final activeTool = canvasState.activeTool;
              final canvasNotifier = ref.read(canvasProvider.notifier);
              final activeLayerId = layerState.activeLayerId;

              final localPos = _screenToCanvas(
                event.localPosition,
                canvasState,
                constraints,
              );

              if (activeTool == DrawingTool.brush ||
                  activeTool == DrawingTool.pencil ||
                  activeTool == DrawingTool.eraser ||
                  activeTool == DrawingTool.smudge) {
                canvasNotifier.endStroke();
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.commitShape();
              } else if (activeTool == DrawingTool.fill && localPos != null) {
                _performFloodFill(localPos, color);
              } else if (activeTool == DrawingTool.text && localPos != null) {
                final canvasW = canvasState.canvas.width.toDouble();
                final canvasH = canvasState.canvas.height.toDouble();
                String? tappedTextId;

                for (final l in layerState.layers) {
                  if (l.isTextLayer && l.isVisible) {
                    final text = l.textContent ?? '';
                    final tp = TextPainter(
                      text: TextSpan(
                        text: text.isNotEmpty ? text : 'Text',
                        style: TextStyle(
                          fontSize: l.fontSize ?? 36.0,
                          fontWeight: l.isBold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: l.isItalic ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      textDirection: TextDirection.ltr,
                    )..layout();
                    final cX = canvasW / 2 + l.offsetX;
                    final cY = canvasH / 2 + l.offsetY;
                    final boxW = math.max(60.0, tp.width + 30.0) * l.scale;
                    final boxH = math.max(40.0, tp.height + 30.0) * l.scale;
                    final rect = Rect.fromCenter(
                        center: Offset(cX, cY), width: boxW, height: boxH);
                    if (rect.contains(localPos)) {
                      tappedTextId = l.id;
                      break;
                    }
                  }
                }

                if (tappedTextId != null) {
                  ref.read(layerProvider.notifier).setActiveLayer(tappedTextId);
                  _showEditTextLayerDialog(context, tappedTextId);
                } else {
                  _showAddTextLayerDialog(context, localPos);
                }
              } else if (activeTool == DrawingTool.gradient &&
                  _gradientStart != null &&
                  localPos != null) {
                String targetLayerId = activeLayerId;
                if (gradientConfig.createInNewLayer) {
                  final layerNotifier = ref.read(layerProvider.notifier);
                  final newName =
                      'Gradient ${layerState.layers.length + 1}';
                  layerNotifier.addLayer(name: newName);
                  targetLayerId = ref.read(layerProvider).activeLayerId;
                }

                canvasNotifier.commitGradient(
                  _gradientStart!,
                  localPos,
                  gradientConfig.startColor,
                  gradientConfig.endColor,
                  isRadial: gradientConfig.isRadial,
                  layerId: targetLayerId,
                );
              }

              _lastDragPos = null;
              setState(() {
                _gradientStart = null;
                _gradientCurrent = null;
              });
            },
            onPointerCancel: (event) {
              _activePointers = 0;
              _isGesturing = false;
              ref.read(canvasProvider.notifier).cancelCurrentStroke();
              _lastDragPos = null;
              setState(() {
                _gradientStart = null;
                _gradientCurrent = null;
              });
            },
            child: ClipRect(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ViewportPainter(
                  canvasState: canvasState,
                  layerState: layerState,
                  brush: brush,
                  brushMap: brushMap,
                  gradientStart: _gradientStart,
                  gradientCurrent: _gradientCurrent,
                  gradientColor1: gradientConfig.startColor,
                  gradientColor2: gradientConfig.endColor,
                  isRadialGradient: gradientConfig.isRadial,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isFloodFilling = false;

  /// MS Paint style BFS flood fill that stops at any drawn strokes/lines/shapes
  Future<void> _performFloodFill(Offset localPos, Color fillColor) async {
    if (_isFloodFilling) return;
    _isFloodFilling = true;

    try {
      final canvasState = ref.read(canvasProvider);
      final layerState = ref.read(layerProvider);
      final activeLayerId = layerState.activeLayerId;
      final brushList = ref.read(brushListProvider);
      final brushMap = {for (final b in brushList) b.id: b};
      final brush = ref.read(activeBrushProvider);

      final canvasW = canvasState.canvas.width;
      final canvasH = canvasState.canvas.height;

      final startX = localPos.dx.round().clamp(0, canvasW - 1);
      final startY = localPos.dy.round().clamp(0, canvasH - 1);

      // 1. Snapshot the current visual canvas into raw RGBA bytes
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = CanvasPainter(
        layers: layerState.layers,
        committedStrokes: canvasState.committedStrokes,
        currentStrokes: const [],
        activeLayerId: activeLayerId,
        brushMap: brushMap,
        showGrid: false,
        gridSize: canvasState.gridSize,
        symmetryMode: SymmetryMode.none,
        radialSymmetryCount: 8,
        showSymmetryGuide: false,
        canvasState: canvasState,
        layerImages: layerState.layerImages,
      );
      painter.paint(canvas, Size(canvasW.toDouble(), canvasH.toDouble()));
      final picture = recorder.endRecording();
      final snapImage = await picture.toImage(canvasW, canvasH);
      final byteData =
          await snapImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final startIdx = (startY * canvasW + startX) * 4;
      final tR = bytes[startIdx];
      final tG = bytes[startIdx + 1];
      final tB = bytes[startIdx + 2];
      final tA = bytes[startIdx + 3];

      final fR = fillColor.red;
      final fG = fillColor.green;
      final fB = fillColor.blue;
      final fA = fillColor.alpha;

      // Don't fill if color is already the same
      if ((tR - fR).abs() <= 5 &&
          (tG - fG).abs() <= 5 &&
          (tB - fB).abs() <= 5 &&
          (tA - fA).abs() <= 5) {
        return;
      }

      // Fast BFS flood fill using flat arrays
      final numPixels = canvasW * canvasH;
      final visited = Uint8List(numPixels);
      final queue = Int32List(numPixels);
      int head = 0;
      int tail = 0;

      queue[tail++] = startY * canvasW + startX;
      visited[startY * canvasW + startX] = 1;

      int minX = startX;
      int maxX = startX;
      int minY = startY;
      int maxY = startY;

      bool matches(int x, int y) {
        final idx = (y * canvasW + x) * 4;
        final r = bytes[idx];
        final g = bytes[idx + 1];
        final b = bytes[idx + 2];
        final a = bytes[idx + 3];
        final diff = (r - tR).abs() +
            (g - tG).abs() +
            (b - tB).abs() +
            (a - tA).abs();
        return diff <= 52; // Tolerance for antialiased stroke edges
      }

      while (head < tail) {
        final pos = queue[head++];
        final curX = pos % canvasW;
        final curY = pos ~/ canvasW;

        if (curX < minX) minX = curX;
        if (curX > maxX) maxX = curX;
        if (curY < minY) minY = curY;
        if (curY > maxY) maxY = curY;

        if (curX + 1 < canvasW) {
          final n = curY * canvasW + (curX + 1);
          if (visited[n] == 0 && matches(curX + 1, curY)) {
            visited[n] = 1;
            queue[tail++] = n;
          }
        }
        if (curX - 1 >= 0) {
          final n = curY * canvasW + (curX - 1);
          if (visited[n] == 0 && matches(curX - 1, curY)) {
            visited[n] = 1;
            queue[tail++] = n;
          }
        }
        if (curY + 1 < canvasH) {
          final n = (curY + 1) * canvasW + curX;
          if (visited[n] == 0 && matches(curX, curY + 1)) {
            visited[n] = 1;
            queue[tail++] = n;
          }
        }
        if (curY - 1 >= 0) {
          final n = (curY - 1) * canvasW + curX;
          if (visited[n] == 0 && matches(curX, curY - 1)) {
            visited[n] = 1;
            queue[tail++] = n;
          }
        }
      }

      // 2. Extract bounding box of filled region
      final regionW = maxX - minX + 1;
      final regionH = maxY - minY + 1;
      final regionRgba = Uint8List(regionW * regionH * 4);

      for (int y = minY; y <= maxY; y++) {
        final rowOffset = (y - minY) * regionW;
        final srcRowOffset = y * canvasW;
        for (int x = minX; x <= maxX; x++) {
          if (visited[srcRowOffset + x] == 1) {
            final rIdx = (rowOffset + (x - minX)) * 4;
            regionRgba[rIdx] = fR;
            regionRgba[rIdx + 1] = fG;
            regionRgba[rIdx + 2] = fB;
            regionRgba[rIdx + 3] = fA;
          }
        }
      }

      // Decode to hardware ui.Image
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        regionRgba,
        regionW,
        regionH,
        ui.PixelFormat.rgba8888,
        (ui.Image img) => completer.complete(img),
      );
      final fillImage = await completer.future;

      // Encode PNG for undo / persistence
      final imgImage = img.Image.fromBytes(
        width: regionW,
        height: regionH,
        bytes: regionRgba.buffer,
        numChannels: 4,
      );
      final pngBytes = Uint8List.fromList(img.encodePng(imgImage));

      ref.read(canvasProvider.notifier).commitFloodFill(
            pngBytes,
            Offset(minX.toDouble(), minY.toDouble()),
            fillImage,
            layerId: activeLayerId,
            color: fillColor,
          );
    } catch (e) {
      debugPrint('Error in flood fill: $e');
    } finally {
      _isFloodFilling = false;
    }
  }

  void _showAddTextLayerDialog(BuildContext context, Offset pos) {
    final textController = TextEditingController();
    double fontSize = 42.0;
    Color textColor = ref.read(drawingColorProvider);
    bool isBold = false;
    bool isItalic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.title, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 8),
              Text('Add Text Layer',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type text here...',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.format_bold,
                          color: isBold
                              ? const Color(0xFF6C63FF)
                              : Colors.white38),
                      tooltip: 'Bold',
                      onPressed: () => setDialogState(() => isBold = !isBold),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic,
                          color: isItalic
                              ? const Color(0xFF6C63FF)
                              : Colors.white38),
                      tooltip: 'Italic',
                      onPressed: () =>
                          setDialogState(() => isItalic = !isItalic),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Size: ',
                        style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 14.0,
                        max: 180.0,
                        onChanged: (v) => setDialogState(() => fontSize = v),
                      ),
                    ),
                    Text('${fontSize.round()} pt',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('Place Text',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  final canvasState = ref.read(canvasProvider);
                  final canvasW = canvasState.canvas.width.toDouble();
                  final canvasH = canvasState.canvas.height.toDouble();
                  ref.read(layerProvider.notifier).addTextLayer(
                        txt,
                        fontSize: fontSize,
                        color: textColor,
                        isBold: isBold,
                        isItalic: isItalic,
                        initialPos: pos,
                        canvasSize: Size(canvasW, canvasH),
                      );
                  ref
                      .read(canvasProvider.notifier)
                      .setTool(DrawingTool.transform);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Text layer created! Drag to move, pinch to scale/rotate.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTextLayerDialog(BuildContext context, String layerId) {
    final layerState = ref.read(layerProvider);
    final layer =
        layerState.layers.firstWhereOrNull((l) => l.id == layerId);
    if (layer == null) return;

    final textController =
        TextEditingController(text: layer.textContent ?? '');
    double fontSize = layer.fontSize ?? 42.0;
    Color textColor = layer.textColor ?? Colors.white;
    bool isBold = layer.isBold;
    bool isItalic = layer.isItalic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 8),
              Text('Edit Text Layer',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Edit text...',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.format_bold,
                          color: isBold
                              ? const Color(0xFF6C63FF)
                              : Colors.white38),
                      tooltip: 'Bold',
                      onPressed: () => setDialogState(() => isBold = !isBold),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic,
                          color: isItalic
                              ? const Color(0xFF6C63FF)
                              : Colors.white38),
                      tooltip: 'Italic',
                      onPressed: () =>
                          setDialogState(() => isItalic = !isItalic),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Size: ',
                        style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 14.0,
                        max: 180.0,
                        onChanged: (v) => setDialogState(() => fontSize = v),
                      ),
                    ),
                    Text('${fontSize.round()} pt',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  ref.read(layerProvider.notifier).updateTextLayer(
                        layerId,
                        text: txt,
                        fontSize: fontSize,
                        color: textColor,
                        isBold: isBold,
                        isItalic: isItalic,
                      );
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sampleColor(
      Offset pos, LayerState layerState, CanvasState canvasState) {
    for (final strokes in canvasState.committedStrokes.values) {
      for (final stroke in strokes.reversed) {
        if (stroke.kind == StrokeKind.freehand) {
          for (final pt in stroke.points) {
            if ((pt.position - pos).distance <= stroke.brushSize) {
              ref.read(drawingColorProvider.notifier).setColor(stroke.color);
              return;
            }
          }
        }
      }
    }
  }

  Offset? _screenToCanvas(
    Offset screenPoint,
    CanvasState state,
    BoxConstraints constraints,
  ) {
    final canvasW = state.canvas.width.toDouble();
    final canvasH = state.canvas.height.toDouble();
    final zoom = state.zoomLevel;
    final pan = state.panOffset;
    final rotation = state.rotation;

    final centerX = constraints.maxWidth / 2 + pan.dx;
    final centerY = constraints.maxHeight / 2 + pan.dy;

    var dx = screenPoint.dx - centerX;
    var dy = screenPoint.dy - centerY;

    if (rotation != 0.0) {
      final cosR = math.cos(-rotation);
      final sinR = math.sin(-rotation);
      final rx = dx * cosR - dy * sinR;
      final ry = dx * sinR + dy * cosR;
      dx = rx;
      dy = ry;
    }

    final canvasX = dx / zoom + canvasW / 2;
    final canvasY = dy / zoom + canvasH / 2;

    return Offset(canvasX, canvasY);
  }
}

class _ViewportPainter extends CustomPainter {
  final CanvasState canvasState;
  final LayerState layerState;
  final BrushModel brush;
  final Map<String, BrushModel> brushMap;
  final Offset? gradientStart;
  final Offset? gradientCurrent;
  final Color? gradientColor1;
  final Color? gradientColor2;
  final bool isRadialGradient;

  _ViewportPainter({
    required this.canvasState,
    required this.layerState,
    required this.brush,
    required this.brushMap,
    this.gradientStart,
    this.gradientCurrent,
    this.gradientColor1,
    this.gradientColor2,
    this.isRadialGradient = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasW = canvasState.canvas.width.toDouble();
    final canvasH = canvasState.canvas.height.toDouble();
    final zoom = canvasState.zoomLevel;
    final pan = canvasState.panOffset;
    final rotation = canvasState.rotation;

    final centerX = size.width / 2 + pan.dx;
    final centerY = size.height / 2 + pan.dy;

    canvas.save();
    canvas.translate(centerX, centerY);
    if (rotation != 0.0) {
      canvas.rotate(rotation);
    }
    canvas.scale(zoom);
    canvas.translate(-canvasW / 2, -canvasH / 2);

    // Drop shadow behind canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
    );

    // Paint canvas content
    final canvasPainter = CanvasPainter(
      layers: layerState.layers,
      committedStrokes: canvasState.committedStrokes,
      currentStrokes: canvasState.currentStrokes,
      activeLayerId: layerState.activeLayerId,
      brushMap: brushMap,
      showGrid: canvasState.showGrid,
      gridSize: canvasState.gridSize,
      symmetryMode: canvasState.symmetryMode,
      radialSymmetryCount: canvasState.radialSymmetryCount,
      showSymmetryGuide: canvasState.showSymmetryGuide,
      canvasState: canvasState,
      layerImages: layerState.layerImages,
    );

    canvasPainter.paint(canvas, Size(canvasW, canvasH));

    // Active Layer Transform Bounding Box & Interactive Handles
    if (canvasState.activeTool == DrawingTool.transform &&
        layerState.activeLayer != null) {
      final l = layerState.activeLayer!;
      final layerImg = layerState.layerImages[l.id];

      double naturalW = canvasW;
      double naturalH = canvasH;
      if (l.isTextLayer) {
        final text = l.textContent ?? '';
        final textStyle = TextStyle(
          fontSize: l.fontSize ?? 36.0,
          fontWeight: l.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: l.isItalic ? FontStyle.italic : FontStyle.normal,
        );
        final tp = TextPainter(
          text: TextSpan(
              text: text.isNotEmpty ? text : 'Text',
              style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        naturalW = math.max(60.0, tp.width + 24.0);
        naturalH = math.max(40.0, tp.height + 24.0);
      } else if (layerImg != null) {
        final imgAspect = layerImg.width / layerImg.height;
        final canvasAspect = canvasW / canvasH;
        if (imgAspect > canvasAspect) {
          naturalW = canvasW;
          naturalH = canvasW / imgAspect;
        } else {
          naturalH = canvasH;
          naturalW = canvasH * imgAspect;
        }
      }

      final halfW = (naturalW * l.scale) / 2;
      final halfH = (naturalH * l.scale) / 2;

      canvas.save();
      canvas.translate(canvasW / 2 + l.offsetX, canvasH / 2 + l.offsetY);
      if (l.rotation != 0.0) canvas.rotate(l.rotation);

      final boxPaint = Paint()
        ..color = const Color(0xFF6C63FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoom;

      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final handleBorder = Paint()
        ..color = const Color(0xFF6C63FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoom;

      final handleRadius = 8.0 / zoom;

      // Draw bounding rectangle
      canvas.drawRect(Rect.fromLTRB(-halfW, -halfH, halfW, halfH), boxPaint);

      // Corner handles
      void drawCircleHandle(double x, double y) {
        canvas.drawCircle(Offset(x, y), handleRadius, handlePaint);
        canvas.drawCircle(Offset(x, y), handleRadius, handleBorder);
      }

      drawCircleHandle(-halfW, -halfH); // Top-left
      drawCircleHandle(halfW, -halfH); // Top-right
      drawCircleHandle(-halfW, halfH); // Bottom-left
      drawCircleHandle(halfW, halfH); // Bottom-right

      // Edge midpoint handles
      drawCircleHandle(0, -halfH);
      drawCircleHandle(0, halfH);
      drawCircleHandle(-halfW, 0);
      drawCircleHandle(halfW, 0);

      // Rotation pin at top
      final rotationPinY = -halfH - 24.0 / zoom;
      canvas.drawLine(Offset(0, -halfH), Offset(0, rotationPinY), boxPaint);
      canvas.drawCircle(
          Offset(0, rotationPinY), handleRadius, Paint()..color = const Color(0xFF6C63FF));
      canvas.drawCircle(
          Offset(0, rotationPinY),
          handleRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / zoom);

      // Center crosshair
      final crossSize = 8.0 / zoom;
      canvas.drawLine(Offset(-crossSize, 0), Offset(crossSize, 0), boxPaint);
      canvas.drawLine(Offset(0, -crossSize), Offset(0, crossSize), boxPaint);

      canvas.restore();
    }

    // Live gradient drag guideline preview
    if (gradientStart != null && gradientCurrent != null) {
      final start = gradientStart!;
      final end = gradientCurrent!;
      final c1 = gradientColor1 ?? Colors.white;
      final c2 = gradientColor2 ?? Colors.transparent;

      final guidePaint = Paint()
        ..color = Colors.white70
        ..strokeWidth = 2.0 / zoom
        ..style = PaintingStyle.stroke;

      if (isRadialGradient) {
        final radius = (end - start).distance;
        canvas.drawCircle(start, radius, guidePaint);
      } else {
        canvas.drawLine(start, end, guidePaint);
      }

      // Endpoint pucks
      final p1 = Paint()
        ..color = c1
        ..style = PaintingStyle.fill;
      final p2 = Paint()
        ..color = c2
        ..style = PaintingStyle.fill;
      final strokeRing = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoom;

      canvas.drawCircle(start, 8.0 / zoom, p1);
      canvas.drawCircle(start, 8.0 / zoom, strokeRing);
      canvas.drawCircle(end, 8.0 / zoom, p2);
      canvas.drawCircle(end, 8.0 / zoom, strokeRing);
    }

    // Canvas border outline
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / zoom,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ViewportPainter oldDelegate) => true;
}
