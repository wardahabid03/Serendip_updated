import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaViewer extends StatefulWidget {
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'

  const MediaViewer({required this.mediaUrl, required this.mediaType, Key? key})
      : super(key: key);

  @override
  _MediaViewerState createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.network(widget.mediaUrl)
        ..initialize().then((_) {
          setState(() {}); // Update the UI once the video is initialized
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: widget.mediaType == 'image'
            ? Image.network(widget.mediaUrl, fit: BoxFit.contain)
            : _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
