import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPhone Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

// ================= MODEL =================
class IphoneItem {
  int? id;
  String model;
  double hargaBeli;
  String sumber;
  double ongkos;
  double hargaJual;
  String terjualKe;
  bool terjual;

  IphoneItem({
    this.id,
    required this.model,
    required this.hargaBeli,
    required this.sumber,
    required this.ongkos,
    required this.hargaJual,
    required this.terjualKe,
    required this.terjual,
  });

  double get totalModal => hargaBeli + ongkos;
  double get laba => terjual ? (hargaJual - totalModal) : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'model': model,
        'hargaBeli': hargaBeli,
        'sumber': sumber,
        'ongkos': ongkos,
        'hargaJual': hargaJual,
        'terjualKe': terjualKe,
        'terjual': terjual ? 1 : 0,
      };

  factory IphoneItem.fromMap(Map<String, dynamic> m) => IphoneItem(
        id: m['id'],
        model: m['model'],
        hargaBeli: (m['hargaBeli'] as num).toDouble(),
        sumber: m['sumber'],
        ongkos: (m['ongkos'] as num).toDouble(),
        hargaJual: (m['hargaJual'] as num).toDouble(),
        terjualKe: m['terjualKe'],
        terjual: m['terjual'] == 1,
      );
}

// ================= DATABASE =================
class DBHelper {
  static Database? _db;
  static Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'iphone_tracker.db');
    _db = await openDatabase(path, version: 1,
        onCreate: (db, v) => db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model TEXT, hargaBeli REAL, sumber TEXT,
            ongkos REAL, hargaJual REAL, terjualKe TEXT, terjual INTEGER
          )
        '''));
    return _db!;
  }

  static Future<int> insert(IphoneItem i) async =>
      (await database).insert('items', i.toMap());

  static Future<List<IphoneItem>> getAll() async {
    final rows = await (await database).query('items', orderBy: 'id DESC');
    return rows.map(IphoneItem.fromMap).toList();
  }

  static Future<int> update(IphoneItem i) async => (await database)
      .update('items', i.toMap(), where: 'id=?', whereArgs: [i.id]);

  static Future<int> delete(int id) async =>
      (await database).delete('items', where: 'id=?', whereArgs: [id]);
}

// ================= FORMAT RUPIAH =================
final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String fmt(num n) => rupiah.format(n);

// ================= HOME =================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<IphoneItem> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DBHelper.getAll();
    setState(() => items = data);
  }

  double get totalLaba => items.fold(0, (s, i) => s + i.laba);
  int get jumlahTerjual => items.where((i) => i.terjual).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iPhone Tracker')),
      body: Column(
        children: [
          // Ringkasan
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Terjual', '$jumlahTerjual unit'),
                _stat('Total Laba', fmt(totalLaba)),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Belum ada data. Tap + untuk tambah.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final it = items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${it.model} ${it.terjual ? "✅" : "⏳"}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Beli: ${fmt(it.hargaBeli)} | Ongkos: ${fmt(it.ongkos)}'),
                              Text('Sumber: ${it.sumber}'),
                              if (it.terjual) ...[
                                Text('Jual: ${fmt(it.hargaJual)} ke ${it.terjualKe}'),
                                Text('Laba: ${fmt(it.laba)}',
                                    style: TextStyle(
                                        color: it.laba >= 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await DBHelper.delete(it.id!);
                              _load();
                            },
                          ),
                          onTap: () => _openForm(it),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );

  void _openForm(IphoneItem? item) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => FormPage(item: item)));
    _load();
  }
}

// ================= FORM =================
class FormPage extends StatefulWidget {
  final IphoneItem? item;
  const FormPage({super.key, this.item});
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController model, hargaBeli, sumber, ongkos, hargaJual, terjualKe;
  bool terjual = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    model = TextEditingController(text: it?.model ?? '');
    hargaBeli = TextEditingController(text: it?.hargaBeli.toString() ?? '');
    sumber = TextEditingController(text: it?.sumber ?? '');
    ongkos = TextEditingController(text: it?.ongkos.toString() ?? '');
    hargaJual = TextEditingController(text: it?.hargaJual.toString() ?? '');
    terjualKe = TextEditingController(text: it?.terjualKe ?? '');
    terjual = it?.terjual ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = IphoneItem(
      id: widget.item?.id,
      model: model.text,
      hargaBeli: double.tryParse(hargaBeli.text) ?? 0,
      sumber: sumber.text,
      ongkos: double.tryParse(ongkos.text) ?? 0,
      hargaJual: double.tryParse(hargaJual.text) ?? 0,
      terjualKe: terjualKe.text,
      terjual: terjual,
    );
    if (widget.item == null) {
      await DBHelper.insert(item);
    } else {
      await DBHelper.update(item);
    }
    // PERBAIKAN ADA DI SINI (menggunakan context.mounted)
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Tambah iPhone' : 'Edit iPhone')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Model iPhone', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: hargaBeli,
              decoration: const InputDecoration(labelText: 'Harga Beli (Rp)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: sumber,
              decoration: const InputDecoration(labelText: 'Sumber Barang (dari siapa)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ongkos,
              decoration: const InputDecoration(labelText: 'Biaya Ongkos Ambil (Rp)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Sudah Terjual?'),
              value: terjual,
              onChanged: (v) => setState(() => terjual = v),
            ),
            if (terjual) ...[
              TextFormField(
                controller: hargaJual,
                decoration: const InputDecoration(labelText: 'Harga Jual (Rp)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: terjualKe,
                decoration: const InputDecoration(labelText: 'Terjual ke siapa', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }
}
