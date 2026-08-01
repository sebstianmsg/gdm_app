import 'package:flutter/material.dart';

/// Catálogo fijo de íconos de categoría: clave string estable (persistida en la
/// columna `icon` de `categories`) → `IconData` de Material.
///
/// Son **56 claves** curadas por tipo de gasto personal. El orden define las
/// **7 páginas** del carrusel de "Símbolos" (8 por página). `help` es el último
/// slot y el fallback de claves desconocidas.
const kCategoryIcons = <String, IconData>{
  // Compras y dinero
  'cart': Icons.shopping_cart,   'basket': Icons.shopping_basket,
  'bag': Icons.shopping_bag,     'store': Icons.store,
  'wallet': Icons.account_balance_wallet, 'bank': Icons.account_balance,
  'card': Icons.credit_card,     'savings': Icons.savings,
  // Comida y bebida
  'fork': Icons.restaurant,      'fastfood': Icons.fastfood,
  'pizza': Icons.local_pizza,    'coffee': Icons.local_cafe,
  'bar': Icons.local_bar,        'cake': Icons.cake,
  'grocery': Icons.local_grocery_store, 'icecream': Icons.icecream,
  // Transporte
  'bus': Icons.directions_bus,   'car': Icons.directions_car,
  'gas': Icons.local_gas_station,'train': Icons.train,
  'subway': Icons.subway,        'taxi': Icons.local_taxi,
  'bike': Icons.directions_bike, 'parking': Icons.local_parking,
  // Viajes
  'plane': Icons.flight,         'hotel': Icons.hotel,
  'luggage': Icons.luggage,      'beach': Icons.beach_access,
  // Hogar y servicios
  'home': Icons.home,            'bolt': Icons.bolt,
  'water': Icons.water_drop,     'fire': Icons.local_fire_department,
  'wifi': Icons.wifi,            'phone': Icons.smartphone,
  'tv': Icons.tv,                'cleaning': Icons.cleaning_services,
  // Salud
  'heart': Icons.favorite,       'medical': Icons.medical_services,
  'pill': Icons.medication,      'hospital': Icons.local_hospital,
  'spa': Icons.spa,              'muscle': Icons.fitness_center,
  // Ocio
  'movie': Icons.movie,          'music': Icons.music_note,
  'game': Icons.sports_esports,  'sports': Icons.sports_soccer,
  'camera': Icons.photo_camera,  'book': Icons.menu_book,
  // Educación, trabajo, personal
  'school': Icons.school,        'work': Icons.work,
  'build': Icons.build,          'gift': Icons.card_giftcard,
  'paw': Icons.pets,             'child': Icons.child_care,
  'checkroom': Icons.checkroom,  'help': Icons.help_outline,
};

/// Devuelve el `IconData` de la clave, con fallback defensivo a `help_outline`
/// ante claves desconocidas (datos viejos o fuera del catálogo).
IconData iconForKey(String key) => kCategoryIcons[key] ?? Icons.help_outline;
