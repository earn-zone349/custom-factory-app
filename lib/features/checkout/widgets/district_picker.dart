import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/bd_districts.dart';

/// Shows a searchable list of districts. Returns the chosen one or null.
Future<String?> showDistrictPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _DistrictPickerSheet(selected: selected);
    },
  );
}

class _DistrictPickerSheet extends StatefulWidget {
  const _DistrictPickerSheet({required this.selected});

  final String? selected;

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  String _query = '';

  List<String> get _matches {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return BdDistricts.all;
    return BdDistricts.all
        .where((String district) => district.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> matches = _matches;
    final double height = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                onChanged: (String value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search district',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No district found'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String district = matches[index];
                        final bool isSelected = district == widget.selected;
                        return ListTile(
                          title: Text(district),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(district),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
