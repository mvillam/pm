part of 'fipa_arch.dart';

class Kvp {
  final List<String> _key;
  final List<String> _value;
  final String sep;

  Kvp({List<String> keys=const[], List<String> values=const[],this.sep="."}):_key = keys,
   _value= values;

  String get key => _key.join(sep);
  String get value => _value.join(sep);

}