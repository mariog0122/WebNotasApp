"""Extrae los mapas curriculares de los Currículos Priorizados de EGB (Elemental, Media) desde el PDF oficial.

Uso: python3 extract_priorizado_egb.py <curriculo.pdf> <id> <salida.json>
     id: elemental | media | preparatoria
(requiere: pip install pdfplumber; salida usada: src/data/curriculos/<id>.json)

Estructura del PDF (igual que el de Alfabetización): por asignatura una página de objetivos y tablas de
3 columnas Criterios | Destrezas | Indicadores; Inglés usa códigos con espacio ("EFL 3.1.1"); al final la
sección de Cívica y Acompañamiento Integral (CAI) en tablas Código | Destreza | Habilidades | Indicadores.
Los textos y códigos se copian literalmente; solo se normaliza el separador de los códigos de Inglés.
"""
import hashlib
import json
import re
import sys
from collections import OrderedDict

import pdfplumber

from extract_alfabetizacion import join_text, lines_of

COLS = [(59, 218), (218, 377), (377, 540)]
PREFIX = r'[A-Z]{1,4}(?:\.[A-Z]{1,2})?'
CODE_RX = {
    'criterio': re.compile(rf'^(?:CE|EC)\.({PREFIX})[ .](\d)\.(\d+)\.?$'),
    'destreza': re.compile(rf'^({PREFIX})[ .]?(\d)\.(\d+)\.(\d+)\.?$'),
    'indicador': re.compile(rf'^(Ref\.\s?)?I\.(?:E\.)?({PREFIX})[ .](\d)\.(\d+)\.(\d+)\.?$'),
    'objetivo': re.compile(rf'^O\.({PREFIX})[ .](\d)\.(\d+)\.?$'),
    'objetivo_general': re.compile(rf'^OG\.({PREFIX})\.(\d+)\.?$'),
}
# Erratas evidentes del PDF oficial: se corrigen y se registran como aviso.
SKILL_PREFIX_FIX = {'L': 'LL'}
# Íconos (hash MD5 del flujo de imagen, verificados visualmente): competencias e inserciones curriculares.
_C, _I = 'competencias', 'inserciones'
ICONS = {
    '6a2b9fa6': (_C, 'comunicacionales'), '1144dd67': (_C, 'comunicacionales'),
    '0c31a845': (_C, 'matematicas'),
    'ea824050': (_C, 'digitales'),
    'ec0456c4': (_C, 'socioemocionales'), 'bbe3fd36': (_C, 'socioemocionales'),
    '02294b50': (_I, 'civica_etica_integridad'), 'e3fd5238': (_I, 'civica_etica_integridad'), 'a2d6629a': (_I, 'civica_etica_integridad'),
    'c19c5813': (_I, 'desarrollo_sostenible'), '3f195789': (_I, 'desarrollo_sostenible'),
    '12212309': (_I, 'socioemocional'), 'a458cbbd': (_I, 'socioemocional'), '0850e613': (_I, 'socioemocional'),
    'b9770712': (_I, 'seguridad_vial'), 'cbd40232': (_I, 'seguridad_vial'),
    '118235ad': (_I, 'financiera'),
    '142433f0': (_I, 'seguridad_integral'), '935d1a52': (_I, 'seguridad_integral'), '9e43747d': (_I, 'seguridad_integral'),
    'cc56d3d7': (_I, 'seguridad_integral'), '5f1ce432': (_I, 'seguridad_integral'), '92189ef2': (_I, 'seguridad_integral'),
    '00f46e7a': (_I, 'seguridad_integral'), '5ae481ba': (_I, 'seguridad_integral'),
}


def normalize(kind, m):
    if kind == 'criterio':
        return f'CE.{m.group(1)}.{m.group(2)}.{m.group(3)}'
    if kind == 'destreza':
        return f'{m.group(1)}.{m.group(2)}.{m.group(3)}.{m.group(4)}'
    if kind == 'indicador':
        return f"{'Ref. ' if m.group(1) else ''}I.{m.group(2)}.{m.group(3)}.{m.group(4)}.{m.group(5)}"
    return f'O.{m.group(1)}.{m.group(2)}.{m.group(3)}'


_COLS_CACHE = {}


def page_cols(page):
    """Límites de las 3 columnas en esta página (algunas tablas están desplazadas unos puntos)."""
    key = (id(page.pdf), page.page_number)
    if key not in _COLS_CACHE:
        xs = sorted({round(l['x0']) for l in page.lines if abs(l['x0'] - l['x1']) < 1 and l['bottom'] - l['top'] > 40}
                    | {round(r['x0']) for r in page.rects if r['height'] > 40 and r['width'] < 5})
        merged = []
        for x in xs:
            if not merged or x - merged[-1] > 20:
                merged.append(x)
        cols = COLS
        for i in range(len(merged) - 3):
            a, b, c, d = merged[i:i + 4]
            if all(120 < w < 200 for w in (b - a, c - b, d - c)):
                cols = [(a, b), (b, c), (c, d + 5)]
                break
        _COLS_CACHE[key] = cols
    return _COLS_CACHE[key]


def match_objective(words):
    code, used = match_code('objetivo', words)
    if code:
        return code, used
    m = CODE_RX['objetivo_general'].match(words[0]['text']) if words else None
    return (f'OG.{m.group(1)}.{m.group(2)}', 1) if m else (None, 0)


def match_code(kind, words):
    """Prueba el código con la primera palabra o con las dos primeras ("EFL 3.1.1." / "CE. P.9.")."""
    for n in (1, 2, 3):
        if len(words) < n:
            break
        text = ' '.join(w['text'] for w in words[:n])
        compact = re.sub(r'(?<=\.)\s+', '', text)
        for candidate in (text, compact):
            m = CODE_RX[kind].match(candidate)
            if m:
                return normalize(kind, m), n
    return None, 0


def table_top(page):
    """Borde superior de la tabla de criterios (lo que esté encima son títulos u objetivos)."""
    words = page.extract_words()
    tops = [w['top'] for w in words if w['text'] in ('Criterios', 'Evaluation') and w['x0'] < 218]
    if not tops:
        return 130
    t0 = min(tops)
    header = [w for w in words if t0 - 12 <= w['top'] <= t0 + 30 and w['text'].lower() in (
        'criterios', 'evaluación', 'destrezas', 'con', 'de', 'desempeño', 'indicadores', 'evaluation', 'criteria',
        'skills', 'and', 'performance', 'descriptors', 'to', 'be', 'evaluated', 'indicators', 'for', 'the')]
    return max(w['bottom'] for w in header) + 1


HEADING_RXS = [
    re.compile(r'Ámbito de desarrollo y aprendizaje \d+:\s*(.+)'),
    re.compile(r'Área del conocimiento/asignatura:\s*(.+)'),
    re.compile(r'Area/subject:\s*(.+)'),
    re.compile(r'^Currículo de (Educación .+?)\s*\d*$'),
]


def clean_heading(name):
    name = name.split('Destrezas con')[0].split('Objetivo')[0]
    name = re.sub(r'\s+(Criterios|Curricular Thread|Thread).*$', '', name)
    return name.strip()


def layout(page):
    """Títulos de asignatura/ámbito y encabezados de tabla de una página, con su posición vertical."""
    words = page.extract_words()
    markers = []
    for line in lines_of(words):
        text = ' '.join(w['text'] for w in line['words']).strip()
        for rx in HEADING_RXS:
            m = rx.search(text)
            if m:
                markers.append((line['top'], clean_heading(m.group(1))))
                break
    headers = []
    for w in words:
        if w['text'] in ('Criterios', 'Evaluation') and w['x0'] < 218:
            band = [x for x in words if w['top'] - 12 <= x['top'] <= w['top'] + 30 and x['text'].lower() in (
                'criterios', 'evaluación', 'destrezas', 'con', 'de', 'desempeño', 'indicadores', 'evaluation', 'criteria',
                'skills', 'and', 'performance', 'descriptors', 'to', 'be', 'evaluated', 'indicators', 'for', 'the')]
            if len(band) >= 4:
                headers.append((w['top'] - 12, max(x['bottom'] for x in band) + 1))
    headers = sorted(set(headers))
    # Zonas de tabla: desde cada encabezado hasta el siguiente título (o el pie de página).
    zones = []
    for top, bottom in headers:
        nxt = min([m[0] for m in markers if m[0] > bottom] + [page.height - 40])
        zones.append((bottom, nxt))
    return markers, zones


def in_zones(word, zones):
    return any(a < word['top'] and word['bottom'] < b for a, b in zones)


def page_area(page):
    text = page.extract_text() or ''
    amb = re.search(r'Ámbito de desarrollo y aprendizaje \d+:\s*(.+)', text)
    if amb:
        return amb.group(1).split('Objetivo')[0].strip()
    m = re.search(r'(?:Área del conocimiento/asignatura|Area/subject):\s*(.+)', text)
    if not m:
        return None
    name = m.group(1).split('Destrezas con')[0].split('Objetivos')[0].strip()
    name = re.sub(r'\s+(Criterios|Curricular Thread|Thread).*$', '', name).strip()
    return name


REF_RX = re.compile(rf'\(?Ref\.\s*\(?\s*(?:I\.)?({PREFIX})\.(\d)\.(\d+)\.(\d+)\.?\s*\)?\s*\)?\s*')
# Código impreso al final del indicador en lugar del inicio ("… model text. I.EFL.2.19.1 (I.3)").
TRAIL_RX = re.compile(rf'\s*\bI\.({PREFIX})\.(\d)\.(\d+)\.(\d+)\.?(?=\s*\([IJS][^)]*\)\s*$|\s*$)')


def collect(pdf, pages, col, kind):
    """Ítems de una columna. Los indicadores "de referencia" no llevan código al inicio: se separan por
    párrafo y su código se toma de "(Ref. I.X.n.m.k.)" al final del texto."""
    items, current = [], None
    for pn in pages:
        page = pdf.pages[pn]
        left, right = page_cols(page)[col]
        _, zones = layout(page)
        words = [w for w in page.extract_words() if left - 2 <= w['x0'] < right - 2 and in_zones(w, zones)]
        prev_bottom = None
        for line in lines_of(words):
            code, used = match_code(kind, line['words'])
            typo = False
            if not code and kind == 'indicador':
                # Errata: indicador impreso sin "I." ("M.1.5.1." en la columna de indicadores).
                alt, alt_used = match_code('destreza', line['words'])
                if alt:
                    code, used, typo = f'I.{alt}', alt_used, True
            bottom = max(w['bottom'] for w in line['words'])
            new_paragraph = prev_bottom is None or line['top'] - prev_bottom > 9
            prev_bottom = bottom
            if code and line['words'][0]['x0'] < left + 25:
                current = {'order': (pn, line['top']), 'code': code, 'parts': [w['text'] for w in line['words'][used:]], 'typo': typo}
                items.append(current)
            elif kind == 'indicador' and (current is None or new_paragraph):
                current = {'order': (pn, line['top']), 'code': None, 'parts': [w['text'] for w in line['words']]}
                items.append(current)
            elif current is not None:
                current['parts'].extend(w['text'] for w in line['words'])
    if kind == 'criterio':
        # Celda real del criterio (puede estar combinada y con el texto centrado verticalmente).
        for i in items:
            page = pdf.pages[i['order'][0]]
            cl, cr = page_cols(page)[0]
            spans = [c for t in page.find_tables() for c in t.cells if c[0] < cl + 10 and c[2] <= cr + 10]
            hit = [c for c in spans if c[1] - 2 <= i['order'][1] <= c[3] + 2]
            if hit:
                i['span'] = (min(c[1] for c in hit), max(c[3] for c in hit))
    out = []
    for i in items:
        text, code = join_text(i['parts']), i['code']
        if kind == 'indicador' and code is None:
            m = REF_RX.search(text)
            if not m:
                t = TRAIL_RX.search(text)
                if t:
                    out.append({'order': i['order'], 'code': f'I.{t.group(1)}.{t.group(2)}.{t.group(3)}.{t.group(4)}',
                                'text': (text[:t.start()] + text[t.end():]).strip(), 'moved_code': True})
                    continue
                # Párrafo sin código: continuación del indicador anterior partido por un salto de página.
                if out:
                    out[-1]['text'] += ' ' + text
                continue
            code = f'Ref. I.{m.group(1)}.{m.group(2)}.{m.group(3)}.{m.group(4)}'
            text = (text[:m.start()] + text[m.end():]).strip()
        out.append({'order': i['order'], 'code': code, 'text': text, 'typo': i.get('typo', False), 'span': i.get('span')})
    return out


def icons(pdf, pages):
    found = []
    for pn in pages:
        left, right = page_cols(pdf.pages[pn])[1]
        for im in pdf.pages[pn].images:
            if left <= im['x0'] < right + 10 and im['width'] < 40:
                h = hashlib.md5(im['stream'].get_data()).hexdigest()[:8]
                if h in ICONS:
                    found.append({'order': (pn, im['top']), 'tipo': ICONS[h][0], 'valor': ICONS[h][1]})
    return found


def objectives(pdf, pn):
    """Objetivos (O.X.n.m / OG.X.n) en recuadros fuera de las tablas; devuelve también su posición."""
    page = pdf.pages[pn]
    markers, zones = layout(page)
    out = []
    for left, right in [(59, 300), (296, 545)]:
        words = [w for w in page.extract_words() if left - 2 <= w['x0'] < right - 2 and w['top'] > 90
                 and w['bottom'] < page.height - 40 and not in_zones(w, zones)]
        current = None
        for line in lines_of(words):
            code, used = match_objective(line['words'])
            if code and line['words'][0]['x0'] < left + 25:
                current = {'codigo': code, 'order': (pn, line['top']), 'parts': [w['text'] for w in line['words'][used:]]}
                out.append(current)
            elif current and not any(rx.search(' '.join(w['text'] for w in line['words'])) for rx in HEADING_RXS):
                current['parts'].extend(w['text'] for w in line['words'])
    return [{'codigo': o['codigo'], 'order': o['order'], 'descripcion': join_text(o['parts'])} for o in out]


def raw_codes(pdf, pages, col, rx):
    """Códigos tal como aparecen impresos (para registrar erratas corregidas)."""
    found = set()
    for pn in pages:
        left, right = page_cols(pdf.pages[pn])[col]
        for w in pdf.pages[pn].extract_words():
            if left - 2 <= w['x0'] < left + 25 and re.match(rx, w['text']):
                found.add(w['text'].rstrip('.'))
    return found


def build_area(name, crits, dests, inds, objetivos, raw_ce, raw_ie):
    """Arma una asignatura/ámbito con los ítems ya asignados a ella (en orden de aparición)."""
    def owner(item):
        pn, top = item['order']
        for c in crits:
            if c.get('span') and c['order'][0] == pn and c['span'][0] - 2 <= top <= c['span'][1] + 2:
                return c
        chosen = None
        for c in crits:
            if c['order'] <= item['order'] or (c['order'][0] == item['order'][0] and abs(c['order'][1] - item['order'][1]) < 15):
                chosen = c
        return chosen

    area_prefixes = {c['code'].split('.')[1] for c in crits}
    typo_notes = []
    for i in inds:
        if i.get('typo'):
            printed = i['code'][2:]
            head = printed.split('.')[0]
            if head not in area_prefixes and head[1:] in area_prefixes:  # "ECS.3.3.1" / "ICN.2.4.2"
                i['code'] = f'I.{head[1:]}{printed[len(head):]}'
            typo_notes.append(f'El PDF oficial imprime "{printed}" en la columna de indicadores; se usa {i["code"]}.')
    criterios = OrderedDict((c['code'], {'codigo': c['code'], 'codigos': [c['code']], 'descripcion': c['text'], 'destrezas': [], 'indicadores': []}) for c in crits)
    for d in dests:
        o = owner(d)
        if o is None:
            continue
        criterios[o['code']]['destrezas'].append({
            'codigo': d['code'], 'descripcion': d['text'], 'subnivel': d['code'].split('.')[-3],
            'competencias': d.get('competencias', []), 'inserciones': d.get('inserciones', []),
        })
    for i in inds:
        o = owner(i)
        if o is None:
            continue
        criterios[o['code']]['indicadores'].append({'codigo': i['code'], 'descripcion': i['text'], 'referencia': i['code'].startswith('Ref.')})
    avisos = list(typo_notes)
    for printed in sorted(raw_ce):
        avisos.append(f'El PDF oficial imprime "{printed}"; se usa {"CE" + printed[2:]}.')
    for printed in sorted(raw_ie):
        avisos.append(f'El PDF oficial imprime "{printed}"; se usa {"I." + printed[4:]}.')
    for i in inds:
        if i.get('moved_code'):
            avisos.append(f'En el PDF oficial el código {i["code"]} aparece al final del indicador; se ubicó al inicio.')
    for crit in criterios.values():
        for d in crit['destrezas']:
            head = d['codigo'].split('.')[0]
            if head in SKILL_PREFIX_FIX and prefix_hint(criterios) == SKILL_PREFIX_FIX[head]:
                fixed = SKILL_PREFIX_FIX[head] + d['codigo'][len(head):]
                avisos.append(f'El PDF oficial imprime "{d["codigo"]}"; se usa {fixed}.')
                d['codigo'] = fixed
    # El currículo repite algunas destrezas en varios criterios (p. ej. Educación Física): se planifican una vez,
    # en su primer criterio, que además registra los otros criterios (con sus indicadores) que también la evalúan.
    host, repeated = {}, []
    for crit in criterios.values():
        unique = []
        for d in crit['destrezas']:
            first = host.get(d['codigo'])
            if first is None:
                host[d['codigo']] = crit
                unique.append(d)
                continue
            repeated.append(d['codigo'])
            if first is not crit:
                rel = first.setdefault('relacionados', [])
                if all(r['codigo'] != crit['codigo'] for r in rel):
                    rel.append({'codigo': crit['codigo'], 'descripcion': crit['descripcion']})
                known = {i['codigo'] for i in first['indicadores']}
                first['indicadores'].extend(i for i in crit['indicadores'] if i['codigo'] not in known)
        crit['destrezas'] = unique
    if repeated:
        avisos.append(f'{len(repeated)} destrezas figuran en más de un criterio en el PDF ({", ".join(sorted(set(repeated))[:6])}…); se planifican una vez y su primer criterio registra los demás como relacionados.')
    crit_list = [c for c in criterios.values() if c['destrezas']]
    codes = [d['codigo'] for c in crit_list for d in c['destrezas']]
    prefix = max(set(c.split('.')[0] for c in codes), key=[c.split('.')[0] for c in codes].count) if codes else ''
    return {
        'id': re.sub(r'[^a-z]+', '_', name.lower().translate(str.maketrans('áéíóúñ', 'aeioun'))).strip('_'),
        'nombre': name,
        'prefijo': prefix,
        'objetivos': objetivos,
        'criterios': crit_list,
        'subniveles': sorted({d['subnivel'] for c in crit_list for d in c['destrezas']}),
        'total_destrezas': len(codes),
        'avisos': avisos,
        'estado': 'con_avisos' if avisos else 'completa',
    }


def prefix_hint(criterios):
    heads = [d['codigo'].split('.')[0] for c in criterios.values() for d in c['destrezas']]
    return max(set(heads), key=heads.count) if heads else ''


def civica(pdf, pages):
    """Cívica y Acompañamiento Integral: bloques con criterio en párrafo y tabla Código | Destreza | Habilidades | Indicadores."""
    bloques = []
    for pn in pages:
        page = pdf.pages[pn]
        words = [w for w in page.extract_words() if w['bottom'] < page.height - 40 and w['top'] > 90]
        lines = lines_of(words)
        rects = sorted({round(r['x0']) for r in page.rects if r['height'] > 30})
        table_top = min((w['top'] for w in words if w['text'] in ('CÓDIGO',)), default=10_000)
        header = join_text([w['text'] for l in lines if l['top'] < table_top for w in l['words']])
        m = re.search(r'Bloque curricular (\d+)[.:]\s*(.*?)\s*Criterio de evaluación \d+[.:]\s*(.*)$', header)
        if m:
            bloques.append({'numero': int(m.group(1)), 'titulo': m.group(2).rstrip('.'), 'criterio': m.group(3), 'destrezas': [], 'indicadores': []})
        if not bloques:
            continue
        bloque = bloques[-1]
        xs = [x for x in rects if 50 < x < 560]
        if len(xs) < 4:
            xs = [60, 128, 282, 388]
        cols = [(xs[0], xs[1]), (xs[1], xs[2]), (xs[2], xs[3]), (xs[3], 560)]
        col_lines = {i: lines_of([w for w in words if a - 2 <= w['x0'] < b - 2 and w['top'] > table_top + 20]) for i, (a, b) in enumerate(cols)}
        rows = [{'codigo': l['words'][0]['text'], 'top': l['top']} for l in col_lines[0] if re.match(r'^CAI\.\d+\.\d+\.\d+$', l['words'][0]['text'])]
        for idx, row in enumerate(rows):
            bottom = rows[idx + 1]['top'] - 2 if idx + 1 < len(rows) else 10_000
            pick = lambda i: join_text([w['text'] for l in col_lines[i] if row['top'] - 3 <= l['top'] < bottom for w in l['words']])
            habilidades = [h.strip() for h in re.split(r'(?<=[a-zóa])\s+(?=[A-ZÁÉÍÓÚ])', pick(2)) if h.strip()]
            bloque['destrezas'].append({'codigo': row['codigo'], 'descripcion': pick(1), 'habilidades_socioemocionales': habilidades})
        ind_text = join_text([w['text'] for l in col_lines[3] for w in l['words']])
        for name, desc in re.findall(r'([A-ZÁÉÍÓÚ][a-záéíóúñ]+(?: [a-záéíóúñ/]+){0,4}):\s*(.*?)(?=\s+[A-ZÁÉÍÓÚ][a-záéíóúñ]+(?: [a-záéíóúñ/]+){0,4}:|$)', ind_text):
            bloque['indicadores'].append({'habilidad': name, 'descripcion': desc})
    return bloques


def civica_as_area(bloques):
    criterios = []
    for b in bloques:
        criterios.append({
            'codigo': None,
            'codigos': [],
            'codigo_descripcion': f"Bloque {b['numero']}",
            'descripcion': f"Bloque curricular {b['numero']}: {b['titulo']}. Criterio de evaluación {b['numero']}: {b['criterio']}",
            'destrezas': [{'codigo': d['codigo'], 'descripcion': d['descripcion'], 'subnivel': d['codigo'].split('.')[1],
                           'competencias': ['socioemocionales'], 'inserciones': ['civica_etica_integridad'],
                           'habilidades_socioemocionales': d['habilidades_socioemocionales']} for d in b['destrezas']],
            'indicadores': [{'codigo': None, 'descripcion': f"{i['habilidad']}: {i['descripcion']}", 'referencia': False} for i in b['indicadores']],
        })
    codes = [d['codigo'] for c in criterios for d in c['destrezas']]
    return {
        'id': 'civica_y_acompanamiento_integral', 'nombre': 'Cívica y Acompañamiento Integral en el Aula', 'prefijo': 'CAI',
        'objetivos': [], 'criterios': criterios, 'subniveles': sorted({c.split('.')[1] for c in codes}),
        'total_destrezas': len(codes), 'avisos': [], 'estado': 'completa',
    }


def main(pdf_path, cid, out_path):
    pdf = pdfplumber.open(pdf_path)
    civic_pages, map_pages, markers = [], [], []
    for pn, page in enumerate(pdf.pages):
        text = page.extract_text() or ''
        if re.search(r'\bCAI\.\d', text) or 'Bloque curricular' in text:
            civic_pages.append(pn)
            continue
        if civic_pages:
            continue
        page_markers, zones = layout(page)
        markers.extend((pn, top, name) for top, name in page_markers)
        if zones or (page_markers and re.search(r'\bO\.[A-Z]|\bOG\.', text)):
            map_pages.append(pn)
    markers.sort()

    def area_of(order):
        name = None
        for pn, top, n in markers:
            if (pn, top) <= order:
                name = n
        return name

    crits = collect(pdf, map_pages, 0, 'criterio')
    dests = collect(pdf, map_pages, 1, 'destreza')
    inds = collect(pdf, map_pages, 2, 'indicador')
    for icon in icons(pdf, map_pages):
        target = None
        for d in dests:
            if d['order'] <= icon['order']:
                target = d
        if target is not None:
            bucket = target.setdefault(icon['tipo'], [])
            if icon['valor'] not in bucket:
                bucket.append(icon['valor'])
    objs = [o for pn in map_pages for o in objectives(pdf, pn)]

    groups = OrderedDict()
    for kind, items in (('c', crits), ('d', dests), ('i', inds), ('o', objs)):
        for item in items:
            name = area_of(item['order'])
            if name:
                groups.setdefault(name, {'c': [], 'd': [], 'i': [], 'o': []})[kind].append(item)
    raw_ce = raw_codes(pdf, map_pages, 0, r'^EC\.')
    raw_ie = raw_codes(pdf, map_pages, 2, r'^I\.E\.')
    asignaturas = []
    for name, g in groups.items():
        if not g['c']:
            continue
        codes_c = {c['code'] for c in g['c']}
        objetivos = []
        for o in sorted(g['o'], key=lambda o: (o['codigo'].split('.')[1], int(o['codigo'].split('.')[-1]))):
            if all(x['codigo'] != o['codigo'] for x in objetivos):
                objetivos.append({'codigo': o['codigo'], 'descripcion': o['descripcion']})
        asignaturas.append(build_area(name, g['c'], g['d'], g['i'], objetivos,
                                      {r for r in raw_ce if 'CE' + r[2:] in codes_c},
                                      {r for r in raw_ie if any(i['code'] == 'I.' + r[4:] for i in g['i'])}))
    if civic_pages:
        asignaturas.append(civica_as_area(civica(pdf, civic_pages)))
    data = {
        'id': cid,
        'titulo': {'elemental': 'Currículo Priorizado de EGB Elemental (2.º a 4.º)', 'media': 'Currículo Priorizado de EGB Media (5.º a 7.º)',
                   'preparatoria': 'Currículo Priorizado de Preparatoria (1.º EGB)'}[cid],
        'fuente': f'Ministerio de Educación, Deporte y Cultura del Ecuador — {pdf_path.split("/")[-1]}',
        'origen': 'Extraído del PDF oficial con extract_priorizado_egb.py',
        'subniveles': {'1': 'Preparatoria', '2': 'Básica Elemental', '3': 'Básica Media'},
        'asignaturas': asignaturas,
        'avisos': [],
    }
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
