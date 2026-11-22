// FloppaOS downloads: https://floppaos.pages.dev/download/<file>
//
// Serves released images from the Cloudflare R2 bucket floppaos-iso (Pages binding RELEASES), and only from its
// folder release/, where iso.yml puts release builds. Test builds in iso/ stay private. Only file names of the
// form floppaos-<version>-x86_64.iso and their .sha256 are served; everything else is a 404. Supports HEAD and
// byte ranges, so download managers and browsers can resume a download.
//
// SPDX-License-Identifier: GPL-3.0-or-later

const NAME = /^floppaos-[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?-x86_64\.iso(\.sha256)?$/;

// _headers does not apply to Functions, so the security headers are set here.
const SECURITY = {
  "X-Content-Type-Options": "nosniff",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
  "Cross-Origin-Resource-Policy": "same-origin",
};

function plain(status, text, extra = {}) {
  return new Response(text + "\n", {
    status,
    headers: { ...SECURITY, "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store", ...extra },
  });
}

function fileHeaders(name, object) {
  const h = new Headers(SECURITY);
  object.writeHttpMetadata(h);
  const iso = name.endsWith(".iso");
  h.set("Content-Type", iso ? "application/x-iso9660-image" : "text/plain; charset=utf-8");
  h.set("Content-Disposition", `attachment; filename="${name}"`);
  h.set("Accept-Ranges", "bytes");
  h.set("ETag", object.httpEtag);
  h.set("Last-Modified", object.uploaded.toUTCString());
  h.set("Cache-Control", "public, max-age=3600, no-transform");
  return h;
}

export async function onRequest({ request, env, params }) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return plain(405, "Method not allowed", { Allow: "GET, HEAD" });
  }
  const parts = Array.isArray(params.path) ? params.path : [params.path].filter(Boolean);
  if (parts.length !== 1 || !NAME.test(parts[0])) {
    return plain(404, "Not found. The download is on https://floppaos.pages.dev/#download");
  }
  const name = parts[0];
  const key = `release/${name}`;

  if (request.method === "HEAD") {
    const head = await env.RELEASES.head(key);
    if (!head) return plain(404, "Not found");
    const h = fileHeaders(name, head);
    h.set("Content-Length", String(head.size));
    return new Response(null, { status: 200, headers: h });
  }

  let object;
  try {
    object = await env.RELEASES.get(key, { range: request.headers, onlyIf: request.headers });
  } catch (e) {
    // A range outside the file
    const head = await env.RELEASES.head(key);
    return plain(416, "Range not satisfiable", head ? { "Content-Range": `bytes */${head.size}` } : {});
  }
  if (!object) return plain(404, "Not found");

  const h = fileHeaders(name, object);
  if (!("body" in object) || !object.body) {
    // A precondition (If-None-Match, If-Modified-Since, If-Match ...) decided: nothing to send
    const status = request.headers.has("if-match") || request.headers.has("if-unmodified-since") ? 412 : 304;
    return new Response(null, { status, headers: h });
  }
  if (request.headers.has("range") && object.range) {
    const r = object.range;
    let start, end;
    if ("suffix" in r && r.suffix !== undefined) {
      start = Math.max(object.size - r.suffix, 0);
      end = object.size - 1;
    } else {
      start = r.offset ?? 0;
      end = r.length !== undefined ? start + r.length - 1 : object.size - 1;
    }
    h.set("Content-Range", `bytes ${start}-${end}/${object.size}`);
    return new Response(object.body, { status: 206, headers: h });
  }
  // The R2 body knows its length, so the runtime sends Content-Length itself.
  return new Response(object.body, { status: 200, headers: h });
}
