import 'package:intl/intl.dart';

/// Formatos de dinero y fechas en es-VE.
class Money {
  static final _usd = NumberFormat.currency(locale: 'es_VE', symbol: r'$', decimalDigits: 2);
  static final _usd0 = NumberFormat.currency(locale: 'es_VE', symbol: r'$', decimalDigits: 0);
  static final _bs = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs ', decimalDigits: 2);
  static final _num = NumberFormat.decimalPatternDigits(locale: 'es_VE', decimalDigits: 2);
  static final _fecha = DateFormat('dd/MM/yyyy', 'es');
  static final _fechaLarga = DateFormat("EEE d 'de' MMMM · h:mm a", 'es');

  static String usd(num? v) {
    if (v == null) return 'Por confirmar';
    return v == v.roundToDouble() ? _usd0.format(v) : _usd.format(v);
  }

  static String bs(num? v) => v == null ? '—' : _bs.format(v);
  static String tasa(num v) => '${_num.format(v)} Bs';
  static String fecha(DateTime d) => _fecha.format(d);
  static String fechaLarga(DateTime d) => _fechaLarga.format(d.toLocal());

  /// Equivalente en Bs con la tasa del euro BCV (como pidió la organización).
  static double? aBs(num? usd, num? tasa) =>
      usd == null || tasa == null ? null : (usd * tasa * 100).roundToDouble() / 100;
}
