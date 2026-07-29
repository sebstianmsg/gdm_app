/// Validadores compartidos por los formularios de auth (login, signup, forgot,
/// reset). Devuelven `null` si el valor es válido o un mensaje de error legible
/// si no lo es — la firma que espera `TextFormField.validator`.
class AuthValidators {
  AuthValidators._();

  /// Largo mínimo de contraseña exigido por Supabase Auth por defecto.
  static const int minPasswordLength = 6;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
  );

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresá tu nombre.';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresá tu email.';
    if (!_emailRegex.hasMatch(v)) return 'Ingresá un email válido.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresá una contraseña.';
    if (v.length < minPasswordLength) {
      return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
    }
    return null;
  }

  /// Valida que `value` coincida con la contraseña original `original`.
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Repetí la contraseña.';
    if (value != original) return 'Las contraseñas no coinciden.';
    return null;
  }
}
