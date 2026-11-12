import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';

/// A French commune returned by the official French government API
/// (https://geo.api.gouv.fr — free, no API key required).
class FrenchCity {
  final String name;
  final String postalCode;
  final String departmentCode;

  const FrenchCity({
    required this.name,
    required this.postalCode,
    required this.departmentCode,
  });

  String get label => postalCode.isNotEmpty ? '$name ($postalCode)' : name;
}

/// City text field with predictive auto-complete for France.
///
/// - When [isFrance] is true, suggestions are fetched from geo.api.gouv.fr
///   after the user types 2+ letters (debounced), sorted by population.
/// - Selecting a suggestion writes the official commune name into
///   [controller], ensuring clean / consistent data.
/// - For other countries it behaves like a normal text field.
class CityAutocompleteField extends StatefulWidget {
  /// False when the last request to geo.api.gouv.fr failed (offline, timeout...).
  /// Lets the form accept free text instead of blocking sign-up.
  static bool apiReachable = true;

  final TextEditingController controller;
  final bool isFrance;
  final InputDecoration decoration;
  final String? Function(String?)? validator;

  /// Called whenever the "selected from list" state changes
  /// (true = value comes from an official suggestion).
  final ValueChanged<bool>? onSelectionChanged;

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.isFrance,
    required this.decoration,
    this.validator,
    this.onSelectionChanged,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _lastQuery = '';
  List<FrenchCity> _lastResults = const [];

  static final Map<String, List<FrenchCity>> _cache = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  static String _normalize(String s) => s.trim().toLowerCase();

  Future<List<FrenchCity>> _fetchCities(String query) async {
    final key = _normalize(query);
    if (_cache.containsKey(key)) return _cache[key]!;

    final uri = Uri.https('geo.api.gouv.fr', '/communes', {
      'nom': query.trim(),
      'fields': 'nom,codesPostaux,codeDepartement',
      'boost': 'population',
      'limit': '10',
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        CityAutocompleteField.apiReachable = false;
        return const [];
      }
      CityAutocompleteField.apiReachable = true;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! List) return const [];
      final cities = data.map<FrenchCity>((e) {
        final m = e as Map<String, dynamic>;
        final codes = (m['codesPostaux'] as List?)?.map((c) => c.toString()).toList() ?? const [];
        return FrenchCity(
          name: m['nom']?.toString() ?? '',
          postalCode: codes.isNotEmpty ? codes.first : '',
          departmentCode: m['codeDepartement']?.toString() ?? '',
        );
      }).where((c) => c.name.isNotEmpty).toList();
      _cache[key] = cities;
      return cities;
    } catch (_) {
      CityAutocompleteField.apiReachable = false;
      return const [];
    }
  }

  /// Debounced async options builder (waits 300ms after the last keystroke).
  Future<Iterable<FrenchCity>> _optionsBuilder(TextEditingValue value) async {
    if (!widget.isFrance) return const [];
    final query = value.text.trim();
    if (query.length < 2) return const [];
    if (query == _lastQuery) return _lastResults;

    _debounce?.cancel();
    final completer = Completer<void>();
    _debounce = Timer(const Duration(milliseconds: 300), completer.complete);
    await completer.future;

    // A newer keystroke arrived meanwhile — drop this request.
    if (widget.controller.text.trim() != query) return _lastResults;

    final results = await _fetchCities(query);
    _lastQuery = query;
    _lastResults = results;
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<FrenchCity>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (c) => c.name,
      optionsBuilder: _optionsBuilder,
      onSelected: (city) {
        widget.controller.text = city.name;
        widget.controller.selection = TextSelection.collapsed(offset: city.name.length);
        widget.onSelectionChanged?.call(true);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: widget.validator,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => widget.onSelectionChanged?.call(false),
          style: AppFonts.primary(
            context,
            fontSize: 15,
            color: AppTheme.getTextPrimary(context),
          ),
          decoration: widget.decoration,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.getCardColor(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 260,
                maxWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: AppTheme.getBorderColor(context),
                ),
                itemBuilder: (context, i) {
                  final city = list[i];
                  return InkWell(
                    onTap: () => onSelected(city),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_city_rounded,
                              size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              city.name,
                              style: AppFonts.primary(
                                context,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                          ),
                          Text(
                            city.postalCode.isNotEmpty
                                ? city.postalCode
                                : city.departmentCode,
                            style: AppFonts.secondary(
                              context,
                              fontSize: 12.5,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
