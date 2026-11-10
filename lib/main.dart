import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'models/project_model.dart';
import 'models/brush_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);

  // Register Hive adapters
  Hive.registerAdapter(ProjectModelAdapter());
  Hive.registerAdapter(BrushModelAdapter());
  Hive.registerAdapter(BrushTypeAdapter());

  // Open boxes
  await Hive.openBox<ProjectModel>('projects');
  await Hive.openBox<BrushModel>('brushes');
  await Hive.openBox('settings');

  runApp(
    const ProviderScope(
      child: OpenArtyApp(),
    ),
  );
}
