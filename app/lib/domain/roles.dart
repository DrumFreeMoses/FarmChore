/// The farm's canonical roles, matching the Chore Defaults pages.
enum FarmRole {
  milkers('milkers', "Milker's Chores"),
  pourers('pourers', "Pourer's Chores"),
  feeders('feeders', "Feeder's Chores"),
  mechanics('mechanics', "Mechanic's Chores"),
  farmers('farmers', "Farmer's Chores"),
  nonJsf('non-jsf', 'Non-JSF');

  const FarmRole(this.id, this.displayName);

  /// Machine id used in d tags and tags.
  final String id;

  /// Human name for the role's chore list page.
  final String displayName;
}

abstract final class FarmRoles {
  static const all = FarmRole.values;
}
