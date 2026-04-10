import 'package:flutter/material.dart';

import '../../models/doctor.dart';

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor});

  final DoctorModel doctor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: doctor.profilePictureUrl != null
              ? NetworkImage(doctor.profilePictureUrl!)
              : null,
          child: doctor.profilePictureUrl == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(doctor.name),
        subtitle: Text('${doctor.designation ?? 'Doctor'} • ${doctor.phone}'),
        trailing: doctor.qualification != null
            ? Text(
                doctor.qualification!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
      ),
    );
  }
}
