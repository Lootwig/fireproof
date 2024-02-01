import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:change_case/change_case.dart';
import 'package:fireproof/src/annotation.dart';
import 'package:source_gen/source_gen.dart';
import 'package:json_annotation/json_annotation.dart';

Builder fireproofBuilder(BuilderOptions options) =>
    PartBuilder([QueryGenerator()], '.fireproof.dart');

class QueryGenerator extends GeneratorForAnnotation<Fireproof> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is ClassElement) {
      final type = element.displayName;
      final buffer = StringBuffer();
      final fields = element.constructors
          .where((element) => element.isFactory)
          .firstOrNull
          ?.parameters
          .where((element) => element.isNamed);
      if (fields != null) {
        buffer.writeln('extension \$${element.name}Mixin on Query<$type> {');
        for (final field in fields) {
          final converters = field.metadata
              .map((m) => m.element)
              .whereType<ConstructorElement>()
              .where((element) => element.enclosingElement.allSupertypes
                  .map((e) => e.getDisplayString(withNullability: false))
                  .any((element) => element.contains('JsonConverter')));
          final converter = converters.firstOrNull;
          final isNullable = field.isOptionalNamed;
          final equalString = switch ((converter, isNullable)) {
            (null, _) => field.name,
            (_, false) =>
              'const ${converter!.displayName}().toJson(${field.name})',
            (_, true) =>
              '${field.name} == null ? null : const ${converter!.displayName}().toJson(${field.name})',
          };
          buffer.writeln(
              '''  Query<$type> where${field.name.toPascalCase()}(${field.type} ${field.name}) {
    return where('${field.name}', isEqualTo: $equalString);
  }\n\n''');
        }
        buffer.writeln('}');
      }
      return buffer.toString();
    }
    throw InvalidGenerationSourceError(
      'Generator cannot target `$element`.',
    );
  }
}
