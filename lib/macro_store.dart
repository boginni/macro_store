import 'dart:async';

import 'package:macros/macros.dart';

macro class MacroStore implements ClassDeclarationsMacro, ClassDefinitionMacro {

  const MacroStore();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder,) async {
    final fields = await builder.fieldsOf(clazz);
    final methods = await builder.methodsOf(clazz);

    void declareGetter(String fieldName,
        TypeAnnotation type,) {
      builder.declareInType(
        DeclarationCode.fromParts([
          '  ',
          'external ',
          type.code,
          ' get ',
          fieldName,
          ';',
        ]),
      );
    }

    void declareSetter(String fieldName,
        TypeAnnotation type,) {
      builder.declareInType(
          DeclarationCode.fromParts([
            '  ',
            'external set ',
            fieldName,
            ' (',
            type.code,
            ' value',
            ');',
          ])
      ,);
    }


    for (final field in fields) {
      final fieldName = field.identifier.name;

      final isPrivate = fieldName.startsWith('_');

      if (!isPrivate || field.hasFinal) {
        continue;
      }

      final type = field.type;

      final getterName = fieldName.substring(1);


      final (getter, setter) = await methods.getMethodPairOf(
        field, allMethods: true,);


      if (getter == null) {
        declareGetter(getterName, type);
      }

      if (setter == null) {
        declareSetter(getterName, type);
      }
    }
  }

  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder,) async {
    final fields = await typeBuilder.fieldsOf(clazz);

    final methods = await typeBuilder.methodsOf(clazz);


    for (final field in fields) {
      final fieldName = field.identifier.name;

      final isPrivate = fieldName.startsWith('_');

      if (!isPrivate) {
        continue;
      }

      final (getter, setter) = await methods.getMethodPairOf(field);


      if (getter != null) {
        final builder = await typeBuilder.buildMethod(getter.identifier);

        builder.augment(FunctionBodyCode.fromParts([
          ' => ',
          fieldName,
          ';',
        ]),);
      }

      if (setter != null) {
        final builder = await typeBuilder.buildMethod(setter.identifier);

        builder.augment(FunctionBodyCode.fromParts([
          '{\n',
          '\t\t$fieldName = value;\n',
          '\t\tnotifyListeners();\n',
          '\t}',
        ]),);
      }
    }
  }
}


extension on List<MethodDeclaration> {

  Future<(MethodDeclaration?, MethodDeclaration?)> getMethodPairOf(
      FieldDeclaration field,
      {
        bool allMethods = false,
      }) async {
    final fieldNames = field.identifier.name.substring(1);

    final methods =
    where((method) => method.hasExternal || allMethods)
        .where((method) => method.identifier.name == fieldNames);

    final getter = methods
        .where((method) => method.isGetter)
        .firstOrNull;
    final setter = methods
        .where((method) => method.isSetter)
        .firstOrNull;

    return (getter, setter);
  }

}
