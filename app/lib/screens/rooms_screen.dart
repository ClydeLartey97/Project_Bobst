import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rooms.dart';
import '../services/api_client.dart';

/// Live study room availability, ingested from NYU's LibCal booking site.
/// Booking needs an NYU login, so tapping a room opens its LibCal page.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<RoomGroup>? _groups;
  Object? _error;
  int _selected = 0;
  bool _freeOnly = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final groups = await widget.api.fetchRooms();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _groups;

    if (groups == null) {
      return Center(
        child: _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Couldn't load study rooms."),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }

    final group = groups[_selected.clamp(0, groups.length - 1)];
    final rooms = _freeOnly
        ? group.rooms.where((r) => r.state == RoomState.free).toList()
        : group.rooms;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 16,
          16,
          120,
        ),
        children: [
          Text(
            'Study Rooms',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < groups.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        '${groups[i].name}  ${groups[i].freeNow}/${groups[i].total}',
                      ),
                      selected: i == _selected,
                      onSelected: (_) => setState(() => _selected = i),
                    ),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Free right now only'),
            value: _freeOnly,
            onChanged: (v) => setState(() => _freeOnly = v),
          ),
          if (group.total == 0)
            _Message(
              group.error != null
                  ? "Couldn't reach LibCal for ${group.name}. Retrying soon."
                  : 'Fetching ${group.name} from LibCal…',
            )
          else if (rooms.isEmpty)
            const _Message('Nothing free right now.')
          else
            for (final room in rooms) _RoomTile(room: room),
          if (group.updatedAt case final updated?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Availability checked ${_clock(context, updated)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, status) = switch (room.state) {
      RoomState.free => (
        Colors.green.shade700,
        room.freeUntil != null
            ? 'Free until ${_clock(context, room.freeUntil!)}'
            : 'Free',
      ),
      RoomState.booked => (
        Colors.orange.shade800,
        room.nextFreeAt != null
            ? 'Booked · free at ${_clock(context, room.nextFreeAt!)}'
            : 'Booked for the rest of the day',
      ),
      RoomState.closed => (
        theme.colorScheme.onSurfaceVariant,
        room.nextFreeAt != null
            ? 'Closed · opens ${_dayClock(context, room.nextFreeAt!)}'
            : 'Not bookable now',
      ),
    };
    final details = [
      if (room.floor != null)
        room.floor!.startsWith('LL') ? room.floor! : 'Floor ${room.floor}',
      if (room.capacity != null)
        '${room.capacity} ${room.capacity == 1 ? 'person' : 'people'}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () =>
            launchUrl(room.bookingUrl, mode: LaunchMode.externalApplication),
        leading: Icon(Icons.circle, size: 14, color: color),
        minLeadingWidth: 14,
        title: Text(
          room.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          details.isEmpty ? status : '$details\n$status',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        isThreeLine: details.isNotEmpty,
        trailing: Icon(
          Icons.open_in_new,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Text(text, textAlign: TextAlign.center),
  );
}

String _clock(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t.toLocal()).format(context);

bool _isToday(DateTime t) {
  final now = DateTime.now();
  final local = t.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

String _dayClock(BuildContext context, DateTime t) {
  final prefix = _isToday(t) ? '' : 'tomorrow ';
  return '$prefix${_clock(context, t)}';
}
