import 'dart:async';

import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../models/dev_settings.dart';
import '../services/api_client.dart';
import '../theme/busyness_colors.dart';
import '../util/format.dart';

/// Tweak the backend's data live: time of day, day, finals, crowd size and
/// per-floor fullness. Changes apply to everyone using the same backend.
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({
    super.key,
    required this.api,
    required this.status,
    required this.onChanged,
  });

  final ApiClient api;
  final BobstStatus status;

  /// Called after the backend accepts new settings, to refetch status.
  final Future<void> Function() onChanged;

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  DevSettings? _settings;
  Object? _error;
  Timer? _debounce;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    widget.api.fetchDevSettings().then(
      (s) => mounted ? setState(() => _settings = s) : null,
      onError: (Object e) => mounted ? setState(() => _error = e) : null,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Update locally right away; push to the backend once the user pauses.
  void _update(DevSettings next) {
    setState(() => _settings = next);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        await widget.api.saveDevSettings(next);
        await widget.onChanged();
      } catch (e) {
        if (mounted) setState(() => _error = e);
      }
    });
  }

  Future<void> _reset() async {
    _debounce?.cancel();
    final fresh = await widget.api.resetDevSettings();
    if (!mounted) return;
    setState(() => _settings = fresh);
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final theme = Theme.of(context);

    if (settings == null) {
      return Center(
        child: _error != null
            ? const Text(
                'Developer settings unavailable.\n'
                'Is the backend running with DEV_MODE on?',
              )
            : const CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 16,
        16,
        120,
      ),
      children: [
        Text(
          'Developer',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        _LivePreview(status: widget.status),
        _Section(
          title: 'Time of day',
          children: [
            SwitchListTile(
              title: const Text('Use real time'),
              value: settings.hour == null,
              onChanged: (real) =>
                  _update(settings.copyWith(hour: () => real ? null : 15)),
            ),
            if (settings.hour case final hour?)
              _LabeledSlider(
                label: _formatHour(hour),
                value: hour,
                max: 23.75,
                divisions: 95,
                onChanged: (v) => _update(settings.copyWith(hour: () => v)),
              ),
          ],
        ),
        _Section(
          title: 'Day',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: settings.weekday == null,
                    onSelected: (_) =>
                        _update(settings.copyWith(weekday: () => null)),
                  ),
                  for (var i = 0; i < 7; i++)
                    ChoiceChip(
                      label: Text(_days[i]),
                      selected: settings.weekday == i,
                      onSelected: (_) =>
                          _update(settings.copyWith(weekday: () => i)),
                    ),
                ],
              ),
            ),
          ],
        ),
        _Section(
          title: 'Finals week',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SegmentedButton<bool?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Calendar')),
                  ButtonSegment(value: true, label: Text('On')),
                  ButtonSegment(value: false, label: Text('Off')),
                ],
                selected: {settings.finals},
                onSelectionChanged: (s) =>
                    _update(settings.copyWith(finals: () => s.first)),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Crowd size',
          children: [
            _LabeledSlider(
              label: '${settings.crowd.toStringAsFixed(1)}× normal',
              value: settings.crowd,
              max: 3,
              divisions: 30,
              onChanged: (v) => _update(settings.copyWith(crowd: v)),
            ),
          ],
        ),
        _Section(
          title: 'Force a floor',
          children: [
            for (final floor in widget.status.floors)
              _FloorOverride(
                floor: floor,
                forced: settings.floorOverrides[floor.id],
                onChanged: (value) {
                  final next = Map.of(settings.floorOverrides);
                  value == null
                      ? next.remove(floor.id)
                      : next[floor.id] = value;
                  _update(settings.copyWith(floorOverrides: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: settings.isDefault ? null : _reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset to live data'),
        ),
      ],
    );
  }
}

String _formatHour(double hour) {
  final h = hour.floor();
  final m = ((hour - h) * 60).round();
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// What the Overview would say right now, so you can see tweaks land.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.status});

  final BobstStatus status;

  @override
  Widget build(BuildContext context) {
    final building = status.building;
    return Card(
      color: colorFor(building.busyness),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOBST IS ${building.busyness.label.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${thousands(building.occupancy)} people · '
                      '${(building.fullness * 100).round()}% full',
                    ),
                  ],
                ),
              ),
              if (status.simulated)
                const Icon(Icons.science, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorOverride extends StatelessWidget {
  const _FloorOverride({
    required this.floor,
    required this.forced,
    required this.onChanged,
  });

  final Floor floor;
  final double? forced;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final forced = this.forced;
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: Text(floor.name),
          subtitle: Text(
            forced == null
                ? 'Live · ${floor.occupancy} people'
                : 'Forced to ${(forced * 100).round()}%',
          ),
          value: forced != null,
          onChanged: (on) => onChanged(on ? floor.fullness : null),
        ),
        if (forced != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Slider(
              value: forced,
              divisions: 20,
              label: '${(forced * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}
