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

/// Diccionario **keyword → clave de ícono** (spec 13). Curado en español para
/// gastos personales. Las keywords ya están normalizadas (minúsculas, sin
/// acentos) para poder compararlas contra el nombre normalizado. El match es
/// por **palabra contenida** en el nombre de la categoría (ver [suggestIconForName]).
///
/// Las claves de valor deben existir en [kCategoryIcons]; si no, se ignora la
/// sugerencia y se cae en `help`.
const kCategoryKeywordIcons = <String, String>{
  // Transporte
  'nafta': 'gas', 'combustible': 'gas', 'gas': 'gas', 'ypf': 'gas', 'shell': 'gas',
  'bondi': 'bus', 'colectivo': 'bus', 'micro': 'bus', 'omnibus': 'bus', 'sube': 'bus',
  'subte': 'subway', 'metro': 'subway',
  'tren': 'train',
  'taxi': 'taxi', 'remis': 'taxi', 'uber': 'taxi', 'cabify': 'taxi', 'didi': 'taxi',
  'auto': 'car', 'cochera': 'parking', 'estacionamiento': 'parking', 'peaje': 'car',
  'bici': 'bike', 'bicicleta': 'bike',
  // Comida y bebida
  'super': 'basket', 'supermercado': 'basket', 'almacen': 'basket', 'mercado': 'basket',
  'compras': 'cart', 'kiosco': 'store', 'verduleria': 'grocery', 'carniceria': 'grocery',
  'panaderia': 'cake', 'comida': 'fork', 'restaurante': 'fork', 'resto': 'fork',
  'almuerzo': 'fork', 'cena': 'fork', 'delivery': 'fastfood', 'pedidosya': 'fastfood',
  'rappi': 'fastfood', 'hamburguesa': 'fastfood', 'pizza': 'pizza', 'cafe': 'coffee',
  'bar': 'bar', 'cerveza': 'bar', 'trago': 'bar', 'helado': 'icecream',
  // Salud
  'farmacia': 'pill', 'remedio': 'pill', 'remedios': 'pill', 'medicamento': 'pill',
  'medico': 'medical', 'doctor': 'medical', 'salud': 'heart', 'obra social': 'heart',
  'prepaga': 'heart', 'hospital': 'hospital', 'clinica': 'hospital', 'dentista': 'medical',
  'gimnasio': 'muscle', 'gym': 'muscle', 'spa': 'spa',
  // Hogar y servicios
  'alquiler': 'home', 'expensas': 'home', 'hogar': 'home', 'casa': 'home',
  'luz': 'bolt', 'electricidad': 'bolt', 'edenor': 'bolt', 'edesur': 'bolt',
  'agua': 'water', 'aysa': 'water', 'gas natural': 'fire',
  'internet': 'wifi', 'wifi': 'wifi', 'fibertel': 'wifi',
  'telefono': 'phone', 'celular': 'phone', 'movistar': 'phone', 'personal': 'phone',
  'claro': 'phone', 'cable': 'tv', 'limpieza': 'cleaning',
  // Ocio
  'cine': 'movie', 'pelicula': 'movie', 'netflix': 'tv', 'spotify': 'music',
  'musica': 'music', 'juego': 'game', 'juegos': 'game', 'videojuego': 'game',
  'futbol': 'sports', 'deporte': 'sports', 'fotografia': 'camera',
  'libro': 'book', 'libros': 'book', 'libreria': 'book',
  // Educación, trabajo, personal
  'escuela': 'school', 'colegio': 'school', 'facultad': 'school', 'curso': 'school',
  'educacion': 'school', 'trabajo': 'work', 'oficina': 'work',
  'ferreteria': 'build', 'herramientas': 'build', 'regalo': 'gift', 'regalos': 'gift',
  'mascota': 'paw', 'perro': 'paw', 'gato': 'paw', 'veterinaria': 'paw',
  'bebe': 'child', 'ninos': 'child', 'ropa': 'checkroom', 'indumentaria': 'checkroom',
  // Dinero
  'banco': 'bank', 'tarjeta': 'card', 'ahorro': 'savings', 'ahorros': 'savings',
  'billetera': 'wallet',
};

/// Normaliza un texto para comparar keywords: minúsculas y sin acentos/diéresis.
/// No es exhaustivo: cubre las vocales acentuadas y la `ñ` habituales en español.
String normalizeForIcon(String input) {
  final lower = input.toLowerCase().trim();
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  };
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(accents[ch] ?? ch);
  }
  return buffer.toString();
}

/// Sugiere una clave de ícono a partir del [name] de una categoría, usando
/// [kCategoryKeywordIcons] con match por **palabra contenida** (tras normalizar).
///
/// Devuelve la clave sugerida (garantizada dentro de [kCategoryIcons]) o `null`
/// si no hay match. Las keywords de una sola palabra matchean contra las
/// palabras del nombre; las keywords con espacios (ej. `obra social`) matchean
/// como subcadena del nombre completo.
String? suggestIconForName(String name) {
  final normalized = normalizeForIcon(name);
  if (normalized.isEmpty) return null;
  final words = normalized.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();
  for (final entry in kCategoryKeywordIcons.entries) {
    final keyword = entry.key;
    final matches = keyword.contains(' ')
        ? normalized.contains(keyword)
        : words.contains(keyword);
    if (matches && kCategoryIcons.containsKey(entry.value)) {
      return entry.value;
    }
  }
  return null;
}

/// Resuelve el ícono a **mostrar** para una categoría, aplicando el fallback
/// del spec 13 sin tocar la DB: si [icon] es `help` (categoría vieja o sin
/// ícono elegido) y el [name] matchea el diccionario, se usa la clave sugerida.
/// En cualquier otro caso se respeta [icon] (el manual siempre gana).
String resolveCategoryIcon(String icon, String name) {
  if (icon == 'help') {
    return suggestIconForName(name) ?? 'help';
  }
  return icon;
}
