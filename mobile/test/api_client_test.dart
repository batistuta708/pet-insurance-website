import 'dart:convert';
import 'dart:typed_data';

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

  test('changePassword posts both passwords', () async {
    late http.Request sent;
    final api = clientReturning(204, null, onRequest: (r) => sent = r)..token = 't';
    await api.changePassword(current: 'oldpassword', newPassword: 'newpassword');
    expect(sent.url.toString(), '$base/me/password');
    expect(jsonDecode(sent.body), {'current_password': 'oldpassword', 'new_password': 'newpassword'});
  });

  test('wrong current password is a 403, not a logout', () async {
    final api = clientReturning(403, {'error': 'Your current password is incorrect.'});
    expect(
      () => api.changePassword(current: 'x', newPassword: 'newpassword'),
      throwsA(isA<ApiException>()
          .having((e) => e.isUnauthorized, 'isUnauthorized', false)
          .having((e) => e.message, 'message', 'Your current password is incorrect.')),
    );
  });

  test('updatePet sends PATCH and parses the new premium', () async {
    late http.Request sent;
    final api = clientReturning(200, {
      'id': 5, 'name': 'Rexy', 'type': 'Dog', 'age': 8,
      'policy': {'id': 9, 'pet_id': 5, 'pet_name': 'Rexy', 'coverage_amount': 1000, 'monthly_premium': 43.2},
    }, onRequest: (r) => sent = r);
    final pet = await api.updatePet(5, name: 'Rexy', type: 'Dog', age: 8);
    expect(sent.method, 'PATCH');
    expect(sent.url.toString(), '$base/pets/5');
    expect(pet.policy!.monthlyPremium, 43.2);
  });

  test('uploadClaimPhoto sends a multipart "photo" field with the token', () async {
    late http.Request sent;
    final api = clientReturning(201, {
      'id': 3, 'policy_id': 2, 'pet_name': 'Tom', 'description': 'Vet visit',
      'amount': 50, 'status': 'Pending', 'has_photo': true,
    }, onRequest: (r) => sent = r)..token = 'tok';
    final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

    final claim = await api.uploadClaimPhoto(3, bytes, filename: 'bill.jpg');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), '$base/claims/3/photo');
    expect(sent.headers['Authorization'], 'Bearer tok');
    expect(sent.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(sent.bodyBytes);
    expect(body, contains('name="photo"'));
    expect(body, contains('filename="bill.jpg"'));
    expect(claim.hasPhoto, isTrue);
    expect(api.claimPhotoUrl(3), '$base/claims/3/photo');
    expect(api.authHeaders, {'Authorization': 'Bearer tok'});
  });

  test('claims without has_photo default to no photo', () async {
    final api = clientReturning(200, [
      {'id': 1, 'policy_id': 2, 'pet_name': 'Tom', 'description': 'Vet visit', 'amount': 10, 'status': 'Pending'},
    ]);
    expect((await api.claims()).single.hasPhoto, isFalse);
  });
}
