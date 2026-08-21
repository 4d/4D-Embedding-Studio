#!/usr/bin/env python3
"""
analyze.py — gap analysis for 4D Embedding Studio configuration.

Reads, WITHOUT running 4D:
  * the 4D catalog          (Project/Sources/catalog.4DCatalog)  -> tables, vector fields, scalar fields, relations
  * entity classes          (Project/Sources/Classes/<Table>Entity.4dm) -> alias & computed attributes
  * the embeddings settings (Settings/embeddings.json)           -> existing vector definitions + scheduler
  * the AIKit providers     (Settings/AIProviders.json)          -> providers + model aliases

Emits a report the LLM uses to propose vector definitions, pick/build an embedding
model alias, and decide whether scheduling can be enabled.

Usage:
  python3 analyze.py [--root DIR] [--embeddings PATH] [--providers PATH] [--json]

Exit code is always 0 unless the catalog cannot be found (2). Missing settings /
providers files are reported as "not configured", not treated as errors.
"""

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET


# --- 4D catalog storage type codes (numeric `type` attribute on <field>) -----
# Only blob / image / object are *excluded* from phrases by the runtime
# (cs._dataclassAttributes.isExcludedStorageType); everything else is usable.
TYPE_LABELS = {
    "1": "boolean",
    "3": "integer",
    "4": "integer",
    "5": "integer",
    "6": "real",
    "8": "date",
    "9": "time",
    "10": "text",
    "12": "image",   # picture   -> excluded from phrases
    "18": "blob",    # blob      -> excluded from phrases
    # 21 is resolved dynamically: vector (has 4D.Vector class) or object.
}
EXCLUDED_LABELS = {"image", "blob", "object"}

# Field names that make good phrase material get ranked first.
PREFERRED_TOKENS = (
    "name", "title", "label", "subject", "description", "desc", "summary",
    "first", "last", "full", "program", "course", "city", "state", "country",
    "university", "school", "email", "company", "product", "category", "status",
    "comment", "note", "address",
)


def local(tag):
    return tag.split("}")[-1]


# --------------------------------------------------------------------------- #
# Path discovery
# --------------------------------------------------------------------------- #
def find_catalog(root):
    """Return (catalog_path, project_package_dir) or (None, None)."""
    direct = os.path.join(root, "Project", "Sources", "catalog.4DCatalog")
    if os.path.isfile(direct):
        return direct, root
    # Walk down a couple of levels in case root is nested.
    for dirpath, _dirs, files in os.walk(root):
        if dirpath.count(os.sep) - root.count(os.sep) > 4:
            continue
        if "catalog.4DCatalog" in files and os.path.basename(dirpath) == "Sources":
            pkg = os.path.dirname(os.path.dirname(dirpath))  # .../<pkg>/Project/Sources -> <pkg>
            return os.path.join(dirpath, "catalog.4DCatalog"), pkg
    return None, None


def find_data_folder(pkg):
    """The folder holding the .4DD data file (fk data folder). Best effort."""
    for name in os.listdir(pkg):
        if name.endswith(".4DD"):
            return pkg  # data file lives at package root here
    data = os.path.join(pkg, "Data")
    return data if os.path.isdir(data) else pkg


def resolve_embeddings_path(pkg, override):
    if override:
        return override
    env = os.environ.get("EMBEDDINGS_SETTINGS_PATH")
    if env:
        return env
    return os.path.join(pkg, "Settings", "embeddings.json")


def resolve_providers_path(pkg, sources_dir, override):
    if override:
        return override
    candidates = [
        os.path.join(find_data_folder(pkg), "Settings", "AIProviders.json"),
        os.path.join(pkg, "Settings", "AIProviders.json"),
        os.path.join(sources_dir, "AIProviders.json"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return candidates[-1]  # report the last (structure) candidate even if absent


# --------------------------------------------------------------------------- #
# Catalog parsing
# --------------------------------------------------------------------------- #
def parse_catalog(catalog_path):
    root = ET.parse(catalog_path).getroot()

    tables = []
    fk_source_uuids = {}   # field uuid -> relation Nto1 name (this field is a FK source)
    relations = []

    # First pass: relations, to know which storage fields are FK sources.
    for rel in (e for e in root.iter() if local(e.tag) == "relation"):
        nto1 = rel.get("name_Nto1") or ""
        src_table = src_field = dst_table = None
        for rf in (e for e in rel.iter() if local(e.tag) == "related_field"):
            kind = rf.get("kind")
            fref = next((e for e in rf if local(e.tag) == "field_ref"), None)
            if fref is None:
                continue
            tref = next((e for e in fref if local(e.tag) == "table_ref"), None)
            if kind == "source":
                src_table = tref.get("name") if tref is not None else None
                src_field = fref.get("name")
                fk_source_uuids[fref.get("uuid")] = nto1
            elif kind == "destination":
                dst_table = tref.get("name") if tref is not None else None
        relations.append({
            "name": nto1,
            "sourceTable": src_table,
            "sourceField": src_field,
            "relatedTable": dst_table,
        })

    for tb in (e for e in root.iter() if local(e.tag) == "table"):
        tname = tb.get("name")
        fields = [f for f in tb if local(f.tag) == "field"]

        field_names = {f.get("name") for f in fields}
        vector_field_names = [
            f.get("name") for f in fields
            if any(local(x.tag) == "field_extra" and x.get("class_id") == "4D.Vector" for x in f)
        ]
        # dirty companion flags: <vector>_dirty booleans present in the table
        dirty_flags = {
            v: (v + "_dirty") for v in vector_field_names if (v + "_dirty") in field_names
        }
        dirty_names = set(dirty_flags.values())

        vector_fields, scalar_fields, excluded_fields = [], [], []
        for f in fields:
            fname = f.get("name")
            ftype = f.get("type") or ""
            if fname in vector_field_names:
                vector_fields.append(fname)
                continue
            if ftype == "21":
                label = "object"       # type 21 without vector class = Object field
            else:
                label = TYPE_LABELS.get(ftype, "field")
            entry = {"name": fname, "type": label}
            if label in EXCLUDED_LABELS:
                excluded_fields.append(entry)
                continue
            entry["isFK"] = f.get("uuid") in fk_source_uuids
            entry["isPrimaryKeyAuto"] = f.get("autosequence") == "true"
            entry["isDirtyFlag"] = fname in dirty_names
            scalar_fields.append(entry)

        # relations reachable FROM this table (N:1) -> usable as {relationName.field}
        table_relations = [
            {"name": r["name"], "relatedTable": r["relatedTable"]}
            for r in relations
            if r["sourceTable"] == tname and r["name"]
        ]

        tables.append({
            "dataclassName": tname,
            "vectorFields": vector_fields,
            "scalarFields": scalar_fields,
            "excludedFields": excluded_fields,
            "relations": table_relations,
            "dirtyFlags": dirty_flags,
        })

    return tables


def parse_entity_extras(sources_dir, tables):
    """Scan <Table>Entity.4dm for alias & computed (get) attributes; attach to tables."""
    classes_dir = os.path.join(sources_dir, "Classes")
    if not os.path.isdir(classes_dir):
        return
    by_name = {t["dataclassName"]: t for t in tables}
    alias_re = re.compile(r"^\s*Alias\s+([A-Za-z_][\w]*)\s+(.+?)\s*$")
    getter_re = re.compile(r"Function\s+get\s+([A-Za-z_][\w]*)\s*\(")
    for t in tables:
        path = os.path.join(classes_dir, t["dataclassName"] + "Entity.4dm")
        aliases, computed = [], []
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = alias_re.match(line)
                    if m:
                        aliases.append({"name": m.group(1), "path": m.group(2)})
                        continue
                    g = getter_re.search(line)
                    if g:
                        computed.append(g.group(1))
        t["aliasAttributes"] = aliases
        t["computedAttributes"] = computed
    _ = by_name  # (kept for clarity; not otherwise needed)


# --------------------------------------------------------------------------- #
# Settings / providers parsing
# --------------------------------------------------------------------------- #
def load_json(path):
    if not path or not os.path.isfile(path):
        return None, "missing"
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return json.load(fh), "ok"
    except Exception as exc:  # malformed JSON
        return None, "invalid: %s" % exc


def analyze_providers(data):
    """Return dict describing providers, aliases, and embedding candidates."""
    providers, aliases = {}, {}
    if isinstance(data, dict):
        providers = data.get("providers") or {}
        aliases = data.get("models") or {}

    provider_list = []
    for name, cfg in providers.items():
        cfg = cfg if isinstance(cfg, dict) else {}
        provider_list.append({
            "name": name,
            "baseURL": cfg.get("baseURL", ""),
            "hasApiKey": bool(cfg.get("apiKey")),
        })

    alias_list = []
    for name, cfg in aliases.items():
        cfg = cfg if isinstance(cfg, dict) else {}
        model = str(cfg.get("model", ""))
        alias_list.append({
            "name": name,
            "provider": str(cfg.get("provider", "")),
            "model": model,
            "looksLikeEmbedding": "embed" in name.lower() or "embed" in model.lower(),
        })

    embedding_aliases = [a for a in alias_list if a["looksLikeEmbedding"]]
    return {
        "providers": sorted(provider_list, key=lambda p: p["name"]),
        "aliases": sorted(alias_list, key=lambda a: a["name"]),
        "embeddingAliases": embedding_aliases,
    }


def suggest_phrase(table):
    """Naive fallback phrase: top scalar fields, preferred names first."""
    def rank(f):
        low = f["name"].lower()
        if f.get("isPrimaryKeyAuto") or f.get("isFK") or low.endswith("_id") or low == "id":
            return (3, low)
        if any(tok in low for tok in PREFERRED_TOKENS):
            return (0, low)
        if f["type"] in ("text", "boolean"):
            return (1, low)
        return (2, low)

    usable = [f for f in table["scalarFields"]
              if not (f.get("isPrimaryKeyAuto") or f.get("isFK") or f.get("isDirtyFlag")
                      or f["name"].lower() == "id" or f["name"].lower().endswith("_id"))]
    usable.sort(key=rank)
    chosen = [f["name"] for f in usable[:5]]
    if not chosen:
        return ""
    return " ".join("{%s}" % n for n in chosen)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def build_report(root, embeddings_override, providers_override):
    catalog_path, pkg = find_catalog(root)
    if not catalog_path:
        return None, "catalog not found under %s" % root

    sources_dir = os.path.dirname(catalog_path)
    tables = parse_catalog(catalog_path)
    parse_entity_extras(sources_dir, tables)

    emb_path = resolve_embeddings_path(pkg, embeddings_override)
    emb_data, emb_status = load_json(emb_path)
    definitions = (emb_data.get("definitions") if isinstance(emb_data, dict) else None) or []
    scheduler = (emb_data.get("scheduler") if isinstance(emb_data, dict) else None) or {}
    phrase_opts = (emb_data.get("phrase") if isinstance(emb_data, dict) else None) or {}

    defined = {(str(d.get("dataclassName")), str(d.get("vectorName"))) for d in definitions}

    prov_path = resolve_providers_path(pkg, sources_dir, providers_override)
    prov_data, prov_status = load_json(prov_path)
    prov = analyze_providers(prov_data)

    # gap analysis
    for t in tables:
        t["unconfiguredVectors"] = [
            {"vectorName": v, "suggestedPhrase": suggest_phrase(t)}
            for v in t["vectorFields"]
            if (t["dataclassName"], v) not in defined
        ]

    report = {
        "paths": {
            "package": pkg,
            "catalog": catalog_path,
            "embeddings": {"path": emb_path, "status": emb_status},
            "providers": {"path": prov_path, "status": prov_status},
        },
        "tables": tables,
        "existingDefinitions": definitions,
        "phraseOptions": phrase_opts,
        "scheduler": scheduler,
        "providersConfig": prov,
        "summary": {
            "tablesWithVectors": sum(1 for t in tables if t["vectorFields"]),
            "totalVectorFields": sum(len(t["vectorFields"]) for t in tables),
            "definedVectors": len(defined),
            "unconfiguredVectors": sum(len(t["unconfiguredVectors"]) for t in tables),
            "providerCount": len(prov["providers"]),
            "embeddingAliasCount": len(prov["embeddingAliases"]),
            "hasProviders": len(prov["providers"]) > 0,
            "hasEmbeddingAlias": len(prov["embeddingAliases"]) > 0,
        },
    }
    return report, None


def print_text(r):
    p = r["paths"]
    s = r["summary"]
    out = []
    out.append("# 4D Embedding Studio — configuration analysis\n")
    out.append("## Paths")
    out.append("- package:    %s" % p["package"])
    out.append("- catalog:    %s" % p["catalog"])
    out.append("- embeddings: %s  [%s]" % (p["embeddings"]["path"], p["embeddings"]["status"]))
    out.append("- providers:  %s  [%s]" % (p["providers"]["path"], p["providers"]["status"]))

    out.append("\n## Providers & model aliases")
    if not r["providersConfig"]["providers"]:
        out.append("- (none) — NO PROVIDERS CONFIGURED. Configure AIProviders.json first (see references/schema.md).")
    for pv in r["providersConfig"]["providers"]:
        key = "apiKey set" if pv["hasApiKey"] else "no apiKey (env fallback or local)"
        out.append("- provider `%s`  baseURL=%s  (%s)" % (pv["name"], pv["baseURL"] or "-", key))
    for a in r["providersConfig"]["aliases"]:
        mark = "  <-- embedding candidate" if a["looksLikeEmbedding"] else ""
        out.append("  alias `%s` -> %s:%s%s" % (a["name"], a["provider"], a["model"], mark))
    if not r["providersConfig"]["embeddingAliases"]:
        out.append("  (no alias whose name/model contains 'embed' — one must be created)")

    out.append("\n## Tables with vector fields")
    for t in r["tables"]:
        if not t["vectorFields"]:
            continue
        out.append("\n### %s" % t["dataclassName"])
        out.append("- vector fields: %s" % ", ".join(t["vectorFields"]))
        if t["dirtyFlags"]:
            out.append("- dirty flags:   %s" % ", ".join("%s->%s" % kv for kv in t["dirtyFlags"].items()))
        scal = ", ".join("%s:%s" % (f["name"], f["type"]) for f in t["scalarFields"]
                         if not (f.get("isPrimaryKeyAuto") or f.get("isFK") or f.get("isDirtyFlag")))
        out.append("- phrase fields: %s" % (scal or "-"))
        if t["relations"]:
            out.append("- relations (N:1, need allowRelations): %s"
                       % ", ".join("%s->%s" % (rl["name"], rl["relatedTable"]) for rl in t["relations"]))
        if t.get("computedAttributes"):
            out.append("- computed (need allowCalculated): %s" % ", ".join(t["computedAttributes"]))
        if t.get("aliasAttributes"):
            out.append("- aliases (need allowAlias): %s"
                       % ", ".join("%s=%s" % (a["name"], a["path"]) for a in t["aliasAttributes"]))
        if t["unconfiguredVectors"]:
            for u in t["unconfiguredVectors"]:
                out.append("  * UNCONFIGURED `%s`  suggestedPhrase: \"%s\""
                           % (u["vectorName"], u["suggestedPhrase"]))
        else:
            out.append("  (all vector fields already have a definition)")

    out.append("\n## Existing definitions")
    if not r["existingDefinitions"]:
        out.append("- (none)")
    for d in r["existingDefinitions"]:
        out.append("- %s.%s  alias=%s  phrase=\"%s\""
                   % (d.get("dataclassName"), d.get("vectorName"),
                      d.get("modelAlias"), d.get("phrase")))
    if r["phraseOptions"]:
        out.append("- phrase options: %s" % json.dumps(r["phraseOptions"]))

    out.append("\n## Scheduler")
    out.append("- current: %s" % (json.dumps(r["scheduler"]) if r["scheduler"] else "(disabled / not set)"))

    out.append("\n## Summary")
    out.append("- vector fields: %d total, %d defined, %d UNCONFIGURED"
               % (s["totalVectorFields"], s["definedVectors"], s["unconfiguredVectors"]))
    out.append("- providers configured: %s  |  embedding alias present: %s"
               % (s["hasProviders"], s["hasEmbeddingAlias"]))

    # Next-step signal for the LLM
    out.append("\n## Gate")
    if not s["hasProviders"]:
        out.append("BLOCKED: configure at least one provider in AIProviders.json before anything else.")
    elif not s["hasEmbeddingAlias"]:
        out.append("ACTION: create an embedding model alias (name/model containing 'embed') in AIProviders.json.")
    elif s["unconfiguredVectors"] > 0:
        out.append("ACTION: propose definitions for the UNCONFIGURED vector fields, then write embeddings.json.")
    else:
        out.append("READY: all vector fields defined — you may propose enabling daily scheduling.")

    print("\n".join(out))


def main():
    ap = argparse.ArgumentParser(description="4D Embedding Studio config analysis")
    ap.add_argument("--root", default=os.getcwd(), help="project package folder (default: cwd)")
    ap.add_argument("--embeddings", help="override path to embeddings.json")
    ap.add_argument("--providers", help="override path to AIProviders.json")
    ap.add_argument("--json", action="store_true", help="emit raw JSON instead of text report")
    args = ap.parse_args()

    report, err = build_report(os.path.abspath(args.root), args.embeddings, args.providers)
    if err:
        print("ERROR: %s" % err, file=sys.stderr)
        sys.exit(2)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_text(report)


if __name__ == "__main__":
    main()
