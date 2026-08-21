#!/usr/bin/env python3
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)


def parse_md(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}, text.strip()
    _, header, body = text.split("---\n", 2)
    meta = {}
    for line in header.splitlines():
        if ":" in line and not line.startswith((" ", "\t")):
            key, value = line.split(":", 1)
            meta[key] = value.strip().strip('"').strip("'")
    return meta, body.strip()


def is_true(value, default=False):
    if value is None:
        return default
    return str(value).lower() == "true"


def stories():
    out = []
    for path in sorted((ROOT / "content/historias").glob("*.md")):
        meta, body = parse_md(path)
        if not is_true(meta.get("draft"), True):
            out.append((path, meta, body))
    return out


def pages():
    out = []
    for path in sorted((ROOT / "content/paginas").glob("*.md")):
        meta, body = parse_md(path)
        if not is_true(meta.get("draft"), False):
            out.append((int(meta.get("ordem", "999")), body))
    return [body for _, body in sorted(out)]


def require(command):
    if shutil.which(command) is None:
        sys.exit(f"Comando obrigatório não encontrado: {command}")


def image_path(meta):
    return (ROOT / "content/historias" / meta["imagem"]).resolve()


def build_epub(items):
    require("pandoc")
    source = DIST / "book.epub.md"
    chunks = pages() + ["# Histórias"]
    for _, meta, body in items:
        chunks += [body, f'![Ilustração de {meta.get("titulo", "história")}]({image_path(meta).as_posix()})', "\\newpage"]
    source.write_text("\n\n".join(chunks), encoding="utf-8")
    subprocess.run(["pandoc", str(source), "-o", str(DIST / "astronautinhas.epub"), "--css", str(ROOT / "publishing/epub/epub.css"), "--metadata-file", str(ROOT / "metadata.yaml"), "--toc"], check=True, cwd=ROOT)


def build_pdf(items):
    require("pandoc")
    require("xelatex")
    source = DIST / "book.pdf.md"
    chunks = pages() + ["# Histórias"]
    for _, meta, body in items:
        chunks += ["\\clearpage\n\\ifodd\\value{page}\\hbox{}\\newpage\\fi", body, "\\newpage", "\\thispagestyle{empty}\n\\begin{center}\n" + f"\\includegraphics[width=\\textwidth,height=0.90\\textheight,keepaspectratio]{{{image_path(meta).as_posix()}}}" + "\n\\end{center}"]
    source.write_text("\n\n".join(chunks), encoding="utf-8")
    subprocess.run(["pandoc", str(source), "-o", str(DIST / "astronautinhas.pdf"), "--pdf-engine=xelatex", "--template", str(ROOT / "publishing/pdf/template.tex"), "--toc", "--metadata-file", str(ROOT / "metadata.yaml")], check=True, cwd=ROOT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--format", choices=["pdf", "epub"], required=True)
    parser.add_argument("--if-empty", choices=["error", "skip"], default="error")
    args = parser.parse_args()
    items = stories()
    if not items:
        msg = "Nenhuma história publicada/importada ainda."
        if args.if_empty == "skip":
            print("SKIP: " + msg)
            return
        sys.exit(msg)
    build_pdf(items) if args.format == "pdf" else build_epub(items)


if __name__ == "__main__":
    main()
