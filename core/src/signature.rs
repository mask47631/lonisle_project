//! 消息签名：构造待签名载荷与验签
//!
//! 消息 ID 由客户端生成并随消息体被设备签名以抗重放；
//! 服务器验签 + 幂等去重。待签名载荷字段序固定，两端一致。

use crate::device::{verify_device_signature, DeviceError};
use crate::proto::{DeleteMessageRequest, EditMessageRequest, Hello, SendMessage};

/// 构造 SendMessage 的待签名载荷（固定字段序）。
/// 注意：`signature` 字段本身不参与签名。
pub fn send_message_signing_payload(msg: &SendMessage) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-msg-v1\0");
    payload.extend_from_slice(msg.topic_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(msg.msg_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(&msg.author_id);
    payload.push(0);
    payload.extend_from_slice(msg.device_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(&msg.client_ts.to_be_bytes());
    payload.push(0);
    // 内容：文本
    payload.extend_from_slice(&msg.content_text_bytes());
    // 附件元数据（若存在，M5）
    if let Some(att) = msg.content.as_ref().and_then(|c| c.attachment.as_ref()) {
        payload.extend_from_slice(b"\0lonisle-att-v1\0");
        payload.extend_from_slice(att.attachment_id.as_bytes());
        payload.push(0);
        payload.extend_from_slice(att.kind.as_bytes());
        payload.push(0);
        payload.extend_from_slice(&att.size.to_be_bytes());
        payload.push(0);
        payload.extend_from_slice(att.mime.as_bytes());
        payload.push(0);
        payload.extend_from_slice(&att.width.to_be_bytes());
        payload.push(0);
        payload.extend_from_slice(&att.height.to_be_bytes());
        payload.push(0);
        payload.extend_from_slice(&att.duration.to_be_bytes());
        payload.push(0);
        payload.extend_from_slice(att.thumbnail_id.as_bytes());
    }
    // 回复引用（F-MSG-6；固定字段序，防篡改）
    payload.extend_from_slice(b"\0lonisle-reply-v1\0");
    payload.extend_from_slice(msg.reply_to.as_bytes());
    payload
}

/// 验证消息的设备签名。
pub fn verify_send_message(
    msg: &SendMessage,
    device_pubkey: &[u8],
) -> Result<(), DeviceError> {
    let payload = send_message_signing_payload(msg);
    verify_device_signature(device_pubkey, &payload, &msg.signature)
}

/// 构造 EditMessageRequest 的待签名载荷（固定字段序，server/client 两端一致）。
/// 注意：`signature` 字段本身不参与签名。
pub fn edit_message_signing_payload(req: &EditMessageRequest) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-edit-v1\0");
    payload.extend_from_slice(req.topic_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(req.msg_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(req.new_text.as_bytes());
    payload
}

/// 验证编辑消息请求的设备签名。
pub fn verify_edit_message(
    req: &EditMessageRequest,
    device_pubkey: &[u8],
) -> Result<(), DeviceError> {
    let payload = edit_message_signing_payload(req);
    verify_device_signature(device_pubkey, &payload, &req.signature)
}

/// 构造 DeleteMessageRequest 的待签名载荷（固定字段序，server/client 两端一致）。
/// 注意：`signature` 字段本身不参与签名。
pub fn delete_message_signing_payload(req: &DeleteMessageRequest) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-delete-v1\0");
    payload.extend_from_slice(req.topic_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(req.msg_id.as_bytes());
    payload
}

/// 验证删除消息请求的设备签名。
pub fn verify_delete_message(
    req: &DeleteMessageRequest,
    device_pubkey: &[u8],
) -> Result<(), DeviceError> {
    let payload = delete_message_signing_payload(req);
    verify_device_signature(device_pubkey, &payload, &req.signature)
}

/// 构造 Hello 握手的待签名载荷（固定字段序，server/client 两端一致）。
/// `device_signature` 字段本身不参与签名。
pub fn hello_signing_payload(hello: &Hello) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-hello-v1\0");
    payload.extend_from_slice(&hello.protocol_version.to_be_bytes());
    if let Some(identity) = &hello.identity {
        payload.extend_from_slice(identity.user_id.as_bytes());
        payload.push(0);
        payload.extend_from_slice(&identity.master_pubkey);
        payload.push(0);
        payload.extend_from_slice(identity.display_name.as_bytes());
    }
    if let Some(cert) = &hello.device_cert {
        payload.extend_from_slice(&prost::Message::encode_to_vec(cert));
    }
    payload
}

/// 辅助：从 SendMessage 提取内容文本字节（统一访问）。
trait MessageContentBytes {
    fn content_text_bytes(&self) -> Vec<u8>;
}

impl MessageContentBytes for SendMessage {
    fn content_text_bytes(&self) -> Vec<u8> {
        self.content
            .as_ref()
            .map(|c| c.text.as_bytes().to_vec())
            .unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::device::DeviceKeypair;
    use crate::proto::MessageContent;

    fn sample_msg() -> SendMessage {
        SendMessage {
            topic_id: "topic1".into(),
            msg_id: "abc123".into(),
            author_id: vec![1, 2, 3],
            device_id: "dev1".into(),
            client_ts: 1700000000,
            content: Some(MessageContent {
                text: "hello".into(),
                attachment: None,
                encrypted: vec![],
            }),
            signature: vec![],
            reply_to: String::new(),
        }
    }

    #[test]
    fn sign_and_verify_roundtrip() {
        let device = DeviceKeypair::generate();
        let mut msg = sample_msg();
        let payload = send_message_signing_payload(&msg);
        msg.signature = device.sign(&payload);

        assert!(verify_send_message(&msg, &device.public_bytes()).is_ok());
    }

    #[test]
    fn tamper_fails() {
        let device = DeviceKeypair::generate();
        let mut msg = sample_msg();
        let payload = send_message_signing_payload(&msg);
        msg.signature = device.sign(&payload);
        msg.msg_id = "tampered".into();

        assert!(verify_send_message(&msg, &device.public_bytes()).is_err());
    }

    #[test]
    fn edit_sign_and_verify_roundtrip() {
        let device = DeviceKeypair::generate();
        let mut req = EditMessageRequest {
            topic_id: "topic1".into(),
            msg_id: "abc123".into(),
            new_text: "编辑后的内容".into(),
            signature: vec![],
        };
        let payload = edit_message_signing_payload(&req);
        req.signature = device.sign(&payload);

        assert!(verify_edit_message(&req, &device.public_bytes()).is_ok());

        req.new_text = "被篡改".into();
        assert!(verify_edit_message(&req, &device.public_bytes()).is_err());
    }

    #[test]
    fn delete_sign_and_verify_roundtrip() {
        let device = DeviceKeypair::generate();
        let mut req = DeleteMessageRequest {
            topic_id: "topic1".into(),
            msg_id: "abc123".into(),
            signature: vec![],
        };
        let payload = delete_message_signing_payload(&req);
        req.signature = device.sign(&payload);

        assert!(verify_delete_message(&req, &device.public_bytes()).is_ok());

        req.msg_id = "tampered".into();
        assert!(verify_delete_message(&req, &device.public_bytes()).is_err());
    }
}
