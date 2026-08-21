#!/usr/bin/env python3
"""
validate.py — validate 4D Embedding Studio config files against their JSON Schemas.

Validates:
  * embeddings.json  against references/schemas/embeddings.schema.json
  * AIProviders.json against references/schemas/aiproviders.schema.json

and (when both are present) runs a referential check that every definition's
modelAlias exists in AIProviders.json > models and that each alias points at a
declared provider — things a per-file schema cannot express.

Validation engine: uses the `jsonschema` library if installed (full compliance);
otherwise falls back to a compact built-in validator that covers the keywords these
schemas use (type, enum, const, required, properties, additionalProperties, items,
pattern, min/max, minLength, minItems, $ref, allOf/anyOf/oneOf).

Usage:
  python3 validate.py                          # auto-detect both files from cwd
  python3 validate.py --root DIR
  python3 validate.py --embeddings PATH --providers PATH
  python3 validate.py --schema S.json --instance I.json   # validate any pair

Exit code: 0 if everything valid, 1 if any error, 2 on usage/IO problems.
"""

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA_DIR = os.path.normpath(os.path.join(HERE, "..", "references", "schemas"))
EMB_SCHEMA = os.path.join(SCHEMA_DIR, "embeddings.schema.json")
PROV_SCHEMA = os.path.join(SCHEMA_DIR, "aiproviders.schema.json")

# Reuse path discovery from the analyzer (same folder). Don't litter a __pycache__.
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
try:
    import analyze  # noqa: E402
except Exception:  # pragma: no cover - analyze always ships beside us
    analyze = None


# --------------------------------------------------------------------------- #
# Compact fallback validator (used only when `jsonschema` is not installed)
# --------------------------------------------------------------------------- #
def _json_type(v):
    if isinstance(v, bool):
        return "boolean"
    if v is None:
        return "null"
    if isinstance(v, int):
        return "integer"
    if isinstance(v, float):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, list):
        return "array"
    if isinstance(v, dict):
        return "object"
    return "unknown"


def _type_ok(v, t):
    jt = _json_type(v)
    if t == "number":
        return jt in ("integer", "number")
    if t == "integer":
        return jt == "integer"
    return jt == t


def _resolve_ref(ref, root):
    node = root
    for part in ref.lstrip("#/").split("/"):
        if part == "":
            continue
        part = part.replace("~1", "/").replace("~0", "~")
        node = node[part]
    return node


def _is_valid(instance, schema, root):
    errs = []
    _validate(instance, schema, root, "", errs)
    return not errs


def _validate(instance, schema, root, path, errors):
    if not isinstance(schema, dict):
        return
    if "$ref" in schema:
        _validate(instance, _resolve_ref(schema["$ref"], root), root, path, errors)
        return

    label = path or "(root)"

    if "type" in schema:
        types = schema["type"]
        types = [types] if isinstance(types, str) else types
        if not any(_type_ok(instance, t) for t in types):
            errors.append("%s: expected type %s, got %s" % (label, schema["type"], _json_type(instance)))
            return  # remaining keyword checks would be noise

    if "enum" in schema and instance not in schema["enum"]:
        errors.append("%s: %r is not one of %s" % (label, instance, schema["enum"]))
    if "const" in schema and instance != schema["const"]:
        errors.append("%s: expected const %r" % (label, schema["const"]))

    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            errors.append("%s: string shorter than minLength %d" % (label, schema["minLength"]))
        if "maxLength" in schema and len(instance) > schema["maxLength"]:
            errors.append("%s: string longer than maxLength %d" % (label, schema["maxLength"]))
        if "pattern" in schema and re.search(schema["pattern"], instance) is None:
            errors.append("%s: %r does not match pattern %s" % (label, instance, schema["pattern"]))

    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append("%s: %s < minimum %s" % (label, instance, schema["minimum"]))
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append("%s: %s > maximum %s" % (label, instance, schema["maximum"]))

    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append("%s: fewer than minItems %d" % (label, schema["minItems"]))
        items = schema.get("items")
        if isinstance(items, dict):
            for i, el in enumerate(instance):
                _validate(el, items, root, "%s[%d]" % (path, i), errors)

    if isinstance(instance, dict):
        props = schema.get("properties", {})
        for req in schema.get("required", []):
            if req not in instance:
                errors.append("%s: missing required property '%s'" % (label, req))
        ap = schema.get("additionalProperties", True)
        for k, v in instance.items():
            child = "%s.%s" % (path, k) if path else k
            if k in props:
                _validate(v, props[k], root, child, errors)
            elif ap is False:
                errors.append("%s: additional property '%s' not allowed" % (label, k))
            elif isinstance(ap, dict):
                _validate(v, ap, root, child, errors)

    for sub in schema.get("allOf", []):
        _validate(instance, sub, root, path, errors)
    if "anyOf" in schema and not any(_is_valid(instance, s, root) for s in schema["anyOf"]):
        errors.append("%s: does not match any of anyOf" % label)
    if "oneOf" in schema:
        n = sum(1 for s in schema["oneOf"] if _is_valid(instance, s, root))
        if n != 1:
            errors.append("%s: matched %d schemas in oneOf (expected exactly 1)" % (label, n))


# --------------------------------------------------------------------------- #
# Driver
# --------------------------------------------------------------------------- #
def _load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def validate_pair(schema_path, instance_path):
    """Return list of human-readable error strings ([] means valid)."""
    schema = _load(schema_path)
    instance = _load(instance_path)
    try:
        from jsonschema import Draft202012Validator
        try:
            from importlib.metadata import version as _pkg_version
            ver = _pkg_version("jsonschema")
        except Exception:
            ver = "?"
        v = Draft202012Validator(schema)
        errs = []
        for e in sorted(v.iter_errors(instance), key=lambda e: list(e.path)):
            loc = "/".join(str(p) for p in e.path) or "(root)"
            errs.append("%s: %s" % (loc, e.message))
        return errs, "jsonschema %s" % ver
    except ImportError:
        errs = []
        _validate(instance, schema, schema, "", errs)
        return errs, "built-in (pip install jsonschema for full validation)"


def cross_check(emb_path, prov_path):
    """Referential integrity between the two files. Returns list of error strings."""
    errs = []
    try:
        emb = _load(emb_path)
        prov = _load(prov_path)
    except Exception:
        return errs
    models = (prov.get("models") if isinstance(prov, dict) else None) or {}
    providers = (prov.get("providers") if isinstance(prov, dict) else None) or {}
    for i, d in enumerate(emb.get("definitions", []) if isinstance(emb, dict) else []):
        if not isinstance(d, dict):
            continue
        alias = d.get("modelAlias")
        where = "definitions[%d] (%s.%s)" % (i, d.get("dataclassName"), d.get("vectorName"))
        if not alias:
            continue
        if alias not in models:
            errs.append("%s: modelAlias '%s' not found in AIProviders.json > models" % (where, alias))
            continue
        pname = models[alias].get("provider") if isinstance(models[alias], dict) else None
        if pname and pname not in providers:
            errs.append("%s: alias '%s' points at undeclared provider '%s'" % (where, alias, pname))
    return errs


def _report(title, path, errs, engine):
    print("\n== %s ==" % title)
    print("file:   %s" % path)
    if engine:
        print("engine: %s" % engine)
    if not errs:
        print("result: VALID")
        return True
    print("result: %d error(s)" % len(errs))
    for e in errs:
        print("  - %s" % e)
    return False


def main():
    ap = argparse.ArgumentParser(description="Validate Embedding Studio config against JSON Schemas")
    ap.add_argument("--root", default=os.getcwd(), help="project package folder (default: cwd)")
    ap.add_argument("--embeddings", help="path to embeddings.json (auto-detected otherwise)")
    ap.add_argument("--providers", help="path to AIProviders.json (auto-detected otherwise)")
    ap.add_argument("--schema", help="validate an arbitrary instance against this schema")
    ap.add_argument("--instance", help="the instance file for --schema")
    args = ap.parse_args()

    # Generic single-pair mode
    if args.schema or args.instance:
        if not (args.schema and args.instance):
            print("ERROR: --schema and --instance must be given together", file=sys.stderr)
            sys.exit(2)
        errs, engine = validate_pair(args.schema, args.instance)
        ok = _report("custom", args.instance, errs, engine)
        sys.exit(0 if ok else 1)

    root = os.path.abspath(args.root)
    pkg = root
    if analyze is not None:
        _cat, found_pkg = analyze.find_catalog(root)
        if found_pkg:
            pkg = found_pkg
    emb_path = args.embeddings or (
        analyze.resolve_embeddings_path(pkg, None) if analyze else os.path.join(pkg, "Settings", "embeddings.json")
    )
    prov_path = args.providers or (
        analyze.resolve_providers_path(pkg, os.path.join(pkg, "Project", "Sources"), None)
        if analyze else os.path.join(pkg, "Settings", "AIProviders.json")
    )

    all_ok = True
    checked_any = False

    if os.path.isfile(emb_path):
        checked_any = True
        errs, engine = validate_pair(EMB_SCHEMA, emb_path)
        all_ok &= _report("embeddings.json", emb_path, errs, engine)
    else:
        print("\n== embeddings.json ==")
        print("file:   %s" % emb_path)
        print("result: not found (nothing to validate yet)")

    if os.path.isfile(prov_path):
        checked_any = True
        errs, engine = validate_pair(PROV_SCHEMA, prov_path)
        all_ok &= _report("AIProviders.json", prov_path, errs, engine)
    else:
        print("\n== AIProviders.json ==")
        print("file:   %s" % prov_path)
        print("result: not found (nothing to validate yet)")

    if os.path.isfile(emb_path) and os.path.isfile(prov_path):
        x = cross_check(emb_path, prov_path)
        all_ok &= _report("cross-reference (alias -> provider)", "%s + %s" % (
            os.path.basename(emb_path), os.path.basename(prov_path)), x, None)

    if not checked_any:
        print("\nNo config files found to validate.")
        sys.exit(0)
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
