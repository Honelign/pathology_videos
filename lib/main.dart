import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;

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
  String? _thumbnailsDir;

  @override
  void initState() {
    super.initState();
    _initThumbnailsDir();
    _loadSavedPath();
  }

  Future<void> _initThumbnailsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailsDir = path.join(appDir.path, 'thumbnails');
    await Directory(_thumbnailsDir!).create(recursive: true);
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
    if (_directoryPath == null) return;

    final directory = Directory(_directoryPath!);
    final List<FileSystemEntity> entities = await directory.list().toList();
    setState(() {
      _videoFiles = entities.whereType<File>().where((file) {
        final extensionIndex = file.path.lastIndexOf('.');
        if (extensionIndex == -1) return false; // No extension found
        final extension = file.path.substring(extensionIndex).toLowerCase();
        return ['.mp4', '.avi', '.mov', '.mkv'].contains(extension);
      }).toList();
    });
  }

  Future<String> _getThumbnail(File videoFile) async {
    final thumbnailPath =
        path.join(_thumbnailsDir!, '${path.basename(videoFile.path)}.jpg');
    final thumbnailFile = File(thumbnailPath);

    if (await thumbnailFile.exists()) {
      return thumbnailPath;
    }

    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: videoFile.path,
      thumbnailPath: thumbnailPath,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );

    return thumbnail ?? 'assets/thumb96.png';
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
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 16 / 9,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _videoFiles.length,
              itemBuilder: (context, index) {
                final file = _videoFiles[index];
                return GestureDetector(
                  onTap: () => _playVideo(file),
                  child: FutureBuilder<String>(
                    future: _getThumbnail(file),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        return CachedNetworkImage(
                          imageUrl: snapshot.data!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        );
                      } else {
                        return Container(color: Colors.grey);
                      }
                    },
                  ),
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
