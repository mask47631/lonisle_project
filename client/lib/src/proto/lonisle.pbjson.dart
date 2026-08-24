// This is a generated file - do not edit.
//
// Generated from proto/lonisle.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use topicTypeDescriptor instead')
const TopicType$json = {
  '1': 'TopicType',
  '2': [
    {'1': 'TOPIC_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TEXT', '2': 1},
    {'1': 'ANNOUNCEMENT', '2': 2},
    {'1': 'AV', '2': 3},
  ],
};

/// Descriptor for `TopicType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List topicTypeDescriptor = $convert.base64Decode(
    'CglUb3BpY1R5cGUSGgoWVE9QSUNfVFlQRV9VTlNQRUNJRklFRBAAEggKBFRFWFQQARIQCgxBTk'
    '5PVU5DRU1FTlQQAhIGCgJBVhAD');

@$core.Deprecated('Use topicPermissionDescriptor instead')
const TopicPermission$json = {
  '1': 'TopicPermission',
  '2': [
    {'1': 'TOPIC_PERMISSION_UNSPECIFIED', '2': 0},
    {'1': 'PUBLIC', '2': 1},
    {'1': 'READONLY', '2': 2},
  ],
};

/// Descriptor for `TopicPermission`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List topicPermissionDescriptor = $convert.base64Decode(
    'Cg9Ub3BpY1Blcm1pc3Npb24SIAocVE9QSUNfUEVSTUlTU0lPTl9VTlNQRUNJRklFRBAAEgoKBl'
    'BVQkxJQxABEgwKCFJFQURPTkxZEAI=');

@$core.Deprecated('Use memberRoleDescriptor instead')
const MemberRole$json = {
  '1': 'MemberRole',
  '2': [
    {'1': 'MEMBER_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'OWNER', '2': 1},
    {'1': 'ADMIN', '2': 2},
    {'1': 'MEMBER', '2': 3},
  ],
};

/// Descriptor for `MemberRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List memberRoleDescriptor = $convert.base64Decode(
    'CgpNZW1iZXJSb2xlEhsKF01FTUJFUl9ST0xFX1VOU1BFQ0lGSUVEEAASCQoFT1dORVIQARIJCg'
    'VBRE1JThACEgoKBk1FTUJFUhAD');

@$core.Deprecated('Use joinStatusDescriptor instead')
const JoinStatus$json = {
  '1': 'JoinStatus',
  '2': [
    {'1': 'JOIN_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'PENDING', '2': 1},
    {'1': 'APPROVED', '2': 2},
    {'1': 'REJECTED', '2': 3},
    {'1': 'IGNORED', '2': 4},
  ],
};

/// Descriptor for `JoinStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List joinStatusDescriptor = $convert.base64Decode(
    'CgpKb2luU3RhdHVzEhsKF0pPSU5fU1RBVFVTX1VOU1BFQ0lGSUVEEAASCwoHUEVORElORxABEg'
    'wKCEFQUFJPVkVEEAISDAoIUkVKRUNURUQQAxILCgdJR05PUkVEEAQ=');

@$core.Deprecated('Use joinStrategyDescriptor instead')
const JoinStrategy$json = {
  '1': 'JoinStrategy',
  '2': [
    {'1': 'JOIN_STRATEGY_UNSPECIFIED', '2': 0},
    {'1': 'APPROVAL', '2': 1},
    {'1': 'OPEN', '2': 2},
    {'1': 'INVITE_ONLY', '2': 3},
  ],
};

/// Descriptor for `JoinStrategy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List joinStrategyDescriptor = $convert.base64Decode(
    'CgxKb2luU3RyYXRlZ3kSHQoZSk9JTl9TVFJBVEVHWV9VTlNQRUNJRklFRBAAEgwKCEFQUFJPVk'
    'FMEAESCAoET1BFThACEg8KC0lOVklURV9PTkxZEAM=');

@$core.Deprecated('Use deviceCertDescriptor instead')
const DeviceCert$json = {
  '1': 'DeviceCert',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_pubkey', '3': 2, '4': 1, '5': 12, '10': 'devicePubkey'},
    {'1': 'device_name', '3': 3, '4': 1, '5': 9, '10': 'deviceName'},
    {'1': 'issued_at', '3': 4, '4': 1, '5': 3, '10': 'issuedAt'},
    {'1': 'signature', '3': 5, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'x25519_pubkey', '3': 6, '4': 1, '5': 12, '10': 'x25519Pubkey'},
  ],
};

/// Descriptor for `DeviceCert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceCertDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VDZXJ0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIjCg1kZXZpY2VfcHVia2V5GA'
    'IgASgMUgxkZXZpY2VQdWJrZXkSHwoLZGV2aWNlX25hbWUYAyABKAlSCmRldmljZU5hbWUSGwoJ'
    'aXNzdWVkX2F0GAQgASgDUghpc3N1ZWRBdBIcCglzaWduYXR1cmUYBSABKAxSCXNpZ25hdHVyZR'
    'IjCg14MjU1MTlfcHVia2V5GAYgASgMUgx4MjU1MTlQdWJrZXk=');

@$core.Deprecated('Use identityDescriptor instead')
const Identity$json = {
  '1': 'Identity',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'master_pubkey', '3': 2, '4': 1, '5': 12, '10': 'masterPubkey'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_seed', '3': 4, '4': 1, '5': 9, '10': 'avatarSeed'},
  ],
};

/// Descriptor for `Identity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identityDescriptor = $convert.base64Decode(
    'CghJZGVudGl0eRIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSIwoNbWFzdGVyX3B1YmtleRgCIA'
    'EoDFIMbWFzdGVyUHVia2V5EiEKDGRpc3BsYXlfbmFtZRgDIAEoCVILZGlzcGxheU5hbWUSHwoL'
    'YXZhdGFyX3NlZWQYBCABKAlSCmF2YXRhclNlZWQ=');

@$core.Deprecated('Use helloDescriptor instead')
const Hello$json = {
  '1': 'Hello',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 5, '10': 'protocolVersion'},
    {
      '1': 'identity',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.lonisle.Identity',
      '10': 'identity'
    },
    {
      '1': 'device_cert',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.lonisle.DeviceCert',
      '10': 'deviceCert'
    },
    {'1': 'device_signature', '3': 4, '4': 1, '5': 12, '10': 'deviceSignature'},
    {'1': 'bot_token', '3': 5, '4': 1, '5': 9, '10': 'botToken'},
  ],
};

/// Descriptor for `Hello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloDescriptor = $convert.base64Decode(
    'CgVIZWxsbxIpChBwcm90b2NvbF92ZXJzaW9uGAEgASgFUg9wcm90b2NvbFZlcnNpb24SLQoIaW'
    'RlbnRpdHkYAiABKAsyES5sb25pc2xlLklkZW50aXR5UghpZGVudGl0eRI0CgtkZXZpY2VfY2Vy'
    'dBgDIAEoCzITLmxvbmlzbGUuRGV2aWNlQ2VydFIKZGV2aWNlQ2VydBIpChBkZXZpY2Vfc2lnbm'
    'F0dXJlGAQgASgMUg9kZXZpY2VTaWduYXR1cmUSGwoJYm90X3Rva2VuGAUgASgJUghib3RUb2tl'
    'bg==');

@$core.Deprecated('Use helloResponseDescriptor instead')
const HelloResponse$json = {
  '1': 'HelloResponse',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 5, '10': 'protocolVersion'},
    {'1': 'compatible', '3': 2, '4': 1, '5': 8, '10': 'compatible'},
    {'1': 'min_supported', '3': 3, '4': 1, '5': 5, '10': 'minSupported'},
    {'1': 'max_supported', '3': 4, '4': 1, '5': 5, '10': 'maxSupported'},
    {'1': 'server_id', '3': 5, '4': 1, '5': 9, '10': 'serverId'},
    {'1': 'server_pubkey', '3': 6, '4': 1, '5': 12, '10': 'serverPubkey'},
    {'1': 'server_name', '3': 7, '4': 1, '5': 9, '10': 'serverName'},
    {'1': 'server_desc', '3': 8, '4': 1, '5': 9, '10': 'serverDesc'},
    {'1': 'is_member', '3': 9, '4': 1, '5': 8, '10': 'isMember'},
    {'1': 'migration_target', '3': 10, '4': 1, '5': 9, '10': 'migrationTarget'},
    {
      '1': 'migration_fingerprint',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'migrationFingerprint'
    },
    {'1': 'av_enabled', '3': 12, '4': 1, '5': 8, '10': 'avEnabled'},
    {
      '1': 'migration_signature',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'migrationSignature'
    },
  ],
};

/// Descriptor for `HelloResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloResponseDescriptor = $convert.base64Decode(
    'Cg1IZWxsb1Jlc3BvbnNlEikKEHByb3RvY29sX3ZlcnNpb24YASABKAVSD3Byb3RvY29sVmVyc2'
    'lvbhIeCgpjb21wYXRpYmxlGAIgASgIUgpjb21wYXRpYmxlEiMKDW1pbl9zdXBwb3J0ZWQYAyAB'
    'KAVSDG1pblN1cHBvcnRlZBIjCg1tYXhfc3VwcG9ydGVkGAQgASgFUgxtYXhTdXBwb3J0ZWQSGw'
    'oJc2VydmVyX2lkGAUgASgJUghzZXJ2ZXJJZBIjCg1zZXJ2ZXJfcHVia2V5GAYgASgMUgxzZXJ2'
    'ZXJQdWJrZXkSHwoLc2VydmVyX25hbWUYByABKAlSCnNlcnZlck5hbWUSHwoLc2VydmVyX2Rlc2'
    'MYCCABKAlSCnNlcnZlckRlc2MSGwoJaXNfbWVtYmVyGAkgASgIUghpc01lbWJlchIpChBtaWdy'
    'YXRpb25fdGFyZ2V0GAogASgJUg9taWdyYXRpb25UYXJnZXQSMwoVbWlncmF0aW9uX2Zpbmdlcn'
    'ByaW50GAsgASgJUhRtaWdyYXRpb25GaW5nZXJwcmludBIdCgphdl9lbmFibGVkGAwgASgIUglh'
    'dkVuYWJsZWQSLwoTbWlncmF0aW9uX3NpZ25hdHVyZRgNIAEoCVISbWlncmF0aW9uU2lnbmF0dX'
    'Jl');

@$core.Deprecated('Use joinRequestDescriptor instead')
const JoinRequest$json = {
  '1': 'JoinRequest',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'push_service_url', '3': 2, '4': 1, '5': 9, '10': 'pushServiceUrl'},
    {
      '1': 'identity',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.lonisle.Identity',
      '10': 'identity'
    },
    {'1': 'claim_code', '3': 4, '4': 1, '5': 9, '10': 'claimCode'},
    {'1': 'invite_token', '3': 5, '4': 1, '5': 9, '10': 'inviteToken'},
  ],
};

/// Descriptor for `JoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinRequestDescriptor = $convert.base64Decode(
    'CgtKb2luUmVxdWVzdBIWCgZyZWFzb24YASABKAlSBnJlYXNvbhIoChBwdXNoX3NlcnZpY2VfdX'
    'JsGAIgASgJUg5wdXNoU2VydmljZVVybBItCghpZGVudGl0eRgDIAEoCzIRLmxvbmlzbGUuSWRl'
    'bnRpdHlSCGlkZW50aXR5Eh0KCmNsYWltX2NvZGUYBCABKAlSCWNsYWltQ29kZRIhCgxpbnZpdG'
    'VfdG9rZW4YBSABKAlSC2ludml0ZVRva2Vu');

@$core.Deprecated('Use joinResponseDescriptor instead')
const JoinResponse$json = {
  '1': 'JoinResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'is_owner', '3': 3, '4': 1, '5': 8, '10': 'isOwner'},
    {
      '1': 'server_info',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.lonisle.ServerInfo',
      '10': 'serverInfo'
    },
    {
      '1': 'topics',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.lonisle.TopicInfo',
      '10': 'topics'
    },
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.lonisle.JoinStatus',
      '10': 'status'
    },
    {'1': 'request_id', '3': 7, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'strategy',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.lonisle.JoinStrategy',
      '10': 'strategy'
    },
  ],
};

/// Descriptor for `JoinResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinResponseDescriptor = $convert.base64Decode(
    'CgxKb2luUmVzcG9uc2USGgoIYWNjZXB0ZWQYASABKAhSCGFjY2VwdGVkEhYKBnJlYXNvbhgCIA'
    'EoCVIGcmVhc29uEhkKCGlzX293bmVyGAMgASgIUgdpc093bmVyEjQKC3NlcnZlcl9pbmZvGAQg'
    'ASgLMhMubG9uaXNsZS5TZXJ2ZXJJbmZvUgpzZXJ2ZXJJbmZvEioKBnRvcGljcxgFIAMoCzISLm'
    'xvbmlzbGUuVG9waWNJbmZvUgZ0b3BpY3MSKwoGc3RhdHVzGAYgASgOMhMubG9uaXNsZS5Kb2lu'
    'U3RhdHVzUgZzdGF0dXMSHQoKcmVxdWVzdF9pZBgHIAEoCVIJcmVxdWVzdElkEjEKCHN0cmF0ZW'
    'd5GAggASgOMhUubG9uaXNsZS5Kb2luU3RyYXRlZ3lSCHN0cmF0ZWd5');

@$core.Deprecated('Use serverInfoDescriptor instead')
const ServerInfo$json = {
  '1': 'ServerInfo',
  '2': [
    {'1': 'server_id', '3': 1, '4': 1, '5': 9, '10': 'serverId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'fingerprint', '3': 4, '4': 1, '5': 9, '10': 'fingerprint'},
    {
      '1': 'strategy',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.lonisle.JoinStrategy',
      '10': 'strategy'
    },
    {'1': 'icon', '3': 6, '4': 1, '5': 9, '10': 'icon'},
    {
      '1': 'rate_limit_per_minute',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'rateLimitPerMinute'
    },
    {
      '1': 'max_attachment_size',
      '3': 8,
      '4': 1,
      '5': 4,
      '10': 'maxAttachmentSize'
    },
    {'1': 'attachment_quota', '3': 9, '4': 1, '5': 4, '10': 'attachmentQuota'},
  ],
};

/// Descriptor for `ServerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverInfoDescriptor = $convert.base64Decode(
    'CgpTZXJ2ZXJJbmZvEhsKCXNlcnZlcl9pZBgBIAEoCVIIc2VydmVySWQSEgoEbmFtZRgCIAEoCV'
    'IEbmFtZRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SIAoLZmluZ2VycHJpbnQY'
    'BCABKAlSC2ZpbmdlcnByaW50EjEKCHN0cmF0ZWd5GAUgASgOMhUubG9uaXNsZS5Kb2luU3RyYX'
    'RlZ3lSCHN0cmF0ZWd5EhIKBGljb24YBiABKAlSBGljb24SMQoVcmF0ZV9saW1pdF9wZXJfbWlu'
    'dXRlGAcgASgNUhJyYXRlTGltaXRQZXJNaW51dGUSLgoTbWF4X2F0dGFjaG1lbnRfc2l6ZRgIIA'
    'EoBFIRbWF4QXR0YWNobWVudFNpemUSKQoQYXR0YWNobWVudF9xdW90YRgJIAEoBFIPYXR0YWNo'
    'bWVudFF1b3Rh');

@$core.Deprecated('Use updateServerSettingsRequestDescriptor instead')
const UpdateServerSettingsRequest$json = {
  '1': 'UpdateServerSettingsRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'strategy',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.lonisle.JoinStrategy',
      '10': 'strategy'
    },
  ],
};

/// Descriptor for `UpdateServerSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateServerSettingsRequestDescriptor =
    $convert.base64Decode(
        'ChtVcGRhdGVTZXJ2ZXJTZXR0aW5nc1JlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtkZX'
        'NjcmlwdGlvbhgCIAEoCVILZGVzY3JpcHRpb24SMQoIc3RyYXRlZ3kYAyABKA4yFS5sb25pc2xl'
        'LkpvaW5TdHJhdGVneVIIc3RyYXRlZ3k=');

@$core.Deprecated('Use topicInfoDescriptor instead')
const TopicInfo$json = {
  '1': 'TopicInfo',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'sort_order', '3': 4, '4': 1, '5': 5, '10': 'sortOrder'},
    {
      '1': 'type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicType',
      '10': 'type'
    },
    {
      '1': 'permission',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicPermission',
      '10': 'permission'
    },
  ],
};

/// Descriptor for `TopicInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicInfoDescriptor = $convert.base64Decode(
    'CglUb3BpY0luZm8SGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SHQoKc29ydF9vcmRlchgEIAEo'
    'BVIJc29ydE9yZGVyEiYKBHR5cGUYBSABKA4yEi5sb25pc2xlLlRvcGljVHlwZVIEdHlwZRI4Cg'
    'pwZXJtaXNzaW9uGAYgASgOMhgubG9uaXNsZS5Ub3BpY1Blcm1pc3Npb25SCnBlcm1pc3Npb24=');

@$core.Deprecated('Use joinAVRequestDescriptor instead')
const JoinAVRequest$json = {
  '1': 'JoinAVRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
  ],
};

/// Descriptor for `JoinAVRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinAVRequestDescriptor = $convert
    .base64Decode('Cg1Kb2luQVZSZXF1ZXN0EhkKCHRvcGljX2lkGAEgASgJUgd0b3BpY0lk');

@$core.Deprecated('Use joinAVResponseDescriptor instead')
const JoinAVResponse$json = {
  '1': 'JoinAVResponse',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `JoinAVResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinAVResponseDescriptor = $convert.base64Decode(
    'Cg5Kb2luQVZSZXNwb25zZRIQCgN1cmwYASABKAlSA3VybBIUCgV0b2tlbhgCIAEoCVIFdG9rZW'
    '4=');

@$core.Deprecated('Use createTopicRequestDescriptor instead')
const CreateTopicRequest$json = {
  '1': 'CreateTopicRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicType',
      '10': 'type'
    },
    {
      '1': 'permission',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicPermission',
      '10': 'permission'
    },
  ],
};

/// Descriptor for `CreateTopicRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTopicRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVUb3BpY1JlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtkZXNjcmlwdGlvbh'
    'gCIAEoCVILZGVzY3JpcHRpb24SJgoEdHlwZRgDIAEoDjISLmxvbmlzbGUuVG9waWNUeXBlUgR0'
    'eXBlEjgKCnBlcm1pc3Npb24YBCABKA4yGC5sb25pc2xlLlRvcGljUGVybWlzc2lvblIKcGVybW'
    'lzc2lvbg==');

@$core.Deprecated('Use updateTopicRequestDescriptor instead')
const UpdateTopicRequest$json = {
  '1': 'UpdateTopicRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicType',
      '10': 'type'
    },
    {
      '1': 'permission',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.lonisle.TopicPermission',
      '10': 'permission'
    },
  ],
};

/// Descriptor for `UpdateTopicRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTopicRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVUb3BpY1JlcXVlc3QSGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SJgoEdHlwZRgE'
    'IAEoDjISLmxvbmlzbGUuVG9waWNUeXBlUgR0eXBlEjgKCnBlcm1pc3Npb24YBSABKA4yGC5sb2'
    '5pc2xlLlRvcGljUGVybWlzc2lvblIKcGVybWlzc2lvbg==');

@$core.Deprecated('Use deleteTopicRequestDescriptor instead')
const DeleteTopicRequest$json = {
  '1': 'DeleteTopicRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
  ],
};

/// Descriptor for `DeleteTopicRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTopicRequestDescriptor =
    $convert.base64Decode(
        'ChJEZWxldGVUb3BpY1JlcXVlc3QSGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQ=');

@$core.Deprecated('Use reorderTopicsRequestDescriptor instead')
const ReorderTopicsRequest$json = {
  '1': 'ReorderTopicsRequest',
  '2': [
    {'1': 'topic_ids', '3': 1, '4': 3, '5': 9, '10': 'topicIds'},
  ],
};

/// Descriptor for `ReorderTopicsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderTopicsRequestDescriptor =
    $convert.base64Decode(
        'ChRSZW9yZGVyVG9waWNzUmVxdWVzdBIbCgl0b3BpY19pZHMYASADKAlSCHRvcGljSWRz');

@$core.Deprecated('Use topicListResponseDescriptor instead')
const TopicListResponse$json = {
  '1': 'TopicListResponse',
  '2': [
    {
      '1': 'topics',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.lonisle.TopicInfo',
      '10': 'topics'
    },
  ],
};

/// Descriptor for `TopicListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List topicListResponseDescriptor = $convert.base64Decode(
    'ChFUb3BpY0xpc3RSZXNwb25zZRIqCgZ0b3BpY3MYASADKAsyEi5sb25pc2xlLlRvcGljSW5mb1'
    'IGdG9waWNz');

@$core.Deprecated('Use messageContentDescriptor instead')
const MessageContent$json = {
  '1': 'MessageContent',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'attachment',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.lonisle.Attachment',
      '10': 'attachment'
    },
    {'1': 'encrypted', '3': 3, '4': 1, '5': 12, '10': 'encrypted'},
  ],
};

/// Descriptor for `MessageContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageContentDescriptor = $convert.base64Decode(
    'Cg5NZXNzYWdlQ29udGVudBISCgR0ZXh0GAEgASgJUgR0ZXh0EjMKCmF0dGFjaG1lbnQYAiABKA'
    'syEy5sb25pc2xlLkF0dGFjaG1lbnRSCmF0dGFjaG1lbnQSHAoJZW5jcnlwdGVkGAMgASgMUgll'
    'bmNyeXB0ZWQ=');

@$core.Deprecated('Use attachmentDescriptor instead')
const Attachment$json = {
  '1': 'Attachment',
  '2': [
    {'1': 'attachment_id', '3': 1, '4': 1, '5': 9, '10': 'attachmentId'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'size', '3': 3, '4': 1, '5': 4, '10': 'size'},
    {'1': 'mime', '3': 4, '4': 1, '5': 9, '10': 'mime'},
    {'1': 'width', '3': 5, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 13, '10': 'height'},
    {'1': 'duration', '3': 7, '4': 1, '5': 13, '10': 'duration'},
    {'1': 'thumbnail_id', '3': 8, '4': 1, '5': 9, '10': 'thumbnailId'},
    {'1': 'filename', '3': 9, '4': 1, '5': 9, '10': 'filename'},
  ],
};

/// Descriptor for `Attachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachmentDescriptor = $convert.base64Decode(
    'CgpBdHRhY2htZW50EiMKDWF0dGFjaG1lbnRfaWQYASABKAlSDGF0dGFjaG1lbnRJZBISCgRraW'
    '5kGAIgASgJUgRraW5kEhIKBHNpemUYAyABKARSBHNpemUSEgoEbWltZRgEIAEoCVIEbWltZRIU'
    'CgV3aWR0aBgFIAEoDVIFd2lkdGgSFgoGaGVpZ2h0GAYgASgNUgZoZWlnaHQSGgoIZHVyYXRpb2'
    '4YByABKA1SCGR1cmF0aW9uEiEKDHRodW1ibmFpbF9pZBgIIAEoCVILdGh1bWJuYWlsSWQSGgoI'
    'ZmlsZW5hbWUYCSABKAlSCGZpbGVuYW1l');

@$core.Deprecated('Use reactionDescriptor instead')
const Reaction$json = {
  '1': 'Reaction',
  '2': [
    {'1': 'emoji', '3': 1, '4': 1, '5': 9, '10': 'emoji'},
    {'1': 'user_id', '3': 2, '4': 3, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `Reaction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reactionDescriptor = $convert.base64Decode(
    'CghSZWFjdGlvbhIUCgVlbW9qaRgBIAEoCVIFZW1vamkSFwoHdXNlcl9pZBgCIAMoCVIGdXNlck'
    'lk');

@$core.Deprecated('Use sendMessageDescriptor instead')
const SendMessage$json = {
  '1': 'SendMessage',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'author_id', '3': 3, '4': 1, '5': 12, '10': 'authorId'},
    {'1': 'device_id', '3': 4, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'client_ts', '3': 5, '4': 1, '5': 3, '10': 'clientTs'},
    {
      '1': 'content',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.lonisle.MessageContent',
      '10': 'content'
    },
    {'1': 'signature', '3': 7, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'reply_to', '3': 8, '4': 1, '5': 9, '10': 'replyTo'},
  ],
};

/// Descriptor for `SendMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageDescriptor = $convert.base64Decode(
    'CgtTZW5kTWVzc2FnZRIZCgh0b3BpY19pZBgBIAEoCVIHdG9waWNJZBIVCgZtc2dfaWQYAiABKA'
    'lSBW1zZ0lkEhsKCWF1dGhvcl9pZBgDIAEoDFIIYXV0aG9ySWQSGwoJZGV2aWNlX2lkGAQgASgJ'
    'UghkZXZpY2VJZBIbCgljbGllbnRfdHMYBSABKANSCGNsaWVudFRzEjEKB2NvbnRlbnQYBiABKA'
    'syFy5sb25pc2xlLk1lc3NhZ2VDb250ZW50Ugdjb250ZW50EhwKCXNpZ25hdHVyZRgHIAEoDFIJ'
    'c2lnbmF0dXJlEhkKCHJlcGx5X3RvGAggASgJUgdyZXBseVRv');

@$core.Deprecated('Use sendMessageAckDescriptor instead')
const SendMessageAck$json = {
  '1': 'SendMessageAck',
  '2': [
    {'1': 'msg_id', '3': 1, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 4, '10': 'seq'},
    {'1': 'duplicated', '3': 3, '4': 1, '5': 8, '10': 'duplicated'},
  ],
};

/// Descriptor for `SendMessageAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageAckDescriptor = $convert.base64Decode(
    'Cg5TZW5kTWVzc2FnZUFjaxIVCgZtc2dfaWQYASABKAlSBW1zZ0lkEhAKA3NlcRgCIAEoBFIDc2'
    'VxEh4KCmR1cGxpY2F0ZWQYAyABKAhSCmR1cGxpY2F0ZWQ=');

@$core.Deprecated('Use broadcastMessageDescriptor instead')
const BroadcastMessage$json = {
  '1': 'BroadcastMessage',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 4, '10': 'seq'},
    {'1': 'topic_id', '3': 2, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 3, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'author_id', '3': 4, '4': 1, '5': 12, '10': 'authorId'},
    {'1': 'device_id', '3': 5, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'author_name', '3': 6, '4': 1, '5': 9, '10': 'authorName'},
    {'1': 'server_ts', '3': 7, '4': 1, '5': 3, '10': 'serverTs'},
    {
      '1': 'content',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.lonisle.MessageContent',
      '10': 'content'
    },
    {'1': 'edited', '3': 9, '4': 1, '5': 8, '10': 'edited'},
    {'1': 'deleted', '3': 10, '4': 1, '5': 8, '10': 'deleted'},
    {'1': 'mentions', '3': 11, '4': 1, '5': 9, '10': 'mentions'},
    {
      '1': 'reactions',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.lonisle.Reaction',
      '10': 'reactions'
    },
    {'1': 'reply_to', '3': 13, '4': 1, '5': 9, '10': 'replyTo'},
  ],
};

/// Descriptor for `BroadcastMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List broadcastMessageDescriptor = $convert.base64Decode(
    'ChBCcm9hZGNhc3RNZXNzYWdlEhAKA3NlcRgBIAEoBFIDc2VxEhkKCHRvcGljX2lkGAIgASgJUg'
    'd0b3BpY0lkEhUKBm1zZ19pZBgDIAEoCVIFbXNnSWQSGwoJYXV0aG9yX2lkGAQgASgMUghhdXRo'
    'b3JJZBIbCglkZXZpY2VfaWQYBSABKAlSCGRldmljZUlkEh8KC2F1dGhvcl9uYW1lGAYgASgJUg'
    'phdXRob3JOYW1lEhsKCXNlcnZlcl90cxgHIAEoA1IIc2VydmVyVHMSMQoHY29udGVudBgIIAEo'
    'CzIXLmxvbmlzbGUuTWVzc2FnZUNvbnRlbnRSB2NvbnRlbnQSFgoGZWRpdGVkGAkgASgIUgZlZG'
    'l0ZWQSGAoHZGVsZXRlZBgKIAEoCFIHZGVsZXRlZBIaCghtZW50aW9ucxgLIAEoCVIIbWVudGlv'
    'bnMSLwoJcmVhY3Rpb25zGAwgAygLMhEubG9uaXNsZS5SZWFjdGlvblIJcmVhY3Rpb25zEhkKCH'
    'JlcGx5X3RvGA0gASgJUgdyZXBseVRv');

@$core.Deprecated('Use editMessageRequestDescriptor instead')
const EditMessageRequest$json = {
  '1': 'EditMessageRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'new_text', '3': 3, '4': 1, '5': 9, '10': 'newText'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `EditMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editMessageRequestDescriptor = $convert.base64Decode(
    'ChJFZGl0TWVzc2FnZVJlcXVlc3QSGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSFQoGbXNnX2'
    'lkGAIgASgJUgVtc2dJZBIZCghuZXdfdGV4dBgDIAEoCVIHbmV3VGV4dBIcCglzaWduYXR1cmUY'
    'BCABKAxSCXNpZ25hdHVyZQ==');

@$core.Deprecated('Use deleteMessageRequestDescriptor instead')
const DeleteMessageRequest$json = {
  '1': 'DeleteMessageRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'signature', '3': 3, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `DeleteMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteMessageRequestDescriptor = $convert.base64Decode(
    'ChREZWxldGVNZXNzYWdlUmVxdWVzdBIZCgh0b3BpY19pZBgBIAEoCVIHdG9waWNJZBIVCgZtc2'
    'dfaWQYAiABKAlSBW1zZ0lkEhwKCXNpZ25hdHVyZRgDIAEoDFIJc2lnbmF0dXJl');

@$core.Deprecated('Use addReactionRequestDescriptor instead')
const AddReactionRequest$json = {
  '1': 'AddReactionRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'emoji', '3': 3, '4': 1, '5': 9, '10': 'emoji'},
  ],
};

/// Descriptor for `AddReactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addReactionRequestDescriptor = $convert.base64Decode(
    'ChJBZGRSZWFjdGlvblJlcXVlc3QSGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSFQoGbXNnX2'
    'lkGAIgASgJUgVtc2dJZBIUCgVlbW9qaRgDIAEoCVIFZW1vamk=');

@$core.Deprecated('Use removeReactionRequestDescriptor instead')
const RemoveReactionRequest$json = {
  '1': 'RemoveReactionRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'emoji', '3': 3, '4': 1, '5': 9, '10': 'emoji'},
  ],
};

/// Descriptor for `RemoveReactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeReactionRequestDescriptor = $convert.base64Decode(
    'ChVSZW1vdmVSZWFjdGlvblJlcXVlc3QSGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSFQoGbX'
    'NnX2lkGAIgASgJUgVtc2dJZBIUCgVlbW9qaRgDIAEoCVIFZW1vamk=');

@$core.Deprecated('Use markMentionReadRequestDescriptor instead')
const MarkMentionReadRequest$json = {
  '1': 'MarkMentionReadRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'msg_id', '3': 2, '4': 1, '5': 9, '10': 'msgId'},
  ],
};

/// Descriptor for `MarkMentionReadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markMentionReadRequestDescriptor =
    $convert.base64Decode(
        'ChZNYXJrTWVudGlvblJlYWRSZXF1ZXN0EhkKCHRvcGljX2lkGAEgASgJUgd0b3BpY0lkEhUKBm'
        '1zZ19pZBgCIAEoCVIFbXNnSWQ=');

@$core.Deprecated('Use mentionReadListRequestDescriptor instead')
const MentionReadListRequest$json = {
  '1': 'MentionReadListRequest',
  '2': [
    {'1': 'msg_id', '3': 1, '4': 1, '5': 9, '10': 'msgId'},
  ],
};

/// Descriptor for `MentionReadListRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mentionReadListRequestDescriptor =
    $convert.base64Decode(
        'ChZNZW50aW9uUmVhZExpc3RSZXF1ZXN0EhUKBm1zZ19pZBgBIAEoCVIFbXNnSWQ=');

@$core.Deprecated('Use mentionReadListResponseDescriptor instead')
const MentionReadListResponse$json = {
  '1': 'MentionReadListResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 3, '5': 9, '10': 'userId'},
    {'1': 'read_at', '3': 2, '4': 1, '5': 3, '10': 'readAt'},
  ],
};

/// Descriptor for `MentionReadListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mentionReadListResponseDescriptor =
    $convert.base64Decode(
        'ChdNZW50aW9uUmVhZExpc3RSZXNwb25zZRIXCgd1c2VyX2lkGAEgAygJUgZ1c2VySWQSFwoHcm'
        'VhZF9hdBgCIAEoA1IGcmVhZEF0');

@$core.Deprecated('Use syncRequestDescriptor instead')
const SyncRequest$json = {
  '1': 'SyncRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'after_seq', '3': 2, '4': 1, '5': 4, '10': 'afterSeq'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `SyncRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncRequestDescriptor = $convert.base64Decode(
    'CgtTeW5jUmVxdWVzdBIZCgh0b3BpY19pZBgBIAEoCVIHdG9waWNJZBIbCglhZnRlcl9zZXEYAi'
    'ABKARSCGFmdGVyU2VxEhQKBWxpbWl0GAMgASgNUgVsaW1pdA==');

@$core.Deprecated('Use syncResponseDescriptor instead')
const SyncResponse$json = {
  '1': 'SyncResponse',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'latest_seq', '3': 2, '4': 1, '5': 4, '10': 'latestSeq'},
    {
      '1': 'messages',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.lonisle.BroadcastMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `SyncResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncResponseDescriptor = $convert.base64Decode(
    'CgxTeW5jUmVzcG9uc2USGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSHQoKbGF0ZXN0X3NlcR'
    'gCIAEoBFIJbGF0ZXN0U2VxEjUKCG1lc3NhZ2VzGAMgAygLMhkubG9uaXNsZS5Ccm9hZGNhc3RN'
    'ZXNzYWdlUghtZXNzYWdlcw==');

@$core.Deprecated('Use historyRequestDescriptor instead')
const HistoryRequest$json = {
  '1': 'HistoryRequest',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {'1': 'before_seq', '3': 2, '4': 1, '5': 4, '10': 'beforeSeq'},
    {'1': 'limit', '3': 3, '4': 1, '5': 13, '10': 'limit'},
  ],
};

/// Descriptor for `HistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyRequestDescriptor = $convert.base64Decode(
    'Cg5IaXN0b3J5UmVxdWVzdBIZCgh0b3BpY19pZBgBIAEoCVIHdG9waWNJZBIdCgpiZWZvcmVfc2'
    'VxGAIgASgEUgliZWZvcmVTZXESFAoFbGltaXQYAyABKA1SBWxpbWl0');

@$core.Deprecated('Use historyResponseDescriptor instead')
const HistoryResponse$json = {
  '1': 'HistoryResponse',
  '2': [
    {'1': 'topic_id', '3': 1, '4': 1, '5': 9, '10': 'topicId'},
    {
      '1': 'messages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.lonisle.BroadcastMessage',
      '10': 'messages'
    },
    {'1': 'has_more', '3': 3, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `HistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historyResponseDescriptor = $convert.base64Decode(
    'Cg9IaXN0b3J5UmVzcG9uc2USGQoIdG9waWNfaWQYASABKAlSB3RvcGljSWQSNQoIbWVzc2FnZX'
    'MYAiADKAsyGS5sb25pc2xlLkJyb2FkY2FzdE1lc3NhZ2VSCG1lc3NhZ2VzEhkKCGhhc19tb3Jl'
    'GAMgASgIUgdoYXNNb3Jl');

@$core.Deprecated('Use memberInfoDescriptor instead')
const MemberInfo$json = {
  '1': 'MemberInfo',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_seed', '3': 3, '4': 1, '5': 9, '10': 'avatarSeed'},
    {'1': 'is_owner', '3': 4, '4': 1, '5': 8, '10': 'isOwner'},
    {'1': 'joined_at', '3': 5, '4': 1, '5': 3, '10': 'joinedAt'},
    {
      '1': 'role',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.lonisle.MemberRole',
      '10': 'role'
    },
    {'1': 'muted', '3': 7, '4': 1, '5': 8, '10': 'muted'},
    {'1': 'banned', '3': 8, '4': 1, '5': 8, '10': 'banned'},
    {'1': 'is_online', '3': 9, '4': 1, '5': 8, '10': 'isOnline'},
    {'1': 'server_nickname', '3': 10, '4': 1, '5': 9, '10': 'serverNickname'},
    {'1': 'server_avatar', '3': 11, '4': 1, '5': 9, '10': 'serverAvatar'},
    {'1': 'is_bot', '3': 12, '4': 1, '5': 8, '10': 'isBot'},
  ],
};

/// Descriptor for `MemberInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberInfoDescriptor = $convert.base64Decode(
    'CgpNZW1iZXJJbmZvEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIhCgxkaXNwbGF5X25hbWUYAi'
    'ABKAlSC2Rpc3BsYXlOYW1lEh8KC2F2YXRhcl9zZWVkGAMgASgJUgphdmF0YXJTZWVkEhkKCGlz'
    'X293bmVyGAQgASgIUgdpc093bmVyEhsKCWpvaW5lZF9hdBgFIAEoA1IIam9pbmVkQXQSJwoEcm'
    '9sZRgGIAEoDjITLmxvbmlzbGUuTWVtYmVyUm9sZVIEcm9sZRIUCgVtdXRlZBgHIAEoCFIFbXV0'
    'ZWQSFgoGYmFubmVkGAggASgIUgZiYW5uZWQSGwoJaXNfb25saW5lGAkgASgIUghpc09ubGluZR'
    'InCg9zZXJ2ZXJfbmlja25hbWUYCiABKAlSDnNlcnZlck5pY2tuYW1lEiMKDXNlcnZlcl9hdmF0'
    'YXIYCyABKAlSDHNlcnZlckF2YXRhchIVCgZpc19ib3QYDCABKAhSBWlzQm90');

@$core.Deprecated('Use memberListRequestDescriptor instead')
const MemberListRequest$json = {
  '1': 'MemberListRequest',
};

/// Descriptor for `MemberListRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberListRequestDescriptor =
    $convert.base64Decode('ChFNZW1iZXJMaXN0UmVxdWVzdA==');

@$core.Deprecated('Use memberListResponseDescriptor instead')
const MemberListResponse$json = {
  '1': 'MemberListResponse',
  '2': [
    {
      '1': 'members',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.lonisle.MemberInfo',
      '10': 'members'
    },
  ],
};

/// Descriptor for `MemberListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberListResponseDescriptor = $convert.base64Decode(
    'ChJNZW1iZXJMaXN0UmVzcG9uc2USLQoHbWVtYmVycxgBIAMoCzITLmxvbmlzbGUuTWVtYmVySW'
    '5mb1IHbWVtYmVycw==');

@$core.Deprecated('Use setMemberRoleRequestDescriptor instead')
const SetMemberRoleRequest$json = {
  '1': 'SetMemberRoleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {
      '1': 'role',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.lonisle.MemberRole',
      '10': 'role'
    },
  ],
};

/// Descriptor for `SetMemberRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMemberRoleRequestDescriptor = $convert.base64Decode(
    'ChRTZXRNZW1iZXJSb2xlUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSJwoEcm9sZR'
    'gCIAEoDjITLmxvbmlzbGUuTWVtYmVyUm9sZVIEcm9sZQ==');

@$core.Deprecated('Use setMuteRequestDescriptor instead')
const SetMuteRequest$json = {
  '1': 'SetMuteRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'muted', '3': 2, '4': 1, '5': 8, '10': 'muted'},
  ],
};

/// Descriptor for `SetMuteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMuteRequestDescriptor = $convert.base64Decode(
    'Cg5TZXRNdXRlUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSFAoFbXV0ZWQYAiABKA'
    'hSBW11dGVk');

@$core.Deprecated('Use kickMemberRequestDescriptor instead')
const KickMemberRequest$json = {
  '1': 'KickMemberRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `KickMemberRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kickMemberRequestDescriptor = $convert.base64Decode(
    'ChFLaWNrTWVtYmVyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use setBanRequestDescriptor instead')
const SetBanRequest$json = {
  '1': 'SetBanRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'banned', '3': 2, '4': 1, '5': 8, '10': 'banned'},
  ],
};

/// Descriptor for `SetBanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setBanRequestDescriptor = $convert.base64Decode(
    'Cg1TZXRCYW5SZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZiYW5uZWQYAiABKA'
    'hSBmJhbm5lZA==');

@$core.Deprecated('Use updateServerProfileRequestDescriptor instead')
const UpdateServerProfileRequest$json = {
  '1': 'UpdateServerProfileRequest',
  '2': [
    {
      '1': 'server_nickname',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'serverNickname',
      '17': true
    },
    {
      '1': 'server_avatar',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'serverAvatar',
      '17': true
    },
  ],
  '8': [
    {'1': '_server_nickname'},
    {'1': '_server_avatar'},
  ],
};

/// Descriptor for `UpdateServerProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateServerProfileRequestDescriptor =
    $convert.base64Decode(
        'ChpVcGRhdGVTZXJ2ZXJQcm9maWxlUmVxdWVzdBIsCg9zZXJ2ZXJfbmlja25hbWUYASABKAlIAF'
        'IOc2VydmVyTmlja25hbWWIAQESKAoNc2VydmVyX2F2YXRhchgCIAEoCUgBUgxzZXJ2ZXJBdmF0'
        'YXKIAQFCEgoQX3NlcnZlcl9uaWNrbmFtZUIQCg5fc2VydmVyX2F2YXRhcg==');

@$core.Deprecated('Use leaveServerRequestDescriptor instead')
const LeaveServerRequest$json = {
  '1': 'LeaveServerRequest',
};

/// Descriptor for `LeaveServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveServerRequestDescriptor =
    $convert.base64Decode('ChJMZWF2ZVNlcnZlclJlcXVlc3Q=');

@$core.Deprecated('Use joinRequestInfoDescriptor instead')
const JoinRequestInfo$json = {
  '1': 'JoinRequestInfo',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'reason', '3': 4, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'push_service_url', '3': 5, '4': 1, '5': 9, '10': 'pushServiceUrl'},
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.lonisle.JoinStatus',
      '10': 'status'
    },
    {'1': 'created_at', '3': 7, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `JoinRequestInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinRequestInfoDescriptor = $convert.base64Decode(
    'Cg9Kb2luUmVxdWVzdEluZm8SHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEhcKB3VzZX'
    'JfaWQYAiABKAlSBnVzZXJJZBIhCgxkaXNwbGF5X25hbWUYAyABKAlSC2Rpc3BsYXlOYW1lEhYK'
    'BnJlYXNvbhgEIAEoCVIGcmVhc29uEigKEHB1c2hfc2VydmljZV91cmwYBSABKAlSDnB1c2hTZX'
    'J2aWNlVXJsEisKBnN0YXR1cxgGIAEoDjITLmxvbmlzbGUuSm9pblN0YXR1c1IGc3RhdHVzEh0K'
    'CmNyZWF0ZWRfYXQYByABKANSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use processJoinRequestDescriptor instead')
const ProcessJoinRequest$json = {
  '1': 'ProcessJoinRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'approve', '3': 2, '4': 1, '5': 8, '10': 'approve'},
  ],
};

/// Descriptor for `ProcessJoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List processJoinRequestDescriptor = $convert.base64Decode(
    'ChJQcm9jZXNzSm9pblJlcXVlc3QSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEhgKB2'
    'FwcHJvdmUYAiABKAhSB2FwcHJvdmU=');

@$core.Deprecated('Use ignoreJoinRequestDescriptor instead')
const IgnoreJoinRequest$json = {
  '1': 'IgnoreJoinRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
  ],
};

/// Descriptor for `IgnoreJoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ignoreJoinRequestDescriptor = $convert.base64Decode(
    'ChFJZ25vcmVKb2luUmVxdWVzdBIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SWQ=');

@$core.Deprecated('Use joinRequestListResponseDescriptor instead')
const JoinRequestListResponse$json = {
  '1': 'JoinRequestListResponse',
  '2': [
    {
      '1': 'requests',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.lonisle.JoinRequestInfo',
      '10': 'requests'
    },
  ],
};

/// Descriptor for `JoinRequestListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinRequestListResponseDescriptor =
    $convert.base64Decode(
        'ChdKb2luUmVxdWVzdExpc3RSZXNwb25zZRI0CghyZXF1ZXN0cxgBIAMoCzIYLmxvbmlzbGUuSm'
        '9pblJlcXVlc3RJbmZvUghyZXF1ZXN0cw==');

@$core.Deprecated('Use revocationProofDescriptor instead')
const RevocationProof$json = {
  '1': 'RevocationProof',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_pubkey', '3': 2, '4': 1, '5': 12, '10': 'devicePubkey'},
    {'1': 'revoked_at', '3': 3, '4': 1, '5': 3, '10': 'revokedAt'},
    {'1': 'signature', '3': 4, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `RevocationProof`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revocationProofDescriptor = $convert.base64Decode(
    'Cg9SZXZvY2F0aW9uUHJvb2YSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiMKDWRldmljZV9wdW'
    'JrZXkYAiABKAxSDGRldmljZVB1YmtleRIdCgpyZXZva2VkX2F0GAMgASgDUglyZXZva2VkQXQS'
    'HAoJc2lnbmF0dXJlGAQgASgMUglzaWduYXR1cmU=');

@$core.Deprecated('Use deviceInfoDescriptor instead')
const DeviceInfo$json = {
  '1': 'DeviceInfo',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'device_name', '3': 2, '4': 1, '5': 9, '10': 'deviceName'},
    {'1': 'platform', '3': 3, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'last_active', '3': 4, '4': 1, '5': 3, '10': 'lastActive'},
    {'1': 'is_current', '3': 5, '4': 1, '5': 8, '10': 'isCurrent'},
    {'1': 'device_pubkey', '3': 6, '4': 1, '5': 12, '10': 'devicePubkey'},
  ],
};

/// Descriptor for `DeviceInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceInfoDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VJbmZvEhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSHwoLZGV2aWNlX25hbW'
    'UYAiABKAlSCmRldmljZU5hbWUSGgoIcGxhdGZvcm0YAyABKAlSCHBsYXRmb3JtEh8KC2xhc3Rf'
    'YWN0aXZlGAQgASgDUgpsYXN0QWN0aXZlEh0KCmlzX2N1cnJlbnQYBSABKAhSCWlzQ3VycmVudB'
    'IjCg1kZXZpY2VfcHVia2V5GAYgASgMUgxkZXZpY2VQdWJrZXk=');

@$core.Deprecated('Use registerDeviceRequestDescriptor instead')
const RegisterDeviceRequest$json = {
  '1': 'RegisterDeviceRequest',
  '2': [
    {
      '1': 'device',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.lonisle.DeviceInfo',
      '10': 'device'
    },
    {'1': 'device_cert', '3': 2, '4': 1, '5': 12, '10': 'deviceCert'},
    {
      '1': 'revocations',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.lonisle.RevocationProof',
      '10': 'revocations'
    },
  ],
};

/// Descriptor for `RegisterDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceRequestDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlckRldmljZVJlcXVlc3QSKwoGZGV2aWNlGAEgASgLMhMubG9uaXNsZS5EZXZpY2'
    'VJbmZvUgZkZXZpY2USHwoLZGV2aWNlX2NlcnQYAiABKAxSCmRldmljZUNlcnQSOgoLcmV2b2Nh'
    'dGlvbnMYAyADKAsyGC5sb25pc2xlLlJldm9jYXRpb25Qcm9vZlILcmV2b2NhdGlvbnM=');

@$core.Deprecated('Use deviceListResponseDescriptor instead')
const DeviceListResponse$json = {
  '1': 'DeviceListResponse',
  '2': [
    {
      '1': 'devices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.lonisle.DeviceInfo',
      '10': 'devices'
    },
  ],
};

/// Descriptor for `DeviceListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceListResponseDescriptor = $convert.base64Decode(
    'ChJEZXZpY2VMaXN0UmVzcG9uc2USLQoHZGV2aWNlcxgBIAMoCzITLmxvbmlzbGUuRGV2aWNlSW'
    '5mb1IHZGV2aWNlcw==');

@$core.Deprecated('Use revokeDeviceRequestDescriptor instead')
const RevokeDeviceRequest$json = {
  '1': 'RevokeDeviceRequest',
  '2': [
    {'1': 'device_pubkey', '3': 1, '4': 1, '5': 12, '10': 'devicePubkey'},
    {
      '1': 'proof',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.lonisle.RevocationProof',
      '10': 'proof'
    },
  ],
};

/// Descriptor for `RevokeDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeDeviceRequestDescriptor = $convert.base64Decode(
    'ChNSZXZva2VEZXZpY2VSZXF1ZXN0EiMKDWRldmljZV9wdWJrZXkYASABKAxSDGRldmljZVB1Ym'
    'tleRIuCgVwcm9vZhgCIAEoCzIYLmxvbmlzbGUuUmV2b2NhdGlvblByb29mUgVwcm9vZg==');

@$core.Deprecated('Use memberDeviceChangeEventDescriptor instead')
const MemberDeviceChangeEvent$json = {
  '1': 'MemberDeviceChangeEvent',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'added', '3': 3, '4': 1, '5': 8, '10': 'added'},
    {'1': 'changed_at', '3': 4, '4': 1, '5': 3, '10': 'changedAt'},
    {'1': 'revocation_proof', '3': 5, '4': 1, '5': 12, '10': 'revocationProof'},
  ],
};

/// Descriptor for `MemberDeviceChangeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberDeviceChangeEventDescriptor = $convert.base64Decode(
    'ChdNZW1iZXJEZXZpY2VDaGFuZ2VFdmVudBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSGwoJZG'
    'V2aWNlX2lkGAIgASgJUghkZXZpY2VJZBIUCgVhZGRlZBgDIAEoCFIFYWRkZWQSHQoKY2hhbmdl'
    'ZF9hdBgEIAEoA1IJY2hhbmdlZEF0EikKEHJldm9jYXRpb25fcHJvb2YYBSABKAxSD3Jldm9jYX'
    'Rpb25Qcm9vZg==');

@$core.Deprecated('Use roleInfoDescriptor instead')
const RoleInfo$json = {
  '1': 'RoleInfo',
  '2': [
    {'1': 'role_id', '3': 1, '4': 1, '5': 9, '10': 'roleId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'permissions', '3': 3, '4': 1, '5': 13, '10': 'permissions'},
  ],
};

/// Descriptor for `RoleInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleInfoDescriptor = $convert.base64Decode(
    'CghSb2xlSW5mbxIXCgdyb2xlX2lkGAEgASgJUgZyb2xlSWQSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IgCgtwZXJtaXNzaW9ucxgDIAEoDVILcGVybWlzc2lvbnM=');

@$core.Deprecated('Use upsertRoleRequestDescriptor instead')
const UpsertRoleRequest$json = {
  '1': 'UpsertRoleRequest',
  '2': [
    {'1': 'role_id', '3': 1, '4': 1, '5': 9, '10': 'roleId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'permissions', '3': 3, '4': 1, '5': 13, '10': 'permissions'},
  ],
};

/// Descriptor for `UpsertRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertRoleRequestDescriptor = $convert.base64Decode(
    'ChFVcHNlcnRSb2xlUmVxdWVzdBIXCgdyb2xlX2lkGAEgASgJUgZyb2xlSWQSEgoEbmFtZRgCIA'
    'EoCVIEbmFtZRIgCgtwZXJtaXNzaW9ucxgDIAEoDVILcGVybWlzc2lvbnM=');

@$core.Deprecated('Use deleteRoleRequestDescriptor instead')
const DeleteRoleRequest$json = {
  '1': 'DeleteRoleRequest',
  '2': [
    {'1': 'role_id', '3': 1, '4': 1, '5': 9, '10': 'roleId'},
  ],
};

/// Descriptor for `DeleteRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteRoleRequestDescriptor = $convert.base64Decode(
    'ChFEZWxldGVSb2xlUmVxdWVzdBIXCgdyb2xlX2lkGAEgASgJUgZyb2xlSWQ=');

@$core.Deprecated('Use roleListResponseDescriptor instead')
const RoleListResponse$json = {
  '1': 'RoleListResponse',
  '2': [
    {
      '1': 'roles',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.lonisle.RoleInfo',
      '10': 'roles'
    },
  ],
};

/// Descriptor for `RoleListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roleListResponseDescriptor = $convert.base64Decode(
    'ChBSb2xlTGlzdFJlc3BvbnNlEicKBXJvbGVzGAEgAygLMhEubG9uaXNsZS5Sb2xlSW5mb1IFcm'
    '9sZXM=');

@$core.Deprecated('Use assignRoleRequestDescriptor instead')
const AssignRoleRequest$json = {
  '1': 'AssignRoleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'role_id', '3': 2, '4': 1, '5': 9, '10': 'roleId'},
  ],
};

/// Descriptor for `AssignRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assignRoleRequestDescriptor = $convert.base64Decode(
    'ChFBc3NpZ25Sb2xlUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSFwoHcm9sZV9pZB'
    'gCIAEoCVIGcm9sZUlk');

@$core.Deprecated('Use unassignRoleRequestDescriptor instead')
const UnassignRoleRequest$json = {
  '1': 'UnassignRoleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'role_id', '3': 2, '4': 1, '5': 9, '10': 'roleId'},
  ],
};

/// Descriptor for `UnassignRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unassignRoleRequestDescriptor = $convert.base64Decode(
    'ChNVbmFzc2lnblJvbGVSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIXCgdyb2xlX2'
    'lkGAIgASgJUgZyb2xlSWQ=');

@$core.Deprecated('Use preKeyBundleDescriptor instead')
const PreKeyBundle$json = {
  '1': 'PreKeyBundle',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'identity_key', '3': 2, '4': 1, '5': 12, '10': 'identityKey'},
    {'1': 'signed_pre_key', '3': 3, '4': 1, '5': 12, '10': 'signedPreKey'},
    {
      '1': 'signed_pre_key_sig',
      '3': 4,
      '4': 1,
      '5': 12,
      '10': 'signedPreKeySig'
    },
    {'1': 'one_time_pre_keys', '3': 5, '4': 3, '5': 12, '10': 'oneTimePreKeys'},
  ],
};

/// Descriptor for `PreKeyBundle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preKeyBundleDescriptor = $convert.base64Decode(
    'CgxQcmVLZXlCdW5kbGUSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiEKDGlkZW50aXR5X2tleR'
    'gCIAEoDFILaWRlbnRpdHlLZXkSJAoOc2lnbmVkX3ByZV9rZXkYAyABKAxSDHNpZ25lZFByZUtl'
    'eRIrChJzaWduZWRfcHJlX2tleV9zaWcYBCABKAxSD3NpZ25lZFByZUtleVNpZxIpChFvbmVfdG'
    'ltZV9wcmVfa2V5cxgFIAMoDFIOb25lVGltZVByZUtleXM=');

@$core.Deprecated('Use uploadPreKeysRequestDescriptor instead')
const UploadPreKeysRequest$json = {
  '1': 'UploadPreKeysRequest',
  '2': [
    {
      '1': 'bundle',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.lonisle.PreKeyBundle',
      '10': 'bundle'
    },
  ],
};

/// Descriptor for `UploadPreKeysRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadPreKeysRequestDescriptor = $convert.base64Decode(
    'ChRVcGxvYWRQcmVLZXlzUmVxdWVzdBItCgZidW5kbGUYASABKAsyFS5sb25pc2xlLlByZUtleU'
    'J1bmRsZVIGYnVuZGxl');

@$core.Deprecated('Use fetchPreKeysRequestDescriptor instead')
const FetchPreKeysRequest$json = {
  '1': 'FetchPreKeysRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `FetchPreKeysRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchPreKeysRequestDescriptor =
    $convert.base64Decode(
        'ChNGZXRjaFByZUtleXNSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZA==');

@$core.Deprecated('Use preKeyBundleResponseDescriptor instead')
const PreKeyBundleResponse$json = {
  '1': 'PreKeyBundleResponse',
  '2': [
    {
      '1': 'bundle',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.lonisle.PreKeyBundle',
      '10': 'bundle'
    },
  ],
};

/// Descriptor for `PreKeyBundleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preKeyBundleResponseDescriptor = $convert.base64Decode(
    'ChRQcmVLZXlCdW5kbGVSZXNwb25zZRItCgZidW5kbGUYASABKAsyFS5sb25pc2xlLlByZUtleU'
    'J1bmRsZVIGYnVuZGxl');

@$core.Deprecated('Use clientEnvelopeDescriptor instead')
const ClientEnvelope$json = {
  '1': 'ClientEnvelope',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.lonisle.ClientEnvelope.MsgType',
      '10': 'type'
    },
    {'1': 'request_id', '3': 2, '4': 1, '5': 4, '10': 'requestId'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
  ],
  '4': [ClientEnvelope_MsgType$json],
};

@$core.Deprecated('Use clientEnvelopeDescriptor instead')
const ClientEnvelope_MsgType$json = {
  '1': 'MsgType',
  '2': [
    {'1': 'HELLO', '2': 0},
    {'1': 'JOIN', '2': 1},
    {'1': 'SEND_MESSAGE', '2': 2},
    {'1': 'SYNC', '2': 3},
    {'1': 'LIST_MEMBERS', '2': 4},
    {'1': 'PING', '2': 5},
    {'1': 'LIST_TOPICS', '2': 6},
    {'1': 'CREATE_TOPIC', '2': 7},
    {'1': 'UPDATE_TOPIC', '2': 8},
    {'1': 'DELETE_TOPIC', '2': 9},
    {'1': 'REORDER_TOPICS', '2': 10},
    {'1': 'LIST_JOIN_REQUESTS', '2': 11},
    {'1': 'PROCESS_JOIN_REQUEST', '2': 12},
    {'1': 'IGNORE_JOIN_REQUEST', '2': 13},
    {'1': 'SET_MEMBER_ROLE', '2': 14},
    {'1': 'SET_MUTE', '2': 15},
    {'1': 'KICK_MEMBER', '2': 16},
    {'1': 'SET_BAN', '2': 17},
    {'1': 'UPDATE_SERVER_PROFILE', '2': 18},
    {'1': 'UPDATE_SERVER_SETTINGS', '2': 19},
    {'1': 'LEAVE_SERVER', '2': 20},
    {'1': 'EDIT_MESSAGE', '2': 21},
    {'1': 'DELETE_MESSAGE', '2': 22},
    {'1': 'REGISTER_DEVICE', '2': 23},
    {'1': 'LIST_DEVICES', '2': 24},
    {'1': 'REVOKE_DEVICE', '2': 25},
    {'1': 'ADD_REACTION', '2': 26},
    {'1': 'REMOVE_REACTION', '2': 27},
    {'1': 'UPLOAD_PRE_KEYS', '2': 28},
    {'1': 'FETCH_PRE_KEYS', '2': 29},
    {'1': 'UPSERT_ROLE', '2': 30},
    {'1': 'DELETE_ROLE', '2': 31},
    {'1': 'LIST_ROLES', '2': 32},
    {'1': 'ASSIGN_ROLE', '2': 33},
    {'1': 'UNASSIGN_ROLE', '2': 34},
    {'1': 'MARK_MENTION_READ', '2': 35},
    {'1': 'MENTION_READ_LIST', '2': 36},
    {'1': 'JOIN_AV', '2': 37},
    {'1': 'HISTORY', '2': 38},
  ],
};

/// Descriptor for `ClientEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientEnvelopeDescriptor = $convert.base64Decode(
    'Cg5DbGllbnRFbnZlbG9wZRIzCgR0eXBlGAEgASgOMh8ubG9uaXNsZS5DbGllbnRFbnZlbG9wZS'
    '5Nc2dUeXBlUgR0eXBlEh0KCnJlcXVlc3RfaWQYAiABKARSCXJlcXVlc3RJZBIYCgdwYXlsb2Fk'
    'GAMgASgMUgdwYXlsb2FkItQFCgdNc2dUeXBlEgkKBUhFTExPEAASCAoESk9JThABEhAKDFNFTk'
    'RfTUVTU0FHRRACEggKBFNZTkMQAxIQCgxMSVNUX01FTUJFUlMQBBIICgRQSU5HEAUSDwoLTElT'
    'VF9UT1BJQ1MQBhIQCgxDUkVBVEVfVE9QSUMQBxIQCgxVUERBVEVfVE9QSUMQCBIQCgxERUxFVE'
    'VfVE9QSUMQCRISCg5SRU9SREVSX1RPUElDUxAKEhYKEkxJU1RfSk9JTl9SRVFVRVNUUxALEhgK'
    'FFBST0NFU1NfSk9JTl9SRVFVRVNUEAwSFwoTSUdOT1JFX0pPSU5fUkVRVUVTVBANEhMKD1NFVF'
    '9NRU1CRVJfUk9MRRAOEgwKCFNFVF9NVVRFEA8SDwoLS0lDS19NRU1CRVIQEBILCgdTRVRfQkFO'
    'EBESGQoVVVBEQVRFX1NFUlZFUl9QUk9GSUxFEBISGgoWVVBEQVRFX1NFUlZFUl9TRVRUSU5HUx'
    'ATEhAKDExFQVZFX1NFUlZFUhAUEhAKDEVESVRfTUVTU0FHRRAVEhIKDkRFTEVURV9NRVNTQUdF'
    'EBYSEwoPUkVHSVNURVJfREVWSUNFEBcSEAoMTElTVF9ERVZJQ0VTEBgSEQoNUkVWT0tFX0RFVk'
    'lDRRAZEhAKDEFERF9SRUFDVElPThAaEhMKD1JFTU9WRV9SRUFDVElPThAbEhMKD1VQTE9BRF9Q'
    'UkVfS0VZUxAcEhIKDkZFVENIX1BSRV9LRVlTEB0SDwoLVVBTRVJUX1JPTEUQHhIPCgtERUxFVE'
    'VfUk9MRRAfEg4KCkxJU1RfUk9MRVMQIBIPCgtBU1NJR05fUk9MRRAhEhEKDVVOQVNTSUdOX1JP'
    'TEUQIhIVChFNQVJLX01FTlRJT05fUkVBRBAjEhUKEU1FTlRJT05fUkVBRF9MSVNUECQSCwoHSk'
    '9JTl9BVhAlEgsKB0hJU1RPUlkQJg==');

@$core.Deprecated('Use serverEnvelopeDescriptor instead')
const ServerEnvelope$json = {
  '1': 'ServerEnvelope',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.lonisle.ServerEnvelope.MsgType',
      '10': 'type'
    },
    {'1': 'request_id', '3': 2, '4': 1, '5': 4, '10': 'requestId'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
  ],
  '4': [ServerEnvelope_MsgType$json],
};

@$core.Deprecated('Use serverEnvelopeDescriptor instead')
const ServerEnvelope_MsgType$json = {
  '1': 'MsgType',
  '2': [
    {'1': 'HELLO_RESPONSE', '2': 0},
    {'1': 'JOIN_RESPONSE', '2': 1},
    {'1': 'SEND_MESSAGE_ACK', '2': 2},
    {'1': 'BROADCAST', '2': 3},
    {'1': 'SYNC_RESPONSE', '2': 4},
    {'1': 'MEMBER_LIST_RESPONSE', '2': 5},
    {'1': 'PONG', '2': 6},
    {'1': 'ERROR', '2': 7},
    {'1': 'TOPIC_LIST_RESPONSE', '2': 8},
    {'1': 'JOIN_REQUEST_LIST_RESPONSE', '2': 9},
    {'1': 'JOIN_REQUEST_UPDATED', '2': 10},
    {'1': 'MEMBER_UPDATED', '2': 11},
    {'1': 'TOPIC_UPDATED', '2': 12},
    {'1': 'OK', '2': 13},
    {'1': 'DEVICE_LIST_RESPONSE', '2': 14},
    {'1': 'MEMBER_DEVICE_CHANGE', '2': 15},
    {'1': 'PRE_KEY_BUNDLE_RESPONSE', '2': 16},
    {'1': 'ROLE_LIST_RESPONSE', '2': 17},
    {'1': 'MENTION_READ_LIST_RESPONSE', '2': 18},
    {'1': 'JOIN_AV_RESPONSE', '2': 19},
    {'1': 'SERVER_INFO_UPDATED', '2': 20},
    {'1': 'HISTORY_RESPONSE', '2': 21},
  ],
};

/// Descriptor for `ServerEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverEnvelopeDescriptor = $convert.base64Decode(
    'Cg5TZXJ2ZXJFbnZlbG9wZRIzCgR0eXBlGAEgASgOMh8ubG9uaXNsZS5TZXJ2ZXJFbnZlbG9wZS'
    '5Nc2dUeXBlUgR0eXBlEh0KCnJlcXVlc3RfaWQYAiABKARSCXJlcXVlc3RJZBIYCgdwYXlsb2Fk'
    'GAMgASgMUgdwYXlsb2FkEhQKBWVycm9yGAQgASgJUgVlcnJvciLnAwoHTXNnVHlwZRISCg5IRU'
    'xMT19SRVNQT05TRRAAEhEKDUpPSU5fUkVTUE9OU0UQARIUChBTRU5EX01FU1NBR0VfQUNLEAIS'
    'DQoJQlJPQURDQVNUEAMSEQoNU1lOQ19SRVNQT05TRRAEEhgKFE1FTUJFUl9MSVNUX1JFU1BPTl'
    'NFEAUSCAoEUE9ORxAGEgkKBUVSUk9SEAcSFwoTVE9QSUNfTElTVF9SRVNQT05TRRAIEh4KGkpP'
    'SU5fUkVRVUVTVF9MSVNUX1JFU1BPTlNFEAkSGAoUSk9JTl9SRVFVRVNUX1VQREFURUQQChISCg'
    '5NRU1CRVJfVVBEQVRFRBALEhEKDVRPUElDX1VQREFURUQQDBIGCgJPSxANEhgKFERFVklDRV9M'
    'SVNUX1JFU1BPTlNFEA4SGAoUTUVNQkVSX0RFVklDRV9DSEFOR0UQDxIbChdQUkVfS0VZX0JVTk'
    'RMRV9SRVNQT05TRRAQEhYKElJPTEVfTElTVF9SRVNQT05TRRAREh4KGk1FTlRJT05fUkVBRF9M'
    'SVNUX1JFU1BPTlNFEBISFAoQSk9JTl9BVl9SRVNQT05TRRATEhcKE1NFUlZFUl9JTkZPX1VQRE'
    'FURUQQFBIUChBISVNUT1JZX1JFU1BPTlNFEBU=');
