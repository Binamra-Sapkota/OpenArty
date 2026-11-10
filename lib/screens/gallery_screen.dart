import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';
import '../models/canvas_model.dart';
import 'canvas_screen.dart';

const _uuid = Uuid();

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late Box<ProjectModel> _projectsBox;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initHive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStoragePermission();
    });
  }

  Future<void> _checkStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final statuses = await [
      Permission.storage,
      Permission.photos,
    ].request();

    final isGranted = statuses[Permission.storage]?.isGranted == true ||
        statuses[Permission.photos]?.isGranted == true;

    if (isGranted) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.folder_shared, color: Color(0xFF6C63FF), size: 28),
            SizedBox(width: 10),
            Text(
              'Storage Permission',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'OpenArty needs storage & photos access on your device to:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text('• Export artworks in PNG, JPEG, SVG, and PDF formats',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Import reference photos and images into drawing layers',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Save artwork projects and thumbnails safely',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Not Now', style: TextStyle(color: Colors.white38)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Grant Permission',
                style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await [
                Permission.storage,
                Permission.photos,
              ].request();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _initHive() async {
    if (Hive.isBoxOpen('projects')) {
      _projectsBox = Hive.box<ProjectModel>('projects');
    } else {
      _projectsBox = await Hive.openBox<ProjectModel>('projects');
    }
    setState(() => _isLoaded = true);
  }

  void _createNewArtwork({
    int width = 1080,
    int height = 1080,
    int dpi = 150,
    String name = 'Untitled',
  }) {
    final newProject = ProjectModel(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      canvasWidth: width,
      canvasHeight: height,
      dpi: dpi,
      layerCount: 1,
    );

    _projectsBox.put(newProject.id, newProject);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CanvasScreen(
          project: newProject,
          initialCanvas: CanvasModel(
            width: width,
            height: height,
            dpi: dpi,
          ),
        ),
      ),
    );
  }

  void _showNewCanvasDialog() {
    _showCustomCanvasDialog();
  }

  void _showCustomCanvasDialog() {
    final widthController = TextEditingController(text: '1080');
    final heightController = TextEditingController(text: '1080');
    final dpiController = TextEditingController(text: '150');
    final nameController = TextEditingController(text: 'Custom Artwork');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Canvas / Dimensions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Artwork Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Width (px)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Height (px)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dpiController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Resolution (DPI)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Preset chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('1:1 Square', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '1080';
                      heightController.text = '1080';
                    },
                  ),
                  ActionChip(
                    label: const Text('16:9 Landscape', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '1920';
                      heightController.text = '1080';
                    },
                  ),
                  ActionChip(
                    label: const Text('9:16 Portrait', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '1080';
                      heightController.text = '1920';
                    },
                  ),
                  ActionChip(
                    label: const Text('4:3 Classic', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '1600';
                      heightController.text = '1200';
                    },
                  ),
                  ActionChip(
                    label: const Text('4K UHD', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '3840';
                      heightController.text = '2160';
                    },
                  ),
                  ActionChip(
                    label: const Text('A4 Print', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      widthController.text = '2480';
                      heightController.text = '3508';
                      dpiController.text = '300';
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create Canvas', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final w = int.tryParse(widthController.text) ?? 1080;
              final h = int.tryParse(heightController.text) ?? 1080;
              final dpi = int.tryParse(dpiController.text) ?? 150;
              final name = nameController.text.trim().isEmpty
                  ? 'Custom Artwork'
                  : nameController.text.trim();
              Navigator.of(ctx).pop();
              _createNewArtwork(
                width: w.clamp(100, 8192),
                height: h.clamp(100, 8192),
                dpi: dpi,
                name: name,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202020),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/icons/logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text(
              'OpenArty',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'New Canvas',
            onPressed: _showNewCanvasDialog,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _projectsBox.listenable(),
        builder: (context, Box<ProjectModel> box, _) {
          final projects = box.values.toList().reversed.toList();

          return Column(
            children: [
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.brush_outlined,
                              size: 72,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Artworks Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap + or start drawing right now',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _showCustomCanvasDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Start Drawing'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: projects.length,
                        itemBuilder: (context, i) {
                          final project = projects[i];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            color: const Color(0xFF222222),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white12),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CanvasScreen(
                                      project: project,
                                      initialCanvas: CanvasModel(
                                        width: project.canvasWidth,
                                        height: project.canvasHeight,
                                        dpi: project.dpi,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: const Color(0xFF181818),
                                      child: (project.thumbnailPath != null &&
                                              File(project.thumbnailPath!)
                                                  .existsSync())
                                          ? Image.file(
                                              File(project.thumbnailPath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 48,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.image,
                                                size: 48,
                                                color: Colors.white24,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                project.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                project.dimensionLabel,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          color: Colors.white38,
                                          onPressed: () => _projectsBox.delete(project.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewCanvasDialog,
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Canvas', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
