// LonIsle 服务器公开首页（图标 / 名称 / 简介 / 人数 / 加入策略）
// 数据来源：公开状态接口 GET /status（无鉴权），30s 自动刷新。

const JOIN_MODE = {
  approval: "审批加入",
  open: "开放加入",
  invite: "仅邀请",
  invite_only: "仅邀请",
};

function el(id) {
  return document.getElementById(id);
}

async function loadStatus() {
  try {
    const res = await fetch("/status");
    if (!res.ok) throw new Error("status " + res.status);
    const d = await res.json();
    el("server-name").textContent = d.name || "—";
    el("server-desc").textContent = d.description || "暂无简介";
    el("server-online").textContent = d.online ?? 0;
    el("server-total").textContent = d.total ?? 0;
    el("server-join").textContent = JOIN_MODE[d.join_mode] || d.join_mode || "—";
    el("server-ver").textContent = d.protocol_version ?? "—";
    el("server-status").textContent = "● 服务运行中";
    // 服务器图标（未设置时回退 logo）
    const icon = el("server-icon");
    icon.onerror = () => {
      icon.onerror = null;
      icon.src = "logo.svg";
    };
    icon.src = "/icon?v=" + Date.now();
  } catch (e) {
    el("server-status").textContent = "● 服务离线（无法连接状态接口）";
  }
}

loadStatus();
setInterval(loadStatus, 30000);
