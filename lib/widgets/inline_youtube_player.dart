import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class InlineYouTubePlayerCard extends StatefulWidget {
  final String videoUrl;
  final String title;

  const InlineYouTubePlayerCard({
    super.key,
    required this.videoUrl,
    this.title = 'YouTube Video',
  });

  @override
  State<InlineYouTubePlayerCard> createState() => _InlineYouTubePlayerCardState();
}

class _InlineYouTubePlayerCardState extends State<InlineYouTubePlayerCard> with AutomaticKeepAliveClientMixin {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _hasError = false;
  bool _isPlayingInline = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  static String? _extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final converted = YoutubePlayerController.convertUrlToId(url.trim());
    if (converted != null && converted.trim().isNotEmpty) {
      return converted.trim();
    }
    final regExp = RegExp(
      r'^.*(?:youtu.be\/|v\/|e\/|u\/\w+\/|embed\/|v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url.trim());
    if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
      return match.group(1)!.trim();
    }
    final trimmed = url.trim();
    if (!trimmed.contains('/') && !trimmed.contains('?')) {
      return trimmed;
    }
    return null;
  }

  void _initController() {
    try {
      final id = _extractVideoId(widget.videoUrl);
      debugPrint('Extracted YouTube Video ID: $id from URL: ${widget.videoUrl}');

      if (id != null && id.isNotEmpty) {
        _videoId = id;
        _controller = YoutubePlayerController.fromVideoId(
          videoId: id,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            mute: false,
          ),
        );
      } else {
        _hasError = true;
      }
    } catch (e) {
      debugPrint('YouTube controller init error: $e');
      _hasError = true;
    }
  }

  @override
  void didUpdateWidget(covariant InlineYouTubePlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      final newId = _extractVideoId(widget.videoUrl);
      if (newId != null && newId != _videoId && _controller != null) {
        debugPrint('YouTube Video ID changed from $_videoId to $newId. Loading new video...');
        _videoId = newId;
        _controller!.loadVideoById(videoId: newId);
      }
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasError || _videoId == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_isPlayingInline && _controller != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _controller!,
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      );
    }

    final thumbnailUrl = 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isPlayingInline = true;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  thumbnailUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF1E293B),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


