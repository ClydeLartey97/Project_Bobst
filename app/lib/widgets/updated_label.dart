import 'package:flutter/material.dart';

class UpdatedLabel extends StatelessWidget {
  const UpdatedLabel({super.key, required this.updatedAt, this.color});

  final DateTime updatedAt;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(updatedAt.toLocal());
    return Text(
      'Updated ${time.format(context)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    );
  }
}
