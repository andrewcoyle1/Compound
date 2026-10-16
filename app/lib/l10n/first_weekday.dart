import 'package:flutter/material.dart';

/// The first day of the week where the device is set, as Swift's
/// `Calendar.current` takes it from the region rather than the language:
/// 0 for Sunday to 6 for Saturday, as [MaterialLocalizations] counts. The
/// app's locale is only English or Spanish, so Material's answer follows
/// the language (Sunday for a British English device).
///
/// Without a region it falls back to Material's answer for the language.
int firstDayOfWeekIndex(BuildContext context) {
  final country = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  if (country == null || country.isEmpty) {
    return MaterialLocalizations.of(context).firstDayOfWeekIndex;
  }
  return firstDayOfWeekIndexIn(country);
}

/// The first day of the week in [country] (an ISO 3166 code), from CLDR's
/// week data: Sunday, Saturday or Friday in the territories listed, Monday
/// everywhere else.
///
/// ponytail: CLDR 44's `firstDay` lists copied by hand; refresh them if a
/// region reports the wrong day.
int firstDayOfWeekIndexIn(String country) => switch (country.toUpperCase()) {
  'MV' => DateTime.friday,
  'AE' ||
  'AF' ||
  'BH' ||
  'DJ' ||
  'DZ' ||
  'EG' ||
  'IQ' ||
  'IR' ||
  'JO' ||
  'KW' ||
  'LY' ||
  'OM' ||
  'QA' ||
  'SD' ||
  'SY' => DateTime.saturday,
  'AG' ||
  'AS' ||
  'BD' ||
  'BR' ||
  'BS' ||
  'BT' ||
  'BW' ||
  'BZ' ||
  'CA' ||
  'CN' ||
  'CO' ||
  'DM' ||
  'DO' ||
  'ET' ||
  'GT' ||
  'GU' ||
  'HK' ||
  'HN' ||
  'ID' ||
  'IL' ||
  'IN' ||
  'JM' ||
  'JP' ||
  'KE' ||
  'KH' ||
  'KR' ||
  'LA' ||
  'MH' ||
  'MM' ||
  'MO' ||
  'MT' ||
  'MX' ||
  'MZ' ||
  'NI' ||
  'NP' ||
  'PA' ||
  'PE' ||
  'PH' ||
  'PK' ||
  'PR' ||
  'PT' ||
  'PY' ||
  'SA' ||
  'SG' ||
  'SV' ||
  'TH' ||
  'TT' ||
  'TW' ||
  'UM' ||
  'US' ||
  'VE' ||
  'VI' ||
  'WS' ||
  'YE' ||
  'ZA' ||
  'ZW' => 0,
  _ => DateTime.monday,
};
