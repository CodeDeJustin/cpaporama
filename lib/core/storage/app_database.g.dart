// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MetaTable extends Meta with TableInfo<$MetaTable, MetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaData extends DataClass implements Insertable<MetaData> {
  final String key;
  final String? value;
  const MetaData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory MetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  MetaData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => MetaData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  MetaData copyWithCompanion(MetaCompanion data) {
    return MetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaData && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<MetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NightsTable extends Nights with TableInfo<$NightsTable, Night> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nightKeyMeta = const VerificationMeta(
    'nightKey',
  );
  @override
  late final GeneratedColumn<String> nightKey = GeneratedColumn<String>(
    'night_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nightDateEpochDayMeta = const VerificationMeta(
    'nightDateEpochDay',
  );
  @override
  late final GeneratedColumn<int> nightDateEpochDay = GeneratedColumn<int>(
    'night_date_epoch_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startEpochMsMeta = const VerificationMeta(
    'startEpochMs',
  );
  @override
  late final GeneratedColumn<int> startEpochMs = GeneratedColumn<int>(
    'start_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endEpochMsMeta = const VerificationMeta(
    'endEpochMs',
  );
  @override
  late final GeneratedColumn<int> endEpochMs = GeneratedColumn<int>(
    'end_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionsCountMeta = const VerificationMeta(
    'sessionsCount',
  );
  @override
  late final GeneratedColumn<int> sessionsCount = GeneratedColumn<int>(
    'sessions_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gapCountMeta = const VerificationMeta(
    'gapCount',
  );
  @override
  late final GeneratedColumn<int> gapCount = GeneratedColumn<int>(
    'gap_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gapSecondsMeta = const VerificationMeta(
    'gapSeconds',
  );
  @override
  late final GeneratedColumn<int> gapSeconds = GeneratedColumn<int>(
    'gap_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _useSecondsMeta = const VerificationMeta(
    'useSeconds',
  );
  @override
  late final GeneratedColumn<int> useSeconds = GeneratedColumn<int>(
    'use_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _labelsJsonMeta = const VerificationMeta(
    'labelsJson',
  );
  @override
  late final GeneratedColumn<String> labelsJson = GeneratedColumn<String>(
    'labels_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nightKey,
    nightDateEpochDay,
    startEpochMs,
    endEpochMs,
    sessionsCount,
    gapCount,
    gapSeconds,
    useSeconds,
    labelsJson,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nights';
  @override
  VerificationContext validateIntegrity(
    Insertable<Night> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('night_key')) {
      context.handle(
        _nightKeyMeta,
        nightKey.isAcceptableOrUnknown(data['night_key']!, _nightKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nightKeyMeta);
    }
    if (data.containsKey('night_date_epoch_day')) {
      context.handle(
        _nightDateEpochDayMeta,
        nightDateEpochDay.isAcceptableOrUnknown(
          data['night_date_epoch_day']!,
          _nightDateEpochDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nightDateEpochDayMeta);
    }
    if (data.containsKey('start_epoch_ms')) {
      context.handle(
        _startEpochMsMeta,
        startEpochMs.isAcceptableOrUnknown(
          data['start_epoch_ms']!,
          _startEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startEpochMsMeta);
    }
    if (data.containsKey('end_epoch_ms')) {
      context.handle(
        _endEpochMsMeta,
        endEpochMs.isAcceptableOrUnknown(
          data['end_epoch_ms']!,
          _endEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endEpochMsMeta);
    }
    if (data.containsKey('sessions_count')) {
      context.handle(
        _sessionsCountMeta,
        sessionsCount.isAcceptableOrUnknown(
          data['sessions_count']!,
          _sessionsCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionsCountMeta);
    }
    if (data.containsKey('gap_count')) {
      context.handle(
        _gapCountMeta,
        gapCount.isAcceptableOrUnknown(data['gap_count']!, _gapCountMeta),
      );
    }
    if (data.containsKey('gap_seconds')) {
      context.handle(
        _gapSecondsMeta,
        gapSeconds.isAcceptableOrUnknown(data['gap_seconds']!, _gapSecondsMeta),
      );
    }
    if (data.containsKey('use_seconds')) {
      context.handle(
        _useSecondsMeta,
        useSeconds.isAcceptableOrUnknown(data['use_seconds']!, _useSecondsMeta),
      );
    }
    if (data.containsKey('labels_json')) {
      context.handle(
        _labelsJsonMeta,
        labelsJson.isAcceptableOrUnknown(data['labels_json']!, _labelsJsonMeta),
      );
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nightKey};
  @override
  Night map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Night(
      nightKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}night_key'],
      )!,
      nightDateEpochDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_date_epoch_day'],
      )!,
      startEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_epoch_ms'],
      )!,
      endEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_epoch_ms'],
      )!,
      sessionsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessions_count'],
      )!,
      gapCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gap_count'],
      )!,
      gapSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gap_seconds'],
      )!,
      useSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_seconds'],
      )!,
      labelsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}labels_json'],
      ),
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $NightsTable createAlias(String alias) {
    return $NightsTable(attachedDatabase, alias);
  }
}

class Night extends DataClass implements Insertable<Night> {
  final String nightKey;
  final int nightDateEpochDay;
  final int startEpochMs;
  final int endEpochMs;
  final int sessionsCount;
  final int gapCount;
  final int gapSeconds;
  final int useSeconds;
  final String? labelsJson;
  final int updatedAtEpochMs;
  const Night({
    required this.nightKey,
    required this.nightDateEpochDay,
    required this.startEpochMs,
    required this.endEpochMs,
    required this.sessionsCount,
    required this.gapCount,
    required this.gapSeconds,
    required this.useSeconds,
    this.labelsJson,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['night_key'] = Variable<String>(nightKey);
    map['night_date_epoch_day'] = Variable<int>(nightDateEpochDay);
    map['start_epoch_ms'] = Variable<int>(startEpochMs);
    map['end_epoch_ms'] = Variable<int>(endEpochMs);
    map['sessions_count'] = Variable<int>(sessionsCount);
    map['gap_count'] = Variable<int>(gapCount);
    map['gap_seconds'] = Variable<int>(gapSeconds);
    map['use_seconds'] = Variable<int>(useSeconds);
    if (!nullToAbsent || labelsJson != null) {
      map['labels_json'] = Variable<String>(labelsJson);
    }
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  NightsCompanion toCompanion(bool nullToAbsent) {
    return NightsCompanion(
      nightKey: Value(nightKey),
      nightDateEpochDay: Value(nightDateEpochDay),
      startEpochMs: Value(startEpochMs),
      endEpochMs: Value(endEpochMs),
      sessionsCount: Value(sessionsCount),
      gapCount: Value(gapCount),
      gapSeconds: Value(gapSeconds),
      useSeconds: Value(useSeconds),
      labelsJson: labelsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(labelsJson),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory Night.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Night(
      nightKey: serializer.fromJson<String>(json['nightKey']),
      nightDateEpochDay: serializer.fromJson<int>(json['nightDateEpochDay']),
      startEpochMs: serializer.fromJson<int>(json['startEpochMs']),
      endEpochMs: serializer.fromJson<int>(json['endEpochMs']),
      sessionsCount: serializer.fromJson<int>(json['sessionsCount']),
      gapCount: serializer.fromJson<int>(json['gapCount']),
      gapSeconds: serializer.fromJson<int>(json['gapSeconds']),
      useSeconds: serializer.fromJson<int>(json['useSeconds']),
      labelsJson: serializer.fromJson<String?>(json['labelsJson']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nightKey': serializer.toJson<String>(nightKey),
      'nightDateEpochDay': serializer.toJson<int>(nightDateEpochDay),
      'startEpochMs': serializer.toJson<int>(startEpochMs),
      'endEpochMs': serializer.toJson<int>(endEpochMs),
      'sessionsCount': serializer.toJson<int>(sessionsCount),
      'gapCount': serializer.toJson<int>(gapCount),
      'gapSeconds': serializer.toJson<int>(gapSeconds),
      'useSeconds': serializer.toJson<int>(useSeconds),
      'labelsJson': serializer.toJson<String?>(labelsJson),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  Night copyWith({
    String? nightKey,
    int? nightDateEpochDay,
    int? startEpochMs,
    int? endEpochMs,
    int? sessionsCount,
    int? gapCount,
    int? gapSeconds,
    int? useSeconds,
    Value<String?> labelsJson = const Value.absent(),
    int? updatedAtEpochMs,
  }) => Night(
    nightKey: nightKey ?? this.nightKey,
    nightDateEpochDay: nightDateEpochDay ?? this.nightDateEpochDay,
    startEpochMs: startEpochMs ?? this.startEpochMs,
    endEpochMs: endEpochMs ?? this.endEpochMs,
    sessionsCount: sessionsCount ?? this.sessionsCount,
    gapCount: gapCount ?? this.gapCount,
    gapSeconds: gapSeconds ?? this.gapSeconds,
    useSeconds: useSeconds ?? this.useSeconds,
    labelsJson: labelsJson.present ? labelsJson.value : this.labelsJson,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  Night copyWithCompanion(NightsCompanion data) {
    return Night(
      nightKey: data.nightKey.present ? data.nightKey.value : this.nightKey,
      nightDateEpochDay: data.nightDateEpochDay.present
          ? data.nightDateEpochDay.value
          : this.nightDateEpochDay,
      startEpochMs: data.startEpochMs.present
          ? data.startEpochMs.value
          : this.startEpochMs,
      endEpochMs: data.endEpochMs.present
          ? data.endEpochMs.value
          : this.endEpochMs,
      sessionsCount: data.sessionsCount.present
          ? data.sessionsCount.value
          : this.sessionsCount,
      gapCount: data.gapCount.present ? data.gapCount.value : this.gapCount,
      gapSeconds: data.gapSeconds.present
          ? data.gapSeconds.value
          : this.gapSeconds,
      useSeconds: data.useSeconds.present
          ? data.useSeconds.value
          : this.useSeconds,
      labelsJson: data.labelsJson.present
          ? data.labelsJson.value
          : this.labelsJson,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Night(')
          ..write('nightKey: $nightKey, ')
          ..write('nightDateEpochDay: $nightDateEpochDay, ')
          ..write('startEpochMs: $startEpochMs, ')
          ..write('endEpochMs: $endEpochMs, ')
          ..write('sessionsCount: $sessionsCount, ')
          ..write('gapCount: $gapCount, ')
          ..write('gapSeconds: $gapSeconds, ')
          ..write('useSeconds: $useSeconds, ')
          ..write('labelsJson: $labelsJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    nightKey,
    nightDateEpochDay,
    startEpochMs,
    endEpochMs,
    sessionsCount,
    gapCount,
    gapSeconds,
    useSeconds,
    labelsJson,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Night &&
          other.nightKey == this.nightKey &&
          other.nightDateEpochDay == this.nightDateEpochDay &&
          other.startEpochMs == this.startEpochMs &&
          other.endEpochMs == this.endEpochMs &&
          other.sessionsCount == this.sessionsCount &&
          other.gapCount == this.gapCount &&
          other.gapSeconds == this.gapSeconds &&
          other.useSeconds == this.useSeconds &&
          other.labelsJson == this.labelsJson &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class NightsCompanion extends UpdateCompanion<Night> {
  final Value<String> nightKey;
  final Value<int> nightDateEpochDay;
  final Value<int> startEpochMs;
  final Value<int> endEpochMs;
  final Value<int> sessionsCount;
  final Value<int> gapCount;
  final Value<int> gapSeconds;
  final Value<int> useSeconds;
  final Value<String?> labelsJson;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const NightsCompanion({
    this.nightKey = const Value.absent(),
    this.nightDateEpochDay = const Value.absent(),
    this.startEpochMs = const Value.absent(),
    this.endEpochMs = const Value.absent(),
    this.sessionsCount = const Value.absent(),
    this.gapCount = const Value.absent(),
    this.gapSeconds = const Value.absent(),
    this.useSeconds = const Value.absent(),
    this.labelsJson = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NightsCompanion.insert({
    required String nightKey,
    required int nightDateEpochDay,
    required int startEpochMs,
    required int endEpochMs,
    required int sessionsCount,
    this.gapCount = const Value.absent(),
    this.gapSeconds = const Value.absent(),
    this.useSeconds = const Value.absent(),
    this.labelsJson = const Value.absent(),
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : nightKey = Value(nightKey),
       nightDateEpochDay = Value(nightDateEpochDay),
       startEpochMs = Value(startEpochMs),
       endEpochMs = Value(endEpochMs),
       sessionsCount = Value(sessionsCount),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<Night> custom({
    Expression<String>? nightKey,
    Expression<int>? nightDateEpochDay,
    Expression<int>? startEpochMs,
    Expression<int>? endEpochMs,
    Expression<int>? sessionsCount,
    Expression<int>? gapCount,
    Expression<int>? gapSeconds,
    Expression<int>? useSeconds,
    Expression<String>? labelsJson,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nightKey != null) 'night_key': nightKey,
      if (nightDateEpochDay != null) 'night_date_epoch_day': nightDateEpochDay,
      if (startEpochMs != null) 'start_epoch_ms': startEpochMs,
      if (endEpochMs != null) 'end_epoch_ms': endEpochMs,
      if (sessionsCount != null) 'sessions_count': sessionsCount,
      if (gapCount != null) 'gap_count': gapCount,
      if (gapSeconds != null) 'gap_seconds': gapSeconds,
      if (useSeconds != null) 'use_seconds': useSeconds,
      if (labelsJson != null) 'labels_json': labelsJson,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NightsCompanion copyWith({
    Value<String>? nightKey,
    Value<int>? nightDateEpochDay,
    Value<int>? startEpochMs,
    Value<int>? endEpochMs,
    Value<int>? sessionsCount,
    Value<int>? gapCount,
    Value<int>? gapSeconds,
    Value<int>? useSeconds,
    Value<String?>? labelsJson,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return NightsCompanion(
      nightKey: nightKey ?? this.nightKey,
      nightDateEpochDay: nightDateEpochDay ?? this.nightDateEpochDay,
      startEpochMs: startEpochMs ?? this.startEpochMs,
      endEpochMs: endEpochMs ?? this.endEpochMs,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      gapCount: gapCount ?? this.gapCount,
      gapSeconds: gapSeconds ?? this.gapSeconds,
      useSeconds: useSeconds ?? this.useSeconds,
      labelsJson: labelsJson ?? this.labelsJson,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nightKey.present) {
      map['night_key'] = Variable<String>(nightKey.value);
    }
    if (nightDateEpochDay.present) {
      map['night_date_epoch_day'] = Variable<int>(nightDateEpochDay.value);
    }
    if (startEpochMs.present) {
      map['start_epoch_ms'] = Variable<int>(startEpochMs.value);
    }
    if (endEpochMs.present) {
      map['end_epoch_ms'] = Variable<int>(endEpochMs.value);
    }
    if (sessionsCount.present) {
      map['sessions_count'] = Variable<int>(sessionsCount.value);
    }
    if (gapCount.present) {
      map['gap_count'] = Variable<int>(gapCount.value);
    }
    if (gapSeconds.present) {
      map['gap_seconds'] = Variable<int>(gapSeconds.value);
    }
    if (useSeconds.present) {
      map['use_seconds'] = Variable<int>(useSeconds.value);
    }
    if (labelsJson.present) {
      map['labels_json'] = Variable<String>(labelsJson.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NightsCompanion(')
          ..write('nightKey: $nightKey, ')
          ..write('nightDateEpochDay: $nightDateEpochDay, ')
          ..write('startEpochMs: $startEpochMs, ')
          ..write('endEpochMs: $endEpochMs, ')
          ..write('sessionsCount: $sessionsCount, ')
          ..write('gapCount: $gapCount, ')
          ..write('gapSeconds: $gapSeconds, ')
          ..write('useSeconds: $useSeconds, ')
          ..write('labelsJson: $labelsJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionKeyMeta = const VerificationMeta(
    'sessionKey',
  );
  @override
  late final GeneratedColumn<String> sessionKey = GeneratedColumn<String>(
    'session_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nightKeyMeta = const VerificationMeta(
    'nightKey',
  );
  @override
  late final GeneratedColumn<String> nightKey = GeneratedColumn<String>(
    'night_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nights (night_key)',
    ),
  );
  static const VerificationMeta _startEpochMsMeta = const VerificationMeta(
    'startEpochMs',
  );
  @override
  late final GeneratedColumn<int> startEpochMs = GeneratedColumn<int>(
    'start_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bestTypeMeta = const VerificationMeta(
    'bestType',
  );
  @override
  late final GeneratedColumn<String> bestType = GeneratedColumn<String>(
    'best_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestFilePathMeta = const VerificationMeta(
    'bestFilePath',
  );
  @override
  late final GeneratedColumn<String> bestFilePath = GeneratedColumn<String>(
    'best_file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typesCsvMeta = const VerificationMeta(
    'typesCsv',
  );
  @override
  late final GeneratedColumn<String> typesCsv = GeneratedColumn<String>(
    'types_csv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionKey,
    nightKey,
    startEpochMs,
    durationSeconds,
    bestType,
    bestFilePath,
    typesCsv,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_key')) {
      context.handle(
        _sessionKeyMeta,
        sessionKey.isAcceptableOrUnknown(data['session_key']!, _sessionKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionKeyMeta);
    }
    if (data.containsKey('night_key')) {
      context.handle(
        _nightKeyMeta,
        nightKey.isAcceptableOrUnknown(data['night_key']!, _nightKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nightKeyMeta);
    }
    if (data.containsKey('start_epoch_ms')) {
      context.handle(
        _startEpochMsMeta,
        startEpochMs.isAcceptableOrUnknown(
          data['start_epoch_ms']!,
          _startEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startEpochMsMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('best_type')) {
      context.handle(
        _bestTypeMeta,
        bestType.isAcceptableOrUnknown(data['best_type']!, _bestTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_bestTypeMeta);
    }
    if (data.containsKey('best_file_path')) {
      context.handle(
        _bestFilePathMeta,
        bestFilePath.isAcceptableOrUnknown(
          data['best_file_path']!,
          _bestFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bestFilePathMeta);
    }
    if (data.containsKey('types_csv')) {
      context.handle(
        _typesCsvMeta,
        typesCsv.isAcceptableOrUnknown(data['types_csv']!, _typesCsvMeta),
      );
    } else if (isInserting) {
      context.missing(_typesCsvMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionKey};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      sessionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_key'],
      )!,
      nightKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}night_key'],
      )!,
      startEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_epoch_ms'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      bestType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}best_type'],
      )!,
      bestFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}best_file_path'],
      )!,
      typesCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}types_csv'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String sessionKey;
  final String nightKey;
  final int startEpochMs;
  final int? durationSeconds;
  final String bestType;
  final String bestFilePath;
  final String typesCsv;
  const Session({
    required this.sessionKey,
    required this.nightKey,
    required this.startEpochMs,
    this.durationSeconds,
    required this.bestType,
    required this.bestFilePath,
    required this.typesCsv,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_key'] = Variable<String>(sessionKey);
    map['night_key'] = Variable<String>(nightKey);
    map['start_epoch_ms'] = Variable<int>(startEpochMs);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['best_type'] = Variable<String>(bestType);
    map['best_file_path'] = Variable<String>(bestFilePath);
    map['types_csv'] = Variable<String>(typesCsv);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      sessionKey: Value(sessionKey),
      nightKey: Value(nightKey),
      startEpochMs: Value(startEpochMs),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      bestType: Value(bestType),
      bestFilePath: Value(bestFilePath),
      typesCsv: Value(typesCsv),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      sessionKey: serializer.fromJson<String>(json['sessionKey']),
      nightKey: serializer.fromJson<String>(json['nightKey']),
      startEpochMs: serializer.fromJson<int>(json['startEpochMs']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      bestType: serializer.fromJson<String>(json['bestType']),
      bestFilePath: serializer.fromJson<String>(json['bestFilePath']),
      typesCsv: serializer.fromJson<String>(json['typesCsv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionKey': serializer.toJson<String>(sessionKey),
      'nightKey': serializer.toJson<String>(nightKey),
      'startEpochMs': serializer.toJson<int>(startEpochMs),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'bestType': serializer.toJson<String>(bestType),
      'bestFilePath': serializer.toJson<String>(bestFilePath),
      'typesCsv': serializer.toJson<String>(typesCsv),
    };
  }

  Session copyWith({
    String? sessionKey,
    String? nightKey,
    int? startEpochMs,
    Value<int?> durationSeconds = const Value.absent(),
    String? bestType,
    String? bestFilePath,
    String? typesCsv,
  }) => Session(
    sessionKey: sessionKey ?? this.sessionKey,
    nightKey: nightKey ?? this.nightKey,
    startEpochMs: startEpochMs ?? this.startEpochMs,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    bestType: bestType ?? this.bestType,
    bestFilePath: bestFilePath ?? this.bestFilePath,
    typesCsv: typesCsv ?? this.typesCsv,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      sessionKey: data.sessionKey.present
          ? data.sessionKey.value
          : this.sessionKey,
      nightKey: data.nightKey.present ? data.nightKey.value : this.nightKey,
      startEpochMs: data.startEpochMs.present
          ? data.startEpochMs.value
          : this.startEpochMs,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      bestType: data.bestType.present ? data.bestType.value : this.bestType,
      bestFilePath: data.bestFilePath.present
          ? data.bestFilePath.value
          : this.bestFilePath,
      typesCsv: data.typesCsv.present ? data.typesCsv.value : this.typesCsv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('sessionKey: $sessionKey, ')
          ..write('nightKey: $nightKey, ')
          ..write('startEpochMs: $startEpochMs, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('bestType: $bestType, ')
          ..write('bestFilePath: $bestFilePath, ')
          ..write('typesCsv: $typesCsv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionKey,
    nightKey,
    startEpochMs,
    durationSeconds,
    bestType,
    bestFilePath,
    typesCsv,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.sessionKey == this.sessionKey &&
          other.nightKey == this.nightKey &&
          other.startEpochMs == this.startEpochMs &&
          other.durationSeconds == this.durationSeconds &&
          other.bestType == this.bestType &&
          other.bestFilePath == this.bestFilePath &&
          other.typesCsv == this.typesCsv);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> sessionKey;
  final Value<String> nightKey;
  final Value<int> startEpochMs;
  final Value<int?> durationSeconds;
  final Value<String> bestType;
  final Value<String> bestFilePath;
  final Value<String> typesCsv;
  final Value<int> rowid;
  const SessionsCompanion({
    this.sessionKey = const Value.absent(),
    this.nightKey = const Value.absent(),
    this.startEpochMs = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.bestType = const Value.absent(),
    this.bestFilePath = const Value.absent(),
    this.typesCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String sessionKey,
    required String nightKey,
    required int startEpochMs,
    this.durationSeconds = const Value.absent(),
    required String bestType,
    required String bestFilePath,
    required String typesCsv,
    this.rowid = const Value.absent(),
  }) : sessionKey = Value(sessionKey),
       nightKey = Value(nightKey),
       startEpochMs = Value(startEpochMs),
       bestType = Value(bestType),
       bestFilePath = Value(bestFilePath),
       typesCsv = Value(typesCsv);
  static Insertable<Session> custom({
    Expression<String>? sessionKey,
    Expression<String>? nightKey,
    Expression<int>? startEpochMs,
    Expression<int>? durationSeconds,
    Expression<String>? bestType,
    Expression<String>? bestFilePath,
    Expression<String>? typesCsv,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionKey != null) 'session_key': sessionKey,
      if (nightKey != null) 'night_key': nightKey,
      if (startEpochMs != null) 'start_epoch_ms': startEpochMs,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (bestType != null) 'best_type': bestType,
      if (bestFilePath != null) 'best_file_path': bestFilePath,
      if (typesCsv != null) 'types_csv': typesCsv,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? sessionKey,
    Value<String>? nightKey,
    Value<int>? startEpochMs,
    Value<int?>? durationSeconds,
    Value<String>? bestType,
    Value<String>? bestFilePath,
    Value<String>? typesCsv,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      sessionKey: sessionKey ?? this.sessionKey,
      nightKey: nightKey ?? this.nightKey,
      startEpochMs: startEpochMs ?? this.startEpochMs,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      bestType: bestType ?? this.bestType,
      bestFilePath: bestFilePath ?? this.bestFilePath,
      typesCsv: typesCsv ?? this.typesCsv,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionKey.present) {
      map['session_key'] = Variable<String>(sessionKey.value);
    }
    if (nightKey.present) {
      map['night_key'] = Variable<String>(nightKey.value);
    }
    if (startEpochMs.present) {
      map['start_epoch_ms'] = Variable<int>(startEpochMs.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (bestType.present) {
      map['best_type'] = Variable<String>(bestType.value);
    }
    if (bestFilePath.present) {
      map['best_file_path'] = Variable<String>(bestFilePath.value);
    }
    if (typesCsv.present) {
      map['types_csv'] = Variable<String>(typesCsv.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('sessionKey: $sessionKey, ')
          ..write('nightKey: $nightKey, ')
          ..write('startEpochMs: $startEpochMs, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('bestType: $bestType, ')
          ..write('bestFilePath: $bestFilePath, ')
          ..write('typesCsv: $typesCsv, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $NightsTable nights = $NightsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [meta, nights, sessions];
}

typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaData,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
          MetaData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaData,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
      MetaData,
      PrefetchHooks Function()
    >;
typedef $$NightsTableCreateCompanionBuilder =
    NightsCompanion Function({
      required String nightKey,
      required int nightDateEpochDay,
      required int startEpochMs,
      required int endEpochMs,
      required int sessionsCount,
      Value<int> gapCount,
      Value<int> gapSeconds,
      Value<int> useSeconds,
      Value<String?> labelsJson,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$NightsTableUpdateCompanionBuilder =
    NightsCompanion Function({
      Value<String> nightKey,
      Value<int> nightDateEpochDay,
      Value<int> startEpochMs,
      Value<int> endEpochMs,
      Value<int> sessionsCount,
      Value<int> gapCount,
      Value<int> gapSeconds,
      Value<int> useSeconds,
      Value<String?> labelsJson,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

final class $$NightsTableReferences
    extends BaseReferences<_$AppDatabase, $NightsTable, Night> {
  $$NightsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: $_aliasNameGenerator(db.nights.nightKey, db.sessions.nightKey),
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager($_db, $_db.sessions).filter(
      (f) => f.nightKey.nightKey.sqlEquals($_itemColumn<String>('night_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NightsTableFilterComposer
    extends Composer<_$AppDatabase, $NightsTable> {
  $$NightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nightKey => $composableBuilder(
    column: $table.nightKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightDateEpochDay => $composableBuilder(
    column: $table.nightDateEpochDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endEpochMs => $composableBuilder(
    column: $table.endEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gapCount => $composableBuilder(
    column: $table.gapCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useSeconds => $composableBuilder(
    column: $table.useSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelsJson => $composableBuilder(
    column: $table.labelsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nightKey,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.nightKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NightsTableOrderingComposer
    extends Composer<_$AppDatabase, $NightsTable> {
  $$NightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nightKey => $composableBuilder(
    column: $table.nightKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightDateEpochDay => $composableBuilder(
    column: $table.nightDateEpochDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endEpochMs => $composableBuilder(
    column: $table.endEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gapCount => $composableBuilder(
    column: $table.gapCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useSeconds => $composableBuilder(
    column: $table.useSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelsJson => $composableBuilder(
    column: $table.labelsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NightsTable> {
  $$NightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nightKey =>
      $composableBuilder(column: $table.nightKey, builder: (column) => column);

  GeneratedColumn<int> get nightDateEpochDay => $composableBuilder(
    column: $table.nightDateEpochDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endEpochMs => $composableBuilder(
    column: $table.endEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionsCount => $composableBuilder(
    column: $table.sessionsCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gapCount =>
      $composableBuilder(column: $table.gapCount, builder: (column) => column);

  GeneratedColumn<int> get gapSeconds => $composableBuilder(
    column: $table.gapSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get useSeconds => $composableBuilder(
    column: $table.useSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get labelsJson => $composableBuilder(
    column: $table.labelsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nightKey,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.nightKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NightsTable,
          Night,
          $$NightsTableFilterComposer,
          $$NightsTableOrderingComposer,
          $$NightsTableAnnotationComposer,
          $$NightsTableCreateCompanionBuilder,
          $$NightsTableUpdateCompanionBuilder,
          (Night, $$NightsTableReferences),
          Night,
          PrefetchHooks Function({bool sessionsRefs})
        > {
  $$NightsTableTableManager(_$AppDatabase db, $NightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> nightKey = const Value.absent(),
                Value<int> nightDateEpochDay = const Value.absent(),
                Value<int> startEpochMs = const Value.absent(),
                Value<int> endEpochMs = const Value.absent(),
                Value<int> sessionsCount = const Value.absent(),
                Value<int> gapCount = const Value.absent(),
                Value<int> gapSeconds = const Value.absent(),
                Value<int> useSeconds = const Value.absent(),
                Value<String?> labelsJson = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NightsCompanion(
                nightKey: nightKey,
                nightDateEpochDay: nightDateEpochDay,
                startEpochMs: startEpochMs,
                endEpochMs: endEpochMs,
                sessionsCount: sessionsCount,
                gapCount: gapCount,
                gapSeconds: gapSeconds,
                useSeconds: useSeconds,
                labelsJson: labelsJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String nightKey,
                required int nightDateEpochDay,
                required int startEpochMs,
                required int endEpochMs,
                required int sessionsCount,
                Value<int> gapCount = const Value.absent(),
                Value<int> gapSeconds = const Value.absent(),
                Value<int> useSeconds = const Value.absent(),
                Value<String?> labelsJson = const Value.absent(),
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => NightsCompanion.insert(
                nightKey: nightKey,
                nightDateEpochDay: nightDateEpochDay,
                startEpochMs: startEpochMs,
                endEpochMs: endEpochMs,
                sessionsCount: sessionsCount,
                gapCount: gapCount,
                gapSeconds: gapSeconds,
                useSeconds: useSeconds,
                labelsJson: labelsJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NightsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<Night, $NightsTable, Session>(
                      currentTable: table,
                      referencedTable: $$NightsTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NightsTableReferences(db, table, p0).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.nightKey == item.nightKey,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NightsTable,
      Night,
      $$NightsTableFilterComposer,
      $$NightsTableOrderingComposer,
      $$NightsTableAnnotationComposer,
      $$NightsTableCreateCompanionBuilder,
      $$NightsTableUpdateCompanionBuilder,
      (Night, $$NightsTableReferences),
      Night,
      PrefetchHooks Function({bool sessionsRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String sessionKey,
      required String nightKey,
      required int startEpochMs,
      Value<int?> durationSeconds,
      required String bestType,
      required String bestFilePath,
      required String typesCsv,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> sessionKey,
      Value<String> nightKey,
      Value<int> startEpochMs,
      Value<int?> durationSeconds,
      Value<String> bestType,
      Value<String> bestFilePath,
      Value<String> typesCsv,
      Value<int> rowid,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NightsTable _nightKeyTable(_$AppDatabase db) => db.nights.createAlias(
    $_aliasNameGenerator(db.sessions.nightKey, db.nights.nightKey),
  );

  $$NightsTableProcessedTableManager get nightKey {
    final $_column = $_itemColumn<String>('night_key')!;

    final manager = $$NightsTableTableManager(
      $_db,
      $_db.nights,
    ).filter((f) => f.nightKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_nightKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bestType => $composableBuilder(
    column: $table.bestType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bestFilePath => $composableBuilder(
    column: $table.bestFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typesCsv => $composableBuilder(
    column: $table.typesCsv,
    builder: (column) => ColumnFilters(column),
  );

  $$NightsTableFilterComposer get nightKey {
    final $$NightsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nightKey,
      referencedTable: $db.nights,
      getReferencedColumn: (t) => t.nightKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NightsTableFilterComposer(
            $db: $db,
            $table: $db.nights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestType => $composableBuilder(
    column: $table.bestType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestFilePath => $composableBuilder(
    column: $table.bestFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typesCsv => $composableBuilder(
    column: $table.typesCsv,
    builder: (column) => ColumnOrderings(column),
  );

  $$NightsTableOrderingComposer get nightKey {
    final $$NightsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nightKey,
      referencedTable: $db.nights,
      getReferencedColumn: (t) => t.nightKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NightsTableOrderingComposer(
            $db: $db,
            $table: $db.nights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionKey => $composableBuilder(
    column: $table.sessionKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startEpochMs => $composableBuilder(
    column: $table.startEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bestType =>
      $composableBuilder(column: $table.bestType, builder: (column) => column);

  GeneratedColumn<String> get bestFilePath => $composableBuilder(
    column: $table.bestFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typesCsv =>
      $composableBuilder(column: $table.typesCsv, builder: (column) => column);

  $$NightsTableAnnotationComposer get nightKey {
    final $$NightsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nightKey,
      referencedTable: $db.nights,
      getReferencedColumn: (t) => t.nightKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NightsTableAnnotationComposer(
            $db: $db,
            $table: $db.nights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool nightKey})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionKey = const Value.absent(),
                Value<String> nightKey = const Value.absent(),
                Value<int> startEpochMs = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String> bestType = const Value.absent(),
                Value<String> bestFilePath = const Value.absent(),
                Value<String> typesCsv = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                sessionKey: sessionKey,
                nightKey: nightKey,
                startEpochMs: startEpochMs,
                durationSeconds: durationSeconds,
                bestType: bestType,
                bestFilePath: bestFilePath,
                typesCsv: typesCsv,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionKey,
                required String nightKey,
                required int startEpochMs,
                Value<int?> durationSeconds = const Value.absent(),
                required String bestType,
                required String bestFilePath,
                required String typesCsv,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                sessionKey: sessionKey,
                nightKey: nightKey,
                startEpochMs: startEpochMs,
                durationSeconds: durationSeconds,
                bestType: bestType,
                bestFilePath: bestFilePath,
                typesCsv: typesCsv,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({nightKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (nightKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.nightKey,
                                referencedTable: $$SessionsTableReferences
                                    ._nightKeyTable(db),
                                referencedColumn: $$SessionsTableReferences
                                    ._nightKeyTable(db)
                                    .nightKey,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool nightKey})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$NightsTableTableManager get nights =>
      $$NightsTableTableManager(_db, _db.nights);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
}
