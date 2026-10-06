"""Extrae los mapas curriculares del Currículo Nacional de Atención y Educación de la Primera Infancia (0-3 años).

Uso: python3 extract_primera_infancia.py <curriculo.pdf> <salida.json>
(requiere: pip install pdfplumber; salida usada: src/data/curriculos/primera_infancia_0_3.json)
El documento oficial NO asigna códigos a las destrezas: aquí se guardan con `codigo: null`
y un identificador interno `ref` (ámbito.fila.edad) solo para enlazar datos, nunca para imprimirlo como código oficial.
"""
import json
import re
import sys
import unicodedata

import pdfplumber

EDADES = [
    ('0_6m', 'Hasta 6 meses'),
    ('6m_1a', 'De 6 meses a 1 año'),
    ('1a_2a', 'De 1 a 2 años'),
    ('2a_3a', 'De 2 a 3 años'),
]
# Ejes de desarrollo y aprendizaje (sección 5.3 del currículo).
EJES = {
    'Vinculación emocional y social': 'Desarrollo personal y social',
    'Cívica y acompañamiento integral': 'Desarrollo personal y social',
    'Descubrimiento del medio natural y cultural': 'Descubrimiento natural y cultural',
    'Manifestación del lenguaje verbal y no verbal': 'Expresión y comunicación',
    'Exploración del cuerpo y motricidad': 'Expresión y comunicación',
}


def clean(text):
    text = (text or '').replace('ﬁ', 'fi').replace('ﬂ', 'fl')
    text = re.sub(r'-\n(?=[a-záéíóúñ])', '', text)
    return text


def flat(text):
    return re.sub(r'\s+', ' ', clean(text)).strip()


def split_destrezas(cell):
    """Una celda puede traer dos destrezas en párrafos distintos."""
    text = clean(cell).strip()
    if not text:
        return []
    parts = re.split(r'(?<=\.)\s*\n(?=[A-ZÁÉÍÓÚ])', text)
    return [re.sub(r'\s+', ' ', p).strip() for p in parts if p.strip()]


def slug(name):
    base = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z]+', '_', base).strip('_')


def main(pdf_path, out_path):
    pdf = pdfplumber.open(pdf_path)
    ambitos = []
    current = None
    objective = None
    for pn in range(24, 40):
        for table in pdf.pages[pn].extract_tables():
            for row in table:
                cells = [c or '' for c in row]
                first = flat(cells[0])
                if not any(flat(c) for c in cells):
                    continue
                if first.startswith('Ámbito'):
                    name = first.replace('Ámbito', '', 1).strip()
                    current = {'id': slug(name), 'nombre': name, 'eje': EJES.get(name, ''), 'objetivo': '', 'objetivos_aprendizaje': []}
                    ambitos.append(current)
                    objective = None
                    continue
                if first.startswith('Objetivo:'):
                    current['objetivo'] = first.replace('Objetivo:', '', 1).strip()
                    continue
                if first.startswith('Objetivos de aprendizaje'):
                    continue
                if first:
                    objective = {'descripcion': first, 'filas': []}
                    current['objetivos_aprendizaje'].append(objective)
                fila_n = len(objective['filas']) + 1
                o_n = len(current['objetivos_aprendizaje'])
                fila = {}
                for (age_id, _), cell in zip(EDADES, cells[1:5]):
                    fila[age_id] = [
                        {'codigo': None, 'ref': f"PI.{current['id']}.{o_n}.{fila_n}.{age_id}.{k + 1}", 'descripcion': d}
                        for k, d in enumerate(split_destrezas(cell))
                    ]
                objective['filas'].append(fila)
    data = {
        'id': 'primera_infancia_0_3',
        'titulo': 'Currículo Nacional de Atención y Educación de la Primera Infancia (0-3 años)',
        'fuente': 'Ministerio de Educación, Deporte y Cultura del Ecuador — contiene inserciones curriculares',
        'nota_codigos': 'El currículo oficial no asigna códigos a las destrezas de 0-3 años; se identifican por ámbito, objetivo de aprendizaje y rango de edad.',
        'edades': [{'id': i, 'nombre': n} for i, n in EDADES],
        'ambitos': ambitos,
    }
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
