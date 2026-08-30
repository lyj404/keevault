import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/sync/data/sync_service.dart';

void main() {
  group('classifySyncError', () {
    test('passes through a SyncException unchanged', () {
      final e = SyncException(SyncErrorType.conflict, 'boom');
      expect(classifySyncError(e), SyncErrorType.conflict);
    });

    test('maps Dio 401/403 to auth', () {
      for (final status in [401, 403]) {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
        );
        expect(classifySyncError(e), SyncErrorType.auth);
      }
    });

    test('maps Dio 404 to notFound', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 404),
      );
      expect(classifySyncError(e), SyncErrorType.notFound);
    });

    test('maps Dio 409/412 to conflict', () {
      for (final status in [409, 412]) {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
        );
        expect(classifySyncError(e), SyncErrorType.conflict);
      }
    });

    test('maps Dio 5xx to serverError', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 500),
      );
      expect(classifySyncError(e), SyncErrorType.serverError);
    });

    test('maps Dio timeout types to timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: type,
        );
        expect(classifySyncError(e), SyncErrorType.timeout);
      }
    });

    test('maps Dio connectionError to network', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(classifySyncError(e), SyncErrorType.network);
    });

    test('maps SocketException to network', () {
      expect(classifySyncError(SocketException('refused')), SyncErrorType.network);
    });

    test('maps TimeoutException to timeout', () {
      expect(
        classifySyncError(TimeoutException('timed out')),
        SyncErrorType.timeout,
      );
    });

    test('a message containing "401" but no typed status is unknown, not auth', () {
      // Regression guard for the fragile string matching that was removed:
      // a generic exception whose toString() contains "401" must NOT be
      // misclassified as an auth error.
      final e = Exception('totally unrelated message about error 401 found');
      expect(classifySyncError(e), SyncErrorType.unknown);
    });

    test('an arbitrary object is unknown', () {
      expect(classifySyncError(Object()), SyncErrorType.unknown);
    });
  });
}
