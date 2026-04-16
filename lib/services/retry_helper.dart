import 'dart:async';
import 'logger_service.dart';

/// Retry policy configuration
class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });
}

/// Retry helper with exponential backoff
class RetryHelper {
  static final RetryHelper _instance = RetryHelper._internal();

  factory RetryHelper() => _instance;

  RetryHelper._internal();

  /// Execute function with retry logic
  Future<T> execute<T>(
    Future<T> Function() fn, {
    RetryPolicy policy = const RetryPolicy(),
    String? label,
  }) async {
    final logger = LoggerService();
    int attempt = 0;
    Duration delay = policy.initialDelay;

    while (true) {
      attempt++;
      try {
        if (label != null) {
          logger.debug('[$label] Attempt $attempt/${policy.maxRetries}');
        }
        return await fn();
      } catch (e, stackTrace) {
        if (attempt >= policy.maxRetries) {
          logger.error(
            label != null
              ? '[$label] Failed after $attempt attempts'
              : 'Retry exhausted after $attempt attempts',
            e,
            stackTrace,
          );
          rethrow;
        }

        logger.warning(
          label != null
            ? '[$label] Attempt $attempt failed, retrying in $delay'
            : 'Attempt $attempt failed, retrying in $delay',
          e.toString(),
        );

        await Future.delayed(delay);

        // Calculate next delay with exponential backoff
        delay = Duration(
          milliseconds: (delay.inMilliseconds * policy.backoffMultiplier).toInt(),
        );
        if (delay > policy.maxDelay) {
          delay = policy.maxDelay;
        }
      }
    }
  }

  /// Execute with custom retry conditions
  Future<T> executeWithCondition<T>(
    Future<T> Function() fn, {
    required bool Function(dynamic error) shouldRetry,
    RetryPolicy policy = const RetryPolicy(),
    String? label,
  }) async {
    final logger = LoggerService();
    int attempt = 0;
    Duration delay = policy.initialDelay;

    while (true) {
      attempt++;
      try {
        if (label != null) {
          logger.debug('[$label] Attempt $attempt/${policy.maxRetries}');
        }
        return await fn();
      } catch (e, stackTrace) {
        if (!shouldRetry(e) || attempt >= policy.maxRetries) {
          logger.error(
            label != null
              ? '[$label] Failed after $attempt attempts'
              : 'Retry exhausted after $attempt attempts',
            e,
            stackTrace,
          );
          rethrow;
        }

        logger.warning(
          label != null
            ? '[$label] Attempt $attempt failed, retrying in $delay'
            : 'Attempt $attempt failed, retrying in $delay',
          e.toString(),
        );

        await Future.delayed(delay);

        delay = Duration(
          milliseconds: (delay.inMilliseconds * policy.backoffMultiplier).toInt(),
        );
        if (delay > policy.maxDelay) {
          delay = policy.maxDelay;
        }
      }
    }
  }
}

