import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:charset_converter/charset_converter.dart';

class CurrencyRate {
  final String code;
  final String name;
  final double value;
  final int nominal;

  CurrencyRate({
    required this.code,
    required this.name,
    required this.value,
    required this.nominal,
  });
}

List<CurrencyRate> parseCbrXml(String xmlString) {
  final doc = XmlDocument.parse(xmlString);
  final valutes = doc.findAllElements('Valute');
  final List<CurrencyRate> result = [];

  for (final valute in valutes) {
    final code = valute.findElements('CharCode').firstOrNull?.text ?? '';
    final name = valute.findElements('Name').firstOrNull?.text ?? 'Неизвестно';
    final nominalText = valute.findElements('Nominal').firstOrNull?.text ?? '1';
    final valueText = valute.findElements('Value').firstOrNull?.text ?? '0';

    final double value = double.tryParse(valueText.replaceAll(',', '.')) ?? 0.0;
    final int nominal = int.tryParse(nominalText) ?? 1;

    if (code.isNotEmpty) {
      result.add(CurrencyRate(
        code: code,
        name: name,
        value: value,
        nominal: nominal,
      ));
    }
  }
  return result;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CurrencyScreen(),
    );
  }
}

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  List<CurrencyRate> _rates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      // Берем напрямую с cbr.ru. Если мы запускаем на Android/iOS, CORS нет, 
      // и прокси не нужен.
      final response = await http.get(
        Uri.parse('https://cbr.ru/scripts/XML_Daily.asp'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Статус: ${response.statusCode}');
      }
      
      // Перекодируем байты из windows-1251 в UTF-8
      final String xmlString = await CharsetConverter.decode('windows-1251', response.bodyBytes);
      
      final rates = parseCbrXml(xmlString);
      setState(() {
        _rates = rates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Курсы валют ЦБ РФ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Column(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  Text('Ошибка: $_error'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _fetchRates();
                    },
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            if (!_isLoading && _error == null)
              Expanded(
                child: ListView.builder(
                  itemCount: _rates.length,
                  itemBuilder: (context, index) {
                    final r = _rates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(r.code)),
                        title: Text(r.name),
                        subtitle: Text(
                            '${r.nominal} ${r.code} = ${r.value.toStringAsFixed(2)} ₽'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
