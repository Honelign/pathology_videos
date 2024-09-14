import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Player App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _directoryPath;
  List<File> _videoFiles = [];
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
  }

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _directoryPath = prefs.getString('videoDirectory');
    });
    if (_directoryPath != null) {
      _loadVideos();
    }
  }

  Future<void> _selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _directoryPath = selectedDirectory;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('videoDirectory', selectedDirectory);
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    debugPrint('loading Videos');
    debugPrint('directory path $_directoryPath');

    if (_directoryPath == null) return;
    debugPrint('loading Videos passed');

    final directory = Directory(_directoryPath!);

    debugPrint('loading Videos passed 1');
    debugPrint('loading Videos passed 1 directory $directory');
    debugPrint('${directory.list().length}');

    final List<FileSystemEntity> entities = await directory.list().toList();

    debugPrint('loading Videos passed 2 $entities');

    setState(() {
      _videoFiles = entities.whereType<File>().where((file) {
        final extensionIndex = file.path.lastIndexOf('.');
        if (extensionIndex == -1) return false; // No extension found
        final extension = file.path.substring(extensionIndex).toLowerCase();
        return ['.mp4', '.avi', '.mov', '.mkv'].contains(extension);
      }).toList();
    });
    debugPrint('loading Videos passed 3 $_videoFiles');
  }

  Future<void> _playVideo(File file) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    setState(() {});
    await _controller!.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _selectDirectory,
          ),
        ],
      ),
      body: _directoryPath == null
          ? const Center(child: Text('Please select a directory'))
          : ListView.builder(
              itemCount: _videoFiles.length,
              itemBuilder: (context, index) {
                final file = _videoFiles[index];
                return ListTile(
                  title: Text(file.path.split('/').last),
                  onTap: () => _playVideo(file),
                );
              },
            ),
      floatingActionButton: _controller != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller!.value.isPlaying
                      ? _controller!.pause()
                      : _controller!.play();
                });
              },
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
