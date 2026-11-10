#!/usr/bin/env python3
"""Aplicador xdelta con comprobacion de identidad. No contiene una traduccion."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


class PatchError(ValueError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def describe(path: Path) -> dict:
    if not path.is_file():
        raise PatchError(f"No es un archivo: {path}")
    return {"size": path.stat().st_size, "sha256": sha256(path)}


def write_new_json(path: Path, data: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def unique_keys(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise PatchError(f"Clave JSON repetida: {key}")
        result[key] = value
    return result


def filename(value: object) -> str:
    # Names must work unchanged on Windows and POSIX; no drive, traversal or ADS.
    if (not isinstance(value, str) or not value or value in {".", ".."}
            or re.search(r'[<>:"/\\|?*\x00-\x1f]', value)
            or value.endswith((".", " "))
            or value.split(".")[0].upper() in
            {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(1, 10)),
             *(f"LPT{i}" for i in range(1, 10))}):
        raise PatchError(f"Nombre de archivo no permitido: {value!r}")
    return value


def validate_manifest(data: object) -> dict:
    """Validate in memory before any file is created."""
    if not isinstance(data, dict) or set(data) != {
            "format", "platform", "label", "status", "base_description",
            "source", "patch", "target"}:
        raise PatchError("Estructura de manifiesto no reconocida")
    if data["format"] != "verified-xdelta-v1" or data["platform"] != "Sega Saturn":
        raise PatchError("Formato o plataforma no reconocidos")
    if not isinstance(data["status"], str) or data["status"] not in {"experimental", "release"}:
        raise PatchError("Estado no reconocido")
    for key in ("label", "base_description"):
        if not isinstance(data[key], str) or not data[key].strip():
            raise PatchError(f"Falta {key}")
    for key in ("source", "patch", "target"):
        item = data[key]
        keys = {"size", "sha256"} | ({"name"} if key != "source" else set())
        if not isinstance(item, dict) or set(item) != keys:
            raise PatchError(f"Descriptor {key} no reconocido")
        if type(item["size"]) is not int or item["size"] < 0:
            raise PatchError(f"Tamano no valido en {key}")
        if not isinstance(item["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
            raise PatchError(f"SHA-256 no valido en {key}")
        if key != "source":
            filename(item["name"])
    if data["target"]["name"].lower() in {"resultado.partial", "verificado.json", "fallo.json"}:
        raise PatchError("Nombre de salida reservado")
    return data


def load_manifest_snapshot(path: Path) -> tuple[dict, str]:
    raw = path.read_bytes()
    data = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=unique_keys)
    return validate_manifest(data), hashlib.sha256(raw).hexdigest()


def read_manifest(path: Path) -> dict:
    return load_manifest_snapshot(path)[0]


def verify(path: Path, expected: dict, label: str) -> None:
    actual = describe(path)
    if actual != {key: expected[key] for key in ("size", "sha256")}:
        raise PatchError(f"{label}: tamano o SHA-256 no coinciden ({actual})")


def preflight(manifest: Path, source: Path) -> tuple[dict, Path, str]:
    data, manifest_digest = load_manifest_snapshot(manifest)
    patch = manifest.parent / data["patch"]["name"]
    if patch.resolve().parent != manifest.parent.resolve():
        raise PatchError("El parche debe estar dentro de la carpeta del manifiesto")
    verify(source, data["source"], "Base incompatible")
    verify(patch, data["patch"], "Parche incompatible")
    return data, patch.resolve(), manifest_digest


def apply(manifest: Path, source: Path, output_dir: Path, xdelta: Path,
          allow_experimental: bool = False) -> Path:
    manifest, source, xdelta = manifest.resolve(), source.resolve(), xdelta.resolve()
    data, patch, manifest_digest = preflight(manifest, source)
    if data["status"] == "experimental" and not allow_experimental:
        raise PatchError("Manifiesto experimental: requiere --allow-experimental")
    if not xdelta.is_file():
        raise PatchError(f"No se encuentra xdelta3: {xdelta}")
    # mkdir without exist_ok also refuses a pre-existing empty folder or symlink.
    output_dir.mkdir()
    output_dir = output_dir.resolve()
    partial = output_dir / "resultado.partial"
    target = output_dir / data["target"]["name"]
    try:
        result = subprocess.run(
            [str(xdelta), "-d", "-s", str(source), str(patch), str(partial)],
            capture_output=True, text=True, errors="replace", check=False)
        if result.returncode:
            raise PatchError(f"xdelta3 termino con codigo {result.returncode}: {result.stderr[-2000:]}")
        verify(source, data["source"], "Base modificada durante la ejecucion")
        verify(patch, data["patch"], "Parche modificado durante la ejecucion")
        if sha256(manifest) != manifest_digest:
            raise PatchError("Manifiesto modificado durante la ejecucion")
        verify(partial, data["target"], "Salida incorrecta")
        # Output folder was created exclusively above; no previous files are replaced.
        if target.exists():
            raise PatchError(f"Ya existe la salida: {target}")
        partial.rename(target)
        write_new_json(output_dir / "VERIFICADO.json", {
            "label": data["label"], "status": data["status"],
            "base_description": data["base_description"],
            "manifest_sha256": manifest_digest, "target": data["target"],
            "note": "Identidad binaria verificada; no certifica traduccion ni jugabilidad."})
    except BaseException as error:
        # Keep every artifact, including incomplete output, for diagnosis.
        write_new_json(output_dir / "FALLO.json", {"error": str(error), "verified": False})
        raise
    return target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "apply"):
        command = commands.add_parser(name)
        command.add_argument("--manifest", type=Path, required=True)
        command.add_argument("--source", type=Path, required=True)
        if name == "apply":
            command.add_argument("--output-dir", type=Path, required=True)
            command.add_argument("--xdelta", type=Path, required=True)
            command.add_argument("--allow-experimental", action="store_true")
    maker = commands.add_parser("make-manifest", help="Describe un candidato; no aprueba su contenido")
    for flag in ("source", "patch", "target", "manifest"):
        maker.add_argument(f"--{flag}", type=Path, required=True)
    maker.add_argument("--base-description", required=True)
    maker.add_argument("--label", required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "make-manifest":
            if args.patch.resolve().parent != args.manifest.resolve().parent:
                raise PatchError("Guardar el manifiesto junto al parche")
            data = {"format": "verified-xdelta-v1", "platform": "Sega Saturn",
                    "label": args.label, "status": "experimental",
                    "base_description": args.base_description,
                    "source": describe(args.source),
                    "patch": {"name": filename(args.patch.name), **describe(args.patch)},
                    "target": {"name": filename(args.target.name), **describe(args.target)}}
            validate_manifest(data)
            write_new_json(args.manifest, data)
            print(f"Manifiesto experimental guardado: {args.manifest}")
        elif args.command == "check":
            data, _, _ = preflight(args.manifest, args.source)
            print(f"Base y parche coinciden. Estado declarado: {data['status']}")
        else:
            target = apply(args.manifest, args.source, args.output_dir, args.xdelta,
                           args.allow_experimental)
            print(f"Salida verificada: {target}")
        return 0
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

