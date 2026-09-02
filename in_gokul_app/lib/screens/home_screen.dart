import 'package:flutter/material.dart';
import '../services/graph_service.dart';
import '../models/node.dart';
import 'destination_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GraphService _graphService = GraphService();
  bool _isLoading = true;
  String? _error;
  List<Node> _destinations = [];
  Node? _selectedStart;

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      await _graphService.init();
      setState(() {
        _destinations = _graphService.getDestinations();
        if (_destinations.isNotEmpty) {
          _selectedStart = _destinations.first;
        }
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
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 80,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to Indoor Navigator',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loaded ${_destinations.length} map nodes from navigation.json',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 40),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.my_location, color: Colors.deepPurple),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select Starting Point:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<Node>(
                                initialValue: _selectedStart,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: _destinations.map((node) {
                                  return DropdownMenuItem<Node>(
                                    value: node,
                                    child: Text('${node.name} (Node #${node.id})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedStart = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Choose Destination', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _selectedStart == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DestinationScreen(
                                      graphService: _graphService,
                                      startNode: _selectedStart!,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
    );
  }
}
