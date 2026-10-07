#!/usr/bin/env python3
"""SRW3 Phase 1G — Authority report PDF (Report pipeline).

Reads /home/z/my-project/srw3-work/SRW3-Phase1D-R1-Verifier-Audit-Report.md (single source of truth) and
renders it with the established Phase-0 report visual system (same palette,
fonts, table/code styling as gen_report_pdf.py Rev 4).
"""
import os
import re
import sys

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak, HRFlowable)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

SRC = '/home/z/my-project/srw3-kevm/phase1g/report/SRW3-Phase1G-Authority-Report.md'
OUT = '/home/z/my-project/srw3-kevm/phase1g/report/SRW3-Phase1G-Authority-Report.pdf'

# ---- palette (same cascade as the Phase-0 report) ----
PAGE_BG      = colors.HexColor('#f3f3f2')
CARD_BG      = colors.HexColor('#ebeae6')
TABLE_STRIPE = colors.HexColor('#efeeec')
HEADER_FILL  = colors.HexColor('#686049')
BORDER       = colors.HexColor('#d5d2ca')
ACCENT       = colors.HexColor('#887129')
TEXT_PRIMARY = colors.HexColor('#262522')
TEXT_MUTED   = colors.HexColor('#797770')
SEM_SUCCESS  = colors.HexColor('#3e8355')
SEM_ERROR    = colors.HexColor('#96463f')

FDIR = '/usr/share/fonts/truetype/dejavu'
pdfmetrics.registerFont(TTFont('DejaVu', f'{FDIR}/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Bold', f'{FDIR}/DejaVuSans-Bold.ttf'))
pdfmetrics.registerFont(TTFont('DejaVu-Mono', f'{FDIR}/DejaVuSansMono.ttf'))
pdfmetrics.registerFontFamily('DejaVu', normal='DejaVu', bold='DejaVu-Bold')

PAGE_W, PAGE_H = A4
LM = RM = 18*mm
AVAIL = PAGE_W - LM - RM


def st(name, **kw):
    base = dict(fontName='DejaVu', fontSize=9.5, leading=13.5,
                textColor=TEXT_PRIMARY, alignment=TA_LEFT, spaceAfter=5)
    base.update(kw)
    return ParagraphStyle(name, **base)


S = {
 'title':  st('title', fontName='DejaVu-Bold', fontSize=20, leading=25, spaceAfter=4),
 'subtitle': st('subtitle', fontSize=11, leading=15, textColor=TEXT_MUTED, spaceAfter=10),
 'h2': st('h2', fontName='DejaVu-Bold', fontSize=13.5, leading=17, spaceBefore=13,
          spaceAfter=6, textColor=HEADER_FILL),
 'h3': st('h3', fontName='DejaVu-Bold', fontSize=11, leading=14, spaceBefore=9,
          spaceAfter=4, textColor=ACCENT),
 'body': st('body'),
 'bullet': st('bullet', leftIndent=12, bulletIndent=2),
 'num': st('num', leftIndent=14),
 'code': st('code', fontName='DejaVu-Mono', fontSize=7.0, leading=9.2,
            textColor=TEXT_PRIMARY, spaceAfter=0),
 'cell': st('cell', fontSize=8, leading=10.6, spaceAfter=0),
 'cellh': st('cellh', fontName='DejaVu-Bold', fontSize=8, leading=10.6,
             textColor=colors.white, spaceAfter=0),
}


def inline(t):
    """markdown inline -> reportlab markup"""
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'(?<!\w)\*([^*\n]+?)\*(?!\w)', r'<i>\1</i>', t)
    t = re.sub(r'`([^`]+?)`', r'<font face="DejaVu-Mono" size="8.2">\1</font>', t)
    return t


def code_block(lines):
    """mono block with per-line wrapping at ~112 chars"""
    flow = []
    for ln in lines:
        while len(ln) > 112:
            flow.append(ln[:112])
            ln = '  ' + ln[112:]
        flow.append(ln)
    # split long code blocks into page-sized chunks so a block taller than
    # one page (the 1F RESULTS block) splits instead of failing layout
    paras = [Paragraph(inline(x) or ' ', S['code']) for x in flow]
    per = 62  # code lines per page-chunk
    chunks = [paras[i:i + per] for i in range(0, len(paras), per)] or [[]]
    out = []
    for ci, ch in enumerate(chunks):
        t = Table([[ch]], colWidths=[AVAIL])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), CARD_BG),
            ('BOX', (0, 0), (-1, -1), 0.5, BORDER),
            ('LEFTPADDING', (0, 0), (-1, -1), 7),
            ('RIGHTPADDING', (0, 0), (-1, -1), 7),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        out.append(t)
        if ci < len(chunks) - 1:
            out.append(Spacer(1, 5))
    out.append(Spacer(1, 5))
    return out


def md_table(rows):
    """rows: list of lists of cell strings (first row = header)"""
    n = max(len(r) for r in rows)
    rows = [r + [''] * (n - len(r)) for r in rows]
    weights = []
    for c in range(n):
        w = max(min(len(rows[i][c]), 90) for i in range(len(rows)))
        weights.append(max(w, 4))
    tot = sum(weights)
    widths = [AVAIL * w / tot for w in weights]
    data = []
    for i, r in enumerate(rows):
        sty = S['cellh'] if i == 0 else S['cell']
        data.append([Paragraph(inline(c), sty) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1)
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_FILL),
        ('GRID', (0, 0), (-1, -1), 0.4, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]
    for i in range(1, len(rows)):
        if i % 2 == 0:
            style.append(('BACKGROUND', (0, i), (-1, i), TABLE_STRIPE))
    t.setStyle(TableStyle(style))
    return [t, Spacer(1, 6)]


def parse(md):
    story = []
    lines = md.splitlines()
    i, first_h1 = 0, True
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('```'):
            j = i + 1
            buf = []
            while j < len(lines) and not lines[j].startswith('```'):
                buf.append(lines[j]); j += 1
            story.extend(code_block(buf))
            i = j + 1
            continue
        if ln.startswith('|'):
            j = i
            rows = []
            while j < len(lines) and lines[j].startswith('|'):
                cells = [c.strip() for c in lines[j].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-{2,}:?', c or '---') for c in cells):
                    rows.append(cells)
                j += 1
            story.extend(md_table(rows))
            i = j
            continue
        if ln.startswith('# '):
            if not first_h1:
                story.append(Spacer(1, 4))
            story.append(Paragraph(inline(ln[2:]), S['title']))
            story.append(HRFlowable(width='100%', thickness=1.2, color=ACCENT,
                                    spaceBefore=3, spaceAfter=7))
            first_h1 = False
            i += 1; continue
        if ln.startswith('## '):
            story.append(Paragraph(inline(ln[3:]), S['h2']))
            i += 1; continue
        if ln.startswith('### '):
            story.append(Paragraph(inline(ln[4:]), S['h3']))
            i += 1; continue
        if ln.strip() == '---':
            story.append(HRFlowable(width='100%', thickness=0.5, color=BORDER,
                                    spaceBefore=6, spaceAfter=6))
            i += 1; continue
        if re.match(r'^- ', ln):
            story.append(Paragraph(inline(ln[2:]), S['bullet'], bulletText='•'))
            i += 1; continue
        m = re.match(r'^(\d+)\. (.*)$', ln)
        if m:
            story.append(Paragraph(inline(m.group(2)), S['num'],
                                   bulletText=m.group(1) + '.'))
            i += 1; continue
        if ln.startswith('**') and ln.rstrip().endswith(('**', '.**')) and ln.count('**') == 2:
            story.append(Paragraph(inline(ln), S['body']))
            i += 1; continue
        if ln.strip() == '':
            story.append(Spacer(1, 3))
            i += 1; continue
        story.append(Paragraph(inline(ln), S['body']))
        i += 1
    return story


def header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(PAGE_BG)
    canvas.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
    canvas.setFillColor(TEXT_MUTED)
    canvas.setFont('DejaVu', 7.2)
    canvas.drawString(LM, PAGE_H - 12*mm,
                      'SRW3 Phase 1D — Verifiable Lineage')
    canvas.drawRightString(PAGE_W - RM, PAGE_H - 12*mm, '2026-10-01')
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.5)
    canvas.line(LM, PAGE_H - 13.5*mm, PAGE_W - RM, PAGE_H - 13.5*mm)
    canvas.line(LM, 13.5*mm, PAGE_W - RM, 13.5*mm)
    canvas.drawCentredString(PAGE_W / 2, 9*mm, f'{doc.page}')
    canvas.restoreState()


def main():
    md = open(SRC).read()
    story = parse(md)
    doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=LM, rightMargin=RM,
                            topMargin=18*mm, bottomMargin=18*mm,
                            title='SRW3 Phase 1D — Verifiable Lineage',
                            author='Z.ai', creator='Z.ai',
                            subject='SRW3 Phase 1C: keccak256 commitment lineage, libsecp256k1 ECDSA path, krypto shim')
    doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
    print(f'written: {OUT} ({os.path.getsize(OUT)} bytes)')


if __name__ == '__main__':
    main()
