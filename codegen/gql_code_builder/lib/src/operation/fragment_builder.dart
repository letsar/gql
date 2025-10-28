import "package:code_builder/code_builder.dart";
import "package:gql/ast.dart";
import "package:gql_code_builder/source.dart";
import "package:gql_code_builder/src/config/when_extension_config.dart";

import "../common.dart";
import "../fragment_inline_info.dart";
import "../utils/selection_utils.dart";
import "selection_builder.dart";

/// Builds data classes for GraphQL fragments.
///
/// For each fragment, builds both:
/// 1. An abstract interface class that defines the fragment's shape
/// 2. A concrete implementation class that can hold fragment data directly
///
/// Example:
/// ```graphql
/// fragment HeroDetails on Character {
///   name
///   friends {
///     name
///   }
/// }
/// ```
/// Will generate classes like `GHeroDetails` (interface) and
/// `GHeroDetailsData` (implementation).
List<Spec> buildFragmentDataClasses(
  FragmentDefinitionNode frag,
  SourceNode docSource,
  SourceNode schemaSource,
  Map<String, Reference> typeOverrides,
  InlineFragmentSpreadWhenExtensionConfig whenExtensionConfig,
  Map<String, SourceSelections> fragmentMap,
  Map<String, Reference> dataClassAliasMap,
  FragmentInlineFragmentInfo fragmentInlineFragmentInfo,
) {
  final selections = mergeSelections(
    frag.selectionSet.selections,
    fragmentMap,
  );

  return [
    // abstract class that will implemented by any class that uses the fragment
    ...buildSelectionSetDataClasses(
      name: frag.name.value,
      selections: selections,
      docSource: docSource,
      schemaSource: schemaSource,
      type: frag.typeCondition.on.name.value,
      typeOverrides: typeOverrides,
      fragmentMap: fragmentMap,
      dataClassAliasMap: dataClassAliasMap,
      superclassSelections: {},
      built: false,
      whenExtensionConfig: whenExtensionConfig,
      fragmentInlineFragmentInfo: fragmentInlineFragmentInfo,
    ),
    // concrete built_value data class for fragment
    ...buildSelectionSetDataClasses(
      name: "${frag.name.value}Data",
      selections: selections,
      docSource: docSource,
      schemaSource: schemaSource,
      type: frag.typeCondition.on.name.value,
      typeOverrides: typeOverrides,
      fragmentMap: fragmentMap,
      dataClassAliasMap: dataClassAliasMap,
      superclassSelections: {
        frag.name.value: SourceSelections(
          url: docSource.url,
          selections: selections,
        )
      },
      whenExtensionConfig: whenExtensionConfig,
      fragmentInlineFragmentInfo: fragmentInlineFragmentInfo,
    ),
  ];
}

/// Analyzes a GraphQL document to track which fragments define inline fragments.
///
/// This function scans all fragment definitions in the document and identifies
/// which fragments have DIRECT inline fragments (not nested through spreads).
///
/// For example, given:
/// ```graphql
/// fragment AuthorFragment on Author {
///   displayName
///   ... on Person {      # <- DIRECT inline fragment
///     firstName
///   }
/// }
///
/// fragment BookFragment on Book {
///   author {
///     ...AuthorFragment  # <- Fragment spread, NOT an inline fragment
///   }
/// }
/// ```
///
/// This will record that:
/// - AuthorFragment HAS inline fragments for "Person"
/// - BookFragment does NOT have inline fragments
///
/// Returns a [FragmentInlineFragmentInfo] that can be used during code generation
/// to decide which specialized interfaces to create.
FragmentInlineFragmentInfo analyzeFragmentInlineFragments(
  DocumentNode document,
  Map<String, SourceSelections> fragmentMap,
) {
  final info = FragmentInlineFragmentInfo();

  // Scan all definitions in the document
  for (final definition in document.definitions) {
    if (definition is FragmentDefinitionNode) {
      final fragmentName = definition.name.value;

      // Look for DIRECT inline fragments in this fragment's selection set
      // (not nested through fragment spreads)
      for (final selection in definition.selectionSet.selections) {
        if (selection is InlineFragmentNode) {
          final typeName = selection.typeCondition?.on.name.value;
          if (typeName != null) {
            info.addInlineFragment(fragmentName, typeName);
          }
        }
      }
    }
  }

  return info;
}
