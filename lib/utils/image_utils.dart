import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/layer_model.dart';
import 'blend_modes.dart';

class ImageUtils {
  ImageUtils._();

  /// Resolve export directory for saved artworks
  static Future<Directory> getExportDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        final picturesDir = Directory('/storage/emulated/0/Pictures/OpenCreate');
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        dir = picturesDir;
      } catch (_) {
        dir = null;
      }
    }
    dir ??= await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/OpenCreate/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  /// Create a blank transparent image of given dimensions
  static Future<ui.Image> createBlankImage(int width, int height,
      {Color? backgroundColor}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (backgroundColor != null && backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = backgroundColor,
      );
    }

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  /// Convert ui.Image to PNG bytes
  static Future<Uint8List> imageToBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Convert PNG bytes to ui.Image
  static Future<ui.Image> bytesToImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Export canvas as PNG
  static Future<String> exportAsPng(
      ui.Image image, String projectName) async {
    final bytes = await imageToBytes(image);
    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Export canvas as JPEG / JPG
  static Future<String> exportAsJpeg(
      ui.Image image, String projectName, {int quality = 92}) async {
    final pngBytes = await imageToBytes(image);
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final jpegBytes = img.encodeJpg(imgImage, quality: quality);
    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.jpg');
    await file.writeAsBytes(jpegBytes);
    return file.path;
  }

  /// Export artwork as SVG (Scalable Vector Graphics)
  static Future<String> exportAsSvg({
    required int width,
    required int height,
    required List<LayerModel> layers,
    required Map<String, List<DrawStroke>> committedStrokes,
    required String projectName,
    Color? backgroundColor,
  }) async {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="$width" height="$height">');

    // Canvas background
    if (backgroundColor != null && backgroundColor != Colors.transparent) {
      sb.writeln(
          '  <rect width="100%" height="100%" fill="${_colorToHex(backgroundColor)}" />');
    }

    // Layers (bottom to top)
    for (final layer in layers.reversed) {
      if (!layer.isVisible) continue;
      final safeName =
          layer.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      sb.writeln(
          '  <g id="$safeName" opacity="${layer.opacity.toStringAsFixed(2)}">');

      final strokes = committedStrokes[layer.id] ?? [];
      for (final stroke in strokes) {
        final strokeColor = _colorToHex(stroke.color);
        final opacity =
            (stroke.color.a * stroke.brushOpacity).clamp(0.0, 1.0);

        switch (stroke.kind) {
          case StrokeKind.freehand:
            if (stroke.points.isEmpty) break;
            if (stroke.points.length == 1) {
              final p = stroke.points.first.position;
              sb.writeln(
                  '    <circle cx="${p.dx.toStringAsFixed(1)}" cy="${p.dy.toStringAsFixed(1)}" r="${(stroke.brushSize / 2).toStringAsFixed(1)}" fill="$strokeColor" opacity="${opacity.toStringAsFixed(2)}" />');
            } else {
              final pathData = StringBuffer();
              pathData.write(
                  'M ${stroke.points.first.position.dx.toStringAsFixed(1)} ${stroke.points.first.position.dy.toStringAsFixed(1)}');
              for (int i = 1; i < stroke.points.length; i++) {
                final pt = stroke.points[i].position;
                pathData.write(' L ${pt.dx.toStringAsFixed(1)} ${pt.dy.toStringAsFixed(1)}');
              }
              sb.writeln(
                  '    <path d="$pathData" fill="none" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            }
            break;

          case StrokeKind.line:
            if (stroke.points.length < 2) break;
            final p1 = stroke.points.first.position;
            final p2 = stroke.points.last.position;
            sb.writeln(
                '    <line x1="${p1.dx.toStringAsFixed(1)}" y1="${p1.dy.toStringAsFixed(1)}" x2="${p2.dx.toStringAsFixed(1)}" y2="${p2.dy.toStringAsFixed(1)}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linecap="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.rectangle:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            sb.writeln(
                '    <rect x="${rect.left.toStringAsFixed(1)}" y="${rect.top.toStringAsFixed(1)}" width="${rect.width.toStringAsFixed(1)}" height="${rect.height.toStringAsFixed(1)}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.roundedRectangle:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            sb.writeln(
                '    <rect x="${rect.left.toStringAsFixed(1)}" y="${rect.top.toStringAsFixed(1)}" width="${rect.width.toStringAsFixed(1)}" height="${rect.height.toStringAsFixed(1)}" rx="16" ry="16" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.circle:
          case StrokeKind.ellipse:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final cx = rect.center.dx;
            final cy = rect.center.dy;
            final rx = (rect.width / 2).abs();
            final ry = (rect.height / 2).abs();
            sb.writeln(
                '    <ellipse cx="${cx.toStringAsFixed(1)}" cy="${cy.toStringAsFixed(1)}" rx="${rx.toStringAsFixed(1)}" ry="${ry.toStringAsFixed(1)}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.triangle:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final top = Offset(rect.center.dx, rect.top);
            final bl = Offset(rect.left, rect.bottom);
            final br = Offset(rect.right, rect.bottom);
            sb.writeln(
                '    <polygon points="${top.dx.toStringAsFixed(1)},${top.dy.toStringAsFixed(1)} ${bl.dx.toStringAsFixed(1)},${bl.dy.toStringAsFixed(1)} ${br.dx.toStringAsFixed(1)},${br.dy.toStringAsFixed(1)}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.text:
            if (stroke.points.isEmpty || stroke.text == null) break;
            final pos = stroke.points.first.position;
            final fontSize = (stroke.fontSize ?? 24.0).toStringAsFixed(1);
            sb.writeln(
                '    <text x="${pos.dx.toStringAsFixed(1)}" y="${pos.dy.toStringAsFixed(1)}" font-size="$fontSize" fill="$strokeColor" text-anchor="middle" dominant-baseline="middle" opacity="${opacity.toStringAsFixed(2)}">${_escapeXml(stroke.text!)}</text>');
            break;

          case StrokeKind.fill:
            sb.writeln(
                '    <rect width="100%" height="100%" fill="$strokeColor" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          default:
            break;
        }
      }

      sb.writeln('  </g>');
    }

    sb.writeln('</svg>');

    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.svg');
    await file.writeAsString(sb.toString());
    return file.path;
  }

  /// Export artwork as PDF document
  static Future<String> exportAsPdf(
    ui.Image image,
    String projectName, {
    int width = 1080,
    int height = 1080,
  }) async {
    final bytes = await imageToBytes(image);
    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(bytes);

    final pdfPageFormat = PdfPageFormat(
      width.toDouble(),
      height.toDouble(),
      marginAll: 0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Save thumbnail for gallery preview
  static Future<String> saveThumbnail(
      ui.Image image, String projectId) async {
    final pngBytes = await imageToBytes(image);
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');

    // Resize to 256x256 thumbnail
    final thumb = img.copyResize(imgImage,
        width: 256, height: 256, interpolation: img.Interpolation.linear);
    final thumbBytes = img.encodePng(thumb);

    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${dir.path}/OpenCreate/thumbnails');
    await thumbDir.create(recursive: true);
    final file = File('${thumbDir.path}/$projectId.png');
    await file.writeAsBytes(thumbBytes);
    return file.path;
  }

  /// Merge multiple ui.Images into one (for layer compositing)
  static Future<ui.Image> mergeLayers(
    List<ui.Image> layers,
    int width,
    int height, {
    Color backgroundColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = backgroundColor,
    );

    // Draw each layer
    for (final layer in layers) {
      canvas.drawImage(layer, Offset.zero, Paint());
    }

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  /// Apply gaussian blur to an image
  static Future<Uint8List> applyGaussianBlur(
      Uint8List pngBytes, double sigma) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final blurred = img.gaussianBlur(imgImage, radius: sigma.round());
    return Uint8List.fromList(img.encodePng(blurred));
  }

  /// Apply HSB adjustments
  static Future<Uint8List> applyHsbAdjustment(
    Uint8List pngBytes, {
    double hueShift = 0,
    double saturationScale = 1.0,
    double brightnessScale = 1.0,
  }) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');

    final adjusted = img.adjustColor(
      imgImage,
      hue: hueShift,
      saturation: saturationScale,
      brightness: brightnessScale,
    );
    return Uint8List.fromList(img.encodePng(adjusted));
  }

  /// Apply sharpen filter
  static Future<Uint8List> applySharpen(Uint8List pngBytes) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final sharpened = img.convolution(imgImage,
        filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);
    return Uint8List.fromList(img.encodePng(sharpened));
  }

  /// Apply grayscale
  static Future<Uint8List> applyGrayscale(Uint8List pngBytes) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final gray = img.grayscale(imgImage);
    return Uint8List.fromList(img.encodePng(gray));
  }

  /// Flip image horizontally
  static Future<Uint8List> flipHorizontal(Uint8List pngBytes) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final flipped = img.flipHorizontal(imgImage);
    return Uint8List.fromList(img.encodePng(flipped));
  }

  /// Flip image vertically
  static Future<Uint8List> flipVertical(Uint8List pngBytes) async {
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final flipped = img.flipVertical(imgImage);
    return Uint8List.fromList(img.encodePng(flipped));
  }
}
