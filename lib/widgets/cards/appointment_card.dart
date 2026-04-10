import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(appointment.date);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month),
        title: Text('Dr. ${appointment.doctorName}'),
        subtitle: Text(dateText),
        trailing: appointment.type != null
            ? Chip(label: Text(appointment.type!))
            : null,
      ),
    );
  }
}
