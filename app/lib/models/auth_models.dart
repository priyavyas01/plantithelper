class TokenResponse {
  final String accessToken;
  final String refreshToken;

  TokenResponse({required this.accessToken, required this.refreshToken});

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
      );
}

class AuthError {
  final String message;
  final int? statusCode;
  AuthError(this.message, {this.statusCode});
}
