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

function label(status) {
  if (status === "ok") return "OK";
  if (status === "fail") return "Falha";
  return "Aviso";
}

function clamp(value) {
  const n = Number(value || 0);
  return Math.max(0, Math.min(100, n));
}

function bar(id, value) {
  const node = $(id);
  const pct = clamp(value);
  node.style.width = `${pct}%`;
  node.classList.toggle("warn", pct >= 75 && pct < 90);
  node.classList.toggle("fail", pct >= 90);
}

function percent(value) {
  if (value === null || value === undefined) return "--";
  return `${Math.round(Number(value))}%`;
}

function age(value) {
  if (value === null || value === undefined) return "pendente";
  return `${value}h`;
}

function render(data) {
  const status = data.status || "warn";
  const summary = data.summary || fallback.summary;
  const resources = data.resources || fallback.resources;
  const backups = data.backups || fallback.backups;
  const security = data.security || fallback.security;
  const services = data.services || [];

  $("overall-status").textContent = label(status);
  $("overall-detail").textContent = status === "ok"
    ? "Todos os sinais principais estao dentro do esperado."
    : "Ha pontos que exigem revisao antes de uso definitivo.";
  $("fail-count").textContent = summary.failures ?? 0;
  $("warn-count").textContent = summary.warnings ?? 0;
  $("service-count").textContent = `${summary.services_ok ?? 0}/${summary.services_total ?? services.length}`;
  $("sidebar-status-text").textContent = label(status);
  $("sidebar-dot").className = `dot ${status}`;
  $("updated-at").textContent = data.generated_at
    ? `Atualizado em ${new Date(data.generated_at).toLocaleString("pt-BR")}`
    : "Aguardando healthcheck real";

  $("cpu-value").textContent = percent(resources.cpu_percent);
  $("memory-value").textContent = percent(resources.memory_percent);
  $("disk-value").textContent = percent(resources.disk_percent);
  $("backup-disk-value").textContent = percent(resources.backup_disk_percent);
  bar("cpu-bar", resources.cpu_percent);
  bar("memory-bar", resources.memory_percent);
  bar("disk-bar", resources.disk_percent);
  bar("backup-disk-bar", resources.backup_disk_percent);

  $("db-backup-age").textContent = age(backups.db_age_hours);
  $("vm-backup-age").textContent = age(backups.vm_age_hours);
  $("restore-status").textContent = backups.restore_drill || "pendente";
  $("admin-ports").textContent = security.admin_ports || "nao testado";
  $("vpn-status").textContent = security.vpn || "pendente";
  $("gono-status").textContent = security.gono || "NO-GO";

  const list = $("services");
  list.innerHTML = "";
  services.forEach((service) => {
    const item = document.createElement("article");
    item.className = "service";
    item.innerHTML = `
      <div>
        <strong>${service.name}</strong>
        <span>${service.role || ""}</span>
      </div>
      <em class="pill ${service.status || "warn"}">${label(service.status)}</em>
    `;
    list.appendChild(item);
  });
}

async function load() {
  try {
    const response = await fetch("./data/status.json", { cache: "no-store" });
    if (!response.ok) throw new Error("status indisponivel");
    render(await response.json());
  } catch (error) {
    render(fallback);
  }
}

$("refresh").addEventListener("click", load);
load();
setInterval(load, 60000);
