import 'category_keywords.dart';

/// Estructura transitoria en memoria que devuelve [parseVoiceExpense] para
/// pasar del texto reconocido por voz al sheet de alta pre-llenado (spec 27).
/// No se persiste ni introduce estado nuevo.
class ParsedVoiceExpense {
  const ParsedVoiceExpense({
    required this.amount,
    required this.description,
    required this.categoryName,
  });

  /// Primer número de la frase, o null si no se detectó monto.
  final double? amount;

  /// Frase transcripta sin el monto ni las palabras "pesos"/`$`.
  final String? description;

  /// Nombre de categoría sugerido por [detectCategoryName], o null si ningún
  /// keyword matchea (el caller decide el fallback).
  final String? categoryName;
}

/// Detecta el primer número de la frase tolerando separador de miles (`.` o
/// espacio) y decimal con coma. Ej.: `3.000` → 3000, `1500,50` → 1500.5.
final RegExp _amountRegExp = RegExp(
  r'\d{1,3}(?:[.  ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?',
);

/// Palabras "peso"/"pesos" y el símbolo `$` que se quitan de la descripción.
final RegExp _moneyWordsRegExp = RegExp(r'\$|\bpesos?\b', caseSensitive: false);

/// Colapsa espacios repetidos a uno solo.
final RegExp _extraSpacesRegExp = RegExp(r'\s+');

/// Quita tildes/diacríticos para que la detección de categoría sea
/// acento-insensible (ej.: `"súper"` matchea el keyword `"super"`). Reusa
/// `categoryKeywords` sin modificarlo (fuera de alcance de la spec 27).
String _stripAccents(String input) {
  const accents = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const plain = 'aaaaaeeeeiiiiooooouuuun';
  final buffer = StringBuffer();
  for (final char in input.split('')) {
    final index = accents.indexOf(char);
    buffer.write(index == -1 ? char : plain[index]);
  }
  return buffer.toString();
}

/// Detección de categoría acento-insensible sobre la frase completa. Reusa la
/// misma lógica y orden de prioridad que [detectCategoryName], pero normaliza
/// acentos antes de comparar (Opción A de la spec 27).
String? _detectCategoryAccentInsensitive(String transcript) {
  final text = _stripAccents(transcript.toLowerCase());
  for (final entry in categoryKeywords.entries) {
    for (final keyword in entry.value) {
      if (text.contains(_stripAccents(keyword))) return entry.key;
    }
  }
  return null;
}

/// Parsea la frase transcripta por voz. Nunca lanza: si algo no matchea, ese
/// campo queda null / vacío y el caller abre el sheet con lo que haya.
ParsedVoiceExpense parseVoiceExpense(String transcript) {
  final match = _amountRegExp.firstMatch(transcript);

  double? amount;
  if (match != null) {
    final raw = match
        .group(0)!
        .replaceAll(RegExp(r'[.  ]'), '')
        .replaceAll(',', '.');
    amount = double.tryParse(raw);
  }

  // Descripción: frase sin el monto ni "pesos"/`$`, con espacios colapsados.
  var description = transcript;
  if (match != null) {
    description = description.replaceRange(match.start, match.end, ' ');
  }
  description = description
      .replaceAll(_moneyWordsRegExp, ' ')
      .replaceAll(_extraSpacesRegExp, ' ')
      .trim();

  return ParsedVoiceExpense(
    amount: amount,
    description: description.isEmpty ? null : description,
    categoryName: _detectCategoryAccentInsensitive(transcript),
  );
}
