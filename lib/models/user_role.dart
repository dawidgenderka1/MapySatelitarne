enum UserRole {
  viewer,
  editor,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.viewer:
        return 'Przeglądający';
      case UserRole.editor:
        return 'Edytor';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}