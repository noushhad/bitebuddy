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

  final List<Map<String, dynamic>> _rows = [];
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
    final List<dynamic> data;
    if (_selectedDate != null) {
      final ds = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      data = await _supabase
          .from('reservations')
          .select()
          .eq('restaurant_id', _restaurantId!)
          .eq('status', 'pending')
          .eq('date', ds)
          .order('date', ascending: true)
          .order('time', ascending: true);
    } else {
      data = await _supabase
          .from('reservations')
          .select()
          .eq('restaurant_id', _restaurantId!)
          .eq('status', 'pending')
          .order('date', ascending: true)
          .order('time', ascending: true);
    }

    _rows
      ..clear()
      ..addAll(
          data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));

    await _hydrateUsers(
      _rows
          .map((e) => (e['user_id'] ?? '').toString())
          .where((s) => s.isNotEmpty),
    );
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
          // manual filter
          if (row['restaurant_id'] != _restaurantId) return;
          if (row['status'] != 'pending') return;
          if (!_datePass(row)) return;

          _rows.removeWhere((r) => r['id'] == row['id']);
          _rows.add(row);
          _sortRows();
          await _hydrateUsers([row['user_id'].toString()]);
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

          final idx = _rows.indexWhere((r) => r['id'] == row['id']);
          final keep = row['status'] == 'pending' && _datePass(row);

          if (!keep) {
            if (idx != -1) _rows.removeAt(idx);
          } else {
            if (idx == -1) {
              _rows.add(row);
            } else {
              _rows[idx] = row;
            }
            _sortRows();
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

  void _sortRows() {
    _rows.sort((a, b) {
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
    final missing = userIds.where((id) => !_userCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      // universal IN filter string (works across postgrest 2.x)
      final list = missing.map((s) => '"$s"').join(',');
      final res = await _supabase
          .from('users') // change if your table name differs
          .select('id,name,contact')
          .filter('id', 'in', '($list)');

      for (final row in res) {
        _userCache[row['id'] as String] = {
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
          'userIds': [
            r['user_id']
          ], // must match OneSignal.login(uid) in customer app
          'title': title,
          'body': body,
          'data': {
            'reservation_id': r['id'].toString(),
            'restaurant_id': r['restaurant_id'].toString(),
            'status': status,
            // optional deep link route (handled in main.dart OneSignal click listener)
            'route': '/customer/reservations',
          },
        });
      } catch (e) {
        // don't block UI if push fails
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
      firstDate: now,
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
    final today = _rows.where((r) => r['date'] == todayStr).toList();
    final later = _rows.where((r) => r['date'] != todayStr).toList();

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

                // List / Sections
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('No pending reservations.'))
                      : ListView(
                          children: [
                            if (_selectedDate != null) ...[
                              // filtered: single list
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
                              if (today.isNotEmpty) _SectionHeader('Today'),
                              ...today.map((r) => _ReservationCard(
                                    row: r,
                                    userCache: _userCache,
                                    processingId: _processingId,
                                    onConfirm: () =>
                                        _updateStatus(r, 'confirmed'),
                                    onReject: () =>
                                        _updateStatus(r, 'rejected'),
                                  )),
                              if (later.isNotEmpty) _SectionHeader('Later'),
                              ...later.map((r) => _ReservationCard(
                                    row: r,
                                    userCache: _userCache,
                                    processingId: _processingId,
                                    onConfirm: () =>
                                        _updateStatus(r, 'confirmed'),
                                    onReject: () =>
                                        _updateStatus(r, 'rejected'),
                                  )),
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
