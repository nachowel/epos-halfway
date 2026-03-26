import '../models/user.dart';
import '../../data/repositories/user_repository.dart';

class AuthService {
  const AuthService(this._userRepository);

  final UserRepository _userRepository;

  Future<User?> loginWithPin(String pin) async {
    final User? user = await _userRepository.getByPin(pin);
    if (user == null) {
      return null;
    }
    if (!user.isActive) {
      return null;
    }
    return user;
  }

  Future<User?> getUserById(int id) {
    return _userRepository.getById(id);
  }
}
