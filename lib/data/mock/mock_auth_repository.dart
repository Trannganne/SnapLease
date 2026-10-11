class MockAuthRepository {
  Future<void> login(String emailOrPhone, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final isEmailOrPhoneValid =
        emailOrPhone == 'test@rentcam.com' || emailOrPhone == '0123456789';
    final isPasswordValid = password == 'password123';

    if (!isEmailOrPhoneValid) {
      throw Exception('EMAIL_NOT_FOUND');
    }

    if (!isPasswordValid) {
      throw Exception('WRONG_PASSWORD');
    }

    // Success
    return;
  }

  Future<void> register(
    String fullName,
    String email,
    String phone,
    String password,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (email.isEmpty || !email.contains('@')) {
      throw Exception('INVALID_EMAIL');
    }

    if (phone.isEmpty || phone.length < 10) {
      throw Exception('INVALID_PHONE');
    }

    if (password.length < 8) {
      throw Exception('WEAK_PASSWORD');
    }

    // Success
    return;
  }
}
