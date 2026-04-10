import 'package:flutter/material.dart';
import 'package:vitalguard/models/vitals_model.dart';

/// Medication Reminders — Phase 1 requirement
/// Triggered based on health data:
///   • High glucose → "Take insulin"
///   • Low SpO2    → "Use inhaler / oxygen"
///   • High BP     → "Take BP medication"
///   • High HR     → "Take beta-blocker / rest"
class MedicationScreen extends StatelessWidget {
  final VitalsModel? vitals;
  const MedicationScreen({super.key, this.vitals});

  List<_MedReminder> get _reminders {
    final reminders = <_MedReminder>[];
    if (vitals == null) return reminders;

    if (vitals!.glucose > 180) {
      reminders.add(_MedReminder(
        icon: Icons.water_drop_rounded, color: const Color(0xFFFF9F43),
        title: 'High Blood Sugar Detected',
        value: '${vitals!.glucose.toStringAsFixed(0)} mg/dL',
        message: 'Your glucose is elevated. Please take your insulin dose as prescribed.',
        urgency: 'High', action: 'Take Insulin Now'));
    }
    if (vitals!.glucose < 70) {
      reminders.add(_MedReminder(
        icon: Icons.local_drink_rounded, color: const Color(0xFF2563EB),
        title: 'Low Blood Sugar Detected',
        value: '${vitals!.glucose.toStringAsFixed(0)} mg/dL',
        message: 'Your glucose is low. Drink juice or eat glucose tablets immediately.',
        urgency: 'Critical', action: 'Eat/Drink Sugar Now'));
    }
    if (vitals!.spo2 < 92) {
      reminders.add(_MedReminder(
        icon: Icons.air_rounded, color: const Color(0xFF006578),
        title: 'Low Oxygen Saturation',
        value: '${vitals!.spo2.toStringAsFixed(1)}%',
        message: 'Your SpO2 is below safe levels. Use your inhaler or supplemental oxygen.',
        urgency: 'Critical', action: 'Use Inhaler / O2'));
    }
    if (vitals!.bpSystolic > 140) {
      reminders.add(_MedReminder(
        icon: Icons.favorite_rounded, color: const Color(0xFFB6171E),
        title: 'High Blood Pressure',
        value: '${vitals!.bpSystolic.toStringAsFixed(0)}/${vitals!.bpDiastolic.toStringAsFixed(0)} mmHg',
        message: 'BP is elevated. Take your antihypertensive medication and rest.',
        urgency: 'High', action: 'Take BP Medication'));
    }
    if (vitals!.heartRate > 110) {
      reminders.add(_MedReminder(
        icon: Icons.monitor_heart_rounded, color: const Color(0xFFB6171E),
        title: 'Elevated Heart Rate',
        value: '${vitals!.heartRate.toStringAsFixed(0)} bpm',
        message: 'Heart rate is high. Rest immediately. Take prescribed beta-blocker if advised.',
        urgency: 'High', action: 'Rest & Take Medication'));
    }
    return reminders;
  }

  static const _schedule = [
    {'time': '08:00 AM', 'med': 'Metformin 500mg', 'type': 'Diabetes', 'color': Color(0xFFFF9F43)},
    {'time': '12:00 PM', 'med': 'Amlodipine 5mg',  'type': 'BP',       'color': Color(0xFFB6171E)},
    {'time': '06:00 PM', 'med': 'Aspirin 75mg',     'type': 'Heart',    'color': Color(0xFF006578)},
    {'time': '09:00 PM', 'med': 'Atorvastatin 10mg','type': 'Cholesterol','color': Color(0xFF9B59B6)},
  ];

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Medication Reminders',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(20), children: [

        // ── Smart Reminders (based on vitals) ──────────────────
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB6171E), size: 18),
          const SizedBox(width: 8),
          const Text('Smart Reminders', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFFDAD6),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Based on your vitals',
              style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 14),

        if (reminders.isEmpty)
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16a34a), size: 40),
              const SizedBox(height: 10),
              const Text('All vitals normal', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15)),
              Text('No medication reminders at this time',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]))
        else
          ...reminders.map((r) => _ReminderCard(r)),

        const SizedBox(height: 24),

        // ── Daily Schedule ─────────────────────────────────────
        const Text('Daily Schedule', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
        const SizedBox(height: 4),
        Text('Your prescribed medications for today',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 14),
        ..._schedule.map((s) => _ScheduleRow(s)),
        const SizedBox(height: 20),

        // ── Tips card ─────────────────────────────────────────
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1A1C1C),
            borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text('Health Tips', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            ...[
              'Take medications at the same time every day',
              'Never skip doses — set phone alarms as backup',
              'Store medications in a cool, dry place',
              'Report side effects to your doctor immediately',
            ].map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(color: Colors.white54)),
                Expanded(child: Text(tip, style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4))),
              ]))),
          ])),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _MedReminder {
  final IconData icon; final Color color;
  final String title, value, message, urgency, action;
  _MedReminder({required this.icon, required this.color, required this.title,
    required this.value, required this.message, required this.urgency, required this.action});
}

class _ReminderCard extends StatelessWidget {
  final _MedReminder r;
  const _ReminderCard(this.r);
  @override
  Widget build(BuildContext context) {
    final isCritical = r.urgency == 'Critical';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFDAD6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? const Color(0xFFB6171E).withOpacity(0.4) : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: r.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(r.icon, color: r.color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Row(children: [
              Text(r.value, style: TextStyle(fontSize: 13,
                color: r.color, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFB6171E) : const Color(0xFFFF9F43),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(r.urgency, style: const TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.w800))),
            ]),
          ])),
        ]),
        const SizedBox(height: 12),
        Text(r.message, style: TextStyle(fontSize: 12,
          color: Colors.grey[700], height: 1.5)),
        const SizedBox(height: 12),
        GestureDetector(
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(r.action, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))))),
      ]));
  }
}

class _ScheduleRow extends StatefulWidget {
  final Map s;
  const _ScheduleRow(this.s);
  @override State<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<_ScheduleRow> {
  bool _taken = false;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _taken ? const Color(0xFFF0FDF4) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _taken ? const Color(0xFF16a34a).withOpacity(0.3) : Colors.grey.shade100),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
    child: Row(children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(
          color: (widget.s['color'] as Color).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.s['time']!.split(' ')[0],
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
              color: widget.s['color'] as Color)),
          Text(widget.s['time']!.split(' ')[1],
            style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ])),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.s['med']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: _taken ? Colors.grey : const Color(0xFF1A1C1C),
          decoration: _taken ? TextDecoration.lineThrough : null)),
        Text(widget.s['type']!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ])),
      GestureDetector(
        onTap: () => setState(() => _taken = !_taken),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _taken ? const Color(0xFF16a34a) : Colors.grey.shade100,
            shape: BoxShape.circle),
          child: Icon(_taken ? Icons.check_rounded : Icons.check_rounded,
            color: _taken ? Colors.white : Colors.grey[300], size: 18))),
    ]));
}
