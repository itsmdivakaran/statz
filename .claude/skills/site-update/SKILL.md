---
name: site-update
description: Edit the static GitHub Pages website in site/ (landing page, user guide, screenshots). Use for website copy, guide or image changes.
---
# Website
`site/` is plain HTML/CSS/JS (`index.html`, `guide.html`, `assets/app.js`, `assets/style.css`, webp images in `assets/img/`). `.github/workflows/pages.yml` deploys it from `dev` on pushes touching `site/`. Download buttons read the latest GitHub release via API, so do not hard-code versions. Convert screenshots to webp and keep them small. Preview with `python3 -m http.server -d site 8000` and check light/dark and mobile widths. Keep the user guide consistent with `analyses/*/help.md` and README feature table.
