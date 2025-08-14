import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationConfirmScreen extends StatefulWidget {
  const ReservationConfirmScreen({super.key});

  @override
  State<ReservationConfirmScreen> createState() =>
      _ReservationConfirmScreenState();
}

class _ReservationConfirmScreenState extends State<ReservationConfirmScreen> {
  final _supabase = Supabase.instance.client;

  String? _restaurantId;
  String? _restaurantName; // used for nicer push copy
  String? _processingId;
  DateTime? _selectedDate;

  // Pending + Confirmed lists (both sorted by date/time asc)
  final List<Map<String, dynamic>> _rows = [];
  final List<Map<String, dynamic>> _confirmedRows = [];

  RealtimeChannel? _channel;

  // Cache { user_id: {name, contact} }
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurantId();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadRestaurantId() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // fetch id + name so we can show it in push text
      final r = await _supabase
          .from('restaurants')
          .select('id,name')
          .eq('owner_id', uid)
          .maybeSingle();

      if (!mounted) return;
      _restaurantId = r?['id'] as String?;
      _restaurantName = (r?['name'] as String?)?.trim();

      if (_restaurantId != null) {
        await _initialFetch();
        _subscribeRealtime();
      } else {
        _toast('No restaurant found for this owner.');
      }
      setState(() {});
    } on PostgrestException catch (e) {
      _toast('Error: ${e.message}');
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _initialFetch() async {
    if (_restaurantId == null) return;

    final String? ds = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    // Build base query for pending
    var pendingQuery = _supabase
        .from('reservations')
        .select()
        .eq('restaurant_id', _restaurantId!)
        .eq('status', 'pending');

    // Build base query for confirmed
    var confirmedQuery = _supabase
        .from('reservations')
        .select()
        .eq('restaurant_id', _restaurantId!)
        .eq('status', 'confirmed');

    if (ds != null) {
      pendingQuery = pendingQuery.eq('date', ds);
      confirmedQuery = confirmedQuery.eq('date', ds);
    }

    final pending = await pendingQuery
        .order('date', ascending: true)
        .order('time', ascending: true);

    final confirmed = await confirmedQuery
        .order('date', ascending: true)
        .order('time', ascending: true);

    _rows
      ..clear()
      ..addAll(pending
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));

    _confirmedRows
      ..clear()
      ..addAll(confirmed
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));

    _sortRows(_rows);
    _sortRows(_confirmedRows);

    // Hydrate user cache for both lists
    await _hydrateUsers([
      ..._rows.map((e) => (e['user_id'] ?? '').toString()),
      ..._confirmedRows.map((e) => (e['user_id'] ?? '').toString()),
    ].where((s) => s.isNotEmpty));

    if (mounted) setState(() {});
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();

    _channel = _supabase.channel('reservations-owner-${_restaurantId!}')
      // INSERT
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'reservations',
        callback: (payload) async {
          final row = Map<String, dynamic>.from(payload.newRecord);
          if (row['restaurant_id'] != _restaurantId) return;
          if (!_datePass(row)) return;

          final status = (row['status'] ?? '').toString();
          if (status == 'pending') {
            _rows.removeWhere((r) => r['id'] == row['id']);
            _rows.add(row);
            _sortRows(_rows);
          } else if (status == 'confirmed') {
            _confirmedRows.removeWhere((r) => r['id'] == row['id']);
            _confirmedRows.add(row);
            _sortRows(_confirmedRows);
          } else {
            // ignore other statuses here
          }

          await _hydrateUsers([row['user_id']?.toString() ?? '']);
          if (mounted) setState(() {});
        },
      )
      // UPDATE
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'reservations',
        callback: (payload) {
          final row = Map<String, dynamic>.from(payload.newRecord);
          if (row['restaurant_id'] != _restaurantId) return;

          final pass = _datePass(row);
          final status = (row['status'] ?? '').toString();

          // Always remove from both first
          _rows.removeWhere((r) => r['id'] == row['id']);
          _confirmedRows.removeWhere((r) => r['id'] == row['id']);

          if (pass) {
            if (status == 'pending') {
              _rows.add(row);
              _sortRows(_rows);
            } else if (status == 'confirmed') {
              _confirmedRows.add(row);
              _sortRows(_confirmedRows);
            } // else (rejected/other) don't show
          }

          if (mounted) setState(() {});
        },
      )
      // DELETE
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'reservations',
        callback: (payload) {
          final old = payload.oldRecord;
          if (old == null) return;
          if (old['restaurant_id'] != _restaurantId) return;

          _rows.removeWhere((r) => r['id'] == old['id']);
          _confirmedRows.removeWhere((r) => r['id'] == old['id']);
          if (mounted) setState(() {});
        },
      )
      ..subscribe();
  }

  bool _datePass(Map<String, dynamic> row) {
    if (_selectedDate == null) return true;
    final ds = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    return (row['date']?.toString() ?? '') == ds;
  }

  void _sortRows(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final ad = (a['date'] ?? '') as String;
      final bd = (b['date'] ?? '') as String;
      final at = (a['time'] ?? '') as String;
      final bt = (b['time'] ?? '') as String;
      final c1 = ad.compareTo(bd);
      if (c1 != 0) return c1;
      return at.compareTo(bt);
    });
  }

  Future<void> _hydrateUsers(Iterable<String> userIds) async {
    final missing = userIds
        .where((id) => id.isNotEmpty && !_userCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    try {
      // universal IN filter string
      final list = missing.map((s) => '"$s"').join(',');
      final res = await _supabase
          .from('users') // your users table with uid, name, contact
          .select('uid,name,contact')
          .filter('uid', 'in', '($list)');

      for (final row in res) {
        final uid = row['uid'] as String;
        _userCache[uid] = {
          'name': row['name'],
          'contact': row['contact'],
        };
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('User hydrate error: $e');
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> r, String status) async {
    final id = r['id'] as String;
    setState(() => _processingId = id);
    try {
      await _supabase
          .from('reservations')
          .update({'status': status}).eq('id', id);

      // ---- OneSignal push via Edge Function ----
      try {
        final restaurant = _restaurantName ?? 'our restaurant';
        final dateStr = (r['date']?.toString() ?? '');
        final timeStr = (r['time']?.toString() ?? '');

        String prettyDate = dateStr;
        String prettyTime = timeStr;
        try {
          if (dateStr.isNotEmpty) {
            final d = DateFormat('yyyy-MM-dd').parse(dateStr);
            prettyDate = DateFormat('EEE, MMM d').format(d);
          }
          if (timeStr.isNotEmpty) {
            final fmt = timeStr.length == 5
                ? DateFormat('HH:mm')
                : DateFormat('HH:mm:ss');
            final t = fmt.parse(timeStr);
            prettyTime = DateFormat('h:mm a').format(t);
          }
        } catch (_) {}

        final title = status == 'confirmed'
            ? 'Reservation confirmed'
            : 'Reservation rejected';
        final body = status == 'confirmed'
            ? 'See you at $restaurant on $prettyDate at $prettyTime.'
            : 'Sorry—your booking at $restaurant was rejected.';

        await _supabase.functions.invoke('push-onesignal', body: {
          'userIds': [r['user_id']], // must match OneSignal.login(uid)
          'title': title,
          'body': body,
          'data': {
            'reservation_id': r['id'].toString(),
            'restaurant_id': r['restaurant_id'].toString(),
            'status': status,
            'route': '/customer/reservations',
          },
        });
      } catch (e) {
        debugPrint('push-onesignal error: $e');
      }
      // -----------------------------------------

      _toast('Reservation ${status == 'confirmed' ? 'confirmed' : 'rejected'}');
    } on PostgrestException catch (e) {
      _toast('Error: ${e.message}');
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ---------- UI ----------

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now
          .subtract(const Duration(days: 1)), // allow today/yesterday if needed
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'Filter by date',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _initialFetch();
      _subscribeRealtime();
    }
  }

  void _clearFilter() async {
    setState(() => _selectedDate = null);
    await _initialFetch();
    _subscribeRealtime();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final rid = _restaurantId;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayPending = _rows.where((r) => r['date'] == todayStr).toList();
    final laterPending = _rows.where((r) => r['date'] != todayStr).toList();

    final todayConfirmed =
        _confirmedRows.where((r) => r['date'] == todayStr).toList();
    final laterConfirmed =
        _confirmedRows.where((r) => r['date'] != todayStr).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Requests')),
      body: rid == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _pickFilterDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDate == null
                                      ? 'Filter date (optional)'
                                      : DateFormat('EEE, MMM d, yyyy')
                                          .format(_selectedDate!),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: _clearFilter,
                          icon: const Icon(Icons.close),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Lists: Pending (top) + Confirmed (bottom)
                Expanded(
                  child: (_rows.isEmpty && _confirmedRows.isEmpty)
                      ? const Center(child: Text('No reservations to show.'))
                      : ListView(
                          children: [
                            // ------ Pending Section ------
                            if (_selectedDate != null) ...[
                              if (_rows.isNotEmpty) _SectionHeader('Pending'),
                              ..._rows.map((r) => _ReservationCard(
                                    row: r,
                                    userCache: _userCache,
                                    processingId: _processingId,
                                    onConfirm: () =>
                                        _updateStatus(r, 'confirmed'),
                                    onReject: () =>
                                        _updateStatus(r, 'rejected'),
                                  )),
                            ] else ...[
                              if (todayPending.isNotEmpty)
                                _SectionHeader('Pending • Today'),
                              ...todayPending.map((r) => _ReservationCard(
                                    row: r,
                                    userCache: _userCache,
                                    processingId: _processingId,
                                    onConfirm: () =>
                                        _updateStatus(r, 'confirmed'),
                                    onReject: () =>
                                        _updateStatus(r, 'rejected'),
                                  )),
                              if (laterPending.isNotEmpty)
                                _SectionHeader('Pending • Later'),
                              ...laterPending.map((r) => _ReservationCard(
                                    row: r,
                                    userCache: _userCache,
                                    processingId: _processingId,
                                    onConfirm: () =>
                                        _updateStatus(r, 'confirmed'),
                                    onReject: () =>
                                        _updateStatus(r, 'rejected'),
                                  )),
                            ],

                            // Divider between sections if both have content
                            if ((_rows.isNotEmpty &&
                                    _confirmedRows.isNotEmpty) ||
                                (_rows.isEmpty && _confirmedRows.isNotEmpty))
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),

                            // ------ Confirmed Section (always bottom) ------
                            if (_selectedDate != null) ...[
                              if (_confirmedRows.isNotEmpty)
                                _SectionHeader('Confirmed'),
                              ..._confirmedRows.map((r) => _ConfirmedCard(
                                    row: r,
                                    userCache: _userCache,
                                  )),
                            ] else ...[
                              if (todayConfirmed.isNotEmpty)
                                _SectionHeader('Confirmed • Today'),
                              ...todayConfirmed.map(
                                (r) => _ConfirmedCard(
                                  row: r,
                                  userCache: _userCache,
                                ),
                              ),
                              if (laterConfirmed.isNotEmpty)
                                _SectionHeader('Confirmed • Later'),
                              ...laterConfirmed.map(
                                (r) => _ConfirmedCard(
                                  row: r,
                                  userCache: _userCache,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final Map<String, Map<String, dynamic>> userCache;
  final String? processingId;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _ReservationCard({
    required this.row,
    required this.userCache,
    required this.processingId,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final id = row['id'];
    final guests = row['guests'];
    final dateStr = row['date']?.toString();
    final timeStr = row['time']?.toString();
    final note = row['note']?.toString(); // optional column
    final uid = row['user_id']?.toString();

    // pretty date/time
    String prettyDate = dateStr ?? '';
    String prettyTime = timeStr ?? '';
    try {
      if (dateStr != null) {
        final d = DateFormat('yyyy-MM-dd').parse(dateStr);
        prettyDate = DateFormat('EEE, MMM d').format(d);
      }
      if (timeStr != null) {
        final fmt =
            timeStr.length == 5 ? DateFormat('HH:mm') : DateFormat('HH:mm:ss');
        final t = fmt.parse(timeStr);
        prettyTime = DateFormat('h:mm a').format(t);
      }
    } catch (_) {}

    final user = uid != null ? userCache[uid] : null;
    final name = user?['name']?.toString();
    final contact = user?['contact']?.toString();

    final processing = processingId == id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row (date/time + guests)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$prettyDate • $prettyTime',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('$guests'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (name != null || contact != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [name, contact]
                          .where((e) => (e ?? '').toString().isNotEmpty)
                          .join(' • '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            if (note != null && note.trim().isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note)),
                ],
              ),
              const SizedBox(height: 6),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: processing ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: processing ? null : onConfirm,
                  icon: processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(processing ? 'Updating…' : 'Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final Map<String, Map<String, dynamic>> userCache;

  const _ConfirmedCard({
    required this.row,
    required this.userCache,
  });

  @override
  Widget build(BuildContext context) {
    final guests = row['guests'];
    final dateStr = row['date']?.toString();
    final timeStr = row['time']?.toString();
    final note = row['note']?.toString();
    final uid = row['user_id']?.toString();

    String prettyDate = dateStr ?? '';
    String prettyTime = timeStr ?? '';
    try {
      if (dateStr != null) {
        final d = DateFormat('yyyy-MM-dd').parse(dateStr);
        prettyDate = DateFormat('EEE, MMM d').format(d);
      }
      if (timeStr != null) {
        final fmt =
            timeStr.length == 5 ? DateFormat('HH:mm') : DateFormat('HH:mm:ss');
        final t = fmt.parse(timeStr);
        prettyTime = DateFormat('h:mm a').format(t);
      }
    } catch (_) {}

    final user = uid != null ? userCache[uid] : null;
    final name = user?['name']?.toString();
    final contact = user?['contact']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row (date/time + guests + confirmed chip)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$prettyDate • $prettyTime',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('$guests'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Confirmed'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (name != null || contact != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [name, contact]
                          .where((e) => (e ?? '').toString().isNotEmpty)
                          .join(' • '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            if (note != null && note.trim().isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note)),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
