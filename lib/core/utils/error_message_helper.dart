class ErrorMessageHelper {
  static String getShortErrorMessage(String error) {
    String message = error
        .replaceAll('Exception: ', '')
        .replaceAll('Failed to ', '')
        .replaceAll('Error: ', '')
        .replaceAll('Error ', '')
        .trim();

    if (message.contains('network') || message.contains('connection')) {
      return 'Network connection failed. Please check your internet.';
    }

    if (message.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (message.contains('unauthorized') || message.contains('401')) {
      return 'Invalid credentials. Please check your login details.';
    }

    if (message.contains('forbidden') || message.contains('403')) {
      return 'Access denied. Please contact support.';
    }

    if (message.contains('not found') || message.contains('404')) {
      return 'Resource not found. Please try again.';
    }

    if (message.contains('server') || message.contains('500')) {
      return 'Server error. Please try again later.';
    }

    if (message.contains('email') && message.contains('already exists')) {
      return 'Email already exists. Please use a different email.';
    }

    if (message.contains('username') && message.contains('already exists')) {
      return 'Username already exists. Please choose a different username.';
    }

    if (message.contains('password') && message.contains('incorrect')) {
      return 'Incorrect password. Please try again.';
    }

    if (message.contains('user not found')) {
      return 'User not found. Please check your credentials.';
    }

    if (message.contains('verification code')) {
      return 'Invalid verification code. Please try again.';
    }

    if (message.contains('profile image') || message.contains('avatar')) {
      return 'Failed to update profile image. Please try again.';
    }

    if (message.contains('StorageException') &&
        message.contains('Bucket not found')) {
      return 'Storage service unavailable. Please try again later.';
    }

    if (message.contains('StorageException') &&
        message.contains('row-level security policy')) {
      return 'Access denied. Please contact support.';
    }

    if (message.contains('Login failed')) {
      return 'Login failed, Please check your password and username.';
    }

    if (message.contains('registration failed')) {
      return 'Registration failed. Please try again.';
    }

    if (message.contains('update failed')) {
      return 'Update failed. Please try again.';
    }

    if (message.contains('delete failed')) {
      return 'Delete failed. Please try again.';
    }

    if (message.contains('sync failed')) {
      return 'Sync failed. Please check your connection.';
    }

    if (message.contains('upload failed')) {
      return 'Upload failed. Please try again.';
    }

    if (message.contains('download failed')) {
      return 'Download failed. Please try again.';
    }

    if (message.contains('validation failed')) {
      return 'Invalid input. Please check your data.';
    }

    if (message.contains('authentication failed')) {
      return 'Authentication failed. Please sign in again.';
    }

    if (message.contains('permission denied')) {
      return 'Permission denied. Please contact support.';
    }

    if (message.contains('invalid format')) {
      return 'Invalid format. Please check your input.';
    }

    if (message.contains('required field')) {
      return 'Required field missing. Please fill all fields.';
    }

    if (message.contains('duplicate entry')) {
      return 'Duplicate entry. Please use different information.';
    }

    if (message.contains('constraint violation')) {
      return 'Invalid data. Please check your input.';
    }

    if (message.contains('database error')) {
      return 'Database error. Please try again later.';
    }

    if (message.contains('file not found')) {
      return 'File not found. Please try again.';
    }

    if (message.contains('invalid token')) {
      return 'Session expired. Please sign in again.';
    }

    if (message.contains('rate limit')) {
      return 'Too many requests. Please wait and try again.';
    }

    if (message.contains('maintenance')) {
      return 'Service under maintenance. Please try again later.';
    }

    if (message.length > 80) {
      message = '${message.substring(0, 77)}...';
    }

    return message;
  }
}
