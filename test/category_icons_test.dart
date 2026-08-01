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
}
