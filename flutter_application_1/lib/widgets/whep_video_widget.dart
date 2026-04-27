import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/whep_stream_service.dart';

enum _StreamState { connecting, playing, error }

class WhepVideoWidget extends StatefulWidget {
  const WhepVideoWidget({super.key});

  @override
  State<WhepVideoWidget> createState() => _WhepVideoWidgetState();
}

class _WhepVideoWidgetState extends State<WhepVideoWidget> {
  final _renderer = RTCVideoRenderer();
  final _service = WhepStreamService();

  _StreamState _state = _StreamState.connecting;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _state = _StreamState.connecting;
      _errorMessage = '';
    });
    try {
      await _renderer.initialize();
      final stream = await _service.connect();
      if (!mounted) return;
      _renderer.srcObject = stream;
      setState(() => _state = _StreamState.playing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _StreamState.error;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _retry() async {
    await _service.dispose();
    await _connect();
  }

  @override
  void dispose() {
    _service.dispose();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _StreamState.playing:
        return RTCVideoView(
          _renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      case _StreamState.connecting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              SizedBox(height: 12),
              Text('攝影機連線中...', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        );
      case _StreamState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 36),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 18),
                  label: const Text('重新連線', style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
        );
    }
  }
}
