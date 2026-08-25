// This is a generated file - do not edit.
//
// Generated from proto/lonisle.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'lonisle.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'lonisle.pbenum.dart';

/// 设备证书（M1 首设备自签；长期有效，不设 expires_at）
class DeviceCert extends $pb.GeneratedMessage {
  factory DeviceCert({
    $core.String? userId,
    $core.List<$core.int>? devicePubkey,
    $core.String? deviceName,
    $fixnum.Int64? issuedAt,
    $core.List<$core.int>? signature,
    $core.List<$core.int>? x25519Pubkey,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (devicePubkey != null) result.devicePubkey = devicePubkey;
    if (deviceName != null) result.deviceName = deviceName;
    if (issuedAt != null) result.issuedAt = issuedAt;
    if (signature != null) result.signature = signature;
    if (x25519Pubkey != null) result.x25519Pubkey = x25519Pubkey;
    return result;
  }

  DeviceCert._();

  factory DeviceCert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceCert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceCert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'devicePubkey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'deviceName')
    ..aInt64(4, _omitFieldNames ? '' : 'issuedAt')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'x25519Pubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceCert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceCert copyWith(void Function(DeviceCert) updates) =>
      super.copyWith((message) => updates(message as DeviceCert)) as DeviceCert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceCert create() => DeviceCert._();
  @$core.override
  DeviceCert createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceCert getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceCert>(create);
  static DeviceCert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get devicePubkey => $_getN(1);
  @$pb.TagNumber(2)
  set devicePubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDevicePubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearDevicePubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get deviceName => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceName() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get issuedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set issuedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIssuedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearIssuedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get signature => $_getN(4);
  @$pb.TagNumber(5)
  set signature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearSignature() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get x25519Pubkey => $_getN(5);
  @$pb.TagNumber(6)
  set x25519Pubkey($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasX25519Pubkey() => $_has(5);
  @$pb.TagNumber(6)
  void clearX25519Pubkey() => $_clearField(6);
}

/// 用户身份（加入时随 Hello 携带）
class Identity extends $pb.GeneratedMessage {
  factory Identity({
    $core.String? userId,
    $core.List<$core.int>? masterPubkey,
    $core.String? displayName,
    $core.String? avatarSeed,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (masterPubkey != null) result.masterPubkey = masterPubkey;
    if (displayName != null) result.displayName = displayName;
    if (avatarSeed != null) result.avatarSeed = avatarSeed;
    return result;
  }

  Identity._();

  factory Identity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Identity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Identity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'masterPubkey', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'avatarSeed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Identity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Identity copyWith(void Function(Identity) updates) =>
      super.copyWith((message) => updates(message as Identity)) as Identity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Identity create() => Identity._();
  @$core.override
  Identity createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Identity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Identity>(create);
  static Identity? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get masterPubkey => $_getN(1);
  @$pb.TagNumber(2)
  set masterPubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMasterPubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearMasterPubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get avatarSeed => $_getSZ(3);
  @$pb.TagNumber(4)
  set avatarSeed($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvatarSeed() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvatarSeed() => $_clearField(4);
}

/// 客户端 → 服务器：Hello 握手
class Hello extends $pb.GeneratedMessage {
  factory Hello({
    $core.int? protocolVersion,
    Identity? identity,
    DeviceCert? deviceCert,
    $core.List<$core.int>? deviceSignature,
    $core.String? botToken,
  }) {
    final result = create();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (identity != null) result.identity = identity;
    if (deviceCert != null) result.deviceCert = deviceCert;
    if (deviceSignature != null) result.deviceSignature = deviceSignature;
    if (botToken != null) result.botToken = botToken;
    return result;
  }

  Hello._();

  factory Hello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Hello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Hello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion')
    ..aOM<Identity>(2, _omitFieldNames ? '' : 'identity',
        subBuilder: Identity.create)
    ..aOM<DeviceCert>(3, _omitFieldNames ? '' : 'deviceCert',
        subBuilder: DeviceCert.create)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'deviceSignature', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'botToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello copyWith(void Function(Hello) updates) =>
      super.copyWith((message) => updates(message as Hello)) as Hello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Hello create() => Hello._();
  @$core.override
  Hello createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Hello getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Hello>(create);
  static Hello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  Identity get identity => $_getN(1);
  @$pb.TagNumber(2)
  set identity(Identity value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentity() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentity() => $_clearField(2);
  @$pb.TagNumber(2)
  Identity ensureIdentity() => $_ensure(1);

  @$pb.TagNumber(3)
  DeviceCert get deviceCert => $_getN(2);
  @$pb.TagNumber(3)
  set deviceCert(DeviceCert value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceCert() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceCert() => $_clearField(3);
  @$pb.TagNumber(3)
  DeviceCert ensureDeviceCert() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.List<$core.int> get deviceSignature => $_getN(3);
  @$pb.TagNumber(4)
  set deviceSignature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get botToken => $_getSZ(4);
  @$pb.TagNumber(5)
  set botToken($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBotToken() => $_has(4);
  @$pb.TagNumber(5)
  void clearBotToken() => $_clearField(5);
}

/// 服务器 → 客户端：Hello 响应
class HelloResponse extends $pb.GeneratedMessage {
  factory HelloResponse({
    $core.int? protocolVersion,
    $core.bool? compatible,
    $core.int? minSupported,
    $core.int? maxSupported,
    $core.String? serverId,
    $core.List<$core.int>? serverPubkey,
    $core.String? serverName,
    $core.String? serverDesc,
    $core.bool? isMember,
    $core.String? migrationTarget,
    $core.String? migrationFingerprint,
    $core.bool? avEnabled,
    $core.String? migrationSignature,
  }) {
    final result = create();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (compatible != null) result.compatible = compatible;
    if (minSupported != null) result.minSupported = minSupported;
    if (maxSupported != null) result.maxSupported = maxSupported;
    if (serverId != null) result.serverId = serverId;
    if (serverPubkey != null) result.serverPubkey = serverPubkey;
    if (serverName != null) result.serverName = serverName;
    if (serverDesc != null) result.serverDesc = serverDesc;
    if (isMember != null) result.isMember = isMember;
    if (migrationTarget != null) result.migrationTarget = migrationTarget;
    if (migrationFingerprint != null)
      result.migrationFingerprint = migrationFingerprint;
    if (avEnabled != null) result.avEnabled = avEnabled;
    if (migrationSignature != null)
      result.migrationSignature = migrationSignature;
    return result;
  }

  HelloResponse._();

  factory HelloResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HelloResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HelloResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion')
    ..aOB(2, _omitFieldNames ? '' : 'compatible')
    ..aI(3, _omitFieldNames ? '' : 'minSupported')
    ..aI(4, _omitFieldNames ? '' : 'maxSupported')
    ..aOS(5, _omitFieldNames ? '' : 'serverId')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'serverPubkey', $pb.PbFieldType.OY)
    ..aOS(7, _omitFieldNames ? '' : 'serverName')
    ..aOS(8, _omitFieldNames ? '' : 'serverDesc')
    ..aOB(9, _omitFieldNames ? '' : 'isMember')
    ..aOS(10, _omitFieldNames ? '' : 'migrationTarget')
    ..aOS(11, _omitFieldNames ? '' : 'migrationFingerprint')
    ..aOB(12, _omitFieldNames ? '' : 'avEnabled')
    ..aOS(13, _omitFieldNames ? '' : 'migrationSignature')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HelloResponse copyWith(void Function(HelloResponse) updates) =>
      super.copyWith((message) => updates(message as HelloResponse))
          as HelloResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HelloResponse create() => HelloResponse._();
  @$core.override
  HelloResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HelloResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HelloResponse>(create);
  static HelloResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get compatible => $_getBF(1);
  @$pb.TagNumber(2)
  set compatible($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompatible() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompatible() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get minSupported => $_getIZ(2);
  @$pb.TagNumber(3)
  set minSupported($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMinSupported() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinSupported() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxSupported => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxSupported($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxSupported() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxSupported() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get serverId => $_getSZ(4);
  @$pb.TagNumber(5)
  set serverId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasServerId() => $_has(4);
  @$pb.TagNumber(5)
  void clearServerId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get serverPubkey => $_getN(5);
  @$pb.TagNumber(6)
  set serverPubkey($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasServerPubkey() => $_has(5);
  @$pb.TagNumber(6)
  void clearServerPubkey() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get serverName => $_getSZ(6);
  @$pb.TagNumber(7)
  set serverName($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasServerName() => $_has(6);
  @$pb.TagNumber(7)
  void clearServerName() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get serverDesc => $_getSZ(7);
  @$pb.TagNumber(8)
  set serverDesc($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasServerDesc() => $_has(7);
  @$pb.TagNumber(8)
  void clearServerDesc() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isMember => $_getBF(8);
  @$pb.TagNumber(9)
  set isMember($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsMember() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsMember() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get migrationTarget => $_getSZ(9);
  @$pb.TagNumber(10)
  set migrationTarget($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMigrationTarget() => $_has(9);
  @$pb.TagNumber(10)
  void clearMigrationTarget() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get migrationFingerprint => $_getSZ(10);
  @$pb.TagNumber(11)
  set migrationFingerprint($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMigrationFingerprint() => $_has(10);
  @$pb.TagNumber(11)
  void clearMigrationFingerprint() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get avEnabled => $_getBF(11);
  @$pb.TagNumber(12)
  set avEnabled($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAvEnabled() => $_has(11);
  @$pb.TagNumber(12)
  void clearAvEnabled() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get migrationSignature => $_getSZ(12);
  @$pb.TagNumber(13)
  set migrationSignature($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasMigrationSignature() => $_has(12);
  @$pb.TagNumber(13)
  void clearMigrationSignature() => $_clearField(13);
}

/// 客户端 → 服务器：开放加入申请（M1 无审批，即加入）
class JoinRequest extends $pb.GeneratedMessage {
  factory JoinRequest({
    $core.String? reason,
    $core.String? pushServiceUrl,
    Identity? identity,
    $core.String? claimCode,
    $core.String? inviteToken,
  }) {
    final result = create();
    if (reason != null) result.reason = reason;
    if (pushServiceUrl != null) result.pushServiceUrl = pushServiceUrl;
    if (identity != null) result.identity = identity;
    if (claimCode != null) result.claimCode = claimCode;
    if (inviteToken != null) result.inviteToken = inviteToken;
    return result;
  }

  JoinRequest._();

  factory JoinRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..aOS(2, _omitFieldNames ? '' : 'pushServiceUrl')
    ..aOM<Identity>(3, _omitFieldNames ? '' : 'identity',
        subBuilder: Identity.create)
    ..aOS(4, _omitFieldNames ? '' : 'claimCode')
    ..aOS(5, _omitFieldNames ? '' : 'inviteToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequest copyWith(void Function(JoinRequest) updates) =>
      super.copyWith((message) => updates(message as JoinRequest))
          as JoinRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinRequest create() => JoinRequest._();
  @$core.override
  JoinRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinRequest>(create);
  static JoinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pushServiceUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set pushServiceUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPushServiceUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearPushServiceUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  Identity get identity => $_getN(2);
  @$pb.TagNumber(3)
  set identity(Identity value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasIdentity() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdentity() => $_clearField(3);
  @$pb.TagNumber(3)
  Identity ensureIdentity() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get claimCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set claimCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClaimCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearClaimCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get inviteToken => $_getSZ(4);
  @$pb.TagNumber(5)
  set inviteToken($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInviteToken() => $_has(4);
  @$pb.TagNumber(5)
  void clearInviteToken() => $_clearField(5);
}

/// 服务器 → 客户端：加入结果
class JoinResponse extends $pb.GeneratedMessage {
  factory JoinResponse({
    $core.bool? accepted,
    $core.String? reason,
    $core.bool? isOwner,
    ServerInfo? serverInfo,
    $core.Iterable<TopicInfo>? topics,
    JoinStatus? status,
    $core.String? requestId,
    JoinStrategy? strategy,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    if (reason != null) result.reason = reason;
    if (isOwner != null) result.isOwner = isOwner;
    if (serverInfo != null) result.serverInfo = serverInfo;
    if (topics != null) result.topics.addAll(topics);
    if (status != null) result.status = status;
    if (requestId != null) result.requestId = requestId;
    if (strategy != null) result.strategy = strategy;
    return result;
  }

  JoinResponse._();

  factory JoinResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aOB(3, _omitFieldNames ? '' : 'isOwner')
    ..aOM<ServerInfo>(4, _omitFieldNames ? '' : 'serverInfo',
        subBuilder: ServerInfo.create)
    ..pPM<TopicInfo>(5, _omitFieldNames ? '' : 'topics',
        subBuilder: TopicInfo.create)
    ..aE<JoinStatus>(6, _omitFieldNames ? '' : 'status',
        enumValues: JoinStatus.values)
    ..aOS(7, _omitFieldNames ? '' : 'requestId')
    ..aE<JoinStrategy>(8, _omitFieldNames ? '' : 'strategy',
        enumValues: JoinStrategy.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinResponse copyWith(void Function(JoinResponse) updates) =>
      super.copyWith((message) => updates(message as JoinResponse))
          as JoinResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinResponse create() => JoinResponse._();
  @$core.override
  JoinResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinResponse>(create);
  static JoinResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isOwner => $_getBF(2);
  @$pb.TagNumber(3)
  set isOwner($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsOwner() => $_clearField(3);

  @$pb.TagNumber(4)
  ServerInfo get serverInfo => $_getN(3);
  @$pb.TagNumber(4)
  set serverInfo(ServerInfo value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasServerInfo() => $_has(3);
  @$pb.TagNumber(4)
  void clearServerInfo() => $_clearField(4);
  @$pb.TagNumber(4)
  ServerInfo ensureServerInfo() => $_ensure(3);

  @$pb.TagNumber(5)
  $pb.PbList<TopicInfo> get topics => $_getList(4);

  @$pb.TagNumber(6)
  JoinStatus get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(JoinStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get requestId => $_getSZ(6);
  @$pb.TagNumber(7)
  set requestId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRequestId() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequestId() => $_clearField(7);

  @$pb.TagNumber(8)
  JoinStrategy get strategy => $_getN(7);
  @$pb.TagNumber(8)
  set strategy(JoinStrategy value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasStrategy() => $_has(7);
  @$pb.TagNumber(8)
  void clearStrategy() => $_clearField(8);
}

class ServerInfo extends $pb.GeneratedMessage {
  factory ServerInfo({
    $core.String? serverId,
    $core.String? name,
    $core.String? description,
    $core.String? fingerprint,
    JoinStrategy? strategy,
    $core.String? icon,
    $core.int? rateLimitPerMinute,
    $fixnum.Int64? maxAttachmentSize,
    $fixnum.Int64? attachmentQuota,
  }) {
    final result = create();
    if (serverId != null) result.serverId = serverId;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (fingerprint != null) result.fingerprint = fingerprint;
    if (strategy != null) result.strategy = strategy;
    if (icon != null) result.icon = icon;
    if (rateLimitPerMinute != null)
      result.rateLimitPerMinute = rateLimitPerMinute;
    if (maxAttachmentSize != null) result.maxAttachmentSize = maxAttachmentSize;
    if (attachmentQuota != null) result.attachmentQuota = attachmentQuota;
    return result;
  }

  ServerInfo._();

  factory ServerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'fingerprint')
    ..aE<JoinStrategy>(5, _omitFieldNames ? '' : 'strategy',
        enumValues: JoinStrategy.values)
    ..aOS(6, _omitFieldNames ? '' : 'icon')
    ..aI(7, _omitFieldNames ? '' : 'rateLimitPerMinute',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'maxAttachmentSize', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'attachmentQuota', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerInfo copyWith(void Function(ServerInfo) updates) =>
      super.copyWith((message) => updates(message as ServerInfo)) as ServerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerInfo create() => ServerInfo._();
  @$core.override
  ServerInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerInfo>(create);
  static ServerInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get serverId => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get fingerprint => $_getSZ(3);
  @$pb.TagNumber(4)
  set fingerprint($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFingerprint() => $_has(3);
  @$pb.TagNumber(4)
  void clearFingerprint() => $_clearField(4);

  @$pb.TagNumber(5)
  JoinStrategy get strategy => $_getN(4);
  @$pb.TagNumber(5)
  set strategy(JoinStrategy value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStrategy() => $_has(4);
  @$pb.TagNumber(5)
  void clearStrategy() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get icon => $_getSZ(5);
  @$pb.TagNumber(6)
  set icon($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIcon() => $_has(5);
  @$pb.TagNumber(6)
  void clearIcon() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get rateLimitPerMinute => $_getIZ(6);
  @$pb.TagNumber(7)
  set rateLimitPerMinute($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRateLimitPerMinute() => $_has(6);
  @$pb.TagNumber(7)
  void clearRateLimitPerMinute() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get maxAttachmentSize => $_getI64(7);
  @$pb.TagNumber(8)
  set maxAttachmentSize($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMaxAttachmentSize() => $_has(7);
  @$pb.TagNumber(8)
  void clearMaxAttachmentSize() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get attachmentQuota => $_getI64(8);
  @$pb.TagNumber(9)
  set attachmentQuota($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAttachmentQuota() => $_has(8);
  @$pb.TagNumber(9)
  void clearAttachmentQuota() => $_clearField(9);
}

/// 管理员 → 服务器：更新服务器设置
class UpdateServerSettingsRequest extends $pb.GeneratedMessage {
  factory UpdateServerSettingsRequest({
    $core.String? name,
    $core.String? description,
    JoinStrategy? strategy,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (strategy != null) result.strategy = strategy;
    return result;
  }

  UpdateServerSettingsRequest._();

  factory UpdateServerSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateServerSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateServerSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aE<JoinStrategy>(3, _omitFieldNames ? '' : 'strategy',
        enumValues: JoinStrategy.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateServerSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateServerSettingsRequest copyWith(
          void Function(UpdateServerSettingsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateServerSettingsRequest))
          as UpdateServerSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateServerSettingsRequest create() =>
      UpdateServerSettingsRequest._();
  @$core.override
  UpdateServerSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateServerSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateServerSettingsRequest>(create);
  static UpdateServerSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  JoinStrategy get strategy => $_getN(2);
  @$pb.TagNumber(3)
  set strategy(JoinStrategy value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStrategy() => $_has(2);
  @$pb.TagNumber(3)
  void clearStrategy() => $_clearField(3);
}

class TopicInfo extends $pb.GeneratedMessage {
  factory TopicInfo({
    $core.String? topicId,
    $core.String? name,
    $core.String? description,
    $core.int? sortOrder,
    TopicType? type,
    TopicPermission? permission,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (type != null) result.type = type;
    if (permission != null) result.permission = permission;
    return result;
  }

  TopicInfo._();

  factory TopicInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TopicInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TopicInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aI(4, _omitFieldNames ? '' : 'sortOrder')
    ..aE<TopicType>(5, _omitFieldNames ? '' : 'type',
        enumValues: TopicType.values)
    ..aE<TopicPermission>(6, _omitFieldNames ? '' : 'permission',
        enumValues: TopicPermission.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicInfo copyWith(void Function(TopicInfo) updates) =>
      super.copyWith((message) => updates(message as TopicInfo)) as TopicInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TopicInfo create() => TopicInfo._();
  @$core.override
  TopicInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TopicInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TopicInfo>(create);
  static TopicInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sortOrder => $_getIZ(3);
  @$pb.TagNumber(4)
  set sortOrder($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSortOrder() => $_has(3);
  @$pb.TagNumber(4)
  void clearSortOrder() => $_clearField(4);

  @$pb.TagNumber(5)
  TopicType get type => $_getN(4);
  @$pb.TagNumber(5)
  set type(TopicType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => $_clearField(5);

  @$pb.TagNumber(6)
  TopicPermission get permission => $_getN(5);
  @$pb.TagNumber(6)
  set permission(TopicPermission value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPermission() => $_has(5);
  @$pb.TagNumber(6)
  void clearPermission() => $_clearField(6);
}

/// 客户端 → 服务器：申请加入音视频话题（AV，LiveKit）
class JoinAVRequest extends $pb.GeneratedMessage {
  factory JoinAVRequest({
    $core.String? topicId,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    return result;
  }

  JoinAVRequest._();

  factory JoinAVRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinAVRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinAVRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinAVRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinAVRequest copyWith(void Function(JoinAVRequest) updates) =>
      super.copyWith((message) => updates(message as JoinAVRequest))
          as JoinAVRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinAVRequest create() => JoinAVRequest._();
  @$core.override
  JoinAVRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinAVRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinAVRequest>(create);
  static JoinAVRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);
}

/// 服务器 → 客户端：音视频加入响应（含 LiveKit 地址与短时 Token）
class JoinAVResponse extends $pb.GeneratedMessage {
  factory JoinAVResponse({
    $core.String? url,
    $core.String? token,
  }) {
    final result = create();
    if (url != null) result.url = url;
    if (token != null) result.token = token;
    return result;
  }

  JoinAVResponse._();

  factory JoinAVResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinAVResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinAVResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinAVResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinAVResponse copyWith(void Function(JoinAVResponse) updates) =>
      super.copyWith((message) => updates(message as JoinAVResponse))
          as JoinAVResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinAVResponse create() => JoinAVResponse._();
  @$core.override
  JoinAVResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinAVResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinAVResponse>(create);
  static JoinAVResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

/// 管理员 → 服务器：创建话题
class CreateTopicRequest extends $pb.GeneratedMessage {
  factory CreateTopicRequest({
    $core.String? name,
    $core.String? description,
    TopicType? type,
    TopicPermission? permission,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (type != null) result.type = type;
    if (permission != null) result.permission = permission;
    return result;
  }

  CreateTopicRequest._();

  factory CreateTopicRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTopicRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTopicRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aE<TopicType>(3, _omitFieldNames ? '' : 'type',
        enumValues: TopicType.values)
    ..aE<TopicPermission>(4, _omitFieldNames ? '' : 'permission',
        enumValues: TopicPermission.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTopicRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTopicRequest copyWith(void Function(CreateTopicRequest) updates) =>
      super.copyWith((message) => updates(message as CreateTopicRequest))
          as CreateTopicRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTopicRequest create() => CreateTopicRequest._();
  @$core.override
  CreateTopicRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTopicRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTopicRequest>(create);
  static CreateTopicRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  TopicType get type => $_getN(2);
  @$pb.TagNumber(3)
  set type(TopicType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  TopicPermission get permission => $_getN(3);
  @$pb.TagNumber(4)
  set permission(TopicPermission value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPermission() => $_has(3);
  @$pb.TagNumber(4)
  void clearPermission() => $_clearField(4);
}

/// 管理员 → 服务器：编辑话题
class UpdateTopicRequest extends $pb.GeneratedMessage {
  factory UpdateTopicRequest({
    $core.String? topicId,
    $core.String? name,
    $core.String? description,
    TopicType? type,
    TopicPermission? permission,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (type != null) result.type = type;
    if (permission != null) result.permission = permission;
    return result;
  }

  UpdateTopicRequest._();

  factory UpdateTopicRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTopicRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTopicRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aE<TopicType>(4, _omitFieldNames ? '' : 'type',
        enumValues: TopicType.values)
    ..aE<TopicPermission>(5, _omitFieldNames ? '' : 'permission',
        enumValues: TopicPermission.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTopicRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTopicRequest copyWith(void Function(UpdateTopicRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateTopicRequest))
          as UpdateTopicRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTopicRequest create() => UpdateTopicRequest._();
  @$core.override
  UpdateTopicRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTopicRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTopicRequest>(create);
  static UpdateTopicRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  TopicType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(TopicType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  TopicPermission get permission => $_getN(4);
  @$pb.TagNumber(5)
  set permission(TopicPermission value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPermission() => $_has(4);
  @$pb.TagNumber(5)
  void clearPermission() => $_clearField(5);
}

/// 管理员 → 服务器：删除话题
class DeleteTopicRequest extends $pb.GeneratedMessage {
  factory DeleteTopicRequest({
    $core.String? topicId,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    return result;
  }

  DeleteTopicRequest._();

  factory DeleteTopicRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTopicRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTopicRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTopicRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTopicRequest copyWith(void Function(DeleteTopicRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteTopicRequest))
          as DeleteTopicRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTopicRequest create() => DeleteTopicRequest._();
  @$core.override
  DeleteTopicRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTopicRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTopicRequest>(create);
  static DeleteTopicRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);
}

/// 管理员 → 服务器：话题排序
class ReorderTopicsRequest extends $pb.GeneratedMessage {
  factory ReorderTopicsRequest({
    $core.Iterable<$core.String>? topicIds,
  }) {
    final result = create();
    if (topicIds != null) result.topicIds.addAll(topicIds);
    return result;
  }

  ReorderTopicsRequest._();

  factory ReorderTopicsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderTopicsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderTopicsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'topicIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTopicsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTopicsRequest copyWith(void Function(ReorderTopicsRequest) updates) =>
      super.copyWith((message) => updates(message as ReorderTopicsRequest))
          as ReorderTopicsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderTopicsRequest create() => ReorderTopicsRequest._();
  @$core.override
  ReorderTopicsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderTopicsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderTopicsRequest>(create);
  static ReorderTopicsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get topicIds => $_getList(0);
}

/// 服务器 → 客户端：话题列表响应（复用 ListTopicsRequest 触发）
class TopicListResponse extends $pb.GeneratedMessage {
  factory TopicListResponse({
    $core.Iterable<TopicInfo>? topics,
  }) {
    final result = create();
    if (topics != null) result.topics.addAll(topics);
    return result;
  }

  TopicListResponse._();

  factory TopicListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TopicListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TopicListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<TopicInfo>(1, _omitFieldNames ? '' : 'topics',
        subBuilder: TopicInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TopicListResponse copyWith(void Function(TopicListResponse) updates) =>
      super.copyWith((message) => updates(message as TopicListResponse))
          as TopicListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TopicListResponse create() => TopicListResponse._();
  @$core.override
  TopicListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TopicListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TopicListResponse>(create);
  static TopicListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TopicInfo> get topics => $_getList(0);
}

/// 消息内容（文本 + 可选附件 + 可选加密）
class MessageContent extends $pb.GeneratedMessage {
  factory MessageContent({
    $core.String? text,
    Attachment? attachment,
    $core.List<$core.int>? encrypted,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (attachment != null) result.attachment = attachment;
    if (encrypted != null) result.encrypted = encrypted;
    return result;
  }

  MessageContent._();

  factory MessageContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageContent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOM<Attachment>(2, _omitFieldNames ? '' : 'attachment',
        subBuilder: Attachment.create)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'encrypted', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageContent copyWith(void Function(MessageContent) updates) =>
      super.copyWith((message) => updates(message as MessageContent))
          as MessageContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageContent create() => MessageContent._();
  @$core.override
  MessageContent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageContent>(create);
  static MessageContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  Attachment get attachment => $_getN(1);
  @$pb.TagNumber(2)
  set attachment(Attachment value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAttachment() => $_has(1);
  @$pb.TagNumber(2)
  void clearAttachment() => $_clearField(2);
  @$pb.TagNumber(2)
  Attachment ensureAttachment() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get encrypted => $_getN(2);
  @$pb.TagNumber(3)
  set encrypted($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEncrypted() => $_has(2);
  @$pb.TagNumber(3)
  void clearEncrypted() => $_clearField(3);
}

/// 附件元数据（随消息体同步，未下载原文件也可渲染占位）
class Attachment extends $pb.GeneratedMessage {
  factory Attachment({
    $core.String? attachmentId,
    $core.String? kind,
    $fixnum.Int64? size,
    $core.String? mime,
    $core.int? width,
    $core.int? height,
    $core.int? duration,
    $core.String? thumbnailId,
    $core.String? filename,
  }) {
    final result = create();
    if (attachmentId != null) result.attachmentId = attachmentId;
    if (kind != null) result.kind = kind;
    if (size != null) result.size = size;
    if (mime != null) result.mime = mime;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (duration != null) result.duration = duration;
    if (thumbnailId != null) result.thumbnailId = thumbnailId;
    if (filename != null) result.filename = filename;
    return result;
  }

  Attachment._();

  factory Attachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Attachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Attachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attachmentId')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'mime')
    ..aI(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'duration', fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'thumbnailId')
    ..aOS(9, _omitFieldNames ? '' : 'filename')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attachment copyWith(void Function(Attachment) updates) =>
      super.copyWith((message) => updates(message as Attachment)) as Attachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attachment create() => Attachment._();
  @$core.override
  Attachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Attachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Attachment>(create);
  static Attachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get attachmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attachmentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttachmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttachmentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mime => $_getSZ(3);
  @$pb.TagNumber(4)
  set mime($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMime() => $_has(3);
  @$pb.TagNumber(4)
  void clearMime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get width => $_getIZ(4);
  @$pb.TagNumber(5)
  set width($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get height => $_getIZ(5);
  @$pb.TagNumber(6)
  set height($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get duration => $_getIZ(6);
  @$pb.TagNumber(7)
  set duration($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDuration() => $_has(6);
  @$pb.TagNumber(7)
  void clearDuration() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get thumbnailId => $_getSZ(7);
  @$pb.TagNumber(8)
  set thumbnailId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasThumbnailId() => $_has(7);
  @$pb.TagNumber(8)
  void clearThumbnailId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get filename => $_getSZ(8);
  @$pb.TagNumber(9)
  set filename($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFilename() => $_has(8);
  @$pb.TagNumber(9)
  void clearFilename() => $_clearField(9);
}

/// 表情回应（Reaction）
class Reaction extends $pb.GeneratedMessage {
  factory Reaction({
    $core.String? emoji,
    $core.Iterable<$core.String>? userId,
  }) {
    final result = create();
    if (emoji != null) result.emoji = emoji;
    if (userId != null) result.userId.addAll(userId);
    return result;
  }

  Reaction._();

  factory Reaction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Reaction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Reaction',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'emoji')
    ..pPS(2, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reaction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reaction copyWith(void Function(Reaction) updates) =>
      super.copyWith((message) => updates(message as Reaction)) as Reaction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Reaction create() => Reaction._();
  @$core.override
  Reaction createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Reaction getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Reaction>(create);
  static Reaction? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get emoji => $_getSZ(0);
  @$pb.TagNumber(1)
  set emoji($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmoji() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmoji() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get userId => $_getList(1);
}

/// 客户端 → 服务器：发送消息
class SendMessage extends $pb.GeneratedMessage {
  factory SendMessage({
    $core.String? topicId,
    $core.String? msgId,
    $core.List<$core.int>? authorId,
    $core.String? deviceId,
    $fixnum.Int64? clientTs,
    MessageContent? content,
    $core.List<$core.int>? signature,
    $core.String? replyTo,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (authorId != null) result.authorId = authorId;
    if (deviceId != null) result.deviceId = deviceId;
    if (clientTs != null) result.clientTs = clientTs;
    if (content != null) result.content = content;
    if (signature != null) result.signature = signature;
    if (replyTo != null) result.replyTo = replyTo;
    return result;
  }

  SendMessage._();

  factory SendMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'authorId', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'deviceId')
    ..aInt64(5, _omitFieldNames ? '' : 'clientTs')
    ..aOM<MessageContent>(6, _omitFieldNames ? '' : 'content',
        subBuilder: MessageContent.create)
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aOS(8, _omitFieldNames ? '' : 'replyTo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessage copyWith(void Function(SendMessage) updates) =>
      super.copyWith((message) => updates(message as SendMessage))
          as SendMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMessage create() => SendMessage._();
  @$core.override
  SendMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMessage>(create);
  static SendMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get authorId => $_getN(2);
  @$pb.TagNumber(3)
  set authorId($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAuthorId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthorId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get clientTs => $_getI64(4);
  @$pb.TagNumber(5)
  set clientTs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientTs() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientTs() => $_clearField(5);

  @$pb.TagNumber(6)
  MessageContent get content => $_getN(5);
  @$pb.TagNumber(6)
  set content(MessageContent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasContent() => $_has(5);
  @$pb.TagNumber(6)
  void clearContent() => $_clearField(6);
  @$pb.TagNumber(6)
  MessageContent ensureContent() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.List<$core.int> get signature => $_getN(6);
  @$pb.TagNumber(7)
  set signature($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSignature() => $_has(6);
  @$pb.TagNumber(7)
  void clearSignature() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get replyTo => $_getSZ(7);
  @$pb.TagNumber(8)
  set replyTo($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReplyTo() => $_has(7);
  @$pb.TagNumber(8)
  void clearReplyTo() => $_clearField(8);
}

/// 服务器 → 客户端：消息回执（含服务器分配的序号）
class SendMessageAck extends $pb.GeneratedMessage {
  factory SendMessageAck({
    $core.String? msgId,
    $fixnum.Int64? seq,
    $core.bool? duplicated,
  }) {
    final result = create();
    if (msgId != null) result.msgId = msgId;
    if (seq != null) result.seq = seq;
    if (duplicated != null) result.duplicated = duplicated;
    return result;
  }

  SendMessageAck._();

  factory SendMessageAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendMessageAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendMessageAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'msgId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(3, _omitFieldNames ? '' : 'duplicated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendMessageAck copyWith(void Function(SendMessageAck) updates) =>
      super.copyWith((message) => updates(message as SendMessageAck))
          as SendMessageAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendMessageAck create() => SendMessageAck._();
  @$core.override
  SendMessageAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendMessageAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendMessageAck>(create);
  static SendMessageAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get msgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set msgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsgId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get duplicated => $_getBF(2);
  @$pb.TagNumber(3)
  set duplicated($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDuplicated() => $_has(2);
  @$pb.TagNumber(3)
  void clearDuplicated() => $_clearField(3);
}

/// 服务器 → 客户端：广播消息（含完整序号与服务器时间）
class BroadcastMessage extends $pb.GeneratedMessage {
  factory BroadcastMessage({
    $fixnum.Int64? seq,
    $core.String? topicId,
    $core.String? msgId,
    $core.List<$core.int>? authorId,
    $core.String? deviceId,
    $core.String? authorName,
    $fixnum.Int64? serverTs,
    MessageContent? content,
    $core.bool? edited,
    $core.bool? deleted,
    $core.String? mentions,
    $core.Iterable<Reaction>? reactions,
    $core.String? replyTo,
  }) {
    final result = create();
    if (seq != null) result.seq = seq;
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (authorId != null) result.authorId = authorId;
    if (deviceId != null) result.deviceId = deviceId;
    if (authorName != null) result.authorName = authorName;
    if (serverTs != null) result.serverTs = serverTs;
    if (content != null) result.content = content;
    if (edited != null) result.edited = edited;
    if (deleted != null) result.deleted = deleted;
    if (mentions != null) result.mentions = mentions;
    if (reactions != null) result.reactions.addAll(reactions);
    if (replyTo != null) result.replyTo = replyTo;
    return result;
  }

  BroadcastMessage._();

  factory BroadcastMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BroadcastMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BroadcastMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'topicId')
    ..aOS(3, _omitFieldNames ? '' : 'msgId')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'authorId', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'deviceId')
    ..aOS(6, _omitFieldNames ? '' : 'authorName')
    ..aInt64(7, _omitFieldNames ? '' : 'serverTs')
    ..aOM<MessageContent>(8, _omitFieldNames ? '' : 'content',
        subBuilder: MessageContent.create)
    ..aOB(9, _omitFieldNames ? '' : 'edited')
    ..aOB(10, _omitFieldNames ? '' : 'deleted')
    ..aOS(11, _omitFieldNames ? '' : 'mentions')
    ..pPM<Reaction>(12, _omitFieldNames ? '' : 'reactions',
        subBuilder: Reaction.create)
    ..aOS(13, _omitFieldNames ? '' : 'replyTo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BroadcastMessage copyWith(void Function(BroadcastMessage) updates) =>
      super.copyWith((message) => updates(message as BroadcastMessage))
          as BroadcastMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BroadcastMessage create() => BroadcastMessage._();
  @$core.override
  BroadcastMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BroadcastMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BroadcastMessage>(create);
  static BroadcastMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get topicId => $_getSZ(1);
  @$pb.TagNumber(2)
  set topicId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTopicId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTopicId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get msgId => $_getSZ(2);
  @$pb.TagNumber(3)
  set msgId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMsgId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMsgId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get authorId => $_getN(3);
  @$pb.TagNumber(4)
  set authorId($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthorId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get deviceId => $_getSZ(4);
  @$pb.TagNumber(5)
  set deviceId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeviceId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeviceId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get authorName => $_getSZ(5);
  @$pb.TagNumber(6)
  set authorName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAuthorName() => $_has(5);
  @$pb.TagNumber(6)
  void clearAuthorName() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get serverTs => $_getI64(6);
  @$pb.TagNumber(7)
  set serverTs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasServerTs() => $_has(6);
  @$pb.TagNumber(7)
  void clearServerTs() => $_clearField(7);

  @$pb.TagNumber(8)
  MessageContent get content => $_getN(7);
  @$pb.TagNumber(8)
  set content(MessageContent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasContent() => $_has(7);
  @$pb.TagNumber(8)
  void clearContent() => $_clearField(8);
  @$pb.TagNumber(8)
  MessageContent ensureContent() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.bool get edited => $_getBF(8);
  @$pb.TagNumber(9)
  set edited($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEdited() => $_has(8);
  @$pb.TagNumber(9)
  void clearEdited() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get deleted => $_getBF(9);
  @$pb.TagNumber(10)
  set deleted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDeleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearDeleted() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get mentions => $_getSZ(10);
  @$pb.TagNumber(11)
  set mentions($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMentions() => $_has(10);
  @$pb.TagNumber(11)
  void clearMentions() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<Reaction> get reactions => $_getList(11);

  @$pb.TagNumber(13)
  $core.String get replyTo => $_getSZ(12);
  @$pb.TagNumber(13)
  set replyTo($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasReplyTo() => $_has(12);
  @$pb.TagNumber(13)
  void clearReplyTo() => $_clearField(13);
}

/// 客户端 → 服务器：编辑消息
class EditMessageRequest extends $pb.GeneratedMessage {
  factory EditMessageRequest({
    $core.String? topicId,
    $core.String? msgId,
    $core.String? newText,
    $core.List<$core.int>? signature,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (newText != null) result.newText = newText;
    if (signature != null) result.signature = signature;
    return result;
  }

  EditMessageRequest._();

  factory EditMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditMessageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..aOS(3, _omitFieldNames ? '' : 'newText')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMessageRequest copyWith(void Function(EditMessageRequest) updates) =>
      super.copyWith((message) => updates(message as EditMessageRequest))
          as EditMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditMessageRequest create() => EditMessageRequest._();
  @$core.override
  EditMessageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditMessageRequest>(create);
  static EditMessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get newText => $_getSZ(2);
  @$pb.TagNumber(3)
  set newText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewText() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);
}

/// 客户端 → 服务器：删除消息
class DeleteMessageRequest extends $pb.GeneratedMessage {
  factory DeleteMessageRequest({
    $core.String? topicId,
    $core.String? msgId,
    $core.List<$core.int>? signature,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (signature != null) result.signature = signature;
    return result;
  }

  DeleteMessageRequest._();

  factory DeleteMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteMessageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMessageRequest copyWith(void Function(DeleteMessageRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteMessageRequest))
          as DeleteMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteMessageRequest create() => DeleteMessageRequest._();
  @$core.override
  DeleteMessageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteMessageRequest>(create);
  static DeleteMessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);
}

/// 客户端 → 服务器：添加表情回应（Reaction）
class AddReactionRequest extends $pb.GeneratedMessage {
  factory AddReactionRequest({
    $core.String? topicId,
    $core.String? msgId,
    $core.String? emoji,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (emoji != null) result.emoji = emoji;
    return result;
  }

  AddReactionRequest._();

  factory AddReactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddReactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddReactionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..aOS(3, _omitFieldNames ? '' : 'emoji')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddReactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddReactionRequest copyWith(void Function(AddReactionRequest) updates) =>
      super.copyWith((message) => updates(message as AddReactionRequest))
          as AddReactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddReactionRequest create() => AddReactionRequest._();
  @$core.override
  AddReactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddReactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddReactionRequest>(create);
  static AddReactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get emoji => $_getSZ(2);
  @$pb.TagNumber(3)
  set emoji($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmoji() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmoji() => $_clearField(3);
}

/// 客户端 → 服务器：移除表情回应
class RemoveReactionRequest extends $pb.GeneratedMessage {
  factory RemoveReactionRequest({
    $core.String? topicId,
    $core.String? msgId,
    $core.String? emoji,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    if (emoji != null) result.emoji = emoji;
    return result;
  }

  RemoveReactionRequest._();

  factory RemoveReactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveReactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveReactionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..aOS(3, _omitFieldNames ? '' : 'emoji')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveReactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveReactionRequest copyWith(
          void Function(RemoveReactionRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveReactionRequest))
          as RemoveReactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveReactionRequest create() => RemoveReactionRequest._();
  @$core.override
  RemoveReactionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveReactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveReactionRequest>(create);
  static RemoveReactionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get emoji => $_getSZ(2);
  @$pb.TagNumber(3)
  set emoji($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmoji() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmoji() => $_clearField(3);
}

/// 客户端 → 服务器：标记 @提及已读（P2 已读回执）
class MarkMentionReadRequest extends $pb.GeneratedMessage {
  factory MarkMentionReadRequest({
    $core.String? topicId,
    $core.String? msgId,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (msgId != null) result.msgId = msgId;
    return result;
  }

  MarkMentionReadRequest._();

  factory MarkMentionReadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkMentionReadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkMentionReadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..aOS(2, _omitFieldNames ? '' : 'msgId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkMentionReadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkMentionReadRequest copyWith(
          void Function(MarkMentionReadRequest) updates) =>
      super.copyWith((message) => updates(message as MarkMentionReadRequest))
          as MarkMentionReadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkMentionReadRequest create() => MarkMentionReadRequest._();
  @$core.override
  MarkMentionReadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkMentionReadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkMentionReadRequest>(create);
  static MarkMentionReadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgId => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgId() => $_clearField(2);
}

/// 客户端 → 服务器：查询某消息的已读列表（P2）
class MentionReadListRequest extends $pb.GeneratedMessage {
  factory MentionReadListRequest({
    $core.String? msgId,
  }) {
    final result = create();
    if (msgId != null) result.msgId = msgId;
    return result;
  }

  MentionReadListRequest._();

  factory MentionReadListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MentionReadListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MentionReadListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'msgId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MentionReadListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MentionReadListRequest copyWith(
          void Function(MentionReadListRequest) updates) =>
      super.copyWith((message) => updates(message as MentionReadListRequest))
          as MentionReadListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MentionReadListRequest create() => MentionReadListRequest._();
  @$core.override
  MentionReadListRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MentionReadListRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MentionReadListRequest>(create);
  static MentionReadListRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get msgId => $_getSZ(0);
  @$pb.TagNumber(1)
  set msgId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMsgId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsgId() => $_clearField(1);
}

/// 服务器 → 客户端：已读列表响应
class MentionReadListResponse extends $pb.GeneratedMessage {
  factory MentionReadListResponse({
    $core.Iterable<$core.String>? userId,
    $fixnum.Int64? readAt,
  }) {
    final result = create();
    if (userId != null) result.userId.addAll(userId);
    if (readAt != null) result.readAt = readAt;
    return result;
  }

  MentionReadListResponse._();

  factory MentionReadListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MentionReadListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MentionReadListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'userId')
    ..aInt64(2, _omitFieldNames ? '' : 'readAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MentionReadListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MentionReadListResponse copyWith(
          void Function(MentionReadListResponse) updates) =>
      super.copyWith((message) => updates(message as MentionReadListResponse))
          as MentionReadListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MentionReadListResponse create() => MentionReadListResponse._();
  @$core.override
  MentionReadListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MentionReadListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MentionReadListResponse>(create);
  static MentionReadListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get userId => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get readAt => $_getI64(1);
  @$pb.TagNumber(2)
  set readAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReadAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearReadAt() => $_clearField(2);
}

/// 客户端 → 服务器：增量同步请求（按游标）
class SyncRequest extends $pb.GeneratedMessage {
  factory SyncRequest({
    $core.String? topicId,
    $fixnum.Int64? afterSeq,
    $core.int? limit,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (afterSeq != null) result.afterSeq = afterSeq;
    if (limit != null) result.limit = limit;
    return result;
  }

  SyncRequest._();

  factory SyncRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'afterSeq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest copyWith(void Function(SyncRequest) updates) =>
      super.copyWith((message) => updates(message as SyncRequest))
          as SyncRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncRequest create() => SyncRequest._();
  @$core.override
  SyncRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncRequest>(create);
  static SyncRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get afterSeq => $_getI64(1);
  @$pb.TagNumber(2)
  set afterSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAfterSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearAfterSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

/// 服务器 → 客户端：增量同步响应
class SyncResponse extends $pb.GeneratedMessage {
  factory SyncResponse({
    $core.String? topicId,
    $fixnum.Int64? latestSeq,
    $core.Iterable<BroadcastMessage>? messages,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (latestSeq != null) result.latestSeq = latestSeq;
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  SyncResponse._();

  factory SyncResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'latestSeq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<BroadcastMessage>(3, _omitFieldNames ? '' : 'messages',
        subBuilder: BroadcastMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse copyWith(void Function(SyncResponse) updates) =>
      super.copyWith((message) => updates(message as SyncResponse))
          as SyncResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncResponse create() => SyncResponse._();
  @$core.override
  SyncResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncResponse>(create);
  static SyncResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get latestSeq => $_getI64(1);
  @$pb.TagNumber(2)
  set latestSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLatestSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearLatestSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<BroadcastMessage> get messages => $_getList(2);
}

/// 客户端 → 服务器：历史消息向前翻页（加载更早消息）
class HistoryRequest extends $pb.GeneratedMessage {
  factory HistoryRequest({
    $core.String? topicId,
    $fixnum.Int64? beforeSeq,
    $core.int? limit,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (beforeSeq != null) result.beforeSeq = beforeSeq;
    if (limit != null) result.limit = limit;
    return result;
  }

  HistoryRequest._();

  factory HistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'beforeSeq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'limit', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryRequest copyWith(void Function(HistoryRequest) updates) =>
      super.copyWith((message) => updates(message as HistoryRequest))
          as HistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistoryRequest create() => HistoryRequest._();
  @$core.override
  HistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoryRequest>(create);
  static HistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get beforeSeq => $_getI64(1);
  @$pb.TagNumber(2)
  set beforeSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBeforeSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearBeforeSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

/// 服务器 → 客户端：历史消息翻页响应
class HistoryResponse extends $pb.GeneratedMessage {
  factory HistoryResponse({
    $core.String? topicId,
    $core.Iterable<BroadcastMessage>? messages,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (topicId != null) result.topicId = topicId;
    if (messages != null) result.messages.addAll(messages);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  HistoryResponse._();

  factory HistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'topicId')
    ..pPM<BroadcastMessage>(2, _omitFieldNames ? '' : 'messages',
        subBuilder: BroadcastMessage.create)
    ..aOB(3, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoryResponse copyWith(void Function(HistoryResponse) updates) =>
      super.copyWith((message) => updates(message as HistoryResponse))
          as HistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistoryResponse create() => HistoryResponse._();
  @$core.override
  HistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoryResponse>(create);
  static HistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get topicId => $_getSZ(0);
  @$pb.TagNumber(1)
  set topicId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTopicId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTopicId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<BroadcastMessage> get messages => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get hasMore => $_getBF(2);
  @$pb.TagNumber(3)
  set hasMore($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasMore() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasMore() => $_clearField(3);
}

/// 表情包（服务器包：管理员管理，成员只读；本地包仅客户端本地存储，不走协议）
class Sticker extends $pb.GeneratedMessage {
  factory Sticker({
    $core.String? id,
    $core.String? packId,
    $core.String? type,
    $core.String? content,
    $core.int? sort,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (packId != null) result.packId = packId;
    if (type != null) result.type = type;
    if (content != null) result.content = content;
    if (sort != null) result.sort = sort;
    return result;
  }

  Sticker._();

  factory Sticker.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Sticker.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Sticker',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'packId')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aI(5, _omitFieldNames ? '' : 'sort')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sticker clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sticker copyWith(void Function(Sticker) updates) =>
      super.copyWith((message) => updates(message as Sticker)) as Sticker;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Sticker create() => Sticker._();
  @$core.override
  Sticker createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Sticker getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Sticker>(create);
  static Sticker? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get packId => $_getSZ(1);
  @$pb.TagNumber(2)
  set packId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sort => $_getIZ(4);
  @$pb.TagNumber(5)
  set sort($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSort() => $_has(4);
  @$pb.TagNumber(5)
  void clearSort() => $_clearField(5);
}

class StickerPack extends $pb.GeneratedMessage {
  factory StickerPack({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    $core.int? sort,
    $core.Iterable<Sticker>? stickers,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (sort != null) result.sort = sort;
    if (stickers != null) result.stickers.addAll(stickers);
    return result;
  }

  StickerPack._();

  factory StickerPack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StickerPack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StickerPack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aI(4, _omitFieldNames ? '' : 'sort')
    ..pPM<Sticker>(5, _omitFieldNames ? '' : 'stickers',
        subBuilder: Sticker.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPack copyWith(void Function(StickerPack) updates) =>
      super.copyWith((message) => updates(message as StickerPack))
          as StickerPack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StickerPack create() => StickerPack._();
  @$core.override
  StickerPack createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StickerPack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StickerPack>(create);
  static StickerPack? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sort => $_getIZ(3);
  @$pb.TagNumber(4)
  set sort($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSort() => $_has(3);
  @$pb.TagNumber(4)
  void clearSort() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<Sticker> get stickers => $_getList(4);
}

/// 客户端 → 服务器：拉取服务器表情包（join 后调用一次，payload 空）
class StickerPackListRequest extends $pb.GeneratedMessage {
  factory StickerPackListRequest() => create();

  StickerPackListRequest._();

  factory StickerPackListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StickerPackListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StickerPackListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPackListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPackListRequest copyWith(
          void Function(StickerPackListRequest) updates) =>
      super.copyWith((message) => updates(message as StickerPackListRequest))
          as StickerPackListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StickerPackListRequest create() => StickerPackListRequest._();
  @$core.override
  StickerPackListRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StickerPackListRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StickerPackListRequest>(create);
  static StickerPackListRequest? _defaultInstance;
}

/// 服务器 → 客户端：表情包列表响应
class StickerPackListResponse extends $pb.GeneratedMessage {
  factory StickerPackListResponse({
    $core.Iterable<StickerPack>? packs,
  }) {
    final result = create();
    if (packs != null) result.packs.addAll(packs);
    return result;
  }

  StickerPackListResponse._();

  factory StickerPackListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StickerPackListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StickerPackListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<StickerPack>(1, _omitFieldNames ? '' : 'packs',
        subBuilder: StickerPack.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPackListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StickerPackListResponse copyWith(
          void Function(StickerPackListResponse) updates) =>
      super.copyWith((message) => updates(message as StickerPackListResponse))
          as StickerPackListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StickerPackListResponse create() => StickerPackListResponse._();
  @$core.override
  StickerPackListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StickerPackListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StickerPackListResponse>(create);
  static StickerPackListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StickerPack> get packs => $_getList(0);
}

class MemberInfo extends $pb.GeneratedMessage {
  factory MemberInfo({
    $core.String? userId,
    $core.String? displayName,
    $core.String? avatarSeed,
    $core.bool? isOwner,
    $fixnum.Int64? joinedAt,
    MemberRole? role,
    $core.bool? muted,
    $core.bool? banned,
    $core.bool? isOnline,
    $core.String? serverNickname,
    $core.String? serverAvatar,
    $core.bool? isBot,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (displayName != null) result.displayName = displayName;
    if (avatarSeed != null) result.avatarSeed = avatarSeed;
    if (isOwner != null) result.isOwner = isOwner;
    if (joinedAt != null) result.joinedAt = joinedAt;
    if (role != null) result.role = role;
    if (muted != null) result.muted = muted;
    if (banned != null) result.banned = banned;
    if (isOnline != null) result.isOnline = isOnline;
    if (serverNickname != null) result.serverNickname = serverNickname;
    if (serverAvatar != null) result.serverAvatar = serverAvatar;
    if (isBot != null) result.isBot = isBot;
    return result;
  }

  MemberInfo._();

  factory MemberInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemberInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemberInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aOS(3, _omitFieldNames ? '' : 'avatarSeed')
    ..aOB(4, _omitFieldNames ? '' : 'isOwner')
    ..aInt64(5, _omitFieldNames ? '' : 'joinedAt')
    ..aE<MemberRole>(6, _omitFieldNames ? '' : 'role',
        enumValues: MemberRole.values)
    ..aOB(7, _omitFieldNames ? '' : 'muted')
    ..aOB(8, _omitFieldNames ? '' : 'banned')
    ..aOB(9, _omitFieldNames ? '' : 'isOnline')
    ..aOS(10, _omitFieldNames ? '' : 'serverNickname')
    ..aOS(11, _omitFieldNames ? '' : 'serverAvatar')
    ..aOB(12, _omitFieldNames ? '' : 'isBot')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberInfo copyWith(void Function(MemberInfo) updates) =>
      super.copyWith((message) => updates(message as MemberInfo)) as MemberInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberInfo create() => MemberInfo._();
  @$core.override
  MemberInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemberInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemberInfo>(create);
  static MemberInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarSeed => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatarSeed($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatarSeed() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatarSeed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isOwner => $_getBF(3);
  @$pb.TagNumber(4)
  set isOwner($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsOwner() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsOwner() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get joinedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set joinedAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJoinedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearJoinedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  MemberRole get role => $_getN(5);
  @$pb.TagNumber(6)
  set role(MemberRole value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRole() => $_has(5);
  @$pb.TagNumber(6)
  void clearRole() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get muted => $_getBF(6);
  @$pb.TagNumber(7)
  set muted($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMuted() => $_has(6);
  @$pb.TagNumber(7)
  void clearMuted() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get banned => $_getBF(7);
  @$pb.TagNumber(8)
  set banned($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBanned() => $_has(7);
  @$pb.TagNumber(8)
  void clearBanned() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isOnline => $_getBF(8);
  @$pb.TagNumber(9)
  set isOnline($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsOnline() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsOnline() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get serverNickname => $_getSZ(9);
  @$pb.TagNumber(10)
  set serverNickname($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasServerNickname() => $_has(9);
  @$pb.TagNumber(10)
  void clearServerNickname() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get serverAvatar => $_getSZ(10);
  @$pb.TagNumber(11)
  set serverAvatar($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasServerAvatar() => $_has(10);
  @$pb.TagNumber(11)
  void clearServerAvatar() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get isBot => $_getBF(11);
  @$pb.TagNumber(12)
  set isBot($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIsBot() => $_has(11);
  @$pb.TagNumber(12)
  void clearIsBot() => $_clearField(12);
}

class MemberListRequest extends $pb.GeneratedMessage {
  factory MemberListRequest() => create();

  MemberListRequest._();

  factory MemberListRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemberListRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemberListRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberListRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberListRequest copyWith(void Function(MemberListRequest) updates) =>
      super.copyWith((message) => updates(message as MemberListRequest))
          as MemberListRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberListRequest create() => MemberListRequest._();
  @$core.override
  MemberListRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemberListRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemberListRequest>(create);
  static MemberListRequest? _defaultInstance;
}

class MemberListResponse extends $pb.GeneratedMessage {
  factory MemberListResponse({
    $core.Iterable<MemberInfo>? members,
  }) {
    final result = create();
    if (members != null) result.members.addAll(members);
    return result;
  }

  MemberListResponse._();

  factory MemberListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemberListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemberListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<MemberInfo>(1, _omitFieldNames ? '' : 'members',
        subBuilder: MemberInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberListResponse copyWith(void Function(MemberListResponse) updates) =>
      super.copyWith((message) => updates(message as MemberListResponse))
          as MemberListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberListResponse create() => MemberListResponse._();
  @$core.override
  MemberListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemberListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemberListResponse>(create);
  static MemberListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MemberInfo> get members => $_getList(0);
}

/// 管理员 → 服务器：设置成员角色
class SetMemberRoleRequest extends $pb.GeneratedMessage {
  factory SetMemberRoleRequest({
    $core.String? userId,
    MemberRole? role,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (role != null) result.role = role;
    return result;
  }

  SetMemberRoleRequest._();

  factory SetMemberRoleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetMemberRoleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMemberRoleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aE<MemberRole>(2, _omitFieldNames ? '' : 'role',
        enumValues: MemberRole.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMemberRoleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMemberRoleRequest copyWith(void Function(SetMemberRoleRequest) updates) =>
      super.copyWith((message) => updates(message as SetMemberRoleRequest))
          as SetMemberRoleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMemberRoleRequest create() => SetMemberRoleRequest._();
  @$core.override
  SetMemberRoleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetMemberRoleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMemberRoleRequest>(create);
  static SetMemberRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  MemberRole get role => $_getN(1);
  @$pb.TagNumber(2)
  set role(MemberRole value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);
}

/// 管理员 → 服务器：禁言/解禁成员
class SetMuteRequest extends $pb.GeneratedMessage {
  factory SetMuteRequest({
    $core.String? userId,
    $core.bool? muted,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (muted != null) result.muted = muted;
    return result;
  }

  SetMuteRequest._();

  factory SetMuteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetMuteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMuteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'muted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMuteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMuteRequest copyWith(void Function(SetMuteRequest) updates) =>
      super.copyWith((message) => updates(message as SetMuteRequest))
          as SetMuteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMuteRequest create() => SetMuteRequest._();
  @$core.override
  SetMuteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetMuteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMuteRequest>(create);
  static SetMuteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get muted => $_getBF(1);
  @$pb.TagNumber(2)
  set muted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMuted() => $_has(1);
  @$pb.TagNumber(2)
  void clearMuted() => $_clearField(2);
}

/// 管理员 → 服务器：踢出成员（可重新申请加入）
class KickMemberRequest extends $pb.GeneratedMessage {
  factory KickMemberRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  KickMemberRequest._();

  factory KickMemberRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KickMemberRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KickMemberRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KickMemberRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KickMemberRequest copyWith(void Function(KickMemberRequest) updates) =>
      super.copyWith((message) => updates(message as KickMemberRequest))
          as KickMemberRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KickMemberRequest create() => KickMemberRequest._();
  @$core.override
  KickMemberRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KickMemberRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KickMemberRequest>(create);
  static KickMemberRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

/// 管理员 → 服务器：封禁/解封成员（按 user_id）
class SetBanRequest extends $pb.GeneratedMessage {
  factory SetBanRequest({
    $core.String? userId,
    $core.bool? banned,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (banned != null) result.banned = banned;
    return result;
  }

  SetBanRequest._();

  factory SetBanRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetBanRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetBanRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'banned')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBanRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBanRequest copyWith(void Function(SetBanRequest) updates) =>
      super.copyWith((message) => updates(message as SetBanRequest))
          as SetBanRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetBanRequest create() => SetBanRequest._();
  @$core.override
  SetBanRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetBanRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetBanRequest>(create);
  static SetBanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get banned => $_getBF(1);
  @$pb.TagNumber(2)
  set banned($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBanned() => $_has(1);
  @$pb.TagNumber(2)
  void clearBanned() => $_clearField(2);
}

/// 成员 → 服务器：更新本服务器内资料覆盖
class UpdateServerProfileRequest extends $pb.GeneratedMessage {
  factory UpdateServerProfileRequest({
    $core.String? serverNickname,
    $core.String? serverAvatar,
  }) {
    final result = create();
    if (serverNickname != null) result.serverNickname = serverNickname;
    if (serverAvatar != null) result.serverAvatar = serverAvatar;
    return result;
  }

  UpdateServerProfileRequest._();

  factory UpdateServerProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateServerProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateServerProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverNickname')
    ..aOS(2, _omitFieldNames ? '' : 'serverAvatar')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateServerProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateServerProfileRequest copyWith(
          void Function(UpdateServerProfileRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateServerProfileRequest))
          as UpdateServerProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateServerProfileRequest create() => UpdateServerProfileRequest._();
  @$core.override
  UpdateServerProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateServerProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateServerProfileRequest>(create);
  static UpdateServerProfileRequest? _defaultInstance;

  /// optional 用于区分「未设置」（不动该字段）与「空字符串」（清除覆盖），
  /// 防止改昵称清空头像、改头像清空昵称
  @$pb.TagNumber(1)
  $core.String get serverNickname => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverNickname($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerNickname() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerNickname() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get serverAvatar => $_getSZ(1);
  @$pb.TagNumber(2)
  set serverAvatar($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerAvatar() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerAvatar() => $_clearField(2);
}

/// 成员 → 服务器：退出服务器
class LeaveServerRequest extends $pb.GeneratedMessage {
  factory LeaveServerRequest() => create();

  LeaveServerRequest._();

  factory LeaveServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveServerRequest copyWith(void Function(LeaveServerRequest) updates) =>
      super.copyWith((message) => updates(message as LeaveServerRequest))
          as LeaveServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveServerRequest create() => LeaveServerRequest._();
  @$core.override
  LeaveServerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveServerRequest>(create);
  static LeaveServerRequest? _defaultInstance;
}

/// 审批条目（管理面板用）
class JoinRequestInfo extends $pb.GeneratedMessage {
  factory JoinRequestInfo({
    $core.String? requestId,
    $core.String? userId,
    $core.String? displayName,
    $core.String? reason,
    $core.String? pushServiceUrl,
    JoinStatus? status,
    $fixnum.Int64? createdAt,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (userId != null) result.userId = userId;
    if (displayName != null) result.displayName = displayName;
    if (reason != null) result.reason = reason;
    if (pushServiceUrl != null) result.pushServiceUrl = pushServiceUrl;
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  JoinRequestInfo._();

  factory JoinRequestInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinRequestInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinRequestInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..aOS(5, _omitFieldNames ? '' : 'pushServiceUrl')
    ..aE<JoinStatus>(6, _omitFieldNames ? '' : 'status',
        enumValues: JoinStatus.values)
    ..aInt64(7, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequestInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequestInfo copyWith(void Function(JoinRequestInfo) updates) =>
      super.copyWith((message) => updates(message as JoinRequestInfo))
          as JoinRequestInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinRequestInfo create() => JoinRequestInfo._();
  @$core.override
  JoinRequestInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinRequestInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinRequestInfo>(create);
  static JoinRequestInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get pushServiceUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set pushServiceUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPushServiceUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearPushServiceUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  JoinStatus get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(JoinStatus value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get createdAt => $_getI64(6);
  @$pb.TagNumber(7)
  set createdAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
}

/// 管理员 → 服务器：处理加入申请
class ProcessJoinRequest extends $pb.GeneratedMessage {
  factory ProcessJoinRequest({
    $core.String? requestId,
    $core.bool? approve,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (approve != null) result.approve = approve;
    return result;
  }

  ProcessJoinRequest._();

  factory ProcessJoinRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProcessJoinRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProcessJoinRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOB(2, _omitFieldNames ? '' : 'approve')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProcessJoinRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProcessJoinRequest copyWith(void Function(ProcessJoinRequest) updates) =>
      super.copyWith((message) => updates(message as ProcessJoinRequest))
          as ProcessJoinRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProcessJoinRequest create() => ProcessJoinRequest._();
  @$core.override
  ProcessJoinRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProcessJoinRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProcessJoinRequest>(create);
  static ProcessJoinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get approve => $_getBF(1);
  @$pb.TagNumber(2)
  set approve($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasApprove() => $_has(1);
  @$pb.TagNumber(2)
  void clearApprove() => $_clearField(2);
}

/// 管理员 → 服务器：忽略加入申请
class IgnoreJoinRequest extends $pb.GeneratedMessage {
  factory IgnoreJoinRequest({
    $core.String? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  IgnoreJoinRequest._();

  factory IgnoreJoinRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IgnoreJoinRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IgnoreJoinRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IgnoreJoinRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IgnoreJoinRequest copyWith(void Function(IgnoreJoinRequest) updates) =>
      super.copyWith((message) => updates(message as IgnoreJoinRequest))
          as IgnoreJoinRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IgnoreJoinRequest create() => IgnoreJoinRequest._();
  @$core.override
  IgnoreJoinRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IgnoreJoinRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IgnoreJoinRequest>(create);
  static IgnoreJoinRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

/// 服务器 → 管理员：待审批申请列表
class JoinRequestListResponse extends $pb.GeneratedMessage {
  factory JoinRequestListResponse({
    $core.Iterable<JoinRequestInfo>? requests,
  }) {
    final result = create();
    if (requests != null) result.requests.addAll(requests);
    return result;
  }

  JoinRequestListResponse._();

  factory JoinRequestListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinRequestListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinRequestListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<JoinRequestInfo>(1, _omitFieldNames ? '' : 'requests',
        subBuilder: JoinRequestInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequestListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinRequestListResponse copyWith(
          void Function(JoinRequestListResponse) updates) =>
      super.copyWith((message) => updates(message as JoinRequestListResponse))
          as JoinRequestListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinRequestListResponse create() => JoinRequestListResponse._();
  @$core.override
  JoinRequestListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinRequestListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinRequestListResponse>(create);
  static JoinRequestListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JoinRequestInfo> get requests => $_getList(0);
}

/// 吊销证明：主私钥对「被吊销设备公钥」的签名
class RevocationProof extends $pb.GeneratedMessage {
  factory RevocationProof({
    $core.String? userId,
    $core.List<$core.int>? devicePubkey,
    $fixnum.Int64? revokedAt,
    $core.List<$core.int>? signature,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (devicePubkey != null) result.devicePubkey = devicePubkey;
    if (revokedAt != null) result.revokedAt = revokedAt;
    if (signature != null) result.signature = signature;
    return result;
  }

  RevocationProof._();

  factory RevocationProof.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevocationProof.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevocationProof',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'devicePubkey', $pb.PbFieldType.OY)
    ..aInt64(3, _omitFieldNames ? '' : 'revokedAt')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevocationProof clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevocationProof copyWith(void Function(RevocationProof) updates) =>
      super.copyWith((message) => updates(message as RevocationProof))
          as RevocationProof;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevocationProof create() => RevocationProof._();
  @$core.override
  RevocationProof createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevocationProof getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevocationProof>(create);
  static RevocationProof? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get devicePubkey => $_getN(1);
  @$pb.TagNumber(2)
  set devicePubkey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDevicePubkey() => $_has(1);
  @$pb.TagNumber(2)
  void clearDevicePubkey() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get revokedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set revokedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRevokedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevokedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signature => $_getN(3);
  @$pb.TagNumber(4)
  set signature($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);
}

/// 设备信息
class DeviceInfo extends $pb.GeneratedMessage {
  factory DeviceInfo({
    $core.String? deviceId,
    $core.String? deviceName,
    $core.String? platform,
    $fixnum.Int64? lastActive,
    $core.bool? isCurrent,
    $core.List<$core.int>? devicePubkey,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (deviceName != null) result.deviceName = deviceName;
    if (platform != null) result.platform = platform;
    if (lastActive != null) result.lastActive = lastActive;
    if (isCurrent != null) result.isCurrent = isCurrent;
    if (devicePubkey != null) result.devicePubkey = devicePubkey;
    return result;
  }

  DeviceInfo._();

  factory DeviceInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceName')
    ..aOS(3, _omitFieldNames ? '' : 'platform')
    ..aInt64(4, _omitFieldNames ? '' : 'lastActive')
    ..aOB(5, _omitFieldNames ? '' : 'isCurrent')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'devicePubkey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo copyWith(void Function(DeviceInfo) updates) =>
      super.copyWith((message) => updates(message as DeviceInfo)) as DeviceInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceInfo create() => DeviceInfo._();
  @$core.override
  DeviceInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceInfo>(create);
  static DeviceInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get platform => $_getSZ(2);
  @$pb.TagNumber(3)
  set platform($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlatform() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlatform() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get lastActive => $_getI64(3);
  @$pb.TagNumber(4)
  set lastActive($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastActive() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastActive() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isCurrent => $_getBF(4);
  @$pb.TagNumber(5)
  set isCurrent($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsCurrent() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsCurrent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get devicePubkey => $_getN(5);
  @$pb.TagNumber(6)
  set devicePubkey($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDevicePubkey() => $_has(5);
  @$pb.TagNumber(6)
  void clearDevicePubkey() => $_clearField(6);
}

/// 客户端 → 服务器：携带吊销证明（连接时/发消息时）
class RegisterDeviceRequest extends $pb.GeneratedMessage {
  factory RegisterDeviceRequest({
    DeviceInfo? device,
    $core.List<$core.int>? deviceCert,
    $core.Iterable<RevocationProof>? revocations,
  }) {
    final result = create();
    if (device != null) result.device = device;
    if (deviceCert != null) result.deviceCert = deviceCert;
    if (revocations != null) result.revocations.addAll(revocations);
    return result;
  }

  RegisterDeviceRequest._();

  factory RegisterDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOM<DeviceInfo>(1, _omitFieldNames ? '' : 'device',
        subBuilder: DeviceInfo.create)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'deviceCert', $pb.PbFieldType.OY)
    ..pPM<RevocationProof>(3, _omitFieldNames ? '' : 'revocations',
        subBuilder: RevocationProof.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest copyWith(
          void Function(RegisterDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterDeviceRequest))
          as RegisterDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest create() => RegisterDeviceRequest._();
  @$core.override
  RegisterDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceRequest>(create);
  static RegisterDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  DeviceInfo get device => $_getN(0);
  @$pb.TagNumber(1)
  set device(DeviceInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDevice() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevice() => $_clearField(1);
  @$pb.TagNumber(1)
  DeviceInfo ensureDevice() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get deviceCert => $_getN(1);
  @$pb.TagNumber(2)
  set deviceCert($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceCert() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceCert() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<RevocationProof> get revocations => $_getList(2);
}

/// 服务器 → 客户端：设备列表
class DeviceListResponse extends $pb.GeneratedMessage {
  factory DeviceListResponse({
    $core.Iterable<DeviceInfo>? devices,
  }) {
    final result = create();
    if (devices != null) result.devices.addAll(devices);
    return result;
  }

  DeviceListResponse._();

  factory DeviceListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<DeviceInfo>(1, _omitFieldNames ? '' : 'devices',
        subBuilder: DeviceInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceListResponse copyWith(void Function(DeviceListResponse) updates) =>
      super.copyWith((message) => updates(message as DeviceListResponse))
          as DeviceListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceListResponse create() => DeviceListResponse._();
  @$core.override
  DeviceListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceListResponse>(create);
  static DeviceListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DeviceInfo> get devices => $_getList(0);
}

/// 客户端 → 服务器：撤销设备（携带吊销证明）
class RevokeDeviceRequest extends $pb.GeneratedMessage {
  factory RevokeDeviceRequest({
    $core.List<$core.int>? devicePubkey,
    RevocationProof? proof,
  }) {
    final result = create();
    if (devicePubkey != null) result.devicePubkey = devicePubkey;
    if (proof != null) result.proof = proof;
    return result;
  }

  RevokeDeviceRequest._();

  factory RevokeDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'devicePubkey', $pb.PbFieldType.OY)
    ..aOM<RevocationProof>(2, _omitFieldNames ? '' : 'proof',
        subBuilder: RevocationProof.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest copyWith(void Function(RevokeDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RevokeDeviceRequest))
          as RevokeDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeDeviceRequest create() => RevokeDeviceRequest._();
  @$core.override
  RevokeDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeDeviceRequest>(create);
  static RevokeDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get devicePubkey => $_getN(0);
  @$pb.TagNumber(1)
  set devicePubkey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDevicePubkey() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevicePubkey() => $_clearField(1);

  @$pb.TagNumber(2)
  RevocationProof get proof => $_getN(1);
  @$pb.TagNumber(2)
  set proof(RevocationProof value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProof() => $_has(1);
  @$pb.TagNumber(2)
  void clearProof() => $_clearField(2);
  @$pb.TagNumber(2)
  RevocationProof ensureProof() => $_ensure(1);
}

/// 成员设备变更事件（服务器 → 其他成员广播，精简、不含私密字段）
class MemberDeviceChangeEvent extends $pb.GeneratedMessage {
  factory MemberDeviceChangeEvent({
    $core.String? userId,
    $core.String? deviceId,
    $core.bool? added,
    $fixnum.Int64? changedAt,
    $core.List<$core.int>? revocationProof,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (deviceId != null) result.deviceId = deviceId;
    if (added != null) result.added = added;
    if (changedAt != null) result.changedAt = changedAt;
    if (revocationProof != null) result.revocationProof = revocationProof;
    return result;
  }

  MemberDeviceChangeEvent._();

  factory MemberDeviceChangeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemberDeviceChangeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemberDeviceChangeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..aOB(3, _omitFieldNames ? '' : 'added')
    ..aInt64(4, _omitFieldNames ? '' : 'changedAt')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'revocationProof', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberDeviceChangeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemberDeviceChangeEvent copyWith(
          void Function(MemberDeviceChangeEvent) updates) =>
      super.copyWith((message) => updates(message as MemberDeviceChangeEvent))
          as MemberDeviceChangeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberDeviceChangeEvent create() => MemberDeviceChangeEvent._();
  @$core.override
  MemberDeviceChangeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemberDeviceChangeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemberDeviceChangeEvent>(create);
  static MemberDeviceChangeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get added => $_getBF(2);
  @$pb.TagNumber(3)
  set added($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAdded() => $_has(2);
  @$pb.TagNumber(3)
  void clearAdded() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get changedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set changedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChangedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearChangedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get revocationProof => $_getN(4);
  @$pb.TagNumber(5)
  set revocationProof($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRevocationProof() => $_has(4);
  @$pb.TagNumber(5)
  void clearRevocationProof() => $_clearField(5);
}

/// 自定义角色（RBAC，P2）
class RoleInfo extends $pb.GeneratedMessage {
  factory RoleInfo({
    $core.String? roleId,
    $core.String? name,
    $core.int? permissions,
  }) {
    final result = create();
    if (roleId != null) result.roleId = roleId;
    if (name != null) result.name = name;
    if (permissions != null) result.permissions = permissions;
    return result;
  }

  RoleInfo._();

  factory RoleInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoleInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roleId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'permissions',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleInfo copyWith(void Function(RoleInfo) updates) =>
      super.copyWith((message) => updates(message as RoleInfo)) as RoleInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoleInfo create() => RoleInfo._();
  @$core.override
  RoleInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoleInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RoleInfo>(create);
  static RoleInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get permissions => $_getIZ(2);
  @$pb.TagNumber(3)
  set permissions($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPermissions() => $_has(2);
  @$pb.TagNumber(3)
  void clearPermissions() => $_clearField(3);
}

/// 客户端 → 服务器：创建/更新角色
class UpsertRoleRequest extends $pb.GeneratedMessage {
  factory UpsertRoleRequest({
    $core.String? roleId,
    $core.String? name,
    $core.int? permissions,
  }) {
    final result = create();
    if (roleId != null) result.roleId = roleId;
    if (name != null) result.name = name;
    if (permissions != null) result.permissions = permissions;
    return result;
  }

  UpsertRoleRequest._();

  factory UpsertRoleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertRoleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertRoleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roleId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'permissions',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertRoleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertRoleRequest copyWith(void Function(UpsertRoleRequest) updates) =>
      super.copyWith((message) => updates(message as UpsertRoleRequest))
          as UpsertRoleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertRoleRequest create() => UpsertRoleRequest._();
  @$core.override
  UpsertRoleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpsertRoleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertRoleRequest>(create);
  static UpsertRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get permissions => $_getIZ(2);
  @$pb.TagNumber(3)
  set permissions($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPermissions() => $_has(2);
  @$pb.TagNumber(3)
  void clearPermissions() => $_clearField(3);
}

/// 客户端 → 服务器：删除角色
class DeleteRoleRequest extends $pb.GeneratedMessage {
  factory DeleteRoleRequest({
    $core.String? roleId,
  }) {
    final result = create();
    if (roleId != null) result.roleId = roleId;
    return result;
  }

  DeleteRoleRequest._();

  factory DeleteRoleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteRoleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteRoleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteRoleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteRoleRequest copyWith(void Function(DeleteRoleRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteRoleRequest))
          as DeleteRoleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteRoleRequest create() => DeleteRoleRequest._();
  @$core.override
  DeleteRoleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteRoleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteRoleRequest>(create);
  static DeleteRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoleId() => $_clearField(1);
}

/// 服务器 → 客户端：角色列表
class RoleListResponse extends $pb.GeneratedMessage {
  factory RoleListResponse({
    $core.Iterable<RoleInfo>? roles,
  }) {
    final result = create();
    if (roles != null) result.roles.addAll(roles);
    return result;
  }

  RoleListResponse._();

  factory RoleListResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoleListResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoleListResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..pPM<RoleInfo>(1, _omitFieldNames ? '' : 'roles',
        subBuilder: RoleInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleListResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoleListResponse copyWith(void Function(RoleListResponse) updates) =>
      super.copyWith((message) => updates(message as RoleListResponse))
          as RoleListResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoleListResponse create() => RoleListResponse._();
  @$core.override
  RoleListResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoleListResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoleListResponse>(create);
  static RoleListResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RoleInfo> get roles => $_getList(0);
}

/// 客户端 → 服务器：给成员分配角色
class AssignRoleRequest extends $pb.GeneratedMessage {
  factory AssignRoleRequest({
    $core.String? userId,
    $core.String? roleId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (roleId != null) result.roleId = roleId;
    return result;
  }

  AssignRoleRequest._();

  factory AssignRoleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssignRoleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssignRoleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'roleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignRoleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssignRoleRequest copyWith(void Function(AssignRoleRequest) updates) =>
      super.copyWith((message) => updates(message as AssignRoleRequest))
          as AssignRoleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssignRoleRequest create() => AssignRoleRequest._();
  @$core.override
  AssignRoleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssignRoleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssignRoleRequest>(create);
  static AssignRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoleId() => $_clearField(2);
}

/// 客户端 → 服务器：移除成员角色
class UnassignRoleRequest extends $pb.GeneratedMessage {
  factory UnassignRoleRequest({
    $core.String? userId,
    $core.String? roleId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (roleId != null) result.roleId = roleId;
    return result;
  }

  UnassignRoleRequest._();

  factory UnassignRoleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnassignRoleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnassignRoleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'roleId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignRoleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnassignRoleRequest copyWith(void Function(UnassignRoleRequest) updates) =>
      super.copyWith((message) => updates(message as UnassignRoleRequest))
          as UnassignRoleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnassignRoleRequest create() => UnassignRoleRequest._();
  @$core.override
  UnassignRoleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnassignRoleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnassignRoleRequest>(create);
  static UnassignRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoleId() => $_clearField(2);
}

/// 预密钥束（E2EE，M6）：客户端上传的 X3DH 预密钥
class PreKeyBundle extends $pb.GeneratedMessage {
  factory PreKeyBundle({
    $core.String? userId,
    $core.List<$core.int>? identityKey,
    $core.List<$core.int>? signedPreKey,
    $core.List<$core.int>? signedPreKeySig,
    $core.Iterable<$core.List<$core.int>>? oneTimePreKeys,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (identityKey != null) result.identityKey = identityKey;
    if (signedPreKey != null) result.signedPreKey = signedPreKey;
    if (signedPreKeySig != null) result.signedPreKeySig = signedPreKeySig;
    if (oneTimePreKeys != null) result.oneTimePreKeys.addAll(oneTimePreKeys);
    return result;
  }

  PreKeyBundle._();

  factory PreKeyBundle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreKeyBundle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreKeyBundle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'identityKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signedPreKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'signedPreKeySig', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'oneTimePreKeys', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreKeyBundle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreKeyBundle copyWith(void Function(PreKeyBundle) updates) =>
      super.copyWith((message) => updates(message as PreKeyBundle))
          as PreKeyBundle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreKeyBundle create() => PreKeyBundle._();
  @$core.override
  PreKeyBundle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreKeyBundle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreKeyBundle>(create);
  static PreKeyBundle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get identityKey => $_getN(1);
  @$pb.TagNumber(2)
  set identityKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdentityKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdentityKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signedPreKey => $_getN(2);
  @$pb.TagNumber(3)
  set signedPreKey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignedPreKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignedPreKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get signedPreKeySig => $_getN(3);
  @$pb.TagNumber(4)
  set signedPreKeySig($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignedPreKeySig() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignedPreKeySig() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.List<$core.int>> get oneTimePreKeys => $_getList(4);
}

/// 客户端 → 服务器：上传预密钥束
class UploadPreKeysRequest extends $pb.GeneratedMessage {
  factory UploadPreKeysRequest({
    PreKeyBundle? bundle,
  }) {
    final result = create();
    if (bundle != null) result.bundle = bundle;
    return result;
  }

  UploadPreKeysRequest._();

  factory UploadPreKeysRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadPreKeysRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadPreKeysRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOM<PreKeyBundle>(1, _omitFieldNames ? '' : 'bundle',
        subBuilder: PreKeyBundle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadPreKeysRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadPreKeysRequest copyWith(void Function(UploadPreKeysRequest) updates) =>
      super.copyWith((message) => updates(message as UploadPreKeysRequest))
          as UploadPreKeysRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadPreKeysRequest create() => UploadPreKeysRequest._();
  @$core.override
  UploadPreKeysRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadPreKeysRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadPreKeysRequest>(create);
  static UploadPreKeysRequest? _defaultInstance;

  @$pb.TagNumber(1)
  PreKeyBundle get bundle => $_getN(0);
  @$pb.TagNumber(1)
  set bundle(PreKeyBundle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBundle() => $_has(0);
  @$pb.TagNumber(1)
  void clearBundle() => $_clearField(1);
  @$pb.TagNumber(1)
  PreKeyBundle ensureBundle() => $_ensure(0);
}

/// 客户端 → 服务器：拉取某用户的预密钥束
class FetchPreKeysRequest extends $pb.GeneratedMessage {
  factory FetchPreKeysRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  FetchPreKeysRequest._();

  factory FetchPreKeysRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchPreKeysRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchPreKeysRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchPreKeysRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchPreKeysRequest copyWith(void Function(FetchPreKeysRequest) updates) =>
      super.copyWith((message) => updates(message as FetchPreKeysRequest))
          as FetchPreKeysRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchPreKeysRequest create() => FetchPreKeysRequest._();
  @$core.override
  FetchPreKeysRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchPreKeysRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchPreKeysRequest>(create);
  static FetchPreKeysRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

/// 服务器 → 客户端：预密钥束响应
class PreKeyBundleResponse extends $pb.GeneratedMessage {
  factory PreKeyBundleResponse({
    PreKeyBundle? bundle,
  }) {
    final result = create();
    if (bundle != null) result.bundle = bundle;
    return result;
  }

  PreKeyBundleResponse._();

  factory PreKeyBundleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreKeyBundleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreKeyBundleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aOM<PreKeyBundle>(1, _omitFieldNames ? '' : 'bundle',
        subBuilder: PreKeyBundle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreKeyBundleResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreKeyBundleResponse copyWith(void Function(PreKeyBundleResponse) updates) =>
      super.copyWith((message) => updates(message as PreKeyBundleResponse))
          as PreKeyBundleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreKeyBundleResponse create() => PreKeyBundleResponse._();
  @$core.override
  PreKeyBundleResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreKeyBundleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreKeyBundleResponse>(create);
  static PreKeyBundleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PreKeyBundle get bundle => $_getN(0);
  @$pb.TagNumber(1)
  set bundle(PreKeyBundle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBundle() => $_has(0);
  @$pb.TagNumber(1)
  void clearBundle() => $_clearField(1);
  @$pb.TagNumber(1)
  PreKeyBundle ensureBundle() => $_ensure(0);
}

class ClientEnvelope extends $pb.GeneratedMessage {
  factory ClientEnvelope({
    ClientEnvelope_MsgType? type,
    $fixnum.Int64? requestId,
    $core.List<$core.int>? payload,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (requestId != null) result.requestId = requestId;
    if (payload != null) result.payload = payload;
    return result;
  }

  ClientEnvelope._();

  factory ClientEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aE<ClientEnvelope_MsgType>(1, _omitFieldNames ? '' : 'type',
        enumValues: ClientEnvelope_MsgType.values)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEnvelope copyWith(void Function(ClientEnvelope) updates) =>
      super.copyWith((message) => updates(message as ClientEnvelope))
          as ClientEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientEnvelope create() => ClientEnvelope._();
  @$core.override
  ClientEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientEnvelope>(create);
  static ClientEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  ClientEnvelope_MsgType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(ClientEnvelope_MsgType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get requestId => $_getI64(1);
  @$pb.TagNumber(2)
  set requestId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);
}

/// 服务器 → 客户端：统一信封
class ServerEnvelope extends $pb.GeneratedMessage {
  factory ServerEnvelope({
    ServerEnvelope_MsgType? type,
    $fixnum.Int64? requestId,
    $core.List<$core.int>? payload,
    $core.String? error,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (requestId != null) result.requestId = requestId;
    if (payload != null) result.payload = payload;
    if (error != null) result.error = error;
    return result;
  }

  ServerEnvelope._();

  factory ServerEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'lonisle'),
      createEmptyInstance: create)
    ..aE<ServerEnvelope_MsgType>(1, _omitFieldNames ? '' : 'type',
        enumValues: ServerEnvelope_MsgType.values)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEnvelope copyWith(void Function(ServerEnvelope) updates) =>
      super.copyWith((message) => updates(message as ServerEnvelope))
          as ServerEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerEnvelope create() => ServerEnvelope._();
  @$core.override
  ServerEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerEnvelope>(create);
  static ServerEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  ServerEnvelope_MsgType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(ServerEnvelope_MsgType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get requestId => $_getI64(1);
  @$pb.TagNumber(2)
  set requestId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
