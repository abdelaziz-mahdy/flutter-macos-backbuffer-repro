import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Repro()));

class Repro extends StatelessWidget {
  const Repro({super.key});

  @override
  Widget build(BuildContext context) {
    // Keeps the raster thread busy every frame, like a playing video.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
