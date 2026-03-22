import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../providers/send_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/config/app_secrets.dart';

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final _destController = TextEditingController();
  final _recipientController = TextEditingController();

  static const _mapboxToken = AppSecrets.mapboxToken;

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _destController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  bool get _canSearch => _destController.text.trim().isNotEmpty;

  void _onDestinationChanged(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _fetchSuggestions(q),
    );
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json'
        '?access_token=$_mapboxToken&language=fr&country=fr&limit=6',
      );
      final res = await http.get(url);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List? ?? [];
        setState(() {
          _suggestions = features
              .map<Map<String, dynamic>>((f) => {
                    'label': f['place_name'] as String,
                    'lng': (f['geometry']['coordinates'][0] as num).toDouble(),
                    'lat': (f['geometry']['coordinates'][1] as num).toDouble(),
                  })
              .toList();
          _showSuggestions = _suggestions.isNotEmpty;
          _isLoadingSuggestions = false;
        });
      } else {
        setState(() => _isLoadingSuggestions = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _destController.text = suggestion['label'] as String;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _search() async {
    ref.read(sendRequestProvider.notifier).setDestination(
          destination: _destController.text.trim(),
          recipientName: _recipientController.text.trim().isEmpty
              ? null
              : _recipientController.text.trim(),
        );
    final user = ref.read(authProvider);
    if (user == null) return;
    context.push('/client/searching');
    await ref.read(sendRequestProvider.notifier).search(user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destination')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepBar(step: 3, total: 4),
              const SizedBox(height: 28),
              Text('Où livrer ?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Indiquez la destination finale',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _destController,
                decoration: const InputDecoration(
                  labelText: 'Adresse de destination',
                  prefixIcon: Icon(Icons.location_on_rounded,
                      color: AppColors.accent, size: 20),
                  hintText: 'Ville, code postal ou adresse…',
                ),
                onChanged: _onDestinationChanged,
                textInputAction: TextInputAction.next,
              ),
              if (_isLoadingSuggestions) ...[
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ] else if (_showSuggestions) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.of(context).cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.of(context).border),
                  ),
                  child: Column(
                    children: _suggestions.map((s) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, size: 18),
                        title: Text(
                          s['label'] as String,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSuggestion(s),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  labelText: 'Destinataire (optionnel)',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _canSearch ? _search : null,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Rechercher un transport'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int step;
  final int total;
  const _StepBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: i < step ? AppColors.primary : AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
