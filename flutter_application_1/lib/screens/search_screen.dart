import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _q = TextEditingController();
  List<String> _results = [];

  void _doSearch() {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _results = List.generate(6, (i) => '$q - result ${i + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _q,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm bác sĩ, dịch vụ, từ khóa...'),
              onSubmitted: (_) => _doSearch(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _doSearch, child: const Text('Tìm')),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('Không có kết quả'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (c, i) => ListTile(title: Text(_results[i])),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
