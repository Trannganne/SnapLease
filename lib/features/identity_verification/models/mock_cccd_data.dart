class MockCccdData {
  final String fullName;
  final String idNumber;
  final String dateOfBirth;
  final String gender;
  final String nationality;
  final String dateOfIssue;
  final String placeOfIssue;
  final String address;

  const MockCccdData({
    required this.fullName,
    required this.idNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.nationality,
    required this.dateOfIssue,
    required this.placeOfIssue,
    required this.address,
  });

  static const MockCccdData defaultMock = MockCccdData(
    fullName: 'NGUYỄN VĂN A',
    idNumber: '079123456789',
    dateOfBirth: '01/01/2003',
    gender: 'Nam',
    nationality: 'Việt Nam',
    dateOfIssue: '01/01/2021',
    placeOfIssue: 'Cục Cảnh sát QLHC về TTXH',
    address: '123 Nguyễn Trãi, Phường 2, Quận 5, TP. Hồ Chí Minh',
  );
}
