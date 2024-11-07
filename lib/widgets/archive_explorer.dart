import 'package:flutter/material.dart';
import '../models/zarchive_model.dart';

class ArchiveExplorer extends StatelessWidget {
  final String archivePath;

  const ArchiveExplorer({
    super.key,
    required this.archivePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Archive: $archivePath'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 0, // Replace with actual entry count
            itemBuilder: (context, index) {
              return const ListTile(
                title: Text('Entry'),
              );
            },
          ),
        ),
      ],
    );
  }
}
