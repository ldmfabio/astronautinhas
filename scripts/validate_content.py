#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
files = sorted((ROOT / "content/historias").glob("*.md"))
errors = []
seen_num = set()
seen_slug = set()


def field(header, name):
    match = re.search(rf"^{re.escape(name)}:\s*[\"']?([^\"'\n]+)", header, re.M)
    return match.group(1).strip() if match else None


for path in files:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        errors.append(f"{path.name}: sem frontmatter YAML")
        continue
    _, header, body = text.split("---\n", 2)
    number = field(header, "numero")
    slug = field(header, "slug")
    title = field(header, "titulo")
    date = field(header, "data")
    image = field(header, "imagem")
    draft = field(header, "draft")
    if not all([number, slug, title, date, image, draft]):
        errors.append(f"{path.name}: metadados obrigatórios ausentes")
        continue
    if number in seen_num:
        errors.append(f"{path.name}: número duplicado {number}")
    if slug in seen_slug:
        errors.append(f"{path.name}: slug duplicado {slug}")
    seen_num.add(number)
    seen_slug.add(slug)
    if not path.name.startswith(f"{int(number):03d}-"):
        errors.append(f"{path.name}: nome do arquivo não corresponde ao número {number}")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        errors.append(f"{path.name}: data inválida: {date}")
    if draft.lower() == "false":
        if "IMPORTAR AQUI" in body:
            errors.append(f"{path.name}: draft=false mas texto original não foi importado")
        if 'status_importacao: "original-importado"' not in header:
            errors.append(f"{path.name}: draft=false sem status original-importado")
        asset = (path.parent / image).resolve()
        if not asset.exists():
            errors.append(f"{path.name}: imagem não encontrada: {image}")

if len(files) != 39:
    errors.append(f"catálogo inicial esperado com 39 histórias; encontrados {len(files)}")
if errors:
    print("\n".join("ERRO: " + e for e in errors))
    sys.exit(1)
published = sum(1 for p in files if re.search(r"^draft:\s*false\s*$", p.read_text(encoding="utf-8"), re.M))
print(f"OK: {len(files)} histórias validadas; {published} liberadas para publicação.")
