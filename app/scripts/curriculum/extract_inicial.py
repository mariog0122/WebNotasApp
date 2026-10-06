"""Extrae los mapas curriculares del Currículo Priorizado de Educación Inicial (Inicial 2, 3-5 años).

Uso: python3 extract_inicial.py <curriculo.pdf> <salida.json>
(requiere: pip install pdfplumber; salida usada: src/data/curriculos/inicial.json)

El documento oficial NO asigna códigos a las destrezas: se guardan con `codigo: null`, organizadas por
ámbito, objetivo de aprendizaje y edad (3-4 / 4-5 años). Habilidades (HC, HLM, HD, HS) e inserciones se
leen de los íconos de cada celda.
"""
import hashlib
import json
import re
import sys
import unicodedata

import pdfplumber

EDADES = [('3_4', '3 a 4 años'), ('4_5', '4 a 5 años')]
HABILIDADES = {'HC': 'comunicacionales', 'HLM': 'matematicas', 'HD': 'digitales', 'HS': 'socioemocionales'}
# hash MD5 del flujo de imagen -> (tipo, valor); verificados visualmente.
ICONS = {
    '464d2b4b': ('competencias', 'comunicacionales'),   # HC
    'e8c8d906': ('competencias', 'socioemocionales'),   # HS
    'a18c40ed': ('competencias', 'matematicas'),        # HLM
    '5da980d8': ('competencias', 'digitales'),          # HD
    '0d1d5c1c': ('inserciones', 'socioemocional'),
    '7a8dfb8c': ('inserciones', 'desarrollo_sostenible'),
    '0c7b8335': ('inserciones', 'civica_etica_integridad'),
    'd10a8bdd': ('inserciones', 'seguridad_integral'),
    '304b3a3d': ('inserciones', 'seguridad_integral'),
    '9a033c21': ('inserciones', 'seguridad_vial'),
    'c24a3453': ('inserciones', 'financiera'),
}


def clean(text):
    text = (text or '').replace('ﬁ', 'fi').replace('ﬂ', 'fl')
    text = re.sub(r'-\n(?=[a-záéíóúñ])', '', text)
    return re.sub(r'\s+', ' ', text).strip()


def slug(name):
    base = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z]+', '_', base).strip('_')


def cell_icons(page, bbox):
    comp, ins = [], []
    for im in page.images:
        if bbox[0] - 2 <= im['x0'] and im['x1'] <= bbox[2] + 2 and bbox[1] - 2 <= im['top'] and im['bottom'] <= bbox[3] + 2:
            kind = ICONS.get(hashlib.md5(im['stream'].get_data()).hexdigest()[:8])
            if kind:
                bucket = comp if kind[0] == 'competencias' else ins
                if kind[1] not in bucket:
                    bucket.append(kind[1])
    return comp, ins


def main(pdf_path, out_path):
    pdf = pdfplumber.open(pdf_path)
    ambitos, current, objective = [], None, None
    for pn, page in enumerate(pdf.pages):
        text = page.extract_text() or ''
        if 'Destrezas de 3 a 4 años' not in text:
            continue
        for table in page.find_tables():
            rows = table.rows
            data = table.extract()
            for row, cells in zip(rows, data):
                cells = [c or '' for c in cells]
                first = clean(cells[0])
                if not any(clean(c) for c in cells):
                    continue
                if first.startswith('Ámbito'):
                    name = first.replace('Ámbito', '', 1).strip()
                    current = {'id': slug(name), 'nombre': name, 'objetivo_nivel': '', 'objetivos': [], 'destrezas': []}
                    ambitos.append(current)
                    objective = None
                    continue
                if first.startswith('Objetivo del nivel:'):
                    current['objetivo_nivel'] = first.replace('Objetivo del nivel:', '', 1).strip()
                    continue
                if first.startswith('Objetivos de aprendizaje'):
                    continue
                if current is None or len(cells) < 3:
                    continue
                if first:
                    objective = first
                    current['objetivos'].append(first)
                for (age_id, _), cell_text, bbox in zip(EDADES, cells[1:3], row.cells[1:3]):
                    desc = clean(cell_text)
                    if not desc or bbox is None:
                        continue
                    comp, ins = cell_icons(page, bbox)
                    current['destrezas'].append({
                        'codigo': None, 'edad': age_id, 'objetivo': objective, 'descripcion': desc,
                        'competencias': comp, 'inserciones': ins, 'pagina': pn + 1,
                    })
    for a in ambitos:
        a['avisos'] = []
    data = {
        'id': 'inicial',
        'titulo': 'Currículo Priorizado de Educación Inicial (Inicial 2, 3-5 años)',
        'fuente': f'Ministerio de Educación, Deporte y Cultura del Ecuador — {pdf_path.split("/")[-1]}',
        'origen': 'Extraído del PDF oficial con extract_inicial.py',
        'nota_codigos': 'El currículo de Educación Inicial no asigna códigos a sus destrezas; se identifican por ámbito, objetivo de aprendizaje y edad.',
        'edades': [{'id': i, 'nombre': n} for i, n in EDADES],
        'ambitos': ambitos,
    }
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
