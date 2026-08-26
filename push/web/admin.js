// LonIsle 推送服务管理端（需要管理 API Key）
// 页面：白名单 / 限速 / 运行模式 / 黑名单 / 目录 / FCM 配置

// ---- 管理 Key（首次访问时输入，存 localStorage） ----
const KEY_STORAGE = "lonisle_push_admin_key";

function adminKey() {
  let k = localStorage.getItem(KEY_STORAGE);
  if (!k) {
    k = prompt("请输入管理 API Key（推送服务首次启动时打印在控制台）：") || "";
    if (k) localStorage.setItem(KEY_STORAGE, k.trim());
  }
  return k.trim();
}

async function apiFetch(url, options = {}) {
  const headers = Object.assign(
    { "X-Admin-Key": adminKey() },
    options.headers || {}
  );
  const res = await fetch(url, Object.assign({}, options, { headers }));
  if (res.status === 401) {
    localStorage.removeItem(KEY_STORAGE);
    alert("管理 Key 无效，请重新输入");
    throw new Error("unauthorized");
  }
  return res;
}

async function getJSON(url) {
  const res = await apiFetch(url);
  return res.json();
}

async function postJSON(url, data) {
  const res = await apiFetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
  return res.json();
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// ---- 白名单 ----
async function fetchWhitelist() {
  const data = await getJSON("/admin/whitelist");
  const body = document.getElementById("whitelist-body");
  body.innerHTML = "";
  for (const e of data.entries || []) {
    const tr = document.createElement("tr");
    const time = new Date(e.applied_at * 1000).toLocaleString("zh-CN");
    tr.innerHTML = `
      <td class="mono">${escapeHtml(e.server_id)}</td>
      <td><span class="badge ${e.approved ? 'approved' : 'pending'}">${e.approved ? '已通过' : '待审核'}</span></td>
      <td>${time}</td>
      <td>
        ${!e.approved ? `
          <button class="btn approve" data-id="${e.server_id}">通过</button>
          <button class="btn reject" data-id="${e.server_id}">拒绝</button>
        ` : ''}
      </td>
    `;
    body.appendChild(tr);
  }
  body.querySelectorAll(".approve").forEach((b) => b.addEventListener("click", () => approve(b.dataset.id, true)));
  body.querySelectorAll(".reject").forEach((b) => b.addEventListener("click", () => approve(b.dataset.id, false)));
}

async function approve(id, ok) {
  await postJSON("/admin/whitelist/approve", { server_id: id, approve: ok });
  fetchWhitelist();
}

async function addWhitelist() {
  const id = document.getElementById("whitelist-add-id").value.trim();
  if (!id) { alert("请输入服务器 ID"); return; }
  const url = document.getElementById("whitelist-add-url").value.trim();
  await postJSON("/admin/whitelist/add", { server_id: id, health_url: url });
  document.getElementById("whitelist-add-id").value = "";
  document.getElementById("whitelist-add-url").value = "";
  alert("已手动添加到白名单");
  fetchWhitelist();
}

// ---- 限速 ----
async function fetchRate() {
  const data = await getJSON("/admin/rate-limit");
  document.getElementById("rate-input").value = data.per_minute;
  document.getElementById("rate-current").textContent = `当前限速：${data.per_minute} 条/分钟`;
}

async function saveRate() {
  const perMinute = parseInt(document.getElementById("rate-input").value, 10);
  if (!perMinute || perMinute < 1) return;
  await postJSON("/admin/rate-limit/set", { per_minute: perMinute });
  fetchRate();
}

// ---- 目录（管理端） ----
async function fetchDirectory() {
  const data = await getJSON("/admin/directory");
  const body = document.getElementById("directory-body");
  body.innerHTML = "";
  for (const s of data.servers || []) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(s.name)}</td>
      <td class="mono">${escapeHtml(s.server_id)}</td>
      <td>${escapeHtml(s.address)}</td>
      <td><span class="badge ${s.approved ? 'approved' : 'pending'}">${s.approved ? '已上架' : '未上架'}</span></td>
      <td><button class="btn reject" data-id="${s.server_id}">下架</button></td>
    `;
    body.appendChild(tr);
  }
  body.querySelectorAll("[data-id]").forEach((b) => b.addEventListener("click", async () => {
    await postJSON("/admin/directory/remove", { server_id: b.dataset.id });
    fetchDirectory();
  }));
}

// ---- 运行模式（F-RATE-5） ----
async function fetchMode() {
  const data = await getJSON("/admin/mode");
  document.getElementById("mode-select").value = String(data.whitelist_mode);
  const modeLabel = data.whitelist_mode ? "白名单" : "黑名单";
  const fcm = data.fcm_configured ? "已启用" : "未配置（回退 Mock）";
  document.getElementById("mode-current").textContent =
    `当前模式：${modeLabel} · 熔断阈值：${data.circuit_breaker_threshold} 次 · FCM：${fcm}`;
}

async function saveMode() {
  const whitelist = document.getElementById("mode-select").value === "true";
  if (!confirm(`确认切换到${whitelist ? "白名单" : "黑名单"}模式？`)) return;
  await postJSON("/admin/mode", { whitelist_mode: whitelist });
  fetchMode();
}

// ---- 黑名单（F-RATE-6） ----
async function fetchBlacklist() {
  const data = await getJSON("/admin/blacklist");
  const body = document.getElementById("blacklist-body");
  body.innerHTML = "";
  for (const e of data.entries || []) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="mono">${escapeHtml(e.server_id)}</td>
      <td>${escapeHtml(e.reason || "—")}</td>
      <td><button class="btn approve" data-id="${e.server_id}">移出黑名单</button></td>
    `;
    body.appendChild(tr);
  }
  body.querySelectorAll("[data-id]").forEach((b) =>
    b.addEventListener("click", async () => {
      await postJSON("/admin/blacklist/remove", { server_id: b.dataset.id });
      fetchBlacklist();
    })
  );
}

async function addBlacklist() {
  const id = document.getElementById("blacklist-id").value.trim();
  if (!id) return alert("请输入服务器 ID");
  await postJSON("/admin/blacklist/add", {
    server_id: id,
    reason: document.getElementById("blacklist-reason").value.trim(),
  });
  document.getElementById("blacklist-id").value = "";
  document.getElementById("blacklist-reason").value = "";
  fetchBlacklist();
}

// ---- FCM 推送配置（F-PUSH-2：服务账号 / OAuth2 两种方式） ----
async function fetchFcm() {
  const data = await getJSON("/admin/fcm-config");
  document.getElementById("fcm-project").value = data.project_id || "";
  document.getElementById("fcm-client-id").value = data.client_id || "";
  // 敏感字段不回显，仅显示是否已设置
  document.getElementById("fcm-client-secret").value = "";
  document.getElementById("fcm-refresh-token").value = "";
  document.getElementById("fcm-service-account").value = "";
  const status = data.configured
    ? "✅ FCM 通道已启用"
    : "⚠️ 未配置（回退 Mock）";
  document.getElementById("fcm-current").textContent =
    `状态：${status} · 服务账号 ${data.service_account_set ? "已设置" : "未设置"} · Client Secret ${data.client_secret_set ? "已设置" : "未设置"} · Refresh Token ${data.refresh_token_set ? "已设置" : "未设置"}`;
}

async function saveFcm() {
  const body = {
    project_id: document.getElementById("fcm-project").value.trim(),
    client_id: document.getElementById("fcm-client-id").value.trim(),
    client_secret: document.getElementById("fcm-client-secret").value.trim(),
    refresh_token: document.getElementById("fcm-refresh-token").value.trim(),
    service_account_json: document.getElementById("fcm-service-account").value.trim(),
  };
  const res = await postJSON("/admin/fcm-config", body);
  if (res.ok === false) return alert("保存失败：" + (res.error || "未知错误"));
  alert(res.enabled ? "已保存，FCM 真实推送通道已启用" : "已保存（凭证不完整，仍为 Mock 通道）");
  fetchFcm();
}

// ---- TLS 证书配置（统一 HTTPS） ----
async function fetchTls() {
  const data = await getJSON("/admin/tls-config");
  document.getElementById("tls-cert-path").value = data.cert_path || "";
  document.getElementById("tls-key-path").value = data.key_path || "";
  const status = data.https
    ? "✅ HTTPS 已配置（重启服务生效）"
    : "⚠️ 未配置（当前 HTTP）";
  document.getElementById("tls-current").textContent =
    `状态：${status} · 证书 ${data.cert_path || "未设置"} · 私钥 ${data.key_path || "未设置"}`;
}

async function saveTls() {
  const body = {
    cert_path: document.getElementById("tls-cert-path").value.trim(),
    key_path: document.getElementById("tls-key-path").value.trim(),
  };
  const res = await postJSON("/admin/tls-config", body);
  if (res.ok === false) return alert("保存失败：" + (res.error || "未知错误"));
  alert(res.https ? "已保存，重启服务后启用 HTTPS" : "已保存，重启服务后回退 HTTP");
  fetchTls();
}

// ---- 导航 ----
document.querySelectorAll(".nav-item").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav-item").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    const page = btn.dataset.page;
    document.querySelectorAll(".page").forEach((p) => p.classList.add("hidden"));
    document.getElementById("page-" + page).classList.remove("hidden");
    if (page === "whitelist") fetchWhitelist();
    if (page === "rate") fetchRate();
    if (page === "mode") fetchMode();
    if (page === "blacklist") fetchBlacklist();
    if (page === "directory") fetchDirectory();
    if (page === "fcm") fetchFcm();
    if (page === "tls") fetchTls();
    if (page === "logs") fetchLogs();
  });
});

// ---- 日志查看 ----
async function fetchLogs() {
  const lines = document.getElementById("log-lines").value || 500;
  try {
    const res = await apiFetch("admin/logs?lines=" + lines);
    const data = await res.json();
    document.getElementById("log-file").textContent = data.file ? "当前文件：" + data.file : "（暂无日志文件）";
    document.getElementById("log-content").textContent = data.content || "（暂无日志）";
  } catch (e) {
    document.getElementById("log-content").textContent = "读取日志失败：" + e.message;
  }
}

document.getElementById("log-refresh").addEventListener("click", fetchLogs);
document.getElementById("log-lines").addEventListener("change", fetchLogs);
document.getElementById("rate-save").addEventListener("click", saveRate);
document.getElementById("mode-save").addEventListener("click", saveMode);
document.getElementById("blacklist-add").addEventListener("click", addBlacklist);
document.getElementById("whitelist-add").addEventListener("click", addWhitelist);
document.getElementById("fcm-save").addEventListener("click", saveFcm);
document.getElementById("tls-save").addEventListener("click", saveTls);

// 初始化
fetchWhitelist();
fetchRate();
fetchDirectory();
