import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalWatchlistEntries extends Table {
  TextColumn get id => text()();
  IntColumn get tmdbId => integer()();
  TextColumn get contentType => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  RealColumn get voteAverage => real().withDefault(const Constant(0.0))();
  TextColumn get releaseYear => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalWatchHistoryEntries extends Table {
  TextColumn get id => text()();
  IntColumn get tmdbId => integer()();
  TextColumn get contentType => text()();
  IntColumn get seasonNumber => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  TextColumn get assetId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  IntColumn get currentPositionSeconds => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(1))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastWatchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalDatabase {
  final QueryExecutor executor;

  LocalDatabase([QueryExecutor? executor])
      : executor = executor ?? driftDatabase(name: 'nam_cinema_local_db');
}

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});
