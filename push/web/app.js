// LonIsle 推送网络 · 公开页面（服务目录 / 申请入列）
// 不需要管理 Key，任何人可访问。

// ---- 公开请求 ----
async function publicGet(url) {
  const res = await fetch(url);
  return res.json();
}

async function publicPost(url, data) {
  const res = await fetch(url, {
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

// ---- 服务目录（F-DISC-2/3：实时状态 + 人数） ----
async function fetchPublicDirectory() {
  const data = await publicGet("/directory");
  const body = document.getElementById("directory-public-body");
  body.innerHTML = "";
  for (const s of data.servers || []) {
    const tr = document.createElement("tr");
    const joinMode = { approval: "审批", open: "开放", invite: "邀请", invite_only: "邀请" }[s.join_mode] || s.join_mode || "—";
    const online = s.status === "online";
    const statusCell = online
      ? `<td><span class="badge approved">● 在线</span> <span class="count">${s.online}/${s.total} 人</span></td>`
      : `<td><span class="badge reject">● 离线</span></td>`;
    const descText = s.description && s.description.trim() ? s.description : "这个服务器啥都没写";
    tr.innerHTML = `
      ${statusCell}
      <td>${escapeHtml(s.name || "—")}</td>
      <td>${escapeHtml(descText)}</td>
      <td class="mono">${escapeHtml(s.address)}</td>
      <td>${joinMode}</td>
      <td><button class="btn" data-addr="${escapeHtml(s.address)}">复制地址</button></td>
    `;
    body.appendChild(tr);
  }
  body.querySelectorAll("[data-addr]").forEach((b) =>
    b.addEventListener("click", () => {
      navigator.clipboard.writeText(b.dataset.addr).then(() => {
        b.textContent = "已复制";
        setTimeout(() => (b.textContent = "复制地址"), 1500);
      });
    })
  );
}

// ---- 申请入列（F-DISC） ----
async function submitApply() {
  const id = document.getElementById("apply-id").value.trim();
  const desc = document.getElementById("apply-desc").value.trim();
  const health = document.getElementById("apply-health").value.trim();
  const result = document.getElementById("apply-result");
  if (!id || !health) {
    result.textContent = "请填写服务器 ID 与健康检查地址";
    return;
  }
  result.textContent = "提交中…";
  try {
    const res = await publicPost("/apply", {
      server_id: id,
      description: desc,
      health_url: health,
    });
    if (res.ok) {
      result.textContent = "✅ 申请已提交，等待管理员审核（管理员在管理端「白名单」页审批）";
      document.getElementById("apply-id").value = "";
      document.getElementById("apply-desc").value = "";
      document.getElementById("apply-health").value = "";
    } else {
      result.textContent = "❌ 提交失败：" + (res.error || "未知错误");
    }
  } catch (e) {
    result.textContent = "❌ 请求失败：" + e;
  }
}

// ---- 导航 ----
document.querySelectorAll(".nav-item").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav-item").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    const page = btn.dataset.page;
    document.querySelectorAll(".page").forEach((p) => p.classList.add("hidden"));
    document.getElementById("page-" + page).classList.remove("hidden");
    if (page === "directory-public") fetchPublicDirectory();
  });
});

document.getElementById("apply-submit").addEventListener("click", submitApply);

// 初始化（默认展示服务目录，公开无需 Key）
fetchPublicDirectory();
