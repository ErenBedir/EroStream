/// Diacritic folding without a Unicode normalization table.
///
/// Covers Latin-1, Latin Extended-A and the combining marks block, which is
/// what shows up in release names and TMDB titles in practice.
library;

const _from = 'ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĹĺĻļĽľĿŀŁłÑñŃńŅņŇňÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž';
const _to = 'AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkLlLlLlLlLlNnNnNnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSsTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz';

final Map<int, String> _map = () {
  final m = <int, String>{};
  final f = _from.runes.toList();
  final t = _to.runes.toList();
  assert(f.length == t.length, 'fold table mismatch ${f.length} != ${t.length}');
  for (var i = 0; i < f.length && i < t.length; i++) {
    m[f[i]] = String.fromCharCode(t[i]);
  }
  m['ß'.runes.first] = 'ss';
  m['Æ'.runes.first] = 'AE';
  m['æ'.runes.first] = 'ae';
  m['Œ'.runes.first] = 'OE';
  m['œ'.runes.first] = 'oe';
  return m;
}();

String foldText(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0300 && r <= 0x036F) continue; // combining marks
    final rep = _map[r];
    if (rep != null) {
      b.write(rep);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}
