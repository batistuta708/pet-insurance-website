double _toDouble(dynamic value) => (value as num).toDouble();

String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

class User {
  const User({required this.id, required this.email, required this.isAdmin});

  final int id;
  final String email;
  final bool isAdmin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        isAdmin: (json['is_admin'] as bool?) ?? false,
      );
}

class Policy {
  const Policy({
    required this.id,
    required this.petId,
    required this.petName,
    required this.coverageAmount,
    required this.monthlyPremium,
  });

  final int id;
  final int petId;
  final String? petName;
  final double coverageAmount;
  final double monthlyPremium;

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        id: json['id'] as int,
        petId: json['pet_id'] as int,
        petName: json['pet_name'] as String?,
        coverageAmount: _toDouble(json['coverage_amount']),
        monthlyPremium: _toDouble(json['monthly_premium']),
      );
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.type,
    required this.age,
    required this.policy,
  });

  final int id;
  final String name;
  final String type;
  final int age;
  final Policy? policy;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String,
        age: json['age'] as int,
        policy: json['policy'] == null
            ? null
            : Policy.fromJson(json['policy'] as Map<String, dynamic>),
      );
}

class Claim {
  const Claim({
    required this.id,
    required this.policyId,
    required this.petName,
    required this.description,
    required this.amount,
    required this.status,
  });

  final int id;
  final int policyId;
  final String? petName;
  final String description;
  final double amount;
  final String status;

  factory Claim.fromJson(Map<String, dynamic> json) => Claim(
        id: json['id'] as int,
        policyId: json['policy_id'] as int,
        petName: json['pet_name'] as String?,
        description: json['description'] as String,
        amount: _toDouble(json['amount']),
        status: json['status'] as String,
      );
}

class Quote {
  const Quote({
    required this.type,
    required this.age,
    required this.monthlyPremium,
    required this.coverageAmount,
  });

  final String type;
  final int age;
  final double monthlyPremium;
  final double coverageAmount;

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        type: json['type'] as String,
        age: json['age'] as int,
        monthlyPremium: _toDouble(json['monthly_premium']),
        coverageAmount: _toDouble(json['coverage_amount']),
      );
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}
