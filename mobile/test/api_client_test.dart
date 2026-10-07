import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_insurance/api/api_client.dart';

const base = 'http://test/api/v1';

ApiClient clientReturning(int status, Object? body, {void Function(http.Request)? onRequest}) {
  return ApiClient(
    baseUrl: base,
    httpClient: MockClient((request) async {
      onRequest?.call(request);
      return http.Response(body == null ? '' : jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    }),
  );
}

void main() {
  test('login parses token and user', () async {
    final api = clientReturning(200, {
      'token': 'abc',
      'user': {'id': 1, 'email': 'a@b.com', 'is_admin': false},
    });
    final result = await api.login('a@b.com', 'password123');
    expect(result.token, 'abc');
    expect(result.user.email, 'a@b.com');
  });

  test('sends bearer token and JSON body', () async {
    late http.Request sent;
    final api = clientReturning(201, {
      'id': 5,
      'name': 'Rex',
      'type': 'Dog',
      'age': 3,
      'policy': {'id': 9, 'pet_id': 5, 'pet_name': 'Rex', 'coverage_amount': 1000, 'monthly_premium': 31.2},
    }, onRequest: (r) => sent = r);
    api.token = 'tok';

    final pet = await api.addPet(name: 'Rex', type: 'Dog', age: 3);

    expect(sent.method, 'POST');
    expect(sent.url.toString(), '$base/pets');
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(sent.body), {'name': 'Rex', 'type': 'Dog', 'age': 3});
    expect(pet.policy!.coverageAmount, 1000.0); // int from JSON becomes double
    expect(pet.policy!.monthlyPremium, 31.2);
  });

  test('server error message is surfaced', () async {
    final api = clientReturning(400, {'error': 'Pet type must be Dog, Cat or Other.'});
    expect(
      () => api.addPet(name: 'X', type: 'Dragon', age: 1),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Pet type must be Dog, Cat or Other.')
          .having((e) => e.statusCode, 'statusCode', 400)),
    );
  });

  test('401 is flagged as unauthorized', () async {
    final api = clientReturning(401, {'error': 'Invalid token.'});
    expect(() => api.me(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', true)));
  });

  test('204 with empty body succeeds', () async {
    final api = clientReturning(204, null);
    await api.deletePet(1);
  });

  test('lists claims', () async {
    final api = clientReturning(200, [
      {'id': 1, 'policy_id': 2, 'pet_name': 'Tom', 'description': 'Vet visit', 'amount': 120.5, 'status': 'Pending'},
    ]);
    final claims = await api.claims();
    expect(claims.single.petName, 'Tom');
    expect(claims.single.amount, 120.5);
  });
}
