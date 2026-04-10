import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalguard/config/app_config.dart';
import 'package:vitalguard/screens/dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid, email;
  const ProfileSetupScreen({super.key, required this.uid, required this.email});
  @override State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age  = TextEditingController();
  final _ecName = TextEditingController();
  final _ecPhone = TextEditingController();
  final _ecRel = TextEditingController();
  final _drName = TextEditingController();
  final _drPhone = TextEditingController();
  final _drHosp = TextEditingController();
  String _blood = 'O+';
  bool _loading = false;
  static const _bloods = ['A+','A-','B+','B-','AB+','AB-','O+','O-'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/auth/profile'),
        headers: {'Authorization': 'Bearer ${widget.uid}',
                  'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': widget.uid, 'email': widget.email,
          'full_name': _name.text.trim(), 'blood_group': _blood,
          'age': int.tryParse(_age.text) ?? 0,
          'emergency_contact_name': _ecName.text.trim(),
          'emergency_contact_phone': _ecPhone.text.trim(),
          'emergency_contact_relation': _ecRel.text.trim(),
          'doctor_name': _drName.text.trim().isNotEmpty ? _drName.text.trim() : null,
          'doctor_phone': _drPhone.text.trim().isNotEmpty ? _drPhone.text.trim() : null,
          'doctor_hospital': _drHosp.text.trim().isNotEmpty ? _drHosp.text.trim() : null,
        }));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', widget.uid);
      await prefs.setString('user_name', _name.text.trim());
      if (mounted) Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => DashboardScreen(userId: widget.uid)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: const Color(0xFFBA1A1A)));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(child: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20,16,20,20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Color(0xFF1A1C1C)))),
          const SizedBox(height: 16),
          const Text('Complete Profile', style: TextStyle(fontSize: 26,
            fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
          const Text('Step 2 of 2 — Emergency & Doctor details',
            style: TextStyle(fontSize: 13, color: Color(0xFF5B403D))),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(value: 1.0,
              backgroundColor: Color(0xFFE8E8E8), color: Color(0xFFB6171E), minHeight: 5)),
        ])),
      Expanded(child: Form(key: _formKey, child: ListView(
        padding: const EdgeInsets.all(20), children: [
        _Section(Icons.person_rounded, 'Personal Information', null, null),
        const SizedBox(height: 12),
        _F('Full Name *', _name, Icons.badge_outlined, required: true),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _F('Age *', _age, Icons.cake_outlined,
            required: true, kb: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: Container(
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: DropdownButtonFormField<String>(value: _blood,
              decoration: const InputDecoration(labelText: 'Blood Group *',
                prefixIcon: Icon(Icons.bloodtype_outlined, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: _bloods.map((g) => DropdownMenuItem(value: g,
                child: Text(g, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
              onChanged: (v) => setState(() => _blood = v!)))),
        ]),
        const SizedBox(height: 20),
        _Section(Icons.family_restroom_rounded, 'Emergency Contact',
          'Called automatically when SOS triggers', const Color(0xFFFFDAD6)),
        const SizedBox(height: 12),
        _F('Contact Name *', _ecName, Icons.person_outlined, required: true),
        const SizedBox(height: 10),
        _F('Relationship *', _ecRel, Icons.people_outline, required: true, hint: 'e.g. Spouse, Parent'),
        const SizedBox(height: 10),
        _F('Phone Number *', _ecPhone, Icons.phone_outlined, required: true, kb: TextInputType.phone),
        const SizedBox(height: 20),
        _Section(Icons.local_hospital_outlined, 'Doctor Details',
          'Shared with emergency responders', const Color(0xFFE6F1FB)),
        const SizedBox(height: 12),
        _F('Doctor Name *', _drName, Icons.medical_services_outlined, required: true),
        const SizedBox(height: 10),
        _F('Doctor Phone *', _drPhone, Icons.phone_outlined, required: true, kb: TextInputType.phone),
        const SizedBox(height: 10),
        _F('Hospital / Clinic', _drHosp, Icons.location_city_outlined),
        const SizedBox(height: 28),
        GestureDetector(onTap: _loading ? null : _save,
          child: Container(height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.35),
                blurRadius: 14, offset: const Offset(0, 5))]),
            child: Center(child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Save & Open Dashboard', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800))))),
        const SizedBox(height: 20),
      ]))),
    ])));
}

class _Section extends StatelessWidget {
  final IconData icon; final String title; final String? sub; final Color? bg;
  const _Section(this.icon, this.title, this.sub, this.bg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg ?? const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF1A1C1C)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14,
          fontWeight: FontWeight.w800, color: Color(0xFF1A1C1C))),
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    ]));
}

class _F extends StatelessWidget {
  final String label; final TextEditingController ctrl; final IconData icon;
  final bool required; final String? hint; final TextInputType kb;
  const _F(this.label, this.ctrl, this.icon, {this.required=false,
    this.hint, this.kb = TextInputType.text});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: TextFormField(controller: ctrl, keyboardType: kb,
      validator: required ? (v) => v!.trim().isEmpty ? 'Required' : null : null,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label, hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))));
}
