import 'package:backend_client/backend_client.dart';

class PatientModel {
  PatientModel({
    required this.name,
    required this.email,
    required this.phone,
    this.bloodGroup,
  });

  final String name;
  final String email;
  final String phone;
  final String? bloodGroup;

  factory PatientModel.fromProfile(PatientProfile profile) => PatientModel(
    name: profile.name,
    email: profile.email,
    phone: profile.phone,
    bloodGroup: profile.bloodGroup,
  );
}
