class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
  };
}

class LoginResponse {
  final String accessToken;
  final String uuid;
  final String name;
  final String username;

  LoginResponse({
    required this.accessToken,
    required this.uuid,
    required this.name,
    required this.username,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      uuid:        json['uuid']         as String,
      name:        json['name']         as String,
      username:    json['username']     as String,
    );
  }
}
