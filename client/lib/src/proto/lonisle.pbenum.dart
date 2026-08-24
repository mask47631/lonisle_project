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

import 'package:protobuf/protobuf.dart' as $pb;

/// 话题类型
class TopicType extends $pb.ProtobufEnum {
  static const TopicType TOPIC_TYPE_UNSPECIFIED =
      TopicType._(0, _omitEnumNames ? '' : 'TOPIC_TYPE_UNSPECIFIED');
  static const TopicType TEXT = TopicType._(1, _omitEnumNames ? '' : 'TEXT');
  static const TopicType ANNOUNCEMENT =
      TopicType._(2, _omitEnumNames ? '' : 'ANNOUNCEMENT');
  static const TopicType AV = TopicType._(3, _omitEnumNames ? '' : 'AV');

  static const $core.List<TopicType> values = <TopicType>[
    TOPIC_TYPE_UNSPECIFIED,
    TEXT,
    ANNOUNCEMENT,
    AV,
  ];

  static final $core.List<TopicType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TopicType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TopicType._(super.value, super.name);
}

/// 话题权限
class TopicPermission extends $pb.ProtobufEnum {
  static const TopicPermission TOPIC_PERMISSION_UNSPECIFIED = TopicPermission._(
      0, _omitEnumNames ? '' : 'TOPIC_PERMISSION_UNSPECIFIED');
  static const TopicPermission PUBLIC =
      TopicPermission._(1, _omitEnumNames ? '' : 'PUBLIC');
  static const TopicPermission READONLY =
      TopicPermission._(2, _omitEnumNames ? '' : 'READONLY');

  static const $core.List<TopicPermission> values = <TopicPermission>[
    TOPIC_PERMISSION_UNSPECIFIED,
    PUBLIC,
    READONLY,
  ];

  static final $core.List<TopicPermission?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TopicPermission? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TopicPermission._(super.value, super.name);
}

/// 成员角色
class MemberRole extends $pb.ProtobufEnum {
  static const MemberRole MEMBER_ROLE_UNSPECIFIED =
      MemberRole._(0, _omitEnumNames ? '' : 'MEMBER_ROLE_UNSPECIFIED');
  static const MemberRole OWNER =
      MemberRole._(1, _omitEnumNames ? '' : 'OWNER');
  static const MemberRole ADMIN =
      MemberRole._(2, _omitEnumNames ? '' : 'ADMIN');
  static const MemberRole MEMBER =
      MemberRole._(3, _omitEnumNames ? '' : 'MEMBER');

  static const $core.List<MemberRole> values = <MemberRole>[
    MEMBER_ROLE_UNSPECIFIED,
    OWNER,
    ADMIN,
    MEMBER,
  ];

  static final $core.List<MemberRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MemberRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MemberRole._(super.value, super.name);
}

/// 加入状态
class JoinStatus extends $pb.ProtobufEnum {
  static const JoinStatus JOIN_STATUS_UNSPECIFIED =
      JoinStatus._(0, _omitEnumNames ? '' : 'JOIN_STATUS_UNSPECIFIED');
  static const JoinStatus PENDING =
      JoinStatus._(1, _omitEnumNames ? '' : 'PENDING');
  static const JoinStatus APPROVED =
      JoinStatus._(2, _omitEnumNames ? '' : 'APPROVED');
  static const JoinStatus REJECTED =
      JoinStatus._(3, _omitEnumNames ? '' : 'REJECTED');
  static const JoinStatus IGNORED =
      JoinStatus._(4, _omitEnumNames ? '' : 'IGNORED');

  static const $core.List<JoinStatus> values = <JoinStatus>[
    JOIN_STATUS_UNSPECIFIED,
    PENDING,
    APPROVED,
    REJECTED,
    IGNORED,
  ];

  static final $core.List<JoinStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static JoinStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const JoinStatus._(super.value, super.name);
}

/// 加入策略
class JoinStrategy extends $pb.ProtobufEnum {
  static const JoinStrategy JOIN_STRATEGY_UNSPECIFIED =
      JoinStrategy._(0, _omitEnumNames ? '' : 'JOIN_STRATEGY_UNSPECIFIED');
  static const JoinStrategy APPROVAL =
      JoinStrategy._(1, _omitEnumNames ? '' : 'APPROVAL');
  static const JoinStrategy OPEN =
      JoinStrategy._(2, _omitEnumNames ? '' : 'OPEN');
  static const JoinStrategy INVITE_ONLY =
      JoinStrategy._(3, _omitEnumNames ? '' : 'INVITE_ONLY');

  static const $core.List<JoinStrategy> values = <JoinStrategy>[
    JOIN_STRATEGY_UNSPECIFIED,
    APPROVAL,
    OPEN,
    INVITE_ONLY,
  ];

  static final $core.List<JoinStrategy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static JoinStrategy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const JoinStrategy._(super.value, super.name);
}

class ClientEnvelope_MsgType extends $pb.ProtobufEnum {
  static const ClientEnvelope_MsgType HELLO =
      ClientEnvelope_MsgType._(0, _omitEnumNames ? '' : 'HELLO');
  static const ClientEnvelope_MsgType JOIN =
      ClientEnvelope_MsgType._(1, _omitEnumNames ? '' : 'JOIN');
  static const ClientEnvelope_MsgType SEND_MESSAGE =
      ClientEnvelope_MsgType._(2, _omitEnumNames ? '' : 'SEND_MESSAGE');
  static const ClientEnvelope_MsgType SYNC =
      ClientEnvelope_MsgType._(3, _omitEnumNames ? '' : 'SYNC');
  static const ClientEnvelope_MsgType LIST_MEMBERS =
      ClientEnvelope_MsgType._(4, _omitEnumNames ? '' : 'LIST_MEMBERS');
  static const ClientEnvelope_MsgType PING =
      ClientEnvelope_MsgType._(5, _omitEnumNames ? '' : 'PING');
  static const ClientEnvelope_MsgType LIST_TOPICS =
      ClientEnvelope_MsgType._(6, _omitEnumNames ? '' : 'LIST_TOPICS');
  static const ClientEnvelope_MsgType CREATE_TOPIC =
      ClientEnvelope_MsgType._(7, _omitEnumNames ? '' : 'CREATE_TOPIC');
  static const ClientEnvelope_MsgType UPDATE_TOPIC =
      ClientEnvelope_MsgType._(8, _omitEnumNames ? '' : 'UPDATE_TOPIC');
  static const ClientEnvelope_MsgType DELETE_TOPIC =
      ClientEnvelope_MsgType._(9, _omitEnumNames ? '' : 'DELETE_TOPIC');
  static const ClientEnvelope_MsgType REORDER_TOPICS =
      ClientEnvelope_MsgType._(10, _omitEnumNames ? '' : 'REORDER_TOPICS');
  static const ClientEnvelope_MsgType LIST_JOIN_REQUESTS =
      ClientEnvelope_MsgType._(11, _omitEnumNames ? '' : 'LIST_JOIN_REQUESTS');
  static const ClientEnvelope_MsgType PROCESS_JOIN_REQUEST =
      ClientEnvelope_MsgType._(
          12, _omitEnumNames ? '' : 'PROCESS_JOIN_REQUEST');
  static const ClientEnvelope_MsgType IGNORE_JOIN_REQUEST =
      ClientEnvelope_MsgType._(13, _omitEnumNames ? '' : 'IGNORE_JOIN_REQUEST');
  static const ClientEnvelope_MsgType SET_MEMBER_ROLE =
      ClientEnvelope_MsgType._(14, _omitEnumNames ? '' : 'SET_MEMBER_ROLE');
  static const ClientEnvelope_MsgType SET_MUTE =
      ClientEnvelope_MsgType._(15, _omitEnumNames ? '' : 'SET_MUTE');
  static const ClientEnvelope_MsgType KICK_MEMBER =
      ClientEnvelope_MsgType._(16, _omitEnumNames ? '' : 'KICK_MEMBER');
  static const ClientEnvelope_MsgType SET_BAN =
      ClientEnvelope_MsgType._(17, _omitEnumNames ? '' : 'SET_BAN');
  static const ClientEnvelope_MsgType UPDATE_SERVER_PROFILE =
      ClientEnvelope_MsgType._(
          18, _omitEnumNames ? '' : 'UPDATE_SERVER_PROFILE');
  static const ClientEnvelope_MsgType UPDATE_SERVER_SETTINGS =
      ClientEnvelope_MsgType._(
          19, _omitEnumNames ? '' : 'UPDATE_SERVER_SETTINGS');
  static const ClientEnvelope_MsgType LEAVE_SERVER =
      ClientEnvelope_MsgType._(20, _omitEnumNames ? '' : 'LEAVE_SERVER');
  static const ClientEnvelope_MsgType EDIT_MESSAGE =
      ClientEnvelope_MsgType._(21, _omitEnumNames ? '' : 'EDIT_MESSAGE');
  static const ClientEnvelope_MsgType DELETE_MESSAGE =
      ClientEnvelope_MsgType._(22, _omitEnumNames ? '' : 'DELETE_MESSAGE');
  static const ClientEnvelope_MsgType REGISTER_DEVICE =
      ClientEnvelope_MsgType._(23, _omitEnumNames ? '' : 'REGISTER_DEVICE');
  static const ClientEnvelope_MsgType LIST_DEVICES =
      ClientEnvelope_MsgType._(24, _omitEnumNames ? '' : 'LIST_DEVICES');
  static const ClientEnvelope_MsgType REVOKE_DEVICE =
      ClientEnvelope_MsgType._(25, _omitEnumNames ? '' : 'REVOKE_DEVICE');
  static const ClientEnvelope_MsgType ADD_REACTION =
      ClientEnvelope_MsgType._(26, _omitEnumNames ? '' : 'ADD_REACTION');
  static const ClientEnvelope_MsgType REMOVE_REACTION =
      ClientEnvelope_MsgType._(27, _omitEnumNames ? '' : 'REMOVE_REACTION');
  static const ClientEnvelope_MsgType UPLOAD_PRE_KEYS =
      ClientEnvelope_MsgType._(28, _omitEnumNames ? '' : 'UPLOAD_PRE_KEYS');
  static const ClientEnvelope_MsgType FETCH_PRE_KEYS =
      ClientEnvelope_MsgType._(29, _omitEnumNames ? '' : 'FETCH_PRE_KEYS');
  static const ClientEnvelope_MsgType UPSERT_ROLE =
      ClientEnvelope_MsgType._(30, _omitEnumNames ? '' : 'UPSERT_ROLE');
  static const ClientEnvelope_MsgType DELETE_ROLE =
      ClientEnvelope_MsgType._(31, _omitEnumNames ? '' : 'DELETE_ROLE');
  static const ClientEnvelope_MsgType LIST_ROLES =
      ClientEnvelope_MsgType._(32, _omitEnumNames ? '' : 'LIST_ROLES');
  static const ClientEnvelope_MsgType ASSIGN_ROLE =
      ClientEnvelope_MsgType._(33, _omitEnumNames ? '' : 'ASSIGN_ROLE');
  static const ClientEnvelope_MsgType UNASSIGN_ROLE =
      ClientEnvelope_MsgType._(34, _omitEnumNames ? '' : 'UNASSIGN_ROLE');
  static const ClientEnvelope_MsgType MARK_MENTION_READ =
      ClientEnvelope_MsgType._(35, _omitEnumNames ? '' : 'MARK_MENTION_READ');
  static const ClientEnvelope_MsgType MENTION_READ_LIST =
      ClientEnvelope_MsgType._(36, _omitEnumNames ? '' : 'MENTION_READ_LIST');
  static const ClientEnvelope_MsgType JOIN_AV =
      ClientEnvelope_MsgType._(37, _omitEnumNames ? '' : 'JOIN_AV');
  static const ClientEnvelope_MsgType HISTORY =
      ClientEnvelope_MsgType._(38, _omitEnumNames ? '' : 'HISTORY');

  static const $core.List<ClientEnvelope_MsgType> values =
      <ClientEnvelope_MsgType>[
    HELLO,
    JOIN,
    SEND_MESSAGE,
    SYNC,
    LIST_MEMBERS,
    PING,
    LIST_TOPICS,
    CREATE_TOPIC,
    UPDATE_TOPIC,
    DELETE_TOPIC,
    REORDER_TOPICS,
    LIST_JOIN_REQUESTS,
    PROCESS_JOIN_REQUEST,
    IGNORE_JOIN_REQUEST,
    SET_MEMBER_ROLE,
    SET_MUTE,
    KICK_MEMBER,
    SET_BAN,
    UPDATE_SERVER_PROFILE,
    UPDATE_SERVER_SETTINGS,
    LEAVE_SERVER,
    EDIT_MESSAGE,
    DELETE_MESSAGE,
    REGISTER_DEVICE,
    LIST_DEVICES,
    REVOKE_DEVICE,
    ADD_REACTION,
    REMOVE_REACTION,
    UPLOAD_PRE_KEYS,
    FETCH_PRE_KEYS,
    UPSERT_ROLE,
    DELETE_ROLE,
    LIST_ROLES,
    ASSIGN_ROLE,
    UNASSIGN_ROLE,
    MARK_MENTION_READ,
    MENTION_READ_LIST,
    JOIN_AV,
    HISTORY,
  ];

  static final $core.List<ClientEnvelope_MsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 38);
  static ClientEnvelope_MsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ClientEnvelope_MsgType._(super.value, super.name);
}

class ServerEnvelope_MsgType extends $pb.ProtobufEnum {
  static const ServerEnvelope_MsgType HELLO_RESPONSE =
      ServerEnvelope_MsgType._(0, _omitEnumNames ? '' : 'HELLO_RESPONSE');
  static const ServerEnvelope_MsgType JOIN_RESPONSE =
      ServerEnvelope_MsgType._(1, _omitEnumNames ? '' : 'JOIN_RESPONSE');
  static const ServerEnvelope_MsgType SEND_MESSAGE_ACK =
      ServerEnvelope_MsgType._(2, _omitEnumNames ? '' : 'SEND_MESSAGE_ACK');
  static const ServerEnvelope_MsgType BROADCAST =
      ServerEnvelope_MsgType._(3, _omitEnumNames ? '' : 'BROADCAST');
  static const ServerEnvelope_MsgType SYNC_RESPONSE =
      ServerEnvelope_MsgType._(4, _omitEnumNames ? '' : 'SYNC_RESPONSE');
  static const ServerEnvelope_MsgType MEMBER_LIST_RESPONSE =
      ServerEnvelope_MsgType._(5, _omitEnumNames ? '' : 'MEMBER_LIST_RESPONSE');
  static const ServerEnvelope_MsgType PONG =
      ServerEnvelope_MsgType._(6, _omitEnumNames ? '' : 'PONG');
  static const ServerEnvelope_MsgType ERROR =
      ServerEnvelope_MsgType._(7, _omitEnumNames ? '' : 'ERROR');
  static const ServerEnvelope_MsgType TOPIC_LIST_RESPONSE =
      ServerEnvelope_MsgType._(8, _omitEnumNames ? '' : 'TOPIC_LIST_RESPONSE');
  static const ServerEnvelope_MsgType JOIN_REQUEST_LIST_RESPONSE =
      ServerEnvelope_MsgType._(
          9, _omitEnumNames ? '' : 'JOIN_REQUEST_LIST_RESPONSE');
  static const ServerEnvelope_MsgType JOIN_REQUEST_UPDATED =
      ServerEnvelope_MsgType._(
          10, _omitEnumNames ? '' : 'JOIN_REQUEST_UPDATED');
  static const ServerEnvelope_MsgType MEMBER_UPDATED =
      ServerEnvelope_MsgType._(11, _omitEnumNames ? '' : 'MEMBER_UPDATED');
  static const ServerEnvelope_MsgType TOPIC_UPDATED =
      ServerEnvelope_MsgType._(12, _omitEnumNames ? '' : 'TOPIC_UPDATED');
  static const ServerEnvelope_MsgType OK =
      ServerEnvelope_MsgType._(13, _omitEnumNames ? '' : 'OK');
  static const ServerEnvelope_MsgType DEVICE_LIST_RESPONSE =
      ServerEnvelope_MsgType._(
          14, _omitEnumNames ? '' : 'DEVICE_LIST_RESPONSE');
  static const ServerEnvelope_MsgType MEMBER_DEVICE_CHANGE =
      ServerEnvelope_MsgType._(
          15, _omitEnumNames ? '' : 'MEMBER_DEVICE_CHANGE');
  static const ServerEnvelope_MsgType PRE_KEY_BUNDLE_RESPONSE =
      ServerEnvelope_MsgType._(
          16, _omitEnumNames ? '' : 'PRE_KEY_BUNDLE_RESPONSE');
  static const ServerEnvelope_MsgType ROLE_LIST_RESPONSE =
      ServerEnvelope_MsgType._(17, _omitEnumNames ? '' : 'ROLE_LIST_RESPONSE');
  static const ServerEnvelope_MsgType MENTION_READ_LIST_RESPONSE =
      ServerEnvelope_MsgType._(
          18, _omitEnumNames ? '' : 'MENTION_READ_LIST_RESPONSE');
  static const ServerEnvelope_MsgType JOIN_AV_RESPONSE =
      ServerEnvelope_MsgType._(19, _omitEnumNames ? '' : 'JOIN_AV_RESPONSE');
  static const ServerEnvelope_MsgType SERVER_INFO_UPDATED =
      ServerEnvelope_MsgType._(20, _omitEnumNames ? '' : 'SERVER_INFO_UPDATED');
  static const ServerEnvelope_MsgType HISTORY_RESPONSE =
      ServerEnvelope_MsgType._(21, _omitEnumNames ? '' : 'HISTORY_RESPONSE');

  static const $core.List<ServerEnvelope_MsgType> values =
      <ServerEnvelope_MsgType>[
    HELLO_RESPONSE,
    JOIN_RESPONSE,
    SEND_MESSAGE_ACK,
    BROADCAST,
    SYNC_RESPONSE,
    MEMBER_LIST_RESPONSE,
    PONG,
    ERROR,
    TOPIC_LIST_RESPONSE,
    JOIN_REQUEST_LIST_RESPONSE,
    JOIN_REQUEST_UPDATED,
    MEMBER_UPDATED,
    TOPIC_UPDATED,
    OK,
    DEVICE_LIST_RESPONSE,
    MEMBER_DEVICE_CHANGE,
    PRE_KEY_BUNDLE_RESPONSE,
    ROLE_LIST_RESPONSE,
    MENTION_READ_LIST_RESPONSE,
    JOIN_AV_RESPONSE,
    SERVER_INFO_UPDATED,
    HISTORY_RESPONSE,
  ];

  static final $core.List<ServerEnvelope_MsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 21);
  static ServerEnvelope_MsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ServerEnvelope_MsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
