import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TherapistScreen extends StatefulWidget {
  const TherapistScreen({super.key});

  @override
  State<TherapistScreen> createState() =>
      _TherapistScreenState();
}

class _TherapistScreenState
    extends State<TherapistScreen> {

  final player = Player();

  late final VideoController controller;

  final channel = WebSocketChannel.connect(
    Uri.parse(
      'wss://therpistwebsocketserver.onrender.com',
    ),
  );

  final List<Map<String, String>> availableVideos = [
    {
      'title': 'Walk Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/walk_animation.mp4',
    },
    {
      'title': 'Stomp Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/stomp_animation.mp4',
    },
    {
      'title': 'Stand Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/stand_animation.mp4',
    },
    {
      'title': 'Fly Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/fly_animation.mp4',
    },
    {
      'title': 'Dance Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/dance_animation.mp4',
    },
    {
      'title': 'Climb Video',
      'url':
          'https://cdn.jsdelivr.net/gh/arjunfloreo-png/speech_animation_1@main/climb_animation.mp4',
    },
  ];

  @override
  void initState() {
    super.initState();

    controller = VideoController(player);

    channel.sink.add(jsonEncode({
      "type": "register",
      "role": "therapist"
    }));
  }

  void showVideoOverlay() {

    showDialog(
      context: context,
      builder: (_) {

        return Dialog(

          child: SizedBox(
            width: 400,
            height: 500,

            child: ListView.builder(
              itemCount: availableVideos.length,

              itemBuilder: (context, index) {

                final video = availableVideos[index];

                return ListTile(

                  title: Text(video['title']!),

                  onTap: () {

                    final url = video['url']!;

                    // Play therapist screen
                    player.open(Media(url));

                    // Send to client
                    channel.sink.add(jsonEncode({
                      "type": "video",
                      "url": url
                    }));

                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    player.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapist App"),
      ),

      body: Column(
        children: [

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: showVideoOverlay,
            child: const Text("Select Animation"),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Video(
              controller: controller,
            ),
          )

        ],
      ),
    );
  }
}