// LonIsle 服务器管理界面（M2 完整版）
const state = {
  members: [],
  requests: [],
  topics: [],
};

// ---- 管理 Token（首次访问时输入，存 localStorage） ----
const TOKEN_KEY = "lonisle_admin_token";

function adminToken() {
  let t = localStorage.getItem(TOKEN_KEY);
  if (!t) {
    t = prompt("请输入管理 API Token（服务器首次启动时打印在控制台）：") || "";
    if (t) localStorage.setItem(TOKEN_KEY, t.trim());
  }
  return t.trim();
}

async function apiFetch(url, options = {}, confirm = false) {
  const headers = Object.assign(
    { Authorization: "Bearer " + adminToken() },
    options.headers || {}
  );
  if (confirm) headers["X-Admin-Confirm"] = adminToken();
  const res = await fetch(url, Object.assign({}, options, { headers }));
  if (res.status === 401) {
    localStorage.removeItem(TOKEN_KEY);
    alert("管理 Token 无效，请重新输入");
    throw new Error("unauthorized");
  }
  if (res.status === 403) {
    alert("该操作为高危操作，需要二次确认");
    throw new Error("forbidden");
  }
  return res;
}

async function getJSON(url) {
  const res = await apiFetch(url);
  return res.json();
}

async function postJSON(url, data, confirm = false) {
  const res = await apiFetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  }, confirm);
  return res.json();
}

// ---- 概览 ----
async function fetchStatus() {
  const data = await getJSON("/api/status");
  document.getElementById("server-name").textContent = data.name || "—";
  document.getElementById("server-id").textContent = data.server_id || "—";
  document.getElementById("member-count").textContent = data.member_count;
  document.getElementById("server-strategy").textContent = strategyLabel(data.strategy);
  document.getElementById("server-desc").textContent = data.description || "";
}

function strategyLabel(s) {
  return { approval: "审批加入", open: "开放加入", invite_only: "仅邀请" }[s] || s;
}

// ---- 审批 ----
async function fetchRequests() {
  const data = await getJSON("/api/join-requests");
  state.requests = data.requests || [];
  const body = document.getElementById("requests-body");
  const empty = document.getElementById("requests-empty");
  body.innerHTML = "";
  empty.hidden = state.requests.length > 0;

  const badge = document.getElementById("req-badge");
  badge.hidden = state.requests.length === 0;

  for (const r of state.requests) {
    const tr = document.createElement("tr");
    const time = new Date(r.created_at * 1000).toLocaleString("zh-CN");
    tr.innerHTML = `
      <td>${escapeHtml(r.display_name)}</td>
      <td class="mono">${escapeHtml(r.user_id)}</td>
      <td>${escapeHtml(r.reason || "—")}</td>
      <td>${time}</td>
      <td>
        <button class="btn small approve" data-id="${r.request_id}">同意</button>
        <button class="btn small reject" data-id="${r.request_id}">拒绝</button>
        <button class="btn small ghost" data-id="${r.request_id}">忽略</button>
      </td>
    `;
    body.appendChild(tr);
  }

  body.querySelectorAll(".approve").forEach((b) =>
    b.addEventListener("click", () => processRequest(b.dataset.id, true))
  );
  body.querySelectorAll(".reject").forEach((b) =>
    b.addEventListener("click", () => processRequest(b.dataset.id, false))
  );
  body.querySelectorAll(".ghost").forEach((b) =>
    b.addEventListener("click", () => ignoreRequest(b.dataset.id))
  );
}

async function processRequest(id, approve) {
  await postJSON("/api/join-requests/process", { request_id: id, approve });
  fetchRequests();
  fetchMembers();
  fetchStatus();
}

async function ignoreRequest(id) {
  await postJSON("/api/join-requests/ignore", { request_id: id });
  fetchRequests();
}

// ---- 成员 ----
async function fetchMembers() {
  const data = await getJSON("/api/members");
  state.members = data.members || [];
  const body = document.getElementById("members-body");
  body.innerHTML = "";

  for (const m of state.members) {
    const tr = document.createElement("tr");
    const role = roleLabel(m.role);
    const roleClass = m.role === "owner" ? "owner" : m.role === "admin" ? "admin" : "member";
    const statusBits = [];
    if (m.banned) statusBits.push('<span class="badge banned">封禁</span>');
    if (m.muted) statusBits.push('<span class="badge muted">禁言</span>');
    const joined = new Date(m.joined_at * 1000).toLocaleString("zh-CN");
    tr.innerHTML = `
      <td>${escapeHtml(m.display_name)}</td>
      <td class="mono">${escapeHtml(m.user_id)}</td>
      <td><span class="badge ${roleClass}">${role}</span></td>
      <td>${statusBits.join(" ") || '<span class="badge member">正常</span>'}</td>
      <td>${joined}</td>
      <td class="ops">
        ${m.role !== "owner" ? `
          <button class="btn small ghost" data-op="admin" data-id="${m.user_id}">设为管理员</button>
          <button class="btn small ghost" data-op="member" data-id="${m.user_id}">降为成员</button>
          <button class="btn small ghost" data-op="mute" data-id="${m.user_id}">${m.muted ? "解除禁言" : "禁言"}</button>
          <button class="btn small ghost" data-op="ban" data-id="${m.user_id}">${m.banned ? "解除封禁" : "封禁"}</button>
          <button class="btn small reject" data-op="kick" data-id="${m.user_id}">踢出</button>
        ` : ""}
      </td>
    `;
    body.appendChild(tr);
  }

  body.querySelectorAll("[data-op]").forEach((b) =>
    b.addEventListener("click", () => memberOp(b.dataset.op, b.dataset.id, b))
  );
}

async function memberOp(op, userId, btn) {
  if (op === "admin" || op === "member") {
    await postJSON("/api/members/role", { user_id: userId, role: op });
  } else if (op === "mute") {
    const muted = btn.textContent.trim() === "禁言";
    await postJSON("/api/members/mute", { user_id: userId, value: muted });
  } else if (op === "ban") {
    const banned = btn.textContent.trim() === "封禁";
    await postJSON("/api/members/ban", { user_id: userId, value: banned });
  } else if (op === "kick") {
    if (!confirm("确认踢出该成员？")) return;
    await postJSON("/api/members/kick", { user_id: userId });
  }
  fetchMembers();
  fetchStatus();
}

function roleLabel(r) {
  return { owner: "所有者", admin: "管理员", member: "成员" }[r] || r;
}

// ---- 话题 ----
async function fetchTopics() {
  const data = await getJSON("/api/topics");
  state.topics = data.topics || [];
  const body = document.getElementById("topics-body");
  body.innerHTML = "";

  // 音视频话题入口仅在配置 LiveKit 后显示（F-TOPIC-6）
  try {
    const lk = await getJSON("/api/livekit");
    const typeSel = document.getElementById("topic-type");
    let avOpt = typeSel.querySelector('option[value="av"]');
    if (lk.url && !avOpt) {
      avOpt = document.createElement("option");
      avOpt.value = "av";
      avOpt.textContent = "音视频（LiveKit）";
      typeSel.appendChild(avOpt);
    } else if (!lk.url && avOpt) {
      avOpt.remove();
    }
    const hint = document.getElementById("topic-av-hint");
    if (hint) hint.hidden = !!lk.url;
  } catch (_) {}

  const typeLabels = { text: "普通", announcement: "订阅", av: "音视频" };
  for (let i = 0; i < state.topics.length; i++) {
    const t = state.topics[i];
    const tr = document.createElement("tr");
    const typeLabel = typeLabels[t.type] || t.type;
    const permLabel = t.permission === "readonly" ? "只读" : "公开";
    tr.innerHTML = `
      <td>${escapeHtml(t.name)}</td>
      <td>${escapeHtml(t.description || "—")}</td>
      <td><span class="badge ${t.type === "announcement" ? "owner" : "member"}">${typeLabel}</span></td>
      <td>${permLabel}</td>
      <td><span class="badge ${t.push_enabled ? "owner" : "member"}">${t.push_enabled ? "开启" : "关闭"}</span></td>
      <td>
        <button class="btn small" data-edit-id="${t.topic_id}">编辑</button>
        <button class="btn small" data-up-id="${i}" ${i === 0 ? "disabled" : ""}>↑</button>
        <button class="btn small" data-down-id="${i}" ${i === state.topics.length - 1 ? "disabled" : ""}>↓</button>
        <button class="btn small reject" data-del-id="${t.topic_id}">删除</button>
      </td>
    `;
    body.appendChild(tr);
  }

  body.querySelectorAll("[data-edit-id]").forEach((b) =>
    b.addEventListener("click", () => {
      const t = state.topics.find((x) => x.topic_id === b.dataset.editId);
      if (t) openTopicModal(t);
    })
  );
  body.querySelectorAll("[data-up-id]").forEach((b) =>
    b.addEventListener("click", () => moveTopic(parseInt(b.dataset.upId, 10), -1))
  );
  body.querySelectorAll("[data-down-id]").forEach((b) =>
    b.addEventListener("click", () => moveTopic(parseInt(b.dataset.downId, 10), 1))
  );
  body.querySelectorAll("[data-del-id]").forEach((b) =>
    b.addEventListener("click", async () => {
      if (!confirm("确认删除该话题？")) return;
      await postJSON("/api/topics/delete", { topic_id: b.dataset.delId });
      fetchTopics();
    })
  );
}

// ---- 话题编辑弹窗（名称/描述/类型/权限/推送） ----
function openTopicModal(t) {
  document.getElementById("edit-topic-id").value = t.topic_id;
  document.getElementById("edit-topic-name").value = t.name;
  document.getElementById("edit-topic-desc").value = t.description || "";
  document.getElementById("edit-topic-type").value = t.type || "text";
  document.getElementById("edit-topic-perm").value = t.permission || "public";
  document.getElementById("edit-topic-push").checked = !!t.push_enabled;
  document.getElementById("topic-modal").classList.remove("hidden");
}

function closeTopicModal() {
  document.getElementById("topic-modal").classList.add("hidden");
}

async function saveTopicModal() {
  const id = document.getElementById("edit-topic-id").value;
  const name = document.getElementById("edit-topic-name").value.trim();
  if (!name) return alert("话题名称不能为空");
  await postJSON("/api/topics/update", {
    topic_id: id,
    name,
    description: document.getElementById("edit-topic-desc").value.trim(),
    type: document.getElementById("edit-topic-type").value,
    permission: document.getElementById("edit-topic-perm").value,
    push_enabled: document.getElementById("edit-topic-push").checked,
  });
  closeTopicModal();
  fetchTopics();
}

// ---- 话题排序（↑/↓，F-TOPIC-2） ----
async function moveTopic(index, delta) {
  const target = index + delta;
  if (target < 0 || target >= state.topics.length) return;
  const arr = state.topics.slice();
  const [item] = arr.splice(index, 1);
  arr.splice(target, 0, item);
  await postJSON("/api/topics/reorder", { topic_ids: arr.map((t) => t.topic_id) });
  state.topics = arr;
  fetchTopics();
}

async function createTopic() {
  const name = document.getElementById("topic-name").value.trim();
  if (!name) return;
  await postJSON("/api/topics/create", {
    name,
    description: document.getElementById("topic-desc").value.trim(),
    type: document.getElementById("topic-type").value,
    permission: document.getElementById("topic-perm").value,
    push_enabled: document.getElementById("topic-push-create").checked,
  });
  document.getElementById("topic-name").value = "";
  document.getElementById("topic-desc").value = "";
  document.getElementById("topic-push-create").checked = false;
  fetchTopics();
}

// ---- 设置 ----
async function fetchSettings() {
  const data = await getJSON("/api/settings");
  document.getElementById("setting-name").value = data.name || "";
  document.getElementById("setting-desc").value = data.description || "";
  document.getElementById("setting-strategy").value = data.strategy || "approval";
  // 图标预览（icon 为 "ext:ts" 版本标识，附带于 URL 做缓存失效）
  const preview = document.getElementById("setting-icon-preview");
  const empty = document.getElementById("setting-icon-empty");
  if (data.icon) {
    preview.src = "/icon?v=" + encodeURIComponent(data.icon);
    preview.hidden = false;
    empty.hidden = true;
  } else {
    preview.hidden = true;
    empty.hidden = false;
  }
}

async function uploadServerIcon() {
  const input = document.getElementById("setting-icon-file");
  if (!input.files || !input.files[0]) {
    alert("请先选择图片文件");
    return;
  }
  const fd = new FormData();
  fd.append("file", input.files[0]);
  const res = await apiFetch("/api/settings/icon", { method: "POST", body: fd });
  const data = await res.json();
  if (data.ok === false) {
    alert("上传失败：" + (data.error || "未知错误"));
    return;
  }
  input.value = "";
  fetchSettings();
  alert("图标已更新，客户端重连后生效");
}

async function saveSettings() {
  await postJSON("/api/settings/update", {
    name: document.getElementById("setting-name").value.trim(),
    description: document.getElementById("setting-desc").value.trim(),
    strategy: document.getElementById("setting-strategy").value,
  });
  fetchStatus();
  alert("设置已保存");
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// ---- 高级设置：迁移/限速/已读开关/LiveKit ----
async function fetchAdvanced() {
  try {
    const migrate = await getJSON("/api/migrate");
    if (document.getElementById("migrate-address")) {
      document.getElementById("migrate-address").value = migrate.target_address || "";
      document.getElementById("migrate-fingerprint").value = migrate.target_fingerprint || "";
    }
  } catch (e) {}
  try {
    const limits = await getJSON("/api/limits");
    document.getElementById("limit-rate").value = limits.rate_limit_per_minute ?? 0;
    // 服务端存字节，界面按 MB 展示（保留 2 位小数，去除尾零）
    document.getElementById("limit-att-size").value =
      bytesToMb(limits.max_attachment_size ?? 0);
  } catch (e) {}
  try {
    const mr = await getJSON("/api/mention-read");
    document.getElementById("mention-read").value = String(mr.enabled === true);
  } catch (e) {}
  try {
    const lk = await getJSON("/api/livekit");
    document.getElementById("livekit-url").value = lk.url || "";
    document.getElementById("livekit-key").value = lk.api_key || "";
  } catch (e) {}
  try {
    fetchTls();
  } catch (e) {}
}

async function saveMigrate() {
  if (!confirm("确认发布迁移公告？客户端将收到迁移提示（高危操作）")) return;
  await postJSON("/api/migrate/update", {
    target_address: document.getElementById("migrate-address").value.trim(),
    target_fingerprint: document.getElementById("migrate-fingerprint").value.trim(),
  }, true);
  alert("迁移公告已发布（含服务器签名）");
}

// 字节 ↔ MB 换算（界面按 MB 输入/展示，服务端按字节存储）
function bytesToMb(bytes) {
  const mb = bytes / 1048576;
  return mb % 1 === 0 ? String(mb) : String(Math.round(mb * 100) / 100);
}
function mbToBytes(mb) {
  return Math.round((parseFloat(mb) || 0) * 1048576);
}

async function saveLimits() {
  await postJSON("/api/limits/update", {
    rate_limit_per_minute: parseInt(document.getElementById("limit-rate").value) || 0,
    max_attachment_size: mbToBytes(document.getElementById("limit-att-size").value),
  });
  alert("限制配置已保存");
}

async function saveMentionRead() {
  await postJSON("/api/mention-read/update", {
    enabled: document.getElementById("mention-read").value === "true",
  });
  alert("已读回执开关已保存");
}

async function saveLiveKit() {
  if (!confirm("确认保存 LiveKit 配置？（高危操作，将影响音视频话题）")) return;
  await postJSON("/api/livekit/update", {
    url: document.getElementById("livekit-url").value.trim(),
    api_key: document.getElementById("livekit-key").value.trim(),
    api_secret: document.getElementById("livekit-secret").value.trim(),
  }, true);
  alert("LiveKit 配置已保存");
}

// ---- TLS 证书配置（HTTPS 外部证书，重启生效） ----
async function fetchTls() {
  const data = await getJSON("/api/tls-config");
  document.getElementById("tls-cert-path").value = data.cert_path || "";
  document.getElementById("tls-key-path").value = data.key_path || "";
  const status = data.external
    ? "✅ 外部证书已配置（重启服务生效）"
    : "⚠️ 未配置（当前使用自签证书）";
  document.getElementById("tls-current").textContent =
    `状态：${status} · 证书 ${data.cert_path || "自签自动生成"} · 私钥 ${data.key_path || "—"}`;
}

async function saveTls() {
  await postJSON("/api/tls-config", {
    cert_path: document.getElementById("tls-cert-path").value.trim(),
    key_path: document.getElementById("tls-key-path").value.trim(),
  });
  alert("证书路径已保存，重启服务后生效");
  fetchTls();
}

// ---- 数据导出（F-PERM-2a，高危：需鉴权 + 二次确认头，不能用裸链接跳转） ----
async function downloadExport(zip) {
  const url = zip ? "/api/export.zip" : "/api/export";
  const res = await apiFetch(url, {}, true);
  if (!res.ok) {
    alert("导出失败");
    return;
  }
  const blob = await res.blob();
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = zip ? "lonisle-export.zip" : "lonisle-export.json";
  a.click();
  URL.revokeObjectURL(a.href);
}

// ---- Bot 管理（F-BOT） ----
async function fetchBots() {
  const data = await getJSON("/api/bots");
  const body = document.getElementById("bots-body");
  body.innerHTML = "";
  for (const b of data.bots || []) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="mono">${escapeHtml(b.bot_id)}</td>
      <td>${escapeHtml(b.name)}</td>
      <td>${escapeHtml(b.events || "[]")}</td>
      <td><span class="badge ${b.revoked ? 'banned' : 'member'}">${b.revoked ? '已撤销' : '活跃'}</span></td>
      <td>
        ${!b.revoked ? `
          <button class="btn small ghost" data-ev="${b.bot_id}">设置事件订阅</button>
          <button class="btn small reject" data-rv="${b.bot_id}">撤销</button>
        ` : ""}
      </td>
    `;
    body.appendChild(tr);
  }
  body.querySelectorAll("[data-rv]").forEach((b) => b.addEventListener("click", async () => {
    if (!confirm("确认撤销该 Bot？其 Token 立即失效。")) return;
    await postJSON("/api/bots/revoke", { bot_id: b.dataset.rv });
    fetchBots();
  }));
  body.querySelectorAll("[data-ev]").forEach((b) => b.addEventListener("click", async () => {
    const input = prompt("订阅事件（逗号分隔：message,member,join,system；留空 = 全部）", "message");
    if (input === null) return;
    const events = input.split(",").map((s) => s.trim()).filter(Boolean);
    await postJSON("/api/bots/events", { bot_id: b.dataset.ev, events });
    fetchBots();
  }));
}

async function createBot() {
  const name = document.getElementById("bot-name").value.trim();
  if (!name) return alert("请输入 Bot 名称");
  const data = await postJSON("/api/bots/create", { name });
  if (data.ok) {
    alert("Bot Token（仅显示一次，请立即保存）：\n\n" + data.token);
    document.getElementById("bot-name").value = "";
    fetchBots();
  } else {
    alert("注册失败");
  }
}

// ---- 数据管理 ----
async function clearTopic() {
  const topicId = document.getElementById("clear-topic-id").value.trim();
  if (!topicId) return alert("请输入 topic_id");
  if (!confirm("确认清除该话题全部消息（连带附件）？")) return;
  const res = await apiFetch("/api/clear/topic", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Admin-Confirm": adminToken() },
    body: JSON.stringify({ topic_id: topicId }),
  });
  alert((await res.json()).ok ? "已清除" : "清除失败");
}

async function clearAll() {
  if (!confirm("⚠ 高危操作：确认清空全部消息？此操作不可恢复！")) return;
  if (!confirm("再次确认：真的要清空全部消息吗？")) return;
  const res = await apiFetch("/api/clear/all", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Admin-Confirm": adminToken() },
    body: "{}",
  });
  alert((await res.json()).ok ? "已清空" : "清空失败");
}

// ---- 导航 ----
document.querySelectorAll(".nav-item").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav-item").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    const page = btn.dataset.page;
    document.querySelectorAll(".page").forEach((p) => p.classList.add("hidden"));
    document.getElementById("page-" + page).classList.remove("hidden");
    if (page === "requests") fetchRequests();
    if (page === "members") fetchMembers();
    if (page === "topics") fetchTopics();
    if (page === "settings") fetchSettings();
    if (page === "advanced") fetchAdvanced();
    if (page === "bots") fetchBots();
    if (page === "stickers") fetchStickerPacks();
    if (page === "logs") fetchLogs();
  });
});

// ---- 日志查看 ----
async function fetchLogs() {
  const lines = document.getElementById("log-lines").value || 500;
  try {
    const res = await apiFetch("api/logs?lines=" + lines);
    const data = await res.json();
    document.getElementById("log-file").textContent = data.file ? "当前文件：" + data.file : "（暂无日志文件）";
    document.getElementById("log-content").textContent = data.content || "（暂无日志）";
  } catch (e) {
    document.getElementById("log-content").textContent = "读取日志失败：" + e.message;
  }
}

// 事件绑定
document.getElementById("log-refresh").addEventListener("click", fetchLogs);
document.getElementById("log-lines").addEventListener("change", fetchLogs);
document.getElementById("topic-create").addEventListener("click", createTopic);
document.getElementById("topic-modal-save").addEventListener("click", saveTopicModal);
document.getElementById("topic-modal-cancel").addEventListener("click", closeTopicModal);
document.getElementById("topic-modal").addEventListener("click", (e) => {
  if (e.target === e.currentTarget) closeTopicModal();
});
document.getElementById("setting-save").addEventListener("click", saveSettings);
document.getElementById("setting-icon-upload").addEventListener("click", uploadServerIcon);
document.getElementById("migrate-save").addEventListener("click", saveMigrate);
document.getElementById("limits-save").addEventListener("click", saveLimits);
document.getElementById("mention-read-save").addEventListener("click", saveMentionRead);
document.getElementById("livekit-save").addEventListener("click", saveLiveKit);
document.getElementById("tls-save").addEventListener("click", saveTls);
document.getElementById("clear-topic-btn").addEventListener("click", clearTopic);
document.getElementById("export-json").addEventListener("click", () => downloadExport(false));
document.getElementById("export-zip").addEventListener("click", () => downloadExport(true));
document.getElementById("clear-all-btn").addEventListener("click", clearAll);
document.getElementById("bot-create").addEventListener("click", createBot);

// ---- 表情包管理（F-STICKER） ----

async function fetchStickerPacks() {
  const data = await getJSON("/api/sticker-packs");
  const wrap = document.getElementById("stk-packs");
  wrap.innerHTML = "";
  for (const p of data.packs || []) {
    const box = document.createElement("div");
    box.className = "form-col";
    box.style.cssText = "border:1px solid rgba(255,255,255,0.1);border-radius:12px;padding:14px;margin-bottom:16px;";
    const head = document.createElement("div");
    head.className = "form-row";
    head.innerHTML = `
      <strong style="font-size:15px">${escapeHtml(p.name)}</strong>
      <button class="btn" data-stk-pack-edit="${p.id}">改</button>
      <button class="btn reject" data-stk-pack-del="${p.id}">删包</button>
      <button class="btn" data-stk-pack-up="${p.id}">上移</button>
      <button class="btn" data-stk-pack-down="${p.id}">下移</button>
    `;
    box.appendChild(head);
    const add = document.createElement("div");
    add.className = "form-row";
    add.innerHTML = `
      <input type="file" accept="image/*" style="flex:1;min-width:200px;color:var(--text)" />
      <button class="btn" data-stk-add="${p.id}">上传为表情</button>
    `;
    box.appendChild(add);
    const grid = document.createElement("div");
    grid.style.cssText = "display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;";
    p.stickers.forEach((s, idx) => {
      const chip = document.createElement("div");
      chip.style.cssText = "display:flex;align-items:center;gap:6px;padding:6px 10px;border-radius:8px;background:var(--bg-3);";
      const media = s.type === "image"
        ? `<img src="/attachments/${s.content.replace("att:", "")}/thumbnail" style="height:40px;width:auto;max-width:120px;object-fit:contain;border-radius:4px" onerror="this.style.display='none'" />`
        : `<span style="font-size:20px">${escapeHtml(s.content)}</span>`;
      chip.innerHTML = `
        ${media}
        <button class="btn reject" style="padding:2px 8px" data-stk-del="${s.id}">×</button>
        <button class="btn" style="padding:2px 8px" data-stk-up="${s.id}" data-pack="${p.id}">↑</button>
        <button class="btn" style="padding:2px 8px" data-stk-down="${s.id}" data-pack="${p.id}">↓</button>
      `;
      grid.appendChild(chip);
    });
    box.appendChild(grid);
    wrap.appendChild(box);
  }
  // 包级事件
  wrap.querySelectorAll("[data-stk-pack-edit]").forEach((b) =>
    b.addEventListener("click", () => {
      const name = prompt("新包名：", "");
      if (!name) return;
      postJSON("/api/sticker-packs/save", { id: b.dataset.stkPackEdit, name, icon: "" }).then(fetchStickerPacks);
    }));
  wrap.querySelectorAll("[data-stk-pack-del]").forEach((b) =>
    b.addEventListener("click", async () => {
      if (!confirm("删除该表情包？")) return;
      await postJSON("/api/sticker-packs/delete", { id: b.dataset.stkPackDel });
      fetchStickerPacks();
    }));
  wrap.querySelectorAll("[data-stk-pack-up],[data-stk-pack-down]").forEach((b) => {
    b.addEventListener("click", () => moveStickerPack(b.dataset.stkPackUp || b.dataset.stkPackDown, b.dataset.stkPackUp ? -1 : 1));
  });
  wrap.querySelectorAll("[data-stk-add]").forEach((b) =>
    b.addEventListener("click", async () => {
      const packId = b.dataset.stkAdd;
      const fileInput = b.parentElement.querySelector('input[type="file"]');
      if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        alert("请先选择图片/GIF 文件");
        return;
      }
      const file = fileInput.files[0];
      const btn = b;
      btn.disabled = true;
      btn.textContent = "上传中…";
      try {
        const fd = new FormData();
        fd.append("file", file);
        fd.append("msg_id", "sticker-" + Date.now());
        fd.append("kind", "image");
        fd.append("user_id", "admin");
        const resp = await fetch("/attachments/upload", { method: "POST", body: fd });
        const data = await resp.json();
        if (data.ok && data.attachment_id) {
          await postJSON("/api/stickers/save", { id: "", pack_id: packId, type: "image", content: "att:" + data.attachment_id });
        } else {
          alert("上传失败：" + (data.error || "未知错误"));
        }
      } catch (e) {
        alert("上传失败：" + e);
      }
      btn.disabled = false;
      btn.textContent = "上传为表情";
      fileInput.value = "";
      fetchStickerPacks();
    }));
  wrap.querySelectorAll("[data-stk-del]").forEach((b) =>
    b.addEventListener("click", async () => {
      await postJSON("/api/stickers/delete", { id: b.dataset.stkDel });
      fetchStickerPacks();
    }));
  wrap.querySelectorAll("[data-stk-up],[data-stk-down]").forEach((b) => {
    b.addEventListener("click", () => moveSticker(b.dataset.stkUp || b.dataset.stkDown, b.dataset.pack, b.dataset.stkUp ? -1 : 1));
  });
}

async function moveStickerPack(id, dir) {
  const data = await getJSON("/api/sticker-packs");
  const packs = data.packs || [];
  const idx = packs.findIndex((p) => p.id === id);
  const j = idx + dir;
  if (idx < 0 || j < 0 || j >= packs.length) return;
  [packs[idx], packs[j]] = [packs[j], packs[idx]];
  await postJSON("/api/sticker-packs/reorder", { ids: packs.map((p) => p.id) });
  fetchStickerPacks();
}

async function moveSticker(id, packId, dir) {
  const data = await getJSON("/api/sticker-packs");
  const pack = (data.packs || []).find((p) => p.id === packId);
  if (!pack) return;
  const idx = pack.stickers.findIndex((s) => s.id === id);
  const j = idx + dir;
  if (idx < 0 || j < 0 || j >= pack.stickers.length) return;
  [pack.stickers[idx], pack.stickers[j]] = [pack.stickers[j], pack.stickers[idx]];
  await postJSON("/api/stickers/reorder", { pack_id: packId, ids: pack.stickers.map((s) => s.id) });
  fetchStickerPacks();
}

document.getElementById("stk-pack-add").addEventListener("click", async () => {
  const name = document.getElementById("stk-pack-name").value.trim();
  if (!name) { alert("请输入包名"); return; }
  await postJSON("/api/sticker-packs/save", { id: "", name, icon: "" });
  document.getElementById("stk-pack-name").value = "";
  fetchStickerPacks();
});

// 初始化
fetchStatus();
fetchRequests();
fetchMembers();
fetchTopics();
setInterval(fetchStatus, 5000);
setInterval(fetchRequests, 10000);
