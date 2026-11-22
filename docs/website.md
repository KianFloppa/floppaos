# floppaos.pages.dev

The FloppaOS website: one page, no scripts, nothing loaded from other addresses, no tracking. It looks like the
FloppaOS desktop: pure black, the caracal's orange, and the menu is a taskbar at the bottom with the version where
the clock would be.

**Online since 2026-11-22.** Cloudflare Pages project `floppaos`, connected to this repository: every push to
`main` that changes something in `site/` puts this folder online as it is (no build step). Other pushes do not
deploy.

- `_headers`: security headers, stricter than usual (`script-src 'none'`, `style-src 'self'`, `connect-src 'none'`).
- `robots.txt`, `sitemap.xml`, `llms.txt`, `404.html`, `.well-known/security.txt` (contact: the shared security page
  floppaland.com/security/), the IndexNow key file (`<32 hex>.txt`).
- `assets/`: styles, the font Bricolage Grotesque (SIL Open Font License, licence file next to it), the logo,
  the link preview picture and a screenshot. The logo and artwork are not under the GPL (`TRADEMARKS.md`).

Changing the page: keep it free of scripts and of files from other addresses, update `lastmod` in `sitemap.xml`,
bump `?v=` on `site.css` and the font when they change, and check it with `tools/seo_check.py` and
`tools/csp_check.py` from KianFloppa's site repository. When the ISO download is public, the "Download" section
gets the link and the SHA-256 checksum.
