import 'package:flutter/material.dart';

import 'appointment.dart';

class AppointmentSummaryCard extends StatelessWidget {
  const AppointmentSummaryCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const ink = Color(0xFF14345C);
    final statusColor = switch (appointment.status) {
      'confirmed' || 'completed' => const Color(0xFF16865C),
      'cancelled' || 'no_show' => const Color(0xFFC34B54),
      'in_progress' => const Color(0xFF7851C2),
      _ => blue,
    };
    final label = appointment.status.replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE3EBF8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF3FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientName,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            appointment.department,
                            style: const TextStyle(
                              color: Color(0xFF657D99),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: blue,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FD),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: blue,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appointment.time,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (appointment.tokenNumber != null)
                      Text(
                        'Token ${appointment.tokenNumber}',
                        style: const TextStyle(
                          color: blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label.isEmpty
                            ? 'Unknown'
                            : '${label[0].toUpperCase()}${label.substring(1)}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFEDF2FA)),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 15,
                      color: Color(0xFF657D99),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        appointment.doctorName,
                        style: const TextStyle(
                          color: Color(0xFF657D99),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Text(
                      'View details',
                      style: TextStyle(
                        color: blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (appointment.number != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      appointment.number!,
                      style: const TextStyle(
                        color: Color(0xFF657D99),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
