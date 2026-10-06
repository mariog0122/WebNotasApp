"""Extrae el mapa curricular de Alfabetización y Postalfabetización (MinEduc 2025) a JSON.

Uso: python3 extract_alfabetizacion.py <curriculo.pdf> <salida.json>
(requiere: pip install pdfplumber; salida usada: src/data/curriculos/alfabetizacion_postalfabetizacion_2025.json)
Los textos y códigos se copian literalmente del PDF oficial; no se generan ni se corrigen.
"""
import hashlib
import json
import re
import sys

import pdfplumber

COLS = [(59, 218, 'criterio'), (218, 377, 'destreza'), (377, 540, 'indicador')]
CODE_RX = {
    'criterio': re.compile(r'^(CE\.[AP]\.\d+)\.?$'),
    'destreza': re.compile(r'^([AP]\.(?:RS|CC|ET)\.\d+)\.?$'),
    'indicador': re.compile(r'^(I\.[AP]\.\d+\.\d+)\.?$'),
    'objetivo': re.compile(r'^(O\.[AP]\.\d+)\.?$'),
}
# Íconos de inserción curricular (hash MD5 del flujo de imagen, verificados visualmente).
INSERTION_ICONS = {
    '7de72010': 'socioemocional', '4b73a02a': 'socioemocional',
    'd445f0ba': 'desarrollo_sostenible', '01aa0bd6': 'desarrollo_sostenible',
    '2437ed92': 'seguridad_integral',
    'c756b228': 'civica_etica_integridad',
    '121d6d07': 'financiera', '255deed0': 'financiera',
    'ace7eccd': 'seguridad_vial',
}
HEADER_WORDS = {'Criterios', 'Destrezas', 'Indicadores', 'con', 'criterios', 'de', 'evaluación', 'desempeño'}


def lines_of(words):
    """Agrupa palabras en líneas por posición vertical."""
    lines = []
    for w in sorted(words, key=lambda w: (round(w['top']), w['x0'])):
        if lines and abs(lines[-1]['top'] - w['top']) < 3:
            lines[-1]['words'].append(w)
        else:
            lines.append({'top': w['top'], 'words': [w]})
    for line in lines:
        line['words'].sort(key=lambda w: w['x0'])
    return lines


def join_text(parts):
    text = ''
    for part in parts:
        if text.endswith('-') and part[:1].islower():
            text = text[:-1] + part
        elif text:
            text += ' ' + part
        else:
            text = part
    text = re.sub(r'\s+', ' ', text).strip()
    return text.replace('ﬁ', 'fi').replace('ﬂ', 'fl')


def collect(pdf, first, last, col_left, col_right, kind, header_bottom=None):
    """Devuelve [(orden, código, texto)] de una columna en el rango de páginas."""
    items = []
    current = None
    for pn in range(first, last + 1):
        page = pdf.pages[pn]
        words = [w for w in page.extract_words() if col_left - 2 <= w['x0'] < col_right - 2]
        # Encabezado de la tabla y número de página fuera.
        top_limit = 115 if header_bottom is None else header_bottom
        words = [w for w in words if w['top'] > top_limit and w['bottom'] < page.height - 40]
        for line in lines_of(words):
            first_word = line['words'][0]
            match = CODE_RX[kind].match(first_word['text'])
            consumed = 1
            if not match and len(line['words']) > 1:
                # El PDF a veces separa el código: "CE. P.9."
                match = CODE_RX[kind].match(first_word['text'] + line['words'][1]['text'])
                consumed = 2
            if match and first_word['x0'] < col_left + 25:
                current = {'order': (pn, line['top']), 'code': match.group(1), 'parts': []}
                items.append(current)
                rest = [w['text'] for w in line['words'][consumed:]]
            else:
                rest = [w['text'] for w in line['words']]
            if current is not None:
                current['parts'].extend(rest)
    return [{'order': it['order'], 'code': it['code'], 'text': join_text(it['parts'])} for it in items]


def objectives(pdf, page_index, prefix):
    page = pdf.pages[page_index]
    out = []
    for left, right in [(59, 300), (300, 540)]:
        words = [w for w in page.extract_words() if left - 2 <= w['x0'] < right - 2 and w['top'] > 140]
        current = None
        for line in lines_of(words):
            fw = line['words'][0]
            m = CODE_RX['objetivo'].match(fw['text'])
            if m and m.group(1).startswith(prefix):
                current = {'code': m.group(1), 'parts': [w['text'] for w in line['words'][1:]]}
                out.append(current)
            elif current:
                current['parts'].extend(w['text'] for w in line['words'])
    result = [{'codigo': o['code'], 'descripcion': join_text(o['parts'])} for o in out]
    return sorted(result, key=lambda o: int(o['codigo'].split('.')[-1]))


def insertion_icons(pdf, first, last):
    icons = []
    for pn in range(first, last + 1):
        for im in pdf.pages[pn].images:
            if COLS[1][0] <= im['x0'] < COLS[1][1] and im['width'] < 40:
                kind = INSERTION_ICONS.get(hashlib.md5(im['stream'].get_data()).hexdigest()[:8])
                if kind:
                    icons.append({'order': (pn, im['top']), 'kind': kind})
    return icons


def build_map(pdf, first, last, subnivel, nombre, objetivos):
    crits = collect(pdf, first, last, *COLS[0][:2], 'criterio')
    dests = collect(pdf, first, last, *COLS[1][:2], 'destreza')
    for icon in insertion_icons(pdf, first, last):
        target = None
        for d in dests:
            if d['order'] <= icon['order']:
                target = d
        if target is not None:
            target.setdefault('inserciones', [])
            if icon['kind'] not in target['inserciones']:
                target['inserciones'].append(icon['kind'])
    inds = collect(pdf, first, last, *COLS[2][:2], 'indicador')

    def owner(item):
        chosen = None
        for c in crits:
            if c['order'] <= item['order'] or (c['order'][0] == item['order'][0] and abs(c['order'][1] - item['order'][1]) < 4):
                chosen = c
        return chosen

    criterios = []
    for c in crits:
        criterios.append({'codigo': c['code'], 'descripcion': c['text'], 'destrezas': [], 'indicadores': []})
    by_code = {c['codigo']: c for c in criterios}
    for d in dests:
        o = owner(d)
        by_code[o['code']]['destrezas'].append({'codigo': d['code'], 'descripcion': d['text'], 'inserciones': d.get('inserciones', [])})
    for i in inds:
        o = owner(i)
        text = i['text']
        refs = re.findall(r'\(([^()]*(?:[IJS]\.\d)[^()]*)\)\.?\s*$', text)
        by_code[o['code']]['indicadores'].append({
            'codigo': i['code'],
            'descripcion': text,
            'perfil_salida': [r.strip() for r in re.split(r',\s*', refs[0])] if refs else [],
        })
    return {'subnivel': subnivel, 'nombre': nombre, 'objetivos': objetivos, 'criterios': criterios}


def civica(pdf, first=66, last=69):
    """Inserción de Educación Cívica, Ética e Integridad (hora de Acompañamiento Integral)."""
    bloques = []
    for pn in range(first, last + 1):
        page = pdf.pages[pn]
        words = [w for w in page.extract_words() if w['bottom'] < page.height - 40]
        lines = lines_of([w for w in words if w['top'] > 90])
        # Párrafos de bloque y criterio (encima de la tabla).
        header = [l for l in lines if l['words'][0]['x0'] < 70]
        text = join_text([w['text'] for l in header for w in l['words']])
        m = re.search(r'Bloque curricular (\d+):\s*(.*?)\s*Criterio de evaluación \d+:\s*(.*)$', text)
        if m:
            bloques.append({'numero': int(m.group(1)), 'titulo': m.group(2).rstrip('.'),
                            'criterio': m.group(3), 'destrezas': [], 'indicadores': []})
        bloque = bloques[-1]
        rows = []
        cols = [(60, 128), (128, 282), (282, 388), (388, 560)]
        col_lines = {i: lines_of([w for w in words if a - 2 <= w['x0'] < b - 2 and w['top'] > 160]) for i, (a, b) in enumerate(cols)}
        for line in col_lines[0]:
            code = line['words'][0]['text']
            if re.match(r'^CAI\.JA\.\d+\.\d+$', code):
                rows.append({'codigo': code, 'top': line['top']})
        for idx, row in enumerate(rows):
            bottom = rows[idx + 1]['top'] - 2 if idx + 1 < len(rows) else 10_000
            pick = lambda i: join_text([w['text'] for l in col_lines[i] if row['top'] - 3 <= l['top'] < bottom for w in l['words']])
            habilidades = [h.strip() for h in re.split(r'(?<=[a-zó])\s+(?=[A-ZÁÉÍÓÚ])', pick(2)) if h.strip()]
            bloque['destrezas'].append({'codigo': row['codigo'], 'descripcion': pick(1), 'habilidades_socioemocionales': habilidades})
        ind_text = join_text([w['text'] for l in col_lines[3] for w in l['words']])
        for name, desc in re.findall(r'([A-ZÁÉÍÓÚ][a-záéíóúñ]+(?: [a-záéíóúñ/]+){0,4}):\s*(.*?)(?=\s+[A-ZÁÉÍÓÚ][a-záéíóúñ]+(?: [a-záéíóúñ/]+){0,4}:|$)', ind_text):
            if 'INDICADORES' not in name:
                bloque['indicadores'].append({'habilidad': name, 'descripcion': desc})
    return {
        'nombre': 'Educación Cívica, Ética e Integridad',
        'objetivo': 'Ejercer su ciudadanía, interactuando de manera comprometida con su comunidad, evaluando críticamente su participación en la sociedad y promoviendo el cambio social y el ejercicio de derechos a través de acciones concretas, para su aprendizaje a lo largo de la vida, basadas en principios éticos y democráticos, mientras desarrolla habilidades emocionales para resolver desafíos cotidianos.',
        'bloques': bloques,
    }


def main(pdf_path, out_path):
    pdf = pdfplumber.open(pdf_path)
    # Índices de página (base 0) del PDF oficial 2025.
    alfa = build_map(pdf, 19, 39, 'alfabetizacion', 'Alfabetización', objectives(pdf, 18, 'O.A'))
    post = build_map(pdf, 41, 64, 'postalfabetizacion', 'Postalfabetización', objectives(pdf, 40, 'O.P'))
    data = {
        'id': 'alfabetizacion_postalfabetizacion_2025',
        'titulo': 'Currículo integrado de Alfabetización y Postalfabetización priorizado con énfasis en competencias (2025)',
        'fuente': 'Ministerio de Educación, Deporte y Cultura del Ecuador — contiene inserciones curriculares',
        'mapas': [alfa, post],
        'insercion_civica': civica(pdf),
    }
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
