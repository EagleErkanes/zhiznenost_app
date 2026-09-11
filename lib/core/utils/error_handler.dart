String getHumanReadableError(dynamic error) {
  final err = error.toString().toLowerCase();

  if (err.contains('socketexception') ||
      err.contains('failed host lookup') ||
      err.contains('clientexception') ||
      err.contains('network') ||
      err.contains('os error') ||
      err.contains('connection refused') ||
      err.contains('timeout')) {
    return 'Няма връзка с интернет. Моля, проверете мрежата си и опитайте отново.';
  }

  if (err.contains('invalid login credentials') ||
      err.contains('invalid_credentials')) {
    return 'Грешен имейл или парола.';
  }

  if (err.contains('email not confirmed')) {
    return 'Имейл адресът все още не е потвърден.';
  }

  if (err.contains('user already registered')) {
    return 'Вече съществува профил с този имейл адрес.';
  }

  return 'Възникна неочаквана грешка. Моля, опитайте отново.';
}