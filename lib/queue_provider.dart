import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => _clients;

  final SupabaseClient _supabase;
  RealtimeChannel? _subscription;

  QueueProvider() : _supabase = Supabase.instance.client {
    _fetchInitialClients();
    _setupRealtimeSubscription();
  }

  @visibleForTesting
  QueueProvider.forTesting(this._supabase) : super();

  Future<void> _fetchInitialClients() async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at');

      _clients.clear();
      _clients.addAll(response.map(Client.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
        .channel('public:clients')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final newClient = Client.fromMap(payload.newRecord);
            if (!_clients.any((client) => client.id == newClient.id)) {
              _clients.add(newClient);
              _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            _clients.removeWhere((client) => client.id == deletedId.toString());
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) {
      debugPrint('Cannot add empty client name');
      return;
    }

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('clients')
          .insert({'name': name.trim()})
          .select();

      if (response.isNotEmpty) {
        final newClient = Client.fromMap(response.first);
        if (!_clients.any((client) => client.id == newClient.id)) {
          _clients.add(newClient);
          _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
      }
      debugPrint('Client added: $name');
    } catch (e) {
      debugPrint('Failed to add client: $e');
    }
  }

  Future<void> removeClient(String id) async {
    try {
      await _supabase.from('clients').delete().match({'id': id});
      _clients.removeWhere((client) => client.id == id);
      notifyListeners();
      debugPrint('Client removed: $id');
    } catch (e) {
      debugPrint('Failed to remove client: $e');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      debugPrint('Queue is empty!');
      return;
    }

    final firstClient = _clients.first;
    await removeClient(firstClient.id);
    debugPrint('Next client: ${firstClient.name}');
  }

  @override
  void dispose() {
    if (_subscription != null) {
      _supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }
}
