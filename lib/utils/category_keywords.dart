/// Detección opcional de categoría por keywords al tipear la descripción del
/// gasto. Portado del prototipo `Ref/gastos-del-mes.html` (`detectCategory`);
/// el backend de producción NO tiene esta lógica — es puramente client-side,
/// solo para preseleccionar el dropdown de categoría en el form de alta.
/// Case-insensitive, primer match gana, orden de prioridad como abajo.
const Map<String, List<String>> categoryKeywords = {
  'Almacén': [
    'super', 'supermercado', 'verduler', 'carnicer', 'almacen', 'feria',
    'panader', 'fiambr', 'despensa',
  ],
  'Comida': [
    'delivery', 'restaurant', 'resto', 'comida', 'cafe', 'café', 'bar',
    'pizza', 'hamburguesa', 'almuerzo', 'cena', 'pedidos ya', 'rappi',
  ],
  'Transporte': [
    'nafta', 'combustible', 'uber', 'taxi', 'peaje', 'estacionamiento',
    'omnibus', 'ómnibus', 'boleto', 'auto', 'service', 'mecanico', 'mecánico',
  ],
  'Servicios': [
    'luz', 'ute', 'agua', 'ose', 'gas', 'internet', 'antel', 'celular',
    'netflix', 'spotify', 'suscripcion', 'suscripción', 'alquiler',
  ],
  'Salud': [
    'farmacia', 'medico', 'médico', 'mutualista', 'mucam', 'dentista',
    'psicolog', 'remedio', 'medicamento',
  ],
  'Ocio': [
    'cine', 'entretenimiento', 'salida', 'juego', 'steam', 'regalo', 'ropa',
    'shopping',
  ],
};

/// Devuelve el nombre de categoría sugerido para [description], o null si
/// ningún keyword matchea (el caller decide el fallback, típicamente "Otros").
String? detectCategoryName(String description) {
  final text = description.toLowerCase();
  for (final entry in categoryKeywords.entries) {
    for (final keyword in entry.value) {
      if (text.contains(keyword)) return entry.key;
    }
  }
  return null;
}
