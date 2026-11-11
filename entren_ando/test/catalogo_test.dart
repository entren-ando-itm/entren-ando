import 'package:entren_ando/features/perfil/catalogo/catalogo_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas del catálogo con alias (ENT-17). No necesitan emulador.
void main() {
  const usuario = '00000000-0000-0000-0000-000000000001';

  test('Sin filtros solo se pasa el usuario y el alias se une sin borrados', () {
    final c = CatalogoRepositorio.consultaBusqueda(idUsuario: usuario);
    expect(c.argumentos, [usuario]);
    expect(c.sql, contains('LEFT JOIN usuario_ejercicio ue'));
    expect(c.sql, contains('ue.eliminado = 0'));
    expect(c.sql, isNot(contains('WHERE')));
  });

  test('El buscador busca en nombre oficial y alias con valores en ?', () {
    final c = CatalogoRepositorio.consultaBusqueda(idUsuario: usuario, texto: '  Garrafón ');
    expect(c.argumentos, [usuario, '%garrafón%', '%garrafón%']);
    expect(c.sql, contains('lower(e.nombre_oficial) LIKE ?'));
    expect(c.sql, contains('lower(ue.nombre_alias) LIKE ?'));
    expect(c.sql, isNot(contains('garrafón')));
  });

  test('Los comodines del texto se escapan', () {
    final c = CatalogoRepositorio.consultaBusqueda(idUsuario: usuario, texto: '50%_a');
    expect(c.argumentos[1], r'%50\%\_a%');
  });

  test('Filtros por grupo y por equipo', () {
    final c = CatalogoRepositorio.consultaBusqueda(
      idUsuario: usuario,
      grupo: 'Pierna',
      equipo: const FiltroEquipo.equipo(3),
    );
    expect(c.argumentos, [usuario, 'Pierna', 3]);
    expect(c.sql, contains('e.grupo_muscular = ?'));
    expect(c.sql, contains('e.id_equipo = ?'));
  });

  test('Filtro de peso corporal busca ejercicios sin equipo', () {
    final c = CatalogoRepositorio.consultaBusqueda(
      idUsuario: usuario,
      equipo: FiltroEquipo.soloPesoCorporal,
    );
    expect(c.argumentos, [usuario]);
    expect(c.sql, contains('e.id_equipo IS NULL'));
  });

  test('El nombre visible es el alias y si no hay, el nombre oficial', () {
    const conAlias = EjercicioCatalogo(
      idEjercicio: 1,
      nombreOficial: 'Peso muerto',
      grupoMuscular: 'Espalda',
      tipoMovimiento: 'compuesto',
      alias: 'Levantamiento de garrafón',
    );
    const sinAlias = EjercicioCatalogo(
      idEjercicio: 2,
      nombreOficial: 'Sentadilla con barra',
      grupoMuscular: 'Pierna',
      tipoMovimiento: 'compuesto',
    );
    expect(conAlias.nombreVisible, 'Levantamiento de garrafón');
    expect(sinAlias.nombreVisible, 'Sentadilla con barra');
    expect(CatalogoRepositorio.nombreVisible, 'COALESCE(ue.nombre_alias, e.nombre_oficial)');
  });

  test('Validación del alias', () {
    expect(CatalogoRepositorio.validarAlias(''), isNotNull);
    expect(CatalogoRepositorio.validarAlias('   '), isNotNull);
    expect(CatalogoRepositorio.validarAlias('a' * 61), isNotNull);
    expect(CatalogoRepositorio.validarAlias('Levantamiento de garrafón'), isNull);
  });
}
