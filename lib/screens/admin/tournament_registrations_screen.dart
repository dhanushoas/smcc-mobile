import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class TournamentRegistrationsScreen extends StatefulWidget {
  const TournamentRegistrationsScreen({Key? key}) : super(key: key);

  @override
  _TournamentRegistrationsScreenState createState() => _TournamentRegistrationsScreenState();
}

class _TournamentRegistrationsScreenState extends State<TournamentRegistrationsScreen> {
  List<dynamic> _registrations = [];
  Map<String, dynamic> _stats = {'total': 0, 'approved': 0, 'rejected': 0};
  bool _loading = true;
  String? _actionLoading;
  bool _schedulingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRegistrations();
  }

  Future<void> _fetchRegistrations() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getRegistrations();
      if (mounted) {
        setState(() {
          _registrations = res['data'] ?? [];
          _stats = res['stats'] ?? {'total': 0, 'approved': 0, 'rejected': 0};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load registrations.')));
      }
    }
  }

  Future<void> _handleAction(String id, String action, String currentStatus) async {
    if (action == 'approve' && currentStatus != 'approved') {
       if ((_stats['approved'] ?? 0) >= 32) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament pool limit (32 teams) reached.')));
          return;
       }
    }

    setState(() => _actionLoading = id);
    try {
      if (action == 'delete') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Registration?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm != true) {
          setState(() => _actionLoading = null);
          return;
        }
        await ApiService.deleteRegistration(id);
      } else {
        await ApiService.updateRegistrationAction(id, action);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration $action successful!')));
      await _fetchRegistrations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actionLoading = null);
    }
  }

  Future<void> _handleGenerateSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate Schedule?'),
        content: const Text('This will clear existing tournament matches and generate a new 32-team knockout schedule. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('PROCEED', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _schedulingLoading = true);
    try {
      await ApiService.generateRegistrationSchedule();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament schedule generated successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _schedulingLoading = false);
    }
  }

  void _showViewModal(Map<String, dynamic> reg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registration Details', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _detailRow('Team Name', (reg['team_name'] ?? '').toUpperCase()),
            _detailRow('Captain', reg['captain_name'] ?? ''),
            _detailRow('Mobile', reg['mobile'] ?? ''),
            _detailRow('Village / Area', reg['village'] ?? ''),
            _detailRow('Status', (reg['status'] ?? '').toString().toUpperCase(), isStatus: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Dismiss', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false}) {
    Color? valColor;
    if (isStatus) {
      valColor = value == 'APPROVED' ? Colors.green : (value == 'REJECTED' ? Colors.red : Colors.orange);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: valColor ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('TEAM REGISTRATIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRegistrations),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRegistrations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsHeader(),
                  if (_stats['approved'] >= 32) _buildScheduleCard(),
                  const SizedBox(height: 16),
                  _buildRegistrationsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          child: Text(
            '${_stats['approved']} / 32 TOURNAMENT POOL',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statCard('Total', _stats['total'], Colors.blueGrey),
            const SizedBox(width: 8),
            _statCard('Approved', _stats['approved'], Colors.green),
            const SizedBox(width: 8),
            _statCard('Rejected', _stats['rejected'], Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, dynamic count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
        child: Column(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('$count', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade100)),
      child: Column(
        children: [
          Text('TOURNAMENT READY!', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
          const SizedBox(height: 8),
          Text('Exactly 32 teams have been approved. You can now generate the knockout schedule.',
              textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _schedulingLoading ? null : _handleGenerateSchedule,
              icon: _schedulingLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.account_tree),
              label: Text('GENERATE SCHEDULE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationsList() {
    if (_registrations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text('No registrations found.', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return Column(
      children: _registrations.map((reg) {
        final id = (reg['id'] ?? reg['_id']).toString();
        final status = reg['status'] ?? 'pending';
        Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((reg['team_name'] ?? '').toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blueAccent)),
                        const SizedBox(height: 4),
                        Text('CAPT: ${(reg['captain_name'] ?? '').toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(reg['mobile'] ?? '', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
                  Text((reg['village'] ?? '').toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blueGrey, size: 22),
                    onPressed: () => _showViewModal(reg),
                    tooltip: 'View',
                  ),
                  if (status != 'approved')
                    IconButton(
                      icon: _actionLoading == id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.green, size: 22),
                      onPressed: _actionLoading != null ? null : () => _handleAction(id, 'approve', status),
                      tooltip: 'Approve',
                    ),
                  if (status == 'pending')
                    IconButton(
                      icon: _actionLoading == id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cancel, color: Colors.orange, size: 22),
                      onPressed: _actionLoading != null ? null : () => _handleAction(id, 'reject', status),
                      tooltip: 'Reject',
                    ),
                  IconButton(
                    icon: _actionLoading == id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: _actionLoading != null ? null : () => _handleAction(id, 'delete', status),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
