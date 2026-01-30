// Base Repository
// Abstract class defining common repository patterns

import 'package:flutter/foundation.dart';

/// Result wrapper for repository operations
class Result<T> {
  final T? data;
  final String? error;
  final bool isLoading;

  const Result._({this.data, this.error, this.isLoading = false});

  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(String error) => Result._(error: error);
  factory Result.loading() => const Result._(isLoading: true);

  bool get isSuccess => data != null && error == null;
  bool get isFailure => error != null;

  /// Map success value to another type
  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess && data != null) {
      return Result.success(mapper(data as T));
    }
    if (isFailure) {
      return Result.failure(error!);
    }
    return Result.loading();
  }

  /// Execute callback on success
  void onSuccess(void Function(T) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
  }

  /// Execute callback on failure
  void onFailure(void Function(String) callback) {
    if (isFailure && error != null) {
      callback(error!);
    }
  }
}

/// Base repository with common caching functionality
abstract class BaseRepository<T> extends ChangeNotifier {
  // Cache storage
  final Map<String, CacheEntry<T>> _cache = {};

  // Default cache duration
  Duration get cacheDuration => const Duration(minutes: 5);

  /// Get cached data if valid
  T? getCached(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data;
    }
    return null;
  }

  /// Store data in cache
  void setCache(String key, T data) {
    _cache[key] = CacheEntry(
      data: data,
      expiry: DateTime.now().add(cacheDuration),
    );
  }

  /// Clear specific cache entry
  void clearCache(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
  }

  /// Check if cache is valid
  bool isCacheValid(String key) {
    final entry = _cache[key];
    return entry != null && !entry.isExpired;
  }
}

/// Cache entry with expiration
class CacheEntry<T> {
  final T data;
  final DateTime expiry;

  CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
