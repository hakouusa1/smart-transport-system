import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../theme_notifier.dart';
import '../l10n/app_localizations.dart';
import '../widgets/bus_loading_indicator.dart';
import '../widgets/notif_listener.dart';
import 'main_screen.dart';

/// Shown when a user's active plan allows fewer buses than they currently own.
/// The user must delete excess buses before they can access the main app.
class ReduceBusesScreen extends StatefulWidget {
  final int planLimit;
  final String planName;

  const ReduceBusesScreen({
    super.key,
    required this.planLimit,
    required this.planName,
  });

  @override
  State<ReduceBusesScreen> createState() => _ReduceBusesScreenState();
}

class _ReduceBusesScreenState extends State<ReduceBusesScreen> {
  final _busService = BusService();
  List<Bus> _buses = [];
  bool _isLoading = true;
  StreamSubscription<List<Bus>>? _busSub;

  @override
  void initState() {
    super.initState();
    final cached = BusService().latestBuses;
    if (cached != null) {
      _buses = cached;
      _isLoading = false;
    }
    _busSub = _busService.getBuses().listen(
      (buses) {
        if (mounted) setState(() { _buses = buses; _isLoading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }

  int get _excess => (_buses.length - widget.planLimit).clamp(0, 9999);
  bool get _compliant => _buses.length <= widget.planLimit;

  void _continueToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotifListener(child: MainScreen())),
      (route) => false,
    );
  }

  Future<void> _confirmDelete(Bus bus) async {
    final l10n = AppLocalizations.of(context);
    final busName = bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}';

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: context.appRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.delete_forever_rounded, color: context.appRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.deleteBusConfirmTitle(busName),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        content: Text(l10n.deleteBusWarning,
            style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.appRed),
            child: Text(l10n.deleteLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _busService.deleteBus(bus.busId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).errorFmt(e.toString())),
            backgroundColor: context.appRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.all(16),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: context.appBg,
          body: _isLoading
              ? Center(child: BusLoadingIndicator(color: context.appPurple, strokeWidth: 2.5))
              : Column(children: [
                  _buildHeader(context, l10n),
                  Expanded(child: _buildBusList(context, l10n)),
                ]),
          bottomNavigationBar: _compliant ? _buildContinueButton(context, l10n) : null,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final isCompliant = _compliant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompliant
              ? [context.appGreen, context.appGreen.withValues(alpha: 0.75)]
              : [const Color(0xFFD32F2F), const Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCompliant ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: Colors.white, size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isCompliant
              ? l10n.reduceBusesCompleted
              : l10n.reduceBusesTitle(widget.planName, widget.planLimit),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        if (!isCompliant) ...[
          const SizedBox(height: 8),
          Text(
            l10n.reduceBusesSubtitle(_excess),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isCompliant
                ? '${_buses.length} / ${widget.planLimit}'
                : l10n.busesToRemoveFmt(_excess),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _buildBusList(BuildContext context, AppLocalizations l10n) {
    if (_buses.isEmpty) {
      return Center(
        child: Text(l10n.noBuses,
            style: TextStyle(color: context.appSub, fontSize: 15)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _buses.length,
      itemBuilder: (ctx, i) => _BusRemoveCard(
        bus: _buses[i],
        isWithinLimit: i < widget.planLimit,
        onDelete: () => _confirmDelete(_buses[i]),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _continueToApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(l10n.continueToApp,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _BusRemoveCard extends StatelessWidget {
  final Bus bus;
  final bool isWithinLimit;
  final VoidCallback onDelete;

  const _BusRemoveCard({
    required this.bus,
    required this.isWithinLimit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busName = bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}';
    final statusColor = bus.validationStatus == 'approved'
        ? context.appGreen
        : bus.validationStatus == 'pending'
            ? context.appOrange
            : context.appRed;
    final statusLabel = bus.validationStatus == 'approved'
        ? l10n.validationApproved
        : bus.validationStatus == 'pending'
            ? l10n.validationPending
            : l10n.validationRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWithinLimit
              ? context.appGreen.withValues(alpha: 0.3)
              : context.appRed.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isWithinLimit
                ? context.appGreen.withValues(alpha: 0.1)
                : context.appRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.directions_bus_rounded,
            color: isWithinLimit ? context.appGreen : context.appRed,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(busName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appDark)),
            const SizedBox(height: 2),
            Text('N° ${bus.busNumber}',
                style: TextStyle(fontSize: 12, color: context.appSub)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(statusLabel,
                  style: TextStyle(fontSize: 11, color: statusColor)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        if (isWithinLimit)
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: context.appGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.check_rounded, color: context.appGreen, size: 18),
          )
        else
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.appRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.delete_outline, color: context.appRed, size: 15),
                const SizedBox(width: 4),
                Text(l10n.deleteLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appRed)),
              ]),
            ),
          ),
      ]),
    );
  }
}
