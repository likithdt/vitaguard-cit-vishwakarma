import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:vitalguard/config/app_config.dart';

class AmbulanceMapScreen extends StatefulWidget {
  final String sosId;
  final double patientLat, patientLng;
  final String hospitalName;
  const AmbulanceMapScreen({super.key, required this.sosId,
    required this.patientLat, required this.patientLng,
    this.hospitalName = 'Apollo Hospital'});
  @override State<AmbulanceMapScreen> createState() => _AmbulanceMapScreenState();
}

class _AmbulanceMapScreenState extends State<AmbulanceMapScreen> {
  Timer? _timer;
  Map<String, dynamic>? _status;
  final MapController _mapController = MapController();

  LatLng get _patientPos => LatLng(widget.patientLat, widget.patientLng);
  LatLng get _ambPos {
    if (_status == null) return _patientPos;
    return LatLng(
      (_status!['current_lat'] as num?)?.toDouble() ?? widget.patientLat,
      (_status!['current_lng'] as num?)?.toDouble() ?? widget.patientLng);
  }
  LatLng get _hospPos {
    if (_status == null) return LatLng(12.9252, 77.6011);
    return LatLng(
      (_status!['destination_lat'] as num?)?.toDouble() ?? 12.9252,
      (_status!['destination_lng'] as num?)?.toDouble() ?? 77.6011);
  }

  bool get _arrived => _status?['status'] == 'arrived';
  double get _progress {
    final step  = (_status?['step']        ?? 0) as int;
    final total = (_status?['total_steps'] ?? 20) as int;
    return total > 0 ? step / total : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/sos/ambulance/${widget.sosId}'),
        headers: {'Authorization': 'Bearer LKT01'});
      if (r.statusCode == 200) {
        setState(() => _status = jsonDecode(r.body));
        if (_arrived) _timer?.cancel();
      }
    } catch (_) {}
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final eta = _status?['eta_minutes'] ?? '--';
    final hospital = _status?['hospital'] ?? widget.hospitalName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Live Ambulance Tracking',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true),
      body: Column(children: [

        // Live map
        Expanded(flex: 6,
          child: ClipRRect(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _patientPos,
                initialZoom: 13.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vitalguard.app'),

                // Route polyline: hospital → ambulance → patient
                PolylineLayer(polylines: [
                  Polyline(points: [_hospPos, _ambPos, _patientPos],
                    strokeWidth: 4, color: const Color(0xFFB6171E).withOpacity(0.5),
                    isDotted: true),
                ]),

                MarkerLayer(markers: [
                  // Patient home marker
                  Marker(point: _patientPos, width: 56, height: 56,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB6171E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
                            blurRadius: 8, offset: const Offset(0, 3))]),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20)),
                    ])),

                  // Hospital marker
                  Marker(point: _hospPos, width: 56, height: 56,
                    child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16a34a),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                          blurRadius: 8, offset: const Offset(0, 3))]),
                      child: const Icon(Icons.local_hospital_rounded,
                        color: Colors.white, size: 20))),

                  // Ambulance marker (moving)
                  Marker(point: _ambPos, width: 56, height: 56,
                    child: Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4))]),
                      child: const Text('🚑', style: TextStyle(fontSize: 20)))),
                ]),
              ],
            ),
          )),

        // Status card
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(children: [
            // ETA
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ESTIMATED ARRIVAL', style: TextStyle(fontSize: 10,
                  color: Colors.grey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic, children: [
                  Text(_arrived ? '0' : '$eta',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1C1C))),
                  const SizedBox(width: 6),
                  Text(_arrived ? 'ARRIVED!' : 'minutes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _arrived ? const Color(0xFF16a34a) : Colors.grey)),
                ]),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _arrived ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(25)),
                child: Text(_arrived ? '✓ On Scene' : '🚑 On Route',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _arrived ? const Color(0xFF16a34a) : const Color(0xFF2563EB)))),
            ]),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress,
                backgroundColor: const Color(0xFFBFDBFE),
                color: _arrived ? const Color(0xFF16a34a) : const Color(0xFF2563EB),
                minHeight: 8)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(hospital, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('${(_progress * 100).toStringAsFixed(0)}% complete',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB))),
            ]),
            const SizedBox(height: 14),
            // Legend
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _LegendItem(Colors.red, 'Your Home'),
              _LegendItem(const Color(0xFF2563EB), 'Ambulance'),
              _LegendItem(const Color(0xFF16a34a), 'Hospital'),
            ]),
          ])),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color; final String label;
  const _LegendItem(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
  ]);
}
