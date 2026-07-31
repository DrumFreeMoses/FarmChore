import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nostr/nostr.dart' hide Event;

import '../data/app_database.dart';
import '../domain/assignment.dart';
import '../domain/chore_instance.dart';
import '../domain/daily_generator.dart';
import '../domain/edit_event.dart';
import '../domain/role_default_set.dart';
import '../domain/roles.dart';
import '../nostr/nostr_event.dart';

/// The single door to chore data: reads and writes the local event log,
/// signs every write with the member keypair.
class ChoreRepository {
  ChoreRepository({
    required this.database,
    required this.keys,
    this.farmPubkey,
  });

  final AppDatabase database;
  final Keys keys;

  /// Pubkey anchoring the farm namespace; attached to every signed event.
  final String? farmPubkey;

  /// This device's member pubkey (signs all writes).
  String get myPubkey => keys.public;

  int _lastCreatedAt = 0;

  /// Monotonic created-at (seconds): guarantees strict LWW ordering even for
  /// rapid writes within the same second.
  int _now() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _lastCreatedAt = now > _lastCreatedAt ? now : _lastCreatedAt + 1;
    return _lastCreatedAt;
  }

  Future<void> _persist(NostrEvent event) async {
    final signed = event.signed(keys);
    await database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            id: signed.idOrComputed,
            pubkey: signed.pubKey,
            kind: signed.kind,
            createdAt: signed.createdAt,
            content: signed.content,
            sig: Value(signed.sig ?? ''),
            tags: Value(jsonEncode(signed.tags)),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Role default sets, latest event wins per role (addressable events).
  Future<List<RoleDefaultSet>> loadRoleDefaultSets() async {
    final rows = await database.eventsForKind(roleDefaultSetKind).get();
    final latest = <String, Event>{};
    for (final row in rows) {
      final key = _dTag(row) ?? row.id;
      final current = latest[key];
      if (current == null ||
          row.createdAt > current.createdAt ||
          (row.createdAt == current.createdAt &&
              row.id.compareTo(current.id) > 0)) {
        latest[key] = row;
      }
    }
    return latest.values
        .map((row) => RoleDefaultSet.fromNostrEvent(_toNostr(row)))
        .toList();
  }

  /// Only the base (active) sets: the ones daily generation uses.
  Future<List<RoleDefaultSet>> loadBaseRoleDefaultSets() async {
    final all = await loadRoleDefaultSets();
    return all.where((s) => s.isBase).toList();
  }

  /// Saves a role default set, replacing any prior set for the role.
  Future<void> saveRoleDefaultSet(RoleDefaultSet set) async {
    final event = set.toNostrEvent(
      pubKey: keys.public,
      createdAt: _now(),
      farmPubkey: farmPubkey,
    );
    await _persist(event);
  }

  /// Stores the current chores of [role] as a named variant
  /// (`d = role:name`); does not affect what is generated.
  Future<void> saveRoleVariant(
    FarmRole role,
    String name,
    List<ChoreDefault> chores,
  ) async {
    await saveRoleDefaultSet(
      RoleDefaultSet(role: role, chores: chores, name: name),
    );
  }

  /// Makes [set]'s chores the role's active base set (LWW replace).
  Future<void> activateRoleSet(RoleDefaultSet set) async {
    await saveRoleDefaultSet(
      RoleDefaultSet(role: set.role, chores: set.chores),
    );
  }

  /// Appends [title] (every workday) to [role]'s active default set.
  Future<void> addDefaultChore(FarmRole role, String title) async {
    final sets = await loadBaseRoleDefaultSets();
    final set = sets.where((s) => s.role == role).firstOrNull;
    await saveRoleDefaultSet(
      RoleDefaultSet(
        role: role,
        chores: [
          ...?set?.chores,
          ChoreDefault(title: title, weekdays: const [1, 2, 3, 4, 5, 6]),
        ],
      ),
    );
  }

  /// Members known to the farm: me first, then everyone who signed or was
  /// assigned an instance, in pubkey order.
  Future<List<String>> loadKnownMembers() async {
    final rows = await database.allEvents().get();
    final members = <String>{};
    for (final row in rows) {
      if (row.kind == choreInstanceKind || row.kind == assignmentKind) {
        members.add(row.pubkey);
      }
      final tags = jsonDecode(row.tags) as List;
      for (final tag in tags) {
        if (tag is List &&
            tag.isNotEmpty &&
            tag.first == 'assignee' &&
            tag.length > 1 &&
            tag[1].isNotEmpty) {
          members.add(tag[1] as String);
        }
      }
    }
    final known = members.toList()..sort();
    known.remove(myPubkey);
    return [myPubkey, ...known];
  }

  /// Instances for [date], newest event first (LWW by createdAt per d tag).
  Future<List<ChoreInstance>> loadInstancesForDate(DateTime date) async {
    final rows = await database.eventsForKind(choreInstanceKind).get();
    final latest = <String, Event>{};
    for (final row in rows) {
      final key = _dTag(row) ?? row.id;
      final existing = latest[key];
      if (existing == null ||
          row.createdAt > existing.createdAt ||
          (row.createdAt == existing.createdAt &&
              row.id.compareTo(existing.id) > 0)) {
        latest[key] = row;
      }
    }
    final instances = <ChoreInstance>[];
    for (final row in latest.values) {
      final instance = ChoreInstance.fromNostrEvent(_toNostr(row));
      if (instance.date.year == date.year &&
          instance.date.month == date.month &&
          instance.date.day == date.day) {
        instances.add(instance);
      }
    }
    instances.sort((a, b) => a.slug.compareTo(b.slug));
    return instances;
  }

  /// Generates today's instances from the role defaults that run today,
  /// persisting only the ones not already in the log. Returns the number
  /// of new instances created.
  Future<int> ensureDayGenerated(DateTime date) async {
    final defaults = await loadBaseRoleDefaultSets();
    final generated = DailyGenerator.generate(defaults: defaults, date: date);
    final existing = await loadInstancesForDate(date);
    final existingTags = existing.map((i) => i.dTag).toSet();
    var created = 0;
    for (final instance in generated) {
      if (existingTags.contains(instance.dTag)) {
        continue;
      }
      final event = instance.toNostrEvent(
        pubKey: keys.public,
        createdAt: _now(),
        farmPubkey: farmPubkey,
      );
      await _persist(event);
      created++;
    }
    return created;
  }

  /// Regenerates [date] to match the base default sets: creates missing
  /// open chores and cancels open chores that are no longer in the
  /// defaults. One-off tasks and non-open instances are left untouched.
  /// Returns the number of instances created or cancelled.
  Future<int> syncDayToDefaults(DateTime date) async {
    var changed = await ensureDayGenerated(date);
    final defaults = await loadBaseRoleDefaultSets();
    final expected = DailyGenerator.generate(defaults: defaults, date: date);
    final expectedKeys = {for (final i in expected) '${i.role.id}|${i.slug}'};
    final instances = await loadInstancesForDate(date);
    for (final instance in instances) {
      if (instance.type != ChoreType.chore) continue;
      if (!instance.status.isOpen) continue;
      if (expectedKeys.contains('${instance.role.id}|${instance.slug}')) {
        continue;
      }
      await editStatus(instance, ChoreStatus.cancelled);
      changed++;
    }
    return changed;
  }

  /// Persists a one-off instance (used for tasks and inline adds).
  Future<void> saveInstance(ChoreInstance instance) async {
    final event = instance.toNostrEvent(
      pubKey: keys.public,
      createdAt: _now(),
      farmPubkey: farmPubkey,
    );
    await _persist(event);
  }

  /// Assigns (or re-assigns) [instance] to [assigneePubkey]. Self-assignment
  /// is just an assignment whose signer is the assignee. An empty pubkey
  /// unassigns the instance.
  Future<void> assign(ChoreInstance instance, String assigneePubkey) async {
    if (assigneePubkey.isEmpty) {
      await saveInstance(instance.copyWith(assignee: null));
      return;
    }
    final assigned = instance.copyWith(assignee: assigneePubkey);
    await saveInstance(assigned);
    final event =
        Assignment(
          instanceId: instance.dTag,
          assignee: assigneePubkey,
        ).toNostrEvent(
          pubKey: keys.public,
          createdAt: _now(),
          farmPubkey: farmPubkey,
        );
    await _persist(event);
  }

  /// Applies a status transition as an edit (kind 31503) to the instance.
  ///
  /// Deferring passes [deferredTo] (the day the chore resurfaces); the
  /// instance then carries the deferred status and date.
  Future<ChoreInstance> editStatus(
    ChoreInstance instance,
    ChoreStatus status, {
    DateTime? deferredTo,
  }) async {
    final updated = instance.copyWith(
      status: status,
      completedAt: status == ChoreStatus.done ? DateTime.now() : null,
      deferredTo: deferredTo,
    );
    await saveInstance(updated);
    await _persist(
      EditEvent(
        instanceId: instance.dTag,
        field: 'status',
        value: status.name,
        scope: EditScope.oneTime,
      ).toNostrEvent(
        pubKey: keys.public,
        createdAt: _now(),
        farmPubkey: farmPubkey,
      ),
    );
    return updated;
  }

  /// Instances between [from] and [to] (inclusive), newest first. Used by
  /// history and the "My Chores" views.
  Future<List<ChoreInstance>> loadInstancesBetween(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await database.eventsForKind(choreInstanceKind).get();
    final latest = <String, Event>{};
    for (final row in rows) {
      final key = _dTag(row) ?? row.id;
      final existing = latest[key];
      if (existing == null ||
          row.createdAt > existing.createdAt ||
          (row.createdAt == existing.createdAt &&
              row.id.compareTo(existing.id) > 0)) {
        latest[key] = row;
      }
    }
    final instances = <ChoreInstance>[];
    for (final row in latest.values) {
      final instance = ChoreInstance.fromNostrEvent(_toNostr(row));
      if (!instance.date.isBefore(from) && !instance.date.isAfter(to)) {
        instances.add(instance);
      }
    }
    instances.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.slug.compareTo(b.slug);
    });
    return instances;
  }

  /// Renames an instance. With [EditScope.default_] the matching role
  /// default set is updated too, so future days use the new title.
  Future<void> updateTitle(
    ChoreInstance instance,
    String newTitle, {
    EditScope scope = EditScope.oneTime,
  }) async {
    final updated = instance.copyWith(title: newTitle);
    await saveInstance(updated);
    await _persist(
      EditEvent(
        instanceId: instance.dTag,
        field: 'title',
        value: newTitle,
        scope: scope,
      ).toNostrEvent(
        pubKey: keys.public,
        createdAt: _now(),
        farmPubkey: farmPubkey,
      ),
    );
    if (scope == EditScope.default_) {
      await _updateDefaultTitle(instance, newTitle);
    }
  }

  Future<void> _updateDefaultTitle(
    ChoreInstance instance,
    String newTitle,
  ) async {
    final sets = await loadBaseRoleDefaultSets();
    final set = sets.where((s) => s.role == instance.role).firstOrNull;
    if (set == null) return;
    final chores = [
      for (final chore in set.chores)
        if (chore.title == instance.title)
          ChoreDefault(
            title: newTitle,
            weekdays: chore.weekdays,
            assigneeHint: chore.assigneeHint,
          )
        else
          chore,
    ];
    await saveRoleDefaultSet(RoleDefaultSet(role: set.role, chores: chores));
  }

  String? _dTag(Event row) {
    final tags = jsonDecode(row.tags) as List;
    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag.first == 'd' && tag.length > 1) {
        return tag[1] as String;
      }
    }
    return null;
  }

  NostrEvent _toNostr(Event row) => NostrEvent(
    id: row.id,
    pubKey: row.pubkey,
    createdAt: row.createdAt,
    kind: row.kind,
    content: row.content,
    sig: row.sig.isEmpty ? null : row.sig,
    tags: (jsonDecode(row.tags) as List)
        .map((t) => (t as List).cast<String>())
        .toList(),
  );
}
