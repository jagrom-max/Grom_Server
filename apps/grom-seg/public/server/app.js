const fallback = {
  generated_at: null,
  status: "warn",
  summary: { failures: 0, warnings: 1, services_ok: 0, services_total: 0 },
  resources: {
    cpu_percent: 0,
    memory_percent: 0,
    disk_percent: 0,
    backup_disk_percent: 0
  },
  backups: {
    db_age_hours: null,
    vm_age_hours: null,
    restore_drill: "pendente"
  },
  security: {
    admin_ports: "nao testado",
    vpn: "pendente",
    gono: "NO-GO"
  },
  services: [
    { name: "OPNsense", role: "Firewall", status: "warn" },
    { name: "Web/SigePol", role: "CT110", status: "warn" },
    { name: "Database", role: "CT111", status: "warn" },
    { name: "Backup", role: "CT112", status: "warn" },
    { name: "Monitoring", role: "CT113", status: "warn" },
    { name: "VPN", role: "CT114", status: "warn" }
  ]
};

const $ = (id) => document.getElementById(id);
const DATA_URL = "./data/status.json";
const REFRESH_MS = 60000;
const FETCH_TIMEOUT_MS = 8000;
let loading = false;
let refreshTimer = null;

function setText(id, value) {
  const node = $(id);
  if (node) node.textContent = value;
}

function setClass(id, value) {
  const node = $(id);
  if (node) node.className = value;
}

function label(status) {
  if (status === "ok") return "OK";
  if (status === "fail") return "Falha";
  return "Aviso";
}

function clamp(value) {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, n));
}

function bar(id, value) {
  const node = $(id);
  if (!node) return;
  const pct = clamp(value);
  node.style.width = `${pct}%`;
  node.classList.toggle("warn", pct >= 75 && pct < 90);
  node.classList.toggle("fail", pct >= 90);
}

function percent(value) {
  if (value === null || value === undefined) return "--";
  return `${Math.round(clamp(value))}%`;
}

function age(value) {
  if (value === null || value === undefined) return "pendente";
  return `${value}h`;
}

function escapeText(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[char]));
}

function normalizeStatus(value) {
  return ["ok", "warn", "fail"].includes(value) ? value : "warn";
}

function setLoading(isLoading) {
  const refresh = $("refresh");
  loading = isLoading;
  if (refresh) {
    refresh.disabled = isLoading;
    refresh.textContent = isLoading ? "Atualizando..." : "Atualizar";
  }
}

function render(data, options = {}) {
  const status = data.status || "warn";
  const summary = data.summary || fallback.summary;
  const resources = data.resources || fallback.resources;
  const backups = data.backups || fallback.backups;
  const security = data.security || fallback.security;
  const services = Array.isArray(data.services) ? data.services : [];

  setText("overall-status", label(status));
  setText("overall-detail", options.message || (status === "ok"
    ? "Todos os sinais principais estao dentro do esperado."
    : "Ha pontos que exigem revisao antes de uso definitivo."));
  setText("fail-count", summary.failures ?? 0);
  setText("warn-count", summary.warnings ?? 0);
  setText("service-count", `${summary.services_ok ?? 0}/${summary.services_total ?? services.length}`);
  setText("sidebar-status-text", label(status));
  setClass("sidebar-dot", `dot ${normalizeStatus(status)}`);
  setText("updated-at", data.generated_at
    ? `Atualizado em ${new Date(data.generated_at).toLocaleString("pt-BR")}`
    : (options.source || "Aguardando healthcheck real"));

  setText("cpu-value", percent(resources.cpu_percent));
  setText("memory-value", percent(resources.memory_percent));
  setText("disk-value", percent(resources.disk_percent));
  setText("backup-disk-value", percent(resources.backup_disk_percent));
  bar("cpu-bar", resources.cpu_percent);
  bar("memory-bar", resources.memory_percent);
  bar("disk-bar", resources.disk_percent);
  bar("backup-disk-bar", resources.backup_disk_percent);

  setText("db-backup-age", age(backups.db_age_hours));
  setText("vm-backup-age", age(backups.vm_age_hours));
  setText("restore-status", security.restore_drill || backups.restore_drill || "pendente");
  setText("admin-ports", security.admin_ports || "nao testado");
  setText("vpn-status", security.vpn || "pendente");
  setText("gono-status", security.gono || "NO-GO");

  const list = $("services");
  if (!list) return;
  list.innerHTML = "";
  services.forEach((service) => {
    const serviceStatus = normalizeStatus(service.status);
    const item = document.createElement("article");
    item.className = "service";
    item.innerHTML = `
      <div>
        <strong>${escapeText(service.name)}</strong>
        <span>${escapeText(service.role || "")}</span>
      </div>
      <em class="pill ${serviceStatus}">${label(serviceStatus)}</em>
    `;
    list.appendChild(item);
  });
}

async function fetchStatus() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const response = await fetch(DATA_URL, {
      cache: "no-store",
      signal: controller.signal
    });
    if (!response.ok) throw new Error("status indisponivel");
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

async function load() {
  if (loading) return;
  setLoading(true);
  try {
    render(await fetchStatus());
  } catch (error) {
    const localFile = window.location.protocol === "file:";
    render(fallback, {
      source: localFile
        ? "Preview local sem servidor HTTP; usando dados de seguranca"
        : "Status indisponivel; usando dados de seguranca",
      message: localFile
        ? "Abra por um servidor HTTP local ou pelo Nginx para carregar status.json."
        : "Nao foi possivel carregar status.json dentro do tempo limite."
    });
  } finally {
    setLoading(false);
  }
}

function start() {
  const refresh = $("refresh");
  if (refresh) refresh.addEventListener("click", load);
  load();
  refreshTimer = setInterval(load, REFRESH_MS);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
