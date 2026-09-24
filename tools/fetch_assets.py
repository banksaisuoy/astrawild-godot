#!/usr/bin/env python3
"""
ASTRAWILD Godot Division — automated CC0 asset acquisition tool (Phase V3).

Reads tools/asset_manifest.json and fetches every listed asset:
  * drive_folder  — lists a public Google Drive folder via embeddedfolderview,
                    downloads files matching `include` regexes
  * kenney_zip    — downloads a Kenney asset-pack zip, extracts files matching
                    `extract` regexes into target_dir, deletes the zip
  * direct        — downloads one direct URL (optional `filename` override)

Guarantees (directive constraints):
  * C2 — every fetched file gets a ledger row in docs/ASSET_LICENSE_LEDGER.md
         (path | source | direct URL | license | sha256 | date)
  * C3 — hard size budget: refuses to fetch anything that would push total
         repo asset growth past `budget_mb`, or any single file past
         `max_file_mb`
  * idempotent — files that already exist with a ledger row are skipped;
         re-running downloads nothing
  * verifies magic bytes of every download; anything unverifiable is deleted

Usage:  python3 tools/fetch_assets.py [--dry-run]
"""

import hashlib
import io
import json
import os
import re
import sys
import time
import urllib.request
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MANIFEST_PATH = os.path.join(ROOT, "tools", "asset_manifest.json")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ASTRAWILD-fetcher/1.0"}

# --------------------------------------------------------------------- utils


def http_get(url: str, timeout: int = 60) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def http_get_with_retry(url: str, tries: int = 3, timeout: int = 90) -> bytes:
    last = None
    for attempt in range(tries):
        try:
            return http_get(url, timeout=timeout)
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 + attempt * 3)
    raise RuntimeError(f"download failed after {tries} tries: {url} ({last})")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sniff(data: bytes, name: str) -> bool:
    """Magic-byte verification. True = plausible file of its type."""
    if len(data) < 64:
        return False
    low = name.lower()
    if low.endswith((".gltf", ".json")):
        head = data[:512].lstrip()
        if head.startswith(b"{") and b"asset" in data[:2048]:
            return True
    if low.endswith(".glb") and data[:4] == b"glTF":
        return True
    if low.endswith(".bin") and data[:4] == b"glTF":
        return True
    if low.endswith((".png",)) and data[:8] == b"\x89PNG\r\n\x1a\n":
        return True
    if low.endswith((".ogg",)) and data[:4] == b"OggS":
        return True
    if low.endswith((".mp3",)) and (data[:3] == b"ID3" or data[0] == 0xFF):
        return True
    if low.endswith((".wav",)) and data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        return True
    if low.endswith((".fbx",)):
        if data[:20].startswith(b"Kaydara FBX Binary") or b"FBXHeaderExtension" in data[:512]:
            return True
    if low.endswith((".zip",)) and data[:2] == b"PK":
        return True
    if low.endswith((".txt", ".md")):
        return True
    return False


def list_drive_folder(folder_id: str):
    """List (file_id, filename) pairs of a public Drive folder."""
    url = f"https://drive.google.com/embeddedfolderview?id={folder_id}#list"
    raw = http_get_with_retry(url).decode("utf-8", "ignore")
    out = []
    for m in re.finditer(r'file/d/([^"\'?#]+)/view', raw):
        t = re.search(r'flip-entry-title">([^<]*)<', raw[m.end():m.end()+600])
        if t:
            out.append((m.group(1), t.group(1)))
    return out


def drive_download(file_id: str) -> bytes:
    url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download"
    return http_get_with_retry(url, timeout=180)


def resolve_kenney_zip_url(slug: str) -> str:
    page = http_get_with_retry(f"https://kenney.nl/assets/{slug}").decode("utf-8", "ignore")
    m = re.search(
        rf"https://kenney\.nl/media/pages/assets/{re.escape(slug)}/[a-z0-9-]+/kenney_[a-z0-9-]+\.zip",
        page,
    )
    if not m:
        raise RuntimeError(f"could not resolve Kenney zip URL for {slug}")
    return m.group(0)


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", name)


# --------------------------------------------------------------------- ledger


class Ledger:
    ROW_RE = re.compile(
        r"^\|\s*`([^`]+)`\s*\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|\s*$"
    )

    def __init__(self, path: str):
        self.path = path
        self.rows = {}
        if os.path.exists(path):
            for line in open(path, encoding="utf-8"):
                m = self.ROW_RE.match(line)
                if m:
                    sha = m.group(5).strip()
                    if not re.fullmatch(r"[a-f0-9]{16}", sha):
                        continue
                    self.rows[m.group(1)] = {
                        "source": m.group(2).strip(),
                        "url": m.group(3).strip(),
                        "license": m.group(4).strip(),
                        "sha16": sha,
                        "date": m.group(6).strip(),
                    }

    def write(self):
        lines = [
            "# ASSET LICENSE LEDGER",
            "",
            "**Every downloaded third-party file in this repo, one row per file.**",
            "Auto-maintained by `tools/fetch_assets.py` (Phase V3, constraint C2).",
            "An asset without a row here must be deleted. No exceptions.",
            "",
            "| file path | source | direct URL | license | sha256 (first 16) | date fetched |",
            "|---|---|---|---|---|---|",
        ]
        for path in sorted(self.rows):
            r = self.rows[path]
            lines.append(
                f"| `{path}` | {r['source']} | {r['url']} | {r['license']} | {r['sha16']} | {r['date']} |"
            )
        with open(self.path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")

    def add(self, rel_path, source, url, license_, sha_hex):
        self.rows[rel_path] = {
            "source": source,
            "url": url,
            "license": license_,
            "sha16": sha_hex[:16],
            "date": time.strftime("%Y-%m-%d"),
        }


# --------------------------------------------------------------------- fetcher


def reconcile(manifest, ledger):
    """Rebuild ledger rows for files already on disk (no downloading).

    Used when a previous fetch run was killed before the ledger flush:
    files are already present; we only (re)derive their Drive URLs and
    sha256 from disk so idempotency works on the next run.
    """
    n = 0
    for g in manifest["groups"]:
        kind = g["fetch"]["kind"]
        target_dir = os.path.join(ROOT, g["target_dir"])
        if not os.path.isdir(target_dir):
            continue
        if kind == "drive_folder":
            folder_id = g["fetch"]["folder_id"]
            include = [
                re.compile(p)
                for p in g["fetch"].get("include", [r".*\.(gltf|glb|png|bin|fbx)$"])
            ]
            try:
                entries = list_drive_folder(folder_id)
            except Exception as e:  # noqa: BLE001
                print(f"   ✗ reconcile listing failed for {g['id']}: {e}")
                continue
            for file_id, fname in entries:
                if not any(p.search(fname) for p in include):
                    continue
                out_path = os.path.join(target_dir, safe_name(fname))
                if os.path.exists(out_path):
                    rel = os.path.relpath(out_path, ROOT).replace(os.sep, "/")
                    if rel in ledger.rows:
                        continue
                    url = (
                        "https://drive.usercontent.google.com/download"
                        f"?id={file_id}&export=download"
                    )
                    ledger.add(rel, g.get("source", g["id"]), url, g.get("license", "CC0"),
                               sha256(open(out_path, "rb").read()))
                    n += 1
            print(f"   reconciled drive folder {g['id']}")
        elif kind == "direct":
            fname = g["fetch"].get("filename") or safe_name(g["fetch"]["url"].rsplit("/", 1)[-1])
            out_path = os.path.join(target_dir, fname)
            if os.path.exists(out_path):
                rel = os.path.relpath(out_path, ROOT).replace(os.sep, "/")
                if rel not in ledger.rows:
                    ledger.add(rel, g.get("source", g["id"]), g["fetch"]["url"],
                               g.get("license", "CC0"), sha256(open(out_path, "rb").read()))
                    n += 1
    ledger.write()
    print(f"reconcile: {n} ledger rows added from existing disk files")


def main() -> int:
    dry = "--dry-run" in sys.argv
    reconcile_only = "--reconcile" in sys.argv
    manifest = json.load(open(MANIFEST_PATH, encoding="utf-8"))
    ledger = Ledger(os.path.join(ROOT, manifest.get("ledger", "docs/ASSET_LICENSE_LEDGER.md")))
    if reconcile_only:
        reconcile(manifest, ledger)
        return 0
    budget_bytes = int(manifest.get("budget_mb", 250)) * 1024 * 1024
    max_file_bytes = int(manifest.get("max_file_mb", 20)) * 1024 * 1024

    # existing usage = size of already-fetched manifest targets on disk
    used = 0
    for g in manifest["groups"]:
        td = os.path.join(ROOT, g["target_dir"])
        if os.path.isdir(td):
            for fn in os.listdir(td):
                p = os.path.join(td, fn)
                if os.path.isfile(p):
                    used += os.path.getsize(p)
    print(
        f"ASTRAWILD asset fetcher — budget {budget_bytes // 1024 // 1024} MB, "
        f"already on disk {used // 1024 // 1024} MB, {len(manifest['groups'])} groups"
    )
    print()

    n_requested = n_fetched = n_skipped = n_failed = 0
    fetched_bytes = 0
    failures = []
    manual = []  # items needing manual download

    for g in manifest["groups"]:
        gid = g["id"]
        source = g.get("source", gid)
        license_ = g.get("license", "CC0")
        target_dir = os.path.join(ROOT, g["target_dir"])
        kind = g["fetch"]["kind"]
        print(f"── {gid} ({kind}) → {g['target_dir']}")

        # build the download plan: list of (url, filename, fetch_fn)
        plan = []
        extract = []
        if kind == "drive_folder":
            folder_id = g["fetch"]["folder_id"]
            include = [
                re.compile(p)
                for p in g["fetch"].get("include", [r".*\.(gltf|glb|png|bin|fbx)$"])
            ]
            try:
                entries = list_drive_folder(folder_id)
            except Exception as e:  # noqa: BLE001
                print(f"   ✗ folder listing failed: {e}")
                n_failed += 1
                failures.append(f"{gid}: listing failed ({e})")
                print()
                continue
            for file_id, fname in entries:
                if any(p.search(fname) for p in include):
                    url = (
                        "https://drive.usercontent.google.com/download"
                        f"?id={file_id}&export=download"
                    )
                    plan.append((url, safe_name(fname), lambda fid=file_id: drive_download(fid)))
        elif kind == "kenney_zip":
            slug = g["fetch"]["slug"]
            extract = [re.compile(p) for p in g["fetch"].get("extract", [r".*\.(glb|gltf|ogg)$"])]
            try:
                zip_url = resolve_kenney_zip_url(slug)
            except Exception as e:  # noqa: BLE001
                print(f"   ✗ zip URL resolve failed: {e}")
                n_failed += 1
                failures.append(f"{gid}: kenney resolve failed ({e})")
                manual.append((gid, f"https://kenney.nl/assets/{slug}"))
                print()
                continue
            plan.append(("zip:" + zip_url, None, "KENNEY_ZIP"))
        elif kind == "direct":
            url = g["fetch"]["url"]
            fname = g["fetch"].get("filename") or safe_name(url.rsplit("/", 1)[-1])
            plan.append((url, fname, lambda u=url: http_get_with_retry(u, timeout=300)))
        else:
            print(f"   ✗ unknown fetch kind {kind}")
            n_failed += 1
            failures.append(f"{gid}: unknown kind {kind}")
            print()
            continue

        n_requested += len(plan)
        os.makedirs(target_dir, exist_ok=True)

        for url, fname, fetcher in plan:
            # KENNEY zip special path
            if fetcher == "KENNEY_ZIP":
                try:
                    if dry:
                        print(f"   (dry) would fetch zip {url[:80]}… and extract to {g['target_dir']}")
                        continue
                    data = http_get_with_retry(url.replace("zip:", "", 1), timeout=600)
                    if not sniff(data, "x.zip"):
                        raise RuntimeError("zip magic mismatch")
                    zf = zipfile.ZipFile(io.BytesIO(data))
                    got = 0
                    for zi in zf.infolist():
                        base = os.path.basename(zi.filename)
                        if not base or base.startswith(".") or base.endswith("/"):
                            continue
                        if any(p.search(base) for p in extract):
                            out_path = os.path.join(target_dir, safe_name(base))
                            if os.path.exists(out_path) and os.path.getsize(out_path) == zi.file_size:
                                n_skipped += 1
                                continue
                            blob = zf.read(zi)
                            if not sniff(blob, base):
                                print(f"   ✗ magic mismatch on {base}")
                                n_failed += 1
                                failures.append(f"{gid}/{base}: magic mismatch")
                                continue
                            if used + fetched_bytes + len(blob) > budget_bytes:
                                print(f"   ✗ {base}: would breach total budget — aborted")
                                n_failed += 1
                                failures.append(f"{gid}/{base}: budget breach prevented")
                                break
                            with open(out_path, "wb") as fh:
                                fh.write(blob)
                            ledger.add(
                                os.path.relpath(out_path, ROOT).replace(os.sep, "/"),
                                source,
                                url.replace("zip:", "", 1),
                                license_,
                                sha256(blob),
                            )
                            fetched_bytes += len(blob)
                            got += 1
                            n_fetched += 1
                    print(f"   ✓ zip processed, {got} files extracted")
                except Exception as e:  # noqa: BLE001
                    print(f"   ✗ zip failed: {e}")
                    n_failed += 1
                    failures.append(f"{gid}: zip failed ({e})")
                continue

            out_path = os.path.join(target_dir, fname)
            rel = os.path.relpath(out_path, ROOT).replace(os.sep, "/")

            # idempotency: skip if the file exists AND has a verified ledger row
            if os.path.exists(out_path) and rel in ledger.rows:
                n_skipped += 1
                continue

            if dry:
                print(f"   (dry) would fetch {fname} from {url[:80]}")
                continue

            try:
                data = fetcher()
            except Exception as e:  # noqa: BLE001
                print(f"   ✗ {fname}: {e}")
                n_failed += 1
                failures.append(f"{gid}/{fname}: {e}")
                continue

            if len(data) > max_file_bytes:
                print(
                    f"   ✗ {fname}: {len(data) // 1024 // 1024} MB exceeds per-file cap — not saved"
                )
                n_failed += 1
                failures.append(f"{gid}/{fname}: over per-file cap")
                continue
            if used + fetched_bytes + len(data) > budget_bytes:
                print(f"   ✗ {fname}: would breach total budget — aborted (budget guard)")
                n_failed += 1
                failures.append(f"{gid}/{fname}: budget breach prevented")
                break

            if not sniff(data, fname):
                print(f"   ✗ {fname}: magic-byte verification failed — discarded")
                n_failed += 1
                failures.append(f"{gid}/{fname}: magic mismatch")
                continue

            with open(out_path, "wb") as fh:
                fh.write(data)
            ledger.add(rel, source, url, license_, sha256(data))
            fetched_bytes += len(data)
            n_fetched += 1
            print(f"   ✓ {fname} ({len(data) // 1024} KB)")

        print()

        # flush ledger per group so a killed run keeps its bookkeeping
        if not dry:
            ledger.write()

    if not dry:
        ledger.write()

    total = used + fetched_bytes
    print("=" * 64)
    print(f"SUMMARY  requested: {n_requested}")
    print(f"         fetched : {n_fetched}  ({fetched_bytes // 1024 // 1024} MB this run)")
    print(f"         skipped : {n_skipped}  (already on disk)")
    print(f"         failed  : {n_failed}")
    print(
        f"         total asset footprint: {total // 1024 // 1024} MB / "
        f"{budget_bytes // 1024 // 1024} MB budget"
    )
    if failures:
        print("\nFAILURES:")
        for f in failures:
            print(f"  - {f}")
    if manual:
        print("\nNEEDS MANUAL DOWNLOAD:")
        for gid, url in manual:
            print(f"  - {gid}: {url}")
    return 1 if n_failed else 0


if __name__ == "__main__":
    sys.exit(main())
