import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/brush_provider.dart';
import '../../providers/layer_provider.dart';
import '../../models/brush_model.dart';
import '../../utils/blend_modes.dart';
import 'canvas_painter.dart';

class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({super.key});

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  double _currentPressure = 1.0;
  double _baseZoom = 1.0;
  Offset _basePan = Offset.zero;
  double _baseRotation = 0.0;
  bool _isGesturing = false;
  int _activePointers = 0;
  Offset? _lastDragPos;
  Offset? _gradientStart;
  Offset? _gradientCurrent;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final layerState = ref.watch(layerProvider);
    final brush = ref.watch(activeBrushProvider);
    final color = ref.watch(drawingColorProvider);
    final secondaryColor =
        ref.watch(drawingColorProvider.notifier).secondaryColor;
    final brushList = ref.watch(brushListProvider);

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
            if (details.pointerCount >= 2) {
              _isGesturing = true;
              ref.read(canvasProvider.notifier).cancelCurrentStroke();
              _baseZoom = canvasState.zoomLevel;
              _basePan = canvasState.panOffset;
              _baseRotation = canvasState.rotation;
            }
          },
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) {
              _isGesturing = true;
              ref.read(canvasProvider.notifier).cancelCurrentStroke();
              final newZoom = (_baseZoom * details.scale).clamp(0.05, 50.0);
              final newPan = _basePan + details.focalPointDelta;
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

              _currentPressure = event.pressure > 0.0 ? event.pressure : 1.0;

              final localPos = _screenToCanvas(
                event.localPosition,
                canvasState,
                constraints,
              );
              if (localPos == null) return;
              _lastDragPos = localPos;

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

              _currentPressure = event.pressure > 0.0 ? event.pressure : 1.0;

              final localPos = _screenToCanvas(
                event.localPosition,
                canvasState,
                constraints,
              );
              if (localPos == null) return;

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
                if (l != null) {
                  ref.read(layerProvider.notifier).updateLayerTransform(
                        l.id,
                        offsetX: l.offsetX + delta.dx,
                        offsetY: l.offsetY + delta.dy,
                      );
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
                final filled = canvasNotifier.fillShapeAt(
                  localPos,
                  color,
                  layerId: activeLayerId,
                );
                if (!filled) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap inside a shape, line, or text to fill with color'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else if (activeTool == DrawingTool.text && localPos != null) {
                final textIdx = canvasNotifier.findTextStrokeAt(
                  localPos,
                  layerId: activeLayerId,
                );
                if (textIdx >= 0) {
                  _showEditTextDialog(context, textIdx, activeLayerId);
                } else {
                  _showPlaceTextDialog(context, localPos, activeLayerId);
                }
              } else if (activeTool == DrawingTool.gradient &&
                  _gradientStart != null &&
                  localPos != null) {
                canvasNotifier.commitGradient(
                  _gradientStart!,
                  localPos,
                  color,
                  secondaryColor,
                  isRadial: canvasState.isRadialGradient,
                  layerId: activeLayerId,
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
                  gradientColor1: color,
                  gradientColor2: secondaryColor,
                  isRadialGradient: canvasState.isRadialGradient,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlaceTextDialog(
      BuildContext context, Offset pos, String layerId) {
    final textController = TextEditingController();
    double fontSize = 36.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Text',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Enter text here...',
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
                  const Text('Size: ',
                      style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12.0,
                      max: 160.0,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                  ),
                  Text('${fontSize.round()} pt',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
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
                  final color = ref.read(drawingColorProvider);
                  ref.read(canvasProvider.notifier).commitText(
                        txt,
                        pos,
                        fontSize,
                        color,
                        layerId: layerId,
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

  void _showEditTextDialog(
      BuildContext context, int strokeIdx, String layerId) {
    final strokes =
        ref.read(canvasProvider).committedStrokes[layerId] ?? [];
    if (strokeIdx < 0 || strokeIdx >= strokes.length) return;
    final stroke = strokes[strokeIdx];

    final textController = TextEditingController(text: stroke.text ?? '');
    double fontSize = stroke.fontSize ?? 36.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF282828),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Text',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
                  const Text('Size: ',
                      style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12.0,
                      max: 160.0,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                  ),
                  Text('${fontSize.round()} pt',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                ref
                    .read(canvasProvider.notifier)
                    .deleteStroke(strokeIdx, layerId: layerId);
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child:
                  const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isNotEmpty) {
                  ref.read(canvasProvider.notifier).updateTextStroke(
                        strokeIdx,
                        text: txt,
                        fontSize: fontSize,
                        layerId: layerId,
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

    final scaledW = canvasW * zoom;
    final scaledH = canvasH * zoom;
    final originX = (constraints.maxWidth - scaledW) / 2 + pan.dx;
    final originY = (constraints.maxHeight - scaledH) / 2 + pan.dy;

    final canvasX = (screenPoint.dx - originX) / zoom;
    final canvasY = (screenPoint.dy - originY) / zoom;

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

    final scaledW = canvasW * zoom;
    final scaledH = canvasH * zoom;
    final originX = (size.width - scaledW) / 2 + pan.dx;
    final originY = (size.height - scaledH) / 2 + pan.dy;

    // Drop shadow behind canvas
    canvas.drawRect(
      Rect.fromLTWH(originX + 6, originY + 6, scaledW, scaledH),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    canvas.save();
    canvas.translate(originX + scaledW / 2, originY + scaledH / 2);
    if (rotation != 0.0) {
      canvas.rotate(rotation);
    }
    canvas.translate(-scaledW / 2, -scaledH / 2);
    canvas.scale(zoom);

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
