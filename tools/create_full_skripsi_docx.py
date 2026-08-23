from __future__ import annotations

import html
import re
import zipfile
from datetime import UTC, datetime
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "doc" / "DRAFT_SKRIPSI_MQTT_DOS_RATE_LIMITING_UNRAM.docx"
FIG_DIR = ROOT / "output" / "doc" / "figures"

DRAFT_FILES = [
    ROOT / "docs" / "skripsi_draft" / "BAB_1_PENDAHULUAN_DRAFT.txt",
    ROOT / "docs" / "skripsi_draft" / "BAB_2_TINJAUAN_PUSTAKA_DRAFT.txt",
    ROOT / "docs" / "skripsi_draft" / "BAB_3_METODOLOGI_PENELITIAN_DRAFT.txt",
    ROOT / "docs" / "skripsi_draft" / "BAB_4_HASIL_DAN_PEMBAHASAN_DRAFT.txt",
    ROOT / "docs" / "skripsi_draft" / "BAB_5_PENUTUP_DRAFT.txt",
]

FRONT_FILE = ROOT / "docs" / "skripsi_draft" / "BAGIAN_AWAL_DRAFT.txt"
APPENDIX_FILE = ROOT / "docs" / "skripsi_draft" / "LAMPIRAN_DRAFT.txt"
REF_FILE = ROOT / "docs" / "REFERENSI_AWAL_DRAFT_SKRIPSI_MQTT_DOS_RATE_LIMITING.txt"

FIGURES = {
    "2.3 Message Queuing Telemetry Transport": {
        "path": FIG_DIR / "gambar_2_1_arsitektur_mqtt.png",
        "caption": "Gambar 2.1 Arsitektur Komunikasi MQTT Publish-Subscribe",
    },
    "2.5 Transmission Control Protocol dan Proses Koneksi": {
        "path": FIG_DIR / "gambar_2_2_tcp_syn_flood.png",
        "caption": "Gambar 2.2 TCP Three-Way Handshake dan Titik Serangan SYN Flood",
    },
    "3.3 Arsitektur Sistem Pengujian": {
        "path": FIG_DIR / "gambar_3_1_arsitektur_sistem_pengujian.png",
        "caption": "Gambar 3.1 Arsitektur Sistem Pengujian",
    },
    "3.5 Skenario Pengujian": {
        "path": FIG_DIR / "gambar_3_3_alur_skenario_pengujian.png",
        "caption": "Gambar 3.2 Alur Skenario Pengujian",
    },
    "3.6 Tahapan Penelitian": {
        "path": FIG_DIR / "gambar_3_2_alur_tahapan_penelitian.png",
        "caption": "Gambar 3.3 Alur Tahapan Penelitian",
    },
}

FIGURE_ORDER = list(FIGURES.values())
FIGURE_RIDS = {item["path"].name: f"rIdImage{i}" for i, item in enumerate(FIGURE_ORDER, start=1)}


def esc(text: str) -> str:
    return html.escape(text, quote=False)


def r(text: str) -> str:
    preserve = ' xml:space="preserve"' if text[:1].isspace() or text[-1:].isspace() else ""
    return f"<w:r><w:t{preserve}>{esc(text)}</w:t></w:r>"


def p(
    text: str = "",
    style: str | None = None,
    align: str | None = None,
    page_before: bool = False,
) -> str:
    props: list[str] = []
    if style:
        props.append(f'<w:pStyle w:val="{style}"/>')
    if align:
        props.append(f'<w:jc w:val="{align}"/>')
    if page_before:
        props.append("<w:pageBreakBefore/>")
    ppr = f"<w:pPr>{''.join(props)}</w:pPr>" if props else ""
    return f"<w:p>{ppr}{r(text) if text else ''}</w:p>"


def page_break() -> str:
    return p("", page_before=True)


def table(rows: list[list[str]]) -> str:
    if not rows:
        return ""
    cols = max(len(row) for row in rows)
    width = max(1000, 9000 // cols)
    grid = "".join(f'<w:gridCol w:w="{width}"/>' for _ in range(cols))
    out = [
        "<w:tbl>",
        "<w:tblPr>",
        '<w:tblW w:w="0" w:type="auto"/>',
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders>',
        "</w:tblPr>",
        f"<w:tblGrid>{grid}</w:tblGrid>",
    ]
    for i, row in enumerate(rows):
        out.append("<w:tr>")
        for cell in row + [""] * (cols - len(row)):
            shading = '<w:shd w:fill="D9EAF7"/>' if i == 0 else ""
            out.append(
                "<w:tc>"
                f"<w:tcPr><w:tcW w:w=\"{width}\" w:type=\"dxa\"/>{shading}</w:tcPr>"
                f"{p(cell)}"
                "</w:tc>"
            )
        out.append("</w:tr>")
    out.append("</w:tbl>")
    return "".join(out)


def image_paragraph(path: Path, caption: str) -> str:
    with Image.open(path) as im:
        px_w, px_h = im.size
    max_w_in = 5.9
    max_h_in = 7.4
    img_w_in = px_w / 180
    img_h_in = px_h / 180
    scale = min(max_w_in / img_w_in, max_h_in / img_h_in, 1.0)
    w_emu = int(img_w_in * scale * 914400)
    h_emu = int(img_h_in * scale * 914400)
    rid = FIGURE_RIDS[path.name]
    drawing = f"""
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="{w_emu}" cy="{h_emu}"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="{list(FIGURE_RIDS).index(path.name) + 1}" name="{esc(caption)}"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>
        </wp:cNvGraphicFramePr>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="{esc(path.name)}"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="{rid}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="{w_emu}" cy="{h_emu}"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"""
    return drawing + p(caption, "Caption")


def is_table_divider(line: str) -> bool:
    stripped = line.strip()
    return bool(stripped.startswith("|") and stripped.endswith("|") and re.fullmatch(r"[\|\-\:\s]+", stripped))


def parse_table_line(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def body_from_text(text: str, first_chapter: bool = False) -> str:
    lines = text.splitlines()
    out: list[str] = []
    table_rows: list[list[str]] = []

    def flush_table() -> None:
        nonlocal table_rows
        if table_rows:
            out.append(table(table_rows))
            table_rows = []

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("|") and stripped.endswith("|"):
            if not is_table_divider(stripped):
                table_rows.append(parse_table_line(stripped))
            continue
        flush_table()

        if not stripped:
            out.append(p(""))
            continue

        if re.fullmatch(r"BAB [IVX]+", stripped):
            if not first_chapter or out:
                out.append(page_break())
            out.append(p(stripped, "Heading1", "center"))
            continue

        if re.fullmatch(r"[A-Z][A-Z\s]+", stripped) and len(stripped) <= 50:
            out.append(p(stripped, "Heading1", "center"))
            continue

        if re.match(r"^\d+\.\d+(\.\d+)?\s+", stripped):
            style = "Heading2" if stripped.count(".") == 1 else "Heading3"
            out.append(p(stripped, style))
            figure = FIGURES.get(stripped)
            if figure and figure["path"].exists():
                out.append(image_paragraph(figure["path"], figure["caption"]))
            continue

        if stripped.startswith("Tabel "):
            out.append(p(stripped, "Caption"))
            continue

        out.append(p(stripped, "Normal"))

    flush_table()
    return "".join(out)


def extract_references() -> list[str]:
    if not REF_FILE.exists():
        return []
    refs: list[str] = []
    current: list[str] = []
    for raw in REF_FILE.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if re.match(r"^\d+\.\s+", line):
            if current:
                refs.append(" ".join(current).strip())
            current = [line]
            continue
        if current and line.strip().startswith(("Kegunaan:", "Link:")):
            continue
        if current and line.strip().startswith("- "):
            continue
        if current and line.strip():
            current.append(line.strip())
    if current:
        refs.append(" ".join(current).strip())
    return refs


def styles_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:after="120" w:line="360" w:lineRule="auto"/><w:jc w:val="both"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="180"/><w:keepNext/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:spacing w:before="200" w:after="120"/><w:keepNext/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="26"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:spacing w:before="160" w:after="100"/><w:keepNext/></w:pPr>
    <w:rPr><w:b/><w:i/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Caption">
    <w:name w:val="Caption"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="120" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="22"/></w:rPr>
  </w:style>
</w:styles>
"""


def content_types_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""


def rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"""


def document_rels_xml() -> str:
    rels = []
    for item in FIGURE_ORDER:
        path = item["path"]
        rels.append(
            f'<Relationship Id="{FIGURE_RIDS[path.name]}" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            f'Target="media/{path.name}"/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(rels)
        + "</Relationships>"
    )


def core_xml() -> str:
    now = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Draft Skripsi MQTT DoS Rate Limiting</dc:title>
  <dc:creator>Generated by project script</dc:creator>
  <cp:lastModifiedBy>Generated by project script</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
"""


def app_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Generated OpenXML</Application>
</Properties>
"""


def build_document_xml() -> str:
    body: list[str] = []
    title = "DRAFT SKRIPSI"
    subtitle = "ANALISIS SERANGAN DOS PADA BROKER MQTT DAN MITIGASINYA DENGAN MENGGUNAKAN RATE LIMITING PADA SERVER UNIVERSITAS MATARAM"

    body.append(p(title, "Title", "center"))
    body.append(p(subtitle, "Title", "center"))
    body.append(p(""))
    body.append(p("Status Dokumen: Draft awal untuk pengembangan skripsi", "Normal", "center"))
    body.append(p("Catatan: BAB IV dan BAB V masih perlu disesuaikan setelah angka hasil eksperimen final tersedia.", "Normal", "center"))
    body.append(p(""))
    body.append(p("Universitas Mataram", "Normal", "center"))
    body.append(page_break())

    if FRONT_FILE.exists():
        body.append(body_from_text(FRONT_FILE.read_text(encoding="utf-8"), first_chapter=True))
        body.append(page_break())

    body.append(p("DAFTAR ISI SEMENTARA", "Heading1", "center"))
    for item in [
        "ABSTRAK",
        "KATA PENGANTAR",
        "DAFTAR GAMBAR SEMENTARA",
        "DAFTAR TABEL SEMENTARA",
        "DAFTAR LAMPIRAN SEMENTARA",
        "BAB I PENDAHULUAN",
        "BAB II TINJAUAN PUSTAKA",
        "BAB III METODOLOGI PENELITIAN",
        "BAB IV HASIL DAN PEMBAHASAN",
        "BAB V PENUTUP",
        "DAFTAR PUSTAKA AWAL",
        "LAMPIRAN",
    ]:
        body.append(p(item))

    for path in DRAFT_FILES:
        body.append(body_from_text(path.read_text(encoding="utf-8"), first_chapter=False))

    refs = extract_references()
    body.append(page_break())
    body.append(p("DAFTAR PUSTAKA AWAL", "Heading1", "center"))
    body.append(
        p(
            "Daftar pustaka ini masih berupa referensi awal dan perlu disesuaikan dengan format penulisan yang diminta oleh program studi atau dosen pembimbing."
        )
    )
    for ref in refs:
        body.append(p(ref))

    if APPENDIX_FILE.exists():
        body.append(page_break())
        body.append(body_from_text(APPENDIX_FILE.read_text(encoding="utf-8"), first_chapter=False))

    sect = (
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1800" w:header="708" w:footer="708" w:gutter="0"/>'
        "</w:sectPr>"
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        f"<w:body>{''.join(body)}{sect}</w:body></w:document>"
    )


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as docx:
        docx.writestr("[Content_Types].xml", content_types_xml())
        docx.writestr("_rels/.rels", rels_xml())
        docx.writestr("word/_rels/document.xml.rels", document_rels_xml())
        docx.writestr("word/document.xml", build_document_xml())
        docx.writestr("word/styles.xml", styles_xml())
        for item in FIGURE_ORDER:
            path = item["path"]
            if path.exists():
                docx.write(path, f"word/media/{path.name}")
        docx.writestr("docProps/core.xml", core_xml())
        docx.writestr("docProps/app.xml", app_xml())
    print(OUT)


if __name__ == "__main__":
    main()
