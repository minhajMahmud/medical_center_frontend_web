import 'package:backend_client/backend_client.dart';

class DoctorModel {
  DoctorModel({
    required this.userId,
    required this.name,
    required this.phone,
    this.designation,
    this.qualification,
    this.profilePictureUrl,
  });

  final int? userId;
  final String name;
  final String phone;
  final String? designation;
  final String? qualification;
  final String? profilePictureUrl;

  factory DoctorModel.fromStaffInfo(StaffInfo staff) => DoctorModel(
    userId: staff.userId,
    name: staff.name,
    phone: staff.phone,
    designation: staff.designation,
    qualification: staff.qualification,
    profilePictureUrl: staff.profilePictureUrl,
  );
}
