import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'api.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<dynamic>> _videos;
  @override
  void initState() {
    super.initState();
    _videos = http.get(Uri.parse('$apiBase/videos')).then((r) => jsonDecode(utf8.decode(r.bodyBytes)) as List);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<dynamic>>(
          future: _videos,
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: s.data!.length,
              itemBuilder: (c, i) => VideoPage(video: s.data![i]),
            );
          },
        ),
      );
}

class VideoPage extends StatefulWidget {
  final Map<String, dynamic> video;
  const VideoPage({super.key, required this.video});
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late VideoPlayerController _ctrl;
  late int likes = widget.video['likes'];
  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.video['url']))
      ..initialize().then((_) {
        _ctrl.setLooping(true);
        _ctrl.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    final r = await http.post(Uri.parse('$apiBase/videos/${widget.video['id']}/like'));
    setState(() => likes = jsonDecode(r.body)['likes']);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        _ctrl.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: _ctrl.value.size.width, height: _ctrl.value.size.height, child: VideoPlayer(_ctrl)))
            : const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 40, right: 16, left: 80,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('@${widget.video['author']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.video['title']),
          ]),
        ),
        Positioned(
          bottom: 40, left: 16,
          child: Column(children: [
            IconButton(iconSize: 36, icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: _like),
            Text('$likes'),
          ]),
        ),
      ]);
}
