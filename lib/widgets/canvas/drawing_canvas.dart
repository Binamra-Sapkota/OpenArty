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
  Offset? _touchStart;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final layerState = ref.watch(layerProvider);
    final brush = ref.watch(activeBrushProvider);
    final color = ref.watch(drawingColorProvider);
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
              _baseZoom = canvasState.zoomLevel;
              _basePan = canvasState.panOffset;
              _baseRotation = canvasState.rotation;
            }
          },
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) {
              _isGesturing = true;
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
          },
          child: Listener(
            onPointerDown: (event) {
              if (_isGesturing || event.buttons == kSecondaryButton) return;

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
              _touchStart = localPos;

              final canvasNotifier = ref.read(canvasProvider.notifier);
              final activeTool = canvasState.activeTool;

              if (activeTool == DrawingTool.brush ||
                  activeTool == DrawingTool.pencil ||
                  activeTool == DrawingTool.eraser ||
                  activeTool == DrawingTool.smudge) {
                // Ensure proper brush is active
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
                  strokeBrush = ref.read(activeBrushProvider.notifier).lastDrawingBrush;
                }

                canvasNotifier.beginStroke(
                  localPos,
                  strokeBrush,
                  color,
                  _currentPressure,
                );
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.beginShape(
                  localPos,
                  color,
                  canvasState.shapeStrokeWidth,
                  canvasState.isShapeFilled,
                );
              } else if (activeTool == DrawingTool.fill) {
                canvasNotifier.commitFill(color);
              } else if (activeTool == DrawingTool.eyedropper) {
                _sampleColor(localPos, layerState, canvasState);
              }
            },
            onPointerMove: (event) {
              if (_isGesturing) return;

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
                  strokeBrush = ref.read(activeBrushProvider.notifier).lastDrawingBrush;
                }
                canvasNotifier.continueStroke(
                  localPos,
                  strokeBrush,
                  _currentPressure,
                );
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.updateShape(localPos);
              } else if (activeTool == DrawingTool.eyedropper) {
                _sampleColor(localPos, layerState, canvasState);
              }
            },
            onPointerUp: (event) {
              final activeTool = canvasState.activeTool;
              final canvasNotifier = ref.read(canvasProvider.notifier);

              if (activeTool == DrawingTool.brush ||
                  activeTool == DrawingTool.pencil ||
                  activeTool == DrawingTool.eraser ||
                  activeTool == DrawingTool.smudge) {
                canvasNotifier.endStroke();
              } else if (activeTool == DrawingTool.shapes) {
                canvasNotifier.commitShape();
              } else if (activeTool == DrawingTool.gradient && _touchStart != null) {
                final localPos = _screenToCanvas(
                  event.localPosition,
                  canvasState,
                  constraints,
                );
                if (localPos != null) {
                  canvasNotifier.commitGradient(
                    _touchStart!,
                    localPos,
                    color,
                    ref.read(drawingColorProvider.notifier).secondaryColor,
                    isRadial: canvasState.isRadialGradient,
                  );
                }
              }
              _touchStart = null;
            },
            onPointerCancel: (event) {
              ref.read(canvasProvider.notifier).endStroke();
              _touchStart = null;
            },
            child: ClipRect(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ViewportPainter(
                  canvasState: canvasState,
                  layerState: layerState,
                  brush: brush,
                  brushMap: brushMap,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _sampleColor(
      Offset pos, LayerState layerState, CanvasState canvasState) {
    // Quick eyedropper sampling: cycles to drawing color
    // For vector stroke canvas, we find the closest stroke at this point
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

  _ViewportPainter({
    required this.canvasState,
    required this.layerState,
    required this.brush,
    required this.brushMap,
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
      activeLayerId: canvasState.activeLayerId,
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
