/// Tracks which GraphQL fragments define inline fragments.
///
/// This is used during code generation to determine when to create specialized
/// interfaces for inline fragments. For example:
///
/// ```graphql
/// fragment AuthorFragment on Author {
///   displayName
///   ... on Person {
///     firstName
///     lastName
///   }
///   ... on Company {
///     name
///   }
/// }
///
/// fragment BookFragment on Book {
///   author {
///     ...AuthorFragment
///   }
/// }
/// ```
///
/// In this case:
/// - AuthorFragment HAS inline fragments for Person and Company
/// - BookFragment does NOT have inline fragments (the spread ...AuthorFragment is not an inline fragment)
///
/// So we should create:
/// - GAuthorFragment__asPerson ✓
/// - GAuthorFragment__asCompany ✓
/// - GBookFragment__asPerson ✗ (NOT created - belongs to AuthorFragment)
/// - GBookFragment__asCompany ✗ (NOT created - belongs to AuthorFragment)
class FragmentInlineFragmentInfo {
  /// Maps fragment names to the set of type names they have inline fragments for.
  /// Example: {"AuthorFragment": {"Person", "Company"}, "heroFieldsFragment": {"Human", "Droid"}}
  final Map<String, Set<String>> _fragmentToInlineTypes = {};

  /// Records that a fragment has an inline fragment for a specific type.
  ///
  /// [typeName] is the type of the inline fragment.
  void addInlineFragment(String fragmentName, String typeName) {
    _fragmentToInlineTypes.putIfAbsent(fragmentName, () => {}).add(typeName);
  }

  /// Checks if a fragment has inline fragments for a specific type.
  ///
  /// [typeName] is the type to check for.
  ///
  /// Returns true if the fragment has an inline fragment for this type.
  bool hasInlineFragmentForType(String fragmentName, String typeName) =>
      _fragmentToInlineTypes[fragmentName]?.contains(typeName) ?? false;

  /// Checks if a fragment has any inline fragments at all.
  bool hasInlineFragments(String fragmentName) =>
      _fragmentToInlineTypes[fragmentName]?.isNotEmpty ?? false;

  /// Gets all inline fragment types for a given fragment.
  Set<String> getInlineFragmentTypes(String fragmentName) =>
      _fragmentToInlineTypes[fragmentName] ?? {};

  @override
  String toString() => "FragmentInlineFragmentInfo($_fragmentToInlineTypes)";
}
