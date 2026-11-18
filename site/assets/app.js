// Download links: read the newest published release from the GitHub API so links
// always point at the current installers. Falls back to the Releases page.
const REPO = "itsmdivakaran/statz";
const RELEASES = `https://github.com/${REPO}/releases`;
const PATTERNS = {
  "win-exe": /_x64-setup\.exe$/i,
  "win-msi": /\.msi$/i,
  "mac-arm": /_aarch64\.dmg$/i,
  "mac-intel": /_x64\.dmg$/i,
  "linux-appimage": /\.AppImage$/i,
  "linux-deb": /\.deb$/i,
};

function detectOS() {
  const p = (navigator.userAgentData?.platform || navigator.platform || navigator.userAgent).toLowerCase();
  if (p.includes("win")) return "win";
  if (p.includes("mac")) return "mac";
  if (p.includes("linux") && !/android/.test(navigator.userAgent.toLowerCase())) return "linux";
  return null;
}

async function latestRelease() {
  // /releases/latest skips prereleases, so take the newest non-draft from the list.
  const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=10`, { headers: { Accept: "application/vnd.github+json" } });
  if (!r.ok) throw new Error(r.status);
  const list = await r.json();
  return list.find((x) => !x.draft && x.assets?.length);
}

async function wireDownloads() {
  const os = detectOS();
  const links = document.querySelectorAll("[data-asset]");
  links.forEach((a) => (a.href = RELEASES));
  if (os) document.querySelector(`.dl [data-os="${os}"]`)?.classList.add("mine");

  const hero = document.getElementById("hero-dl");
  const heroLabel = { win: "Download for Windows", mac: "Download for Mac", linux: "Download for Linux" }[os];
  const heroKey = { win: "win-exe", mac: "mac-arm", linux: "linux-appimage" }[os];
  if (hero && heroLabel) hero.querySelector("span").textContent = heroLabel;

  try {
    const rel = await latestRelease();
    if (!rel) return;
    const urlFor = (k) => rel.assets.find((x) => PATTERNS[k].test(x.name))?.browser_download_url;
    links.forEach((a) => { const u = urlFor(a.dataset.asset); if (u) a.href = u; });
    if (hero && heroKey && urlFor(heroKey)) hero.href = urlFor(heroKey);
    const v = rel.tag_name.replace(/^v/, "");
    document.querySelectorAll("[data-version]").forEach((el) => (el.textContent = `v${v}`));
    document.querySelectorAll("[data-release-link]").forEach((el) => (el.href = rel.html_url));
  } catch (e) {
    // offline or rate-limited: links already point at the Releases page
  }
}

function lightbox() {
  const dlg = document.querySelector("dialog.lb");
  if (!dlg) return;
  const img = dlg.querySelector("img");
  document.querySelectorAll("[data-zoom]").forEach((el) =>
    el.addEventListener("click", () => { img.src = el.currentSrc || el.src; img.alt = el.alt; dlg.showModal(); })
  );
  dlg.addEventListener("click", () => dlg.close());
}

document.querySelectorAll("[data-year]").forEach((el) => (el.textContent = new Date().getFullYear()));
wireDownloads();
lightbox();
