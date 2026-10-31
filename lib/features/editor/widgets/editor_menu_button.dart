import 'package:flutter/material.dart';

/// Actions available from the editor's overflow menu.
enum EditorMenuAction { save, export }

/// The "more" menu in the editor's app bar.
class EditorMenuButton extends StatelessWidget {
  const EditorMenuButton({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<EditorMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EditorMenuAction>(
      tooltip: 'More',
      enabled: enabled,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) =>
          const <PopupMenuEntry<EditorMenuAction>>[
        PopupMenuItem<EditorMenuAction>(
          value: EditorMenuAction.save,
          child: ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text('Save design'),
          ),
        ),
        PopupMenuItem<EditorMenuAction>(
          value: EditorMenuAction.export,
          child: ListTile(
            leading: Icon(Icons.ios_share_rounded),
            title: Text('Export print file'),
          ),
        ),
      ],
    );
  }
}
