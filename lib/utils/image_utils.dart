import 'dart:convert';
import 'dart:math' as math;
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
import '../models/history_model.dart';
import 'blend_modes.dart';

class ImageUtils {
  ImageUtils._();

  /// Resolve export directory for saved artworks
  static Future<Directory> getExportDirectory({String folder = 'Pictures'}) async {
    if (Platform.isAndroid) {
      try {
        final targetDir = Directory('/storage/emulated/0/$folder/OpenArty');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        return targetDir;
      } catch (_) {}
    }
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/$folder/OpenArty');
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
      ui.Image image, String projectName, {String? customDir}) async {
    final bytes = await imageToBytes(image);
    final Directory exportDir = customDir != null
        ? Directory(customDir)
        : await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Export canvas as JPEG / JPG
  static Future<String> exportAsJpeg(
      ui.Image image, String projectName, {int quality = 92, String? customDir}) async {
    final pngBytes = await imageToBytes(image);
    final imgImage = img.decodePng(pngBytes);
    if (imgImage == null) throw Exception('Failed to decode image');
    final jpegBytes = img.encodeJpg(imgImage, quality: quality);
    final Directory exportDir = customDir != null
        ? Directory(customDir)
        : await getExportDirectory();
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
    String? customDir,
  }) async {
    final svgContent = buildSvgContent(
      width: width,
      height: height,
      layers: layers,
      committedStrokes: committedStrokes,
      backgroundColor: backgroundColor,
    );

    final Directory exportDir = customDir != null
        ? Directory(customDir)
        : await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.svg');
    await file.writeAsString(svgContent);
    return file.path;
  }

  /// Build SVG XML content string from layers and committed strokes
  static String buildSvgContent({
    required int width,
    required int height,
    required List<LayerModel> layers,
    required Map<String, List<DrawStroke>> committedStrokes,
    Color? backgroundColor,
  }) {
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

          case StrokeKind.star:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final c = rect.center;
            final rOuter = math.min(rect.width.abs(), rect.height.abs()) / 2;
            final rInner = rOuter * 0.45;
            final starPts = StringBuffer();
            for (int i = 0; i < 10; i++) {
              final r = i.isEven ? rOuter : rInner;
              final angle = -math.pi / 2 + (i * math.pi / 5);
              final px = (c.dx + r * math.cos(angle)).toStringAsFixed(1);
              final py = (c.dy + r * math.sin(angle)).toStringAsFixed(1);
              starPts.write('$px,$py ');
            }
            sb.writeln(
                '    <polygon points="${starPts.toString().trim()}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.polygon:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final c = rect.center;
            final r = math.min(rect.width.abs(), rect.height.abs()) / 2;
            final polyPts = StringBuffer();
            for (int i = 0; i < 6; i++) {
              final angle = (i * math.pi / 3) - math.pi / 6;
              final px = (c.dx + r * math.cos(angle)).toStringAsFixed(1);
              final py = (c.dy + r * math.sin(angle)).toStringAsFixed(1);
              polyPts.write('$px,$py ');
            }
            sb.writeln(
                '    <polygon points="${polyPts.toString().trim()}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.diamond:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            sb.writeln(
                '    <polygon points="${rect.center.dx.toStringAsFixed(1)},${rect.top.toStringAsFixed(1)} ${rect.right.toStringAsFixed(1)},${rect.center.dy.toStringAsFixed(1)} ${rect.center.dx.toStringAsFixed(1)},${rect.bottom.toStringAsFixed(1)} ${rect.left.toStringAsFixed(1)},${rect.center.dy.toStringAsFixed(1)}" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.heart:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final w = rect.width.abs();
            final h = rect.height.abs();
            final l = rect.left;
            final t = rect.top;
            final heartPath =
                'M ${(l + w * 0.5).toStringAsFixed(1)} ${(t + h * 0.28).toStringAsFixed(1)} '
                'C ${(l + w * 0.15).toStringAsFixed(1)} ${t.toStringAsFixed(1)}, $l ${(t + h * 0.35).toStringAsFixed(1)}, ${(l + w * 0.5).toStringAsFixed(1)} ${(t + h * 0.95).toStringAsFixed(1)} '
                'C ${(l + w).toStringAsFixed(1)} ${(t + h * 0.35).toStringAsFixed(1)}, ${(l + w * 0.85).toStringAsFixed(1)} ${t.toStringAsFixed(1)}, ${(l + w * 0.5).toStringAsFixed(1)} ${(t + h * 0.28).toStringAsFixed(1)} Z';
            sb.writeln(
                '    <path d="$heartPath" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.arrow:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final w = rect.width.abs();
            final h = rect.height.abs();
            final l = rect.left;
            final t = rect.top;
            final arrowPts =
                '$l,${(t + h * 0.35).toStringAsFixed(1)} '
                '${(l + w * 0.6).toStringAsFixed(1)},${(t + h * 0.35).toStringAsFixed(1)} '
                '${(l + w * 0.6).toStringAsFixed(1)},${(t + h * 0.15).toStringAsFixed(1)} '
                '${(l + w).toStringAsFixed(1)},${(t + h * 0.5).toStringAsFixed(1)} '
                '${(l + w * 0.6).toStringAsFixed(1)},${(t + h * 0.85).toStringAsFixed(1)} '
                '${(l + w * 0.6).toStringAsFixed(1)},${(t + h * 0.65).toStringAsFixed(1)} '
                '$l,${(t + h * 0.65).toStringAsFixed(1)}';
            sb.writeln(
                '    <polygon points="$arrowPts" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.speechBubble:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final mw = rect.width.abs();
            final mh = rect.height.abs() * 0.78;
            final l = rect.left;
            final t = rect.top;
            sb.writeln(
                '    <rect x="${l.toStringAsFixed(1)}" y="${t.toStringAsFixed(1)}" width="${mw.toStringAsFixed(1)}" height="${mh.toStringAsFixed(1)}" rx="16" ry="16" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            final tailPts =
                '${(l + mw * 0.2).toStringAsFixed(1)},${(t + mh).toStringAsFixed(1)} '
                '${(l + mw * 0.08).toStringAsFixed(1)},${rect.bottom.toStringAsFixed(1)} '
                '${(l + mw * 0.38).toStringAsFixed(1)},${(t + mh).toStringAsFixed(1)}';
            sb.writeln(
                '    <polygon points="$tailPts" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" opacity="${opacity.toStringAsFixed(2)}" />');
            break;

          case StrokeKind.cloud:
            if (stroke.points.length < 2) break;
            final rect = Rect.fromPoints(
                stroke.points.first.position, stroke.points.last.position);
            final w = rect.width.abs();
            final h = rect.height.abs();
            final l = rect.left;
            final t = rect.top;
            final cloudPath =
                'M ${(l + w * 0.2).toStringAsFixed(1)} ${(t + h * 0.7).toStringAsFixed(1)} '
                'C $l ${(t + h * 0.7).toStringAsFixed(1)}, $l ${(t + h * 0.4).toStringAsFixed(1)}, ${(l + w * 0.25).toStringAsFixed(1)} ${(t + h * 0.4).toStringAsFixed(1)} '
                'C ${(l + w * 0.2).toStringAsFixed(1)} ${(t + h * 0.15).toStringAsFixed(1)}, ${(l + w * 0.55).toStringAsFixed(1)} ${(t + h * 0.1).toStringAsFixed(1)}, ${(l + w * 0.6).toStringAsFixed(1)} ${(t + h * 0.35).toStringAsFixed(1)} '
                'C ${(l + w * 0.7).toStringAsFixed(1)} ${(t + h * 0.2).toStringAsFixed(1)}, ${(l + w).toStringAsFixed(1)} ${(t + h * 0.25).toStringAsFixed(1)}, ${(l + w * 0.95).toStringAsFixed(1)} ${(t + h * 0.55).toStringAsFixed(1)} '
                'C ${(l + w).toStringAsFixed(1)} ${(t + h * 0.75).toStringAsFixed(1)}, ${(l + w * 0.8).toStringAsFixed(1)} ${(t + h * 0.85).toStringAsFixed(1)}, ${(l + w * 0.65).toStringAsFixed(1)} ${(t + h * 0.75).toStringAsFixed(1)} '
                'L ${(l + w * 0.2).toStringAsFixed(1)} ${(t + h * 0.75).toStringAsFixed(1)} Z';
            sb.writeln(
                '    <path d="$cloudPath" fill="${stroke.isFilled ? strokeColor : 'none'}" stroke="$strokeColor" stroke-width="${stroke.brushSize.toStringAsFixed(1)}" stroke-linejoin="round" opacity="${opacity.toStringAsFixed(2)}" />');
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

      // Render dedicated text layer into SVG
      if (layer.isTextLayer && layer.textContent != null && layer.textContent!.isNotEmpty) {
        final tColor = _colorToHex(layer.textColor ?? Colors.white);
        final fSize = (layer.fontSize ?? 36.0).toStringAsFixed(1);
        final cX = (width / 2 + layer.offsetX).toStringAsFixed(1);
        final cY = (height / 2 + layer.offsetY).toStringAsFixed(1);
        final weight = layer.isBold ? ' font-weight="bold"' : '';
        final style = layer.isItalic ? ' font-style="italic"' : '';
        sb.writeln(
            '    <text x="$cX" y="$cY" font-size="$fSize" fill="$tColor" text-anchor="middle" dominant-baseline="middle"$weight$style opacity="${layer.opacity.toStringAsFixed(2)}">${_escapeXml(layer.textContent!)}</text>');
      }

      sb.writeln('  </g>');
    }

    sb.writeln('</svg>');
    return sb.toString();
  }

  /// Export artwork as PDF document
  static Future<String> exportAsPdf(
    ui.Image image,
    String projectName, {
    int width = 1080,
    int height = 1080,
    String? customDir,
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
    final Directory exportDir = customDir != null
        ? Directory(customDir)
        : await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Export artwork as Adobe Photoshop PSD document (.psd)
  static Future<String> exportAsPsd(
    ui.Image image,
    String projectName, {
    int? width,
    int? height,
    String? customDir,
  }) async {
    final w = width ?? image.width;
    final h = height ?? image.height;

    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to get raw RGBA data for PSD export');
    }
    final rawRgba = byteData.buffer.asUint8List();

    final psdBytes = buildPsdBytes(w, h, rawRgba);

    final Directory exportDir = customDir != null
        ? Directory(customDir)
        : await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/${projectName}_$timestamp.psd');
    await file.writeAsBytes(psdBytes);
    return file.path;
  }

  /// Build standard Adobe Photoshop PSD bytes with RGBA channels
  static Uint8List buildPsdBytes(int width, int height, Uint8List rawRgba) {
    final numPixels = width * height;
    const channels = 4; // R, G, B, A

    final builder = BytesBuilder();

    // 1. Header (26 bytes)
    final header = ByteData(26);
    header.setUint8(0, 0x38); // '8'
    header.setUint8(1, 0x42); // 'B'
    header.setUint8(2, 0x50); // 'P'
    header.setUint8(3, 0x53); // 'S'
    header.setUint16(4, 1); // Version 1
    // 6 reserved bytes: 0
    header.setUint16(12, channels);
    header.setUint32(14, height);
    header.setUint32(18, width);
    header.setUint16(22, 8); // 8 bits per channel
    header.setUint16(24, 3); // 3 = RGB mode
    builder.add(header.buffer.asUint8List());

    // 2. Color Mode Data Section (Length: 0 for RGB)
    final colorModeLen = ByteData(4);
    colorModeLen.setUint32(0, 0);
    builder.add(colorModeLen.buffer.asUint8List());

    // 3. Image Resources Section (Length: 0)
    final resLen = ByteData(4);
    resLen.setUint32(0, 0);
    builder.add(resLen.buffer.asUint8List());

    // 4. Layer and Mask Section (Section length: 4, Layer Info length: 0)
    final layerLen = ByteData(8);
    layerLen.setUint32(0, 4); // Section length = 4
    layerLen.setUint32(4, 0); // Layer info length = 0
    builder.add(layerLen.buffer.asUint8List());

    // 5. Image Data Section (Composite)
    // Compression: 0 = Raw
    final comp = ByteData(2);
    comp.setUint16(0, 0);
    builder.add(comp.buffer.asUint8List());

    // Planar channel separation
    final rPlane = Uint8List(numPixels);
    final gPlane = Uint8List(numPixels);
    final bPlane = Uint8List(numPixels);
    final aPlane = Uint8List(numPixels);

    for (int i = 0; i < numPixels; i++) {
      final idx = i * 4;
      rPlane[i] = rawRgba[idx];
      gPlane[i] = rawRgba[idx + 1];
      bPlane[i] = rawRgba[idx + 2];
      aPlane[i] = rawRgba[idx + 3];
    }

    builder.add(rPlane);
    builder.add(gPlane);
    builder.add(bPlane);
    builder.add(aPlane);

    return builder.toBytes();
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
    final thumbDir = Directory('${dir.path}/OpenArty/thumbnails');
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

  /// Crop image with specified bounding rectangle
  static Future<Uint8List> cropImage(
    Uint8List rawBytes, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final cropped = img.copyCrop(
      decoded,
      x: x.clamp(0, decoded.width - 1),
      y: y.clamp(0, decoded.height - 1),
      width: width.clamp(1, decoded.width),
      height: height.clamp(1, decoded.height),
    );
    return Uint8List.fromList(img.encodePng(cropped));
  }

  static Future<File> getProjectFile(String projectId) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory('${appDocDir.path}/opencreate_projects');
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return File('${projectsDir.path}/$projectId.json');
  }

  static Future<void> saveProjectData({
    required String projectId,
    required List<LayerModel> layers,
    required Map<String, List<DrawStroke>> committedStrokes,
    required String activeLayerId,
    required int canvasWidth,
    required int canvasHeight,
    Color? backgroundColor,
    List<CanvasHistoryEntry>? historyUndoStack,
    List<CanvasHistoryEntry>? historyRedoStack,
  }) async {
    final file = await getProjectFile(projectId);
    final data = {
      'projectId': projectId,
      'savedAt': DateTime.now().toIso8601String(),
      'activeLayerId': activeLayerId,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'backgroundColor': (backgroundColor ?? Colors.white).value,
      'layers': layers.map((l) => l.toJson()).toList(),
      'committedStrokes': committedStrokes.map(
        (key, strokes) =>
            MapEntry(key, strokes.map((s) => s.toJson()).toList()),
      ),
      'undoStack': (historyUndoStack ?? []).map((e) => e.toJson()).toList(),
      'redoStack': (historyRedoStack ?? []).map((e) => e.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadProjectData(String projectId) async {
    try {
      final file = await getProjectFile(projectId);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
