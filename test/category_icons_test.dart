import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/categories/category_icons.dart';

void main() {
  group('kCategoryIcons', () {
    test('tiene 56 claves (7 páginas de 8)', () {
      expect(kCategoryIcons.length, 56);
    });

    test('incluye "help" como fallback del catálogo', () {
      expect(kCategoryIcons.containsKey('help'), isTrue);
    });
  });

  group('iconForKey', () {
    test('devuelve el ícono de una clave conocida', () {
      expect(iconForKey('cart'), Icons.shopping_cart);
    });

    test('devuelve help_outline ante una clave desconocida', () {
      expect(iconForKey('xxx'), Icons.help_outline);
    });
  });

  group('kCategoryKeywordIcons', () {
    test('todas las claves de valor existen en el catálogo', () {
      for (final key in kCategoryKeywordIcons.values) {
        expect(kCategoryIcons.containsKey(key), isTrue, reason: 'clave inexistente: $key');
      }
    });

    test('las keywords ya están normalizadas (minúsculas/sin acentos)', () {
      for (final keyword in kCategoryKeywordIcons.keys) {
        expect(normalizeForIcon(keyword), keyword, reason: 'keyword sin normalizar: $keyword');
      }
    });
  });

  group('normalizeForIcon', () {
    test('pasa a minúsculas y quita acentos y ñ', () {
      expect(normalizeForIcon('Médico'), 'medico');
      expect(normalizeForIcon('NIÑOS'), 'ninos');
      expect(normalizeForIcon('  Nafta  '), 'nafta');
    });
  });

  group('suggestIconForName', () {
    test('sugiere por palabra contenida y con acentos', () {
      expect(suggestIconForName('Nafta'), 'gas');
      expect(suggestIconForName('Farmacia del pueblo'), 'pill');
      expect(suggestIconForName('Médico de familia'), 'medical');
      expect(suggestIconForName('Colectivo y subte'), 'bus');
    });

    test('soporta keywords con espacios (subcadena)', () {
      expect(suggestIconForName('Mi obra social'), 'heart');
    });

    test('no matchea palabras parciales de una sola keyword', () {
      // "gaseosa" contiene "gas" como subcadena pero no como palabra completa.
      expect(suggestIconForName('Gaseosa'), isNot('gas'));
    });

    test('devuelve null sin match', () {
      expect(suggestIconForName('Zxqw'), isNull);
      expect(suggestIconForName(''), isNull);
    });
  });

  group('resolveCategoryIcon', () {
    test('help + nombre que matchea → clave sugerida (fallback visual)', () {
      expect(resolveCategoryIcon('help', 'Nafta'), 'gas');
    });

    test('help + nombre sin match → se mantiene help', () {
      expect(resolveCategoryIcon('help', 'Zxqw'), 'help');
    });

    test('ícono manual nunca es pisado por la sugerencia', () {
      expect(resolveCategoryIcon('cart', 'Nafta'), 'cart');
    });
  });
}
