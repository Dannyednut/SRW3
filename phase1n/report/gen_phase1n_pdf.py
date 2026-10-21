#!/usr/bin/env python3
"""SRW3 Phase 1N — render the phase report MD as PDF (reportlab, single
source of truth = the MD).  Minimal, deterministic, no network."""
import pathlib
import re
import sys

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                PageBreak)

HERE = pathlib.Path(__file__).resolve().parent
MD = HERE / "SRW3-Phase1N-Abstract-Transition-Simulation-Report.md"
PDF = HERE / "SRW3-Phase1N-Abstract-Transition-Simulation-Report.pdf"

INK = HexColor("#1a1a1a")
ACCENT = HexColor("#0f4c5c")

def esc(t):
    return (t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))

def inline(t):
    t = esc(t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"`([^`]+)`", r"<font face='Courier' size='8'>\1</font>", t)
    t = re.sub(r"\*([^*]+)\*", r"<i>\1</i>", t)
    return t

def main() -> int:
    text = MD.read_text()
    ss = getSampleStyleSheet()
    body = ParagraphStyle("body", parent=ss["Normal"], fontName="Helvetica",
                          fontSize=8.6, leading=11.6, textColor=INK)
    h1 = ParagraphStyle("h1", parent=body, fontName="Helvetica-Bold",
                        fontSize=13, leading=16, textColor=ACCENT,
                        spaceBefore=10, spaceAfter=5)
    h2 = ParagraphStyle("h2", parent=body, fontName="Helvetica-Bold",
                        fontSize=10.5, leading=13.5, textColor=INK,
                        spaceBefore=8, spaceAfter=3)
    mono = ParagraphStyle("mono", parent=body, fontName="Courier",
                          fontSize=7.4, leading=9.2, backColor=HexColor("#f4f4f0"),
                          leftIndent=4 * mm, spaceBefore=2, spaceAfter=4)
    story = []
    for block in text.split("\n\n"):
        b = block.strip()
        if not b:
            continue
        if b.startswith("## "):
            story.append(Paragraph(inline(b[3:]), h2))
        elif b.startswith("# "):
            story.append(Paragraph(inline(b[2:]), h1))
        elif b.startswith("```"):
            code = b.strip("`").strip()
            story.append(Paragraph(esc(code).replace("\n", "<br/>"), mono))
        elif b.startswith("* ") or b.startswith("- "):
            items = [inline("• " + li[2:]) for li in b.split("\n") if li.strip().startswith(("* ", "- "))]
            for it in items:
                story.append(Paragraph(it, body))
            story.append(Spacer(1, 3))
        else:
            story.append(Paragraph(inline(b.replace("\n", " ")), body))
            story.append(Spacer(1, 3))

    def footer(canv, doc):
        canv.saveState()
        canv.setFont("Helvetica", 6.6)
        canv.setFillColor(ACCENT)
        canv.drawString(18 * mm, 12 * mm,
                        "SRW3 Phase 1N — Abstract-Transition Simulation — Level III only — no consensus-integration claim")
        canv.drawRightString(192 * mm, 12 * mm, f"p. {doc.page}")
        canv.restoreState()

    doc = SimpleDocTemplate(str(PDF), pagesize=A4,
                            leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=18 * mm,
                            title="SRW3 Phase 1N — Abstract-Transition Simulation")
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print("PDF written:", PDF)
    return 0

if __name__ == "__main__":
    sys.exit(main())
