import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class WhepStreamService {
  static const String _whepUrl = 'http://137.184.181.86:8889/cam/whep';
  static const String _username = 'viewer';
  static const String _password = 'petcage-stream-key-2025';

  static final String _basicAuth =
      'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _peerConnection;

  Future<MediaStream> connect() async {
    final streamCompleter = Completer<MediaStream>();

    _peerConnection = await createPeerConnection(_rtcConfig);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty && !streamCompleter.isCompleted) {
        streamCompleter.complete(event.streams[0]);
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (!streamCompleter.isCompleted &&
          (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
           state == RTCIceConnectionState.RTCIceConnectionStateDisconnected)) {
        streamCompleter.completeError(Exception('ICE 連線失敗 ($state)'));
      }
    };

    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final response = await http.post(
      Uri.parse(_whepUrl),
      headers: {
        'Content-Type': 'application/sdp',
        'Accept': 'application/sdp',
        'Authorization': _basicAuth,
      },
      body: offer.sdp,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('WHEP 伺服器連線逾時'),
    );

    if (response.statusCode == 401) {
      throw Exception('驗證失敗：帳號或密碼錯誤 (HTTP 401)');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('WHEP 交握失敗 (HTTP ${response.statusCode})');
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(response.body, 'answer'),
    );

    return streamCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('等待影像串流逾時'),
    );
  }

  Future<void> dispose() async {
    await _peerConnection?.close();
    _peerConnection = null;
  }
}
