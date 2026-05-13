import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webview_windows/webview_windows.dart';

class TherapistScreen extends StatefulWidget {
  const TherapistScreen({super.key});

  @override
  State<TherapistScreen> createState() => _TherapistScreenState();
}

class _TherapistScreenState extends State<TherapistScreen> {
  // ───────────────────────────────────────────
  // MEDIA
  // ───────────────────────────────────────────
  final player = Player();
  late final VideoController controller;

  // ───────────────────────────────────────────
  // WEBSOCKET
  // ───────────────────────────────────────────
  late final WebSocketChannel channel;

  // ───────────────────────────────────────────
  // AGORA
  // ───────────────────────────────────────────
  late RtcEngine agoraEngine;

  List<ScreenCaptureSourceInfo> windows = [];

  bool isSharingScreen = false;

  // ───────────────────────────────────────────
  // BROWSER
  // ───────────────────────────────────────────
  final WebviewController webviewController =
      WebviewController();

  bool showBrowser = false;

  // ───────────────────────────────────────────
  // PLAYBACK STATE
  // ───────────────────────────────────────────
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  // subscriptions
  late final StreamSubscription _posSub;
  late final StreamSubscription _durSub;
  late final StreamSubscription _playSub;

  @override
  void initState() {
    super.initState();

    controller = VideoController(player);

    initAgora();

    initBrowser();

    channel = WebSocketChannel.connect(
      Uri.parse(
        'wss://therpistwebsocketserver.onrender.com',
      ),
    );

    channel.sink.add(
      jsonEncode({
        'type': 'register',
        'role': 'therapist',
      }),
    );

    _posSub = player.stream.position.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durSub = player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });

    _playSub = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _playing = playing;
        });
      }
    });
  }

  // ───────────────────────────────────────────
  // INIT BROWSER
  // ───────────────────────────────────────────
  Future<void> initBrowser() async {
    await webviewController.initialize();

    await webviewController.setPopupWindowPolicy(
      WebviewPopupWindowPolicy.deny,
    );

    // Load blank initially — Google is loaded when user clicks LET ME SHARE
    await webviewController.loadUrl('about:blank');
  }

  // ───────────────────────────────────────────
  // INIT AGORA
  // ───────────────────────────────────────────
  Future<void> initAgora() async {
    agoraEngine = createAgoraRtcEngine();

    await agoraEngine.initialize(
      const RtcEngineContext(
        appId: '9bbcfb22bb73429fa08643c4da2fcc0b',
        channelProfile:
            ChannelProfileType.channelProfileCommunication,
      ),
    );

    await agoraEngine.enableVideo();

    await agoraEngine.joinChannel(
      token:
          '007eJxTYHhce+LChCiTA+/W/7hq+OPhAYFbe9xixf6cWd8y9/n5qbn/FBgsk5KS05KMjJKSzI1NjCzTEg0szEyMk01SEo3SkpMNku7os2Q1BDIySN/9yMzIAIEgPjdDSUZqUUFmcYljQQEDAwAjwygV',
      channelId: 'therpistApp',
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    await loadWindows();
  }

  // ───────────────────────────────────────────
  // LOAD WINDOWS
  // ───────────────────────────────────────────
  Future<void> loadWindows() async {
    final result =
        await agoraEngine.getScreenCaptureSources(
      thumbSize:
          const SIZE(width: 320, height: 180),
      iconSize: const SIZE(width: 64, height: 64),
      includeScreen: false,
    );

    setState(() {
      windows = result;
    });
  }

  // ───────────────────────────────────────────
  // START WINDOW SHARE
  // ───────────────────────────────────────────
  Future<void> startWindowShare(
    ScreenCaptureSourceInfo source,
  ) async {
    await agoraEngine.startScreenCaptureByWindowId(
      windowId: source.sourceId!,
      regionRect: const Rectangle(
        x: 0,
        y: 0,
        width: 0,
        height: 0,
      ),
      captureParams: const ScreenCaptureParameters(
        frameRate: 15,
        bitrate: 0,
        captureMouseCursor: true,
        windowFocus: true,
      ),
    );

    await agoraEngine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishScreenCaptureVideo: true,
        publishScreenCaptureAudio: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
      ),
    );

    setState(() {
      isSharingScreen = true;
    });
  }

  // ───────────────────────────────────────────
  // STOP SHARE
  // ───────────────────────────────────────────
  Future<void> stopScreenShare() async {
    // STOP AGORA SCREEN SHARE
    await agoraEngine.stopScreenCapture();

    await agoraEngine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishScreenCaptureVideo: false,
        publishScreenCaptureAudio: false,
      ),
    );

    // HIDE BROWSER INSTANTLY — shows "Click LET ME SHARE" placeholder
    setState(() {
      isSharingScreen = false;
      showBrowser = false;
    });

    // RESET WEBVIEW IN BACKGROUND so next share starts clean
    try {
      await webviewController.loadUrl('about:blank');
    } catch (e) {
      debugPrint('Failed to reset webview: $e');
    }
  }

  // ───────────────────────────────────────────
  // OPEN BROWSER & SHARE
  // ───────────────────────────────────────────
  Future<void> openBrowserAndShare() async {
    // Load Google FIRST so webview has content before it becomes visible
    await webviewController.loadUrl('https://www.google.com');

    // NOW show the webview panel
    setState(() {
      showBrowser = true;
    });

    await Future.delayed(
      const Duration(seconds: 2),
    );

    await loadWindows();

    try {
      final browserWindow = windows.firstWhere(
        (e) {
          final name =
              e.sourceName?.toLowerCase() ?? '';

          return name.contains('chrome') ||
              name.contains('google') ||
              name.contains('edge') ||
              name.contains('firefox');
        },
      );

      await startWindowShare(browserWindow);
    } catch (e) {
      debugPrint('Browser window not found');
    }
  }

  // ───────────────────────────────────────────
  // PLAY / PAUSE
  // ───────────────────────────────────────────
  void togglePlayPause() {
    if (_playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  // ───────────────────────────────────────────
  // SEEK
  // ───────────────────────────────────────────
  void seek(double ms) {
    player.seek(
      Duration(milliseconds: ms.toInt()),
    );
  }

  // ───────────────────────────────────────────
  // FORMAT TIME
  // ───────────────────────────────────────────
  String format(Duration d) {
    final m = d.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final s = d.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$m:$s';
  }

  // ───────────────────────────────────────────
  // CAMERA PANEL
  // ───────────────────────────────────────────
  Widget buildCameraPanel(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D084),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Waiting for client...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
          ),

          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: const [
                Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 10),
                Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),

          Positioned(
            left: 12,
            bottom: 12,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // DISPOSE
  // ───────────────────────────────────────────
  @override
  void dispose() {
    _posSub.cancel();
    _durSub.cancel();
    _playSub.cancel();

    agoraEngine.leaveChannel();
    agoraEngine.release();

    webviewController.dispose();

    player.dispose();

    channel.sink.close();

    super.dispose();
  }

  // ───────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),

      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────
            // TOP CONTENT
            // ─────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // ─────────────────────────────
                    // MAIN SCREEN
                    // ─────────────────────────────
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(24),
                          color: Colors.black,
                          border: Border.all(
                            color:
                                const Color(0xFF00D084),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(22),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: showBrowser
                                ? Webview(
                                    webviewController,
                                  )
                                : Container(
                                    color:
                                        const Color(
                                      0xFF1A2B1A,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Click LET ME SHARE',
                                        style: TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ─────────────────────────────
                    // RIGHT CAMERA PANELS
                    // ─────────────────────────────
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          Expanded(
                            child:
                                buildCameraPanel(
                              'Client',
                            ),
                          ),

                          const SizedBox(height: 12),

                          Expanded(
                            child:
                                buildCameraPanel(
                              'Therapist',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─────────────────────────────
            // BOTTOM CONTROLS
            // ─────────────────────────────
            Container(
              margin: const EdgeInsets.all(12),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF00D084),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed:
                        openBrowserAndShare,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF00C16A,
                      ),
                      foregroundColor:
                          Colors.white,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(30),
                      ),
                    ),
                    child: const Text(
                      'LET ME SHARE',
                    ),
                  ),

                  const SizedBox(width: 12),

                  ElevatedButton(
                    onPressed: stopScreenShare,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red,
                      foregroundColor:
                          Colors.white,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(30),
                      ),
                    ),
                    child: const Text(
                      'STOP SHARE',
                    ),
                  ),

                  const SizedBox(width: 12),

                  IconButton(
                    onPressed: togglePlayPause,
                    iconSize: 34,
                    icon: Icon(
                      _playing
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: Colors.green,
                    ),
                  ),

                  Expanded(
                    child: Slider(
                      value: _position
                          .inMilliseconds
                          .toDouble()
                          .clamp(
                            0,
                            _duration
                                .inMilliseconds
                                .toDouble(),
                          ),
                      min: 0,
                      max:
                          _duration
                                      .inMilliseconds >
                                  0
                              ? _duration
                                  .inMilliseconds
                                  .toDouble()
                              : 1,
                      onChanged: seek,
                    ),
                  ),

                  Text(
                    '${format(_position)} / ${format(_duration)}',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
