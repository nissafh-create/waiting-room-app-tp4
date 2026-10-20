import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/queue_provider.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final List<dynamic> insertedValues = [];

  @override
  SupabaseQueryBuilder from(String table) {
    return FakeSupabaseQueryBuilder(this, table);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final FakeSupabaseClient client;
  final String table;

  FakeSupabaseQueryBuilder(this.client, this.table);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    client.insertedValues.add(values);
    return FakePostgrestFilterBuilder([
      {
        'id': 'test-id-1',
        'name': (values as Map)['name'],
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);
  }
}

class FakePostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final List<Map<String, dynamic>> result;

  FakePostgrestFilterBuilder(this.result);

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return FakePostgrestTransformBuilder(result);
  }
}

class FakePostgrestTransformBuilder extends Fake
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {
  final List<Map<String, dynamic>> result;

  FakePostgrestTransformBuilder(this.result);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    return Future.value(result).then(onValue, onError: onError);
  }
}

void main() {
  test('addClient calls insert', () async {
    final fakeClient = FakeSupabaseClient();
    final provider = QueueProvider.forTesting(fakeClient);

    await provider.addClient("Alice");

    expect(fakeClient.insertedValues.length, 1);
    expect(fakeClient.insertedValues.first, {'name': 'Alice'});
  });
}
