class AuthValidation {
  static const passwordRule =
      'Mật khẩu phải có 8–128 ký tự, gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.';

  static String? emailError(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Vui lòng nhập email đã đăng ký.';
    if (email.length > 255 ||
        !RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(email)) {
      return 'Vui lòng nhập địa chỉ email hợp lệ.';
    }
    return null;
  }

  static String? passwordError(String password) {
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (password.length < 8 || password.length > 128) {
      return 'Mật khẩu từ 8 đến 128 ký tự';
    }
    // Match the backend's UTF-16 char.IsUpper/Lower/Digit checks.
    final units = password.codeUnits.map(String.fromCharCode).toList();
    bool has(String pattern) =>
        units.any((c) => RegExp(pattern, unicode: true).hasMatch(c));
    if (!has(r'\p{Lu}') ||
        !has(r'\p{Ll}') ||
        !has(r'\p{Nd}') ||
        !has(r'[^\p{L}\p{Nd}\s]')) {
      return 'Mật khẩu phải gồm chữ hoa, thường, số và ký tự đặc biệt';
    }
    return null;
  }
}
