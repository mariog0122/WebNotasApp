"""Normaliza currículos entregados en JSON (extracción externa) al formato que usa la app, con validación y
registro de correcciones. Hoy solo se usa para Adaptaciones curriculares de jóvenes y adultos, porque no se
cuenta con su PDF; Inicial, Preparatoria, Elemental y Media se extraen del PDF oficial (extract_inicial.py y
extract_priorizado_egb.py), que es la fuente preferida.

Uso: python3 normalize_priorizados.py <carpeta_json_origen> <carpeta_salida> [id ...]   (por defecto: adaptaciones_jovenes_adultos, superior, bachillerato)
Salida: src/data/curriculos/<id>.json

Los JSON de origen fueron generados por un extractor externo y traen errores sistemáticos. Este script:
  - nunca inventa texto curricular: solo mueve, limpia o descarta, y deja cada cambio en "avisos";
  - reconstruye los códigos de criterio de cada bloque a partir de sus indicadores (bloques fusionados);
  - separa la sección de Cívica y Acompañamiento Integral (CAI) que quedó pegada a la última asignatura;
  - marca como "incompleta" la asignatura que no trae destrezas suficientes para planificar.
"""
import json
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

SOURCES = {
    'inicial': 'Curriculo-priorizado-inicial.json',
    'preparatoria': 'Curriculo-Priorizado-Preparatoria.json',
    'elemental': 'Curriculo-Priorizado-Elemental.json',
    'media': 'Curriculo-Priorizado-EGB-Media.json',
    'adaptaciones_jovenes_adultos': 'Adaptaciones__curriculares__EGB_BS_BG_jovenes_adultos__y__adultos__mayores.json',
    'superior': 'Curriculo-Priorizado-Superior.json',
    'bachillerato': 'Curriculo_Bachillerato.json',
}
TITULOS = {
    'inicial': 'Currículo Priorizado de Educación Inicial (Inicial 2, 3-5 años)',
    'preparatoria': 'Currículo Priorizado de Preparatoria (1.º EGB)',
    'elemental': 'Currículo Priorizado de EGB Elemental (2.º a 4.º)',
    'media': 'Currículo Priorizado de EGB Media (5.º a 7.º)',
    'adaptaciones_jovenes_adultos': 'Adaptaciones curriculares EGB y BGU para personas jóvenes, adultas y adultas mayores',
    'superior': 'Currículo Priorizado de EGB Superior (8.º a 10.º)',
    'bachillerato': 'Currículo Priorizado de Bachillerato General Unificado (1.º a 3.º BGU)',
}
SUBNIVELES = {'1': 'Preparatoria', '2': 'Básica Elemental', '3': 'Básica Media', '4': 'Básica Superior', '5': 'Bachillerato'}
COMPETENCIAS = {'COM': 'comunicacionales', 'MAT': 'matematicas', 'DIG': 'digitales', 'SOC': 'socioemocionales'}
INSERCIONES = {
    'SOS': 'desarrollo_sostenible', 'CIV': 'civica_etica_integridad', 'EMO': 'socioemocional',
    'FIN': 'financiera', 'VIA': 'seguridad_vial', 'SEG': 'seguridad_integral',
}
# Prefijos con error evidente en el origen -> prefijo oficial (solo para destrezas en infinitivo).
SKILL_PREFIX_FIX = {'L': 'LL', 'ELL': 'LL', 'REF': 'EF', 'IEF': 'EF'}
# Indicadores que quedaron en la lista de destrezas -> prefijo oficial de indicador.
INDICATOR_PREFIX_FIX = {'ICN': 'I.CN', 'IEFL': 'I.EFL', 'I.CS': 'I.CS', 'IEF': 'I.EF'}

SKILL_RX = re.compile(r'^([A-Z]{1,4}(?:\.[A-Z]{1,2})?)\.(\d)\.(\d+)\.(\d+)$')
IND_RX = re.compile(r'^(?:Ref\.\s*)?I\.([A-Z]{1,4}(?:\.[A-Z]{1,2})?)\.(\d)\.(\d+)\.(\d+)$')
CRIT_RX = re.compile(r'^CE\.([A-Z]{1,4}(?:\.[A-Z]{1,2})?)\.(\d)\.(\d+)$')


def clean(text):
    text = re.sub(r'\s+', ' ', text or '').strip()
    # Números de página pegados al final ("… optimizarla. 82 82 82").
    text = re.sub(r'(?<=[.)])(\s+\d{1,3})+$', '', text)
    text = re.sub(r'(?<=[a-záéíóúñ])\s+\d{1,3}$', '', text)
    return text.strip()


def is_infinitive_sentence(text):
    first = (text.split() or [''])[0].lower().strip('¿¡"“')
    return bool(re.search(r'(ar|er|ir|arse|erse|irse)$', first))


def norm_indicator(code):
    code = code.strip()
    ref = code.startswith('Ref')
    base = re.sub(r'^Ref\.\s*', '', code)
    return (f'Ref. {base}' if ref else base), ref, base


def tags_of(item):
    tags = item.get('tags') or []
    return (sorted({COMPETENCIAS[t] for t in tags if t in COMPETENCIAS}),
            [INSERCIONES[t] for t in tags if t in INSERCIONES])


def dominant_prefix(codes):
    prefixes = Counter(SKILL_RX.match(c).group(1) for c in codes if SKILL_RX.match(c))
    return prefixes.most_common(1)[0][0] if prefixes else ''


def normalize_coded(data, cid):
    avisos = []
    asignaturas = OrderedDict()

    def asignatura(nombre, prefijo=''):
        if nombre not in asignaturas:
            asignaturas[nombre] = {'nombre': nombre, 'prefijo': prefijo, 'criterios': [], 'avisos': []}
        return asignaturas[nombre]

    for area in data['areas']:
        target = asignatura(area['area'])
        for block in area['criterios']:
            destrezas, indicadores, cai = [], [], []
            for raw in block.get('destrezas', []):
                code = (raw.get('code') or '').strip()
                text = clean(raw.get('text'))
                if not text:
                    continue
                if code.startswith('CAI.'):
                    cai.append((code, text, raw))
                    continue
                m = SKILL_RX.match(code)
                prefix = code.split('.')[0] if '.' in code else code
                if m and prefix not in SKILL_PREFIX_FIX and not code.startswith('I'):
                    if text[:1].islower() and destrezas:
                        destrezas[-1]['descripcion'] += ' ' + text
                        target['avisos'].append(f'{code}: fragmento unido a la destreza anterior.')
                        continue
                    comp, ins = tags_of(raw)
                    destrezas.append({'codigo': code, 'descripcion': text, 'subnivel': m.group(2), 'competencias': comp, 'inserciones': ins})
                    continue
                # Código irregular: decidir por la redacción si es destreza (infinitivo) o indicador (3.ª persona).
                head = 'I.CS' if code.startswith('I.CS.') else prefix
                rest = code[len(head) + 1:]
                if is_infinitive_sentence(text) and head in SKILL_PREFIX_FIX:
                    fixed = f'{SKILL_PREFIX_FIX[head]}.{rest}'
                    comp, ins = tags_of(raw)
                    destrezas.append({'codigo': fixed, 'descripcion': text, 'subnivel': fixed.split('.')[-3], 'competencias': comp, 'inserciones': ins})
                    target['avisos'].append(f'Código "{code}" corregido a "{fixed}" (prefijo con error en el archivo).')
                elif not is_infinitive_sentence(text) and head in INDICATOR_PREFIX_FIX:
                    fixed = f'{INDICATOR_PREFIX_FIX[head]}.{rest}'
                    indicadores.append({'codigo': fixed, 'descripcion': text, 'referencia': False})
                    target['avisos'].append(f'"{code}" era un indicador listado como destreza; se movió como {fixed}.')
                else:
                    target['avisos'].append(f'Se descartó "{code}": código no reconocible ({text[:60]}…).')
            for raw in block.get('indicadores', []):
                code = (raw.get('code') or '').strip()
                text = clean(raw.get('text'))
                if not code or not text:
                    continue  # encabezados de tabla ("Indicators for the performance criteria") u objetivos sueltos
                shown, ref, base = norm_indicator(code)
                if not IND_RX.match(code.replace('Ref.', 'Ref. ').replace('Ref.  ', 'Ref. ')) and not IND_RX.match(base):
                    target['avisos'].append(f'Indicador con código irregular conservado tal cual: {code}.')
                indicadores.append({'codigo': shown, 'descripcion': text, 'referencia': ref})

            header = (block.get('code') or '').strip()
            codes = []
            if CRIT_RX.match(header):
                codes.append(header)
            for ind in indicadores:
                im = IND_RX.match(ind['codigo'])
                if im:
                    c = f'CE.{im.group(1)}.{im.group(2)}.{im.group(3)}'
                    if c not in codes:
                        codes.append(c)
            codes.sort(key=lambda c: (c.split('.')[1], int(c.split('.')[-1])))
            if destrezas or indicadores:
                crit = {
                    'codigo': ' / '.join(codes) or header,
                    'codigos': codes,
                    'codigo_descripcion': header,
                    'descripcion': clean(block.get('text')),
                    'destrezas': destrezas,
                    'indicadores': indicadores,
                }
                if len(codes) > 1:
                    otros = [c for c in codes if c != header]
                    crit['nota'] = f'El archivo fuente fusionó este bloque con {", ".join(otros)}; solo trae la descripción de {header}.'
                target['criterios'].append(crit)

            if cai:
                civ = asignatura('Educación Cívica, Ética e Integridad (Acompañamiento Integral)', 'CAI')
                for code, text, raw in cai:
                    bloque = code.split('.')[2]
                    crit = next((c for c in civ['criterios'] if c['codigo_descripcion'] == f'Bloque {bloque}'), None)
                    if crit is None:
                        crit = {'codigo': None, 'codigos': [], 'codigo_descripcion': f'Bloque {bloque}',
                                'descripcion': f'Bloque curricular {bloque}', 'destrezas': [], 'indicadores': []}
                        civ['criterios'].append(crit)
                    comp, ins = tags_of(raw)
                    crit['destrezas'].append({'codigo': code, 'descripcion': text, 'subnivel': code.split('.')[1],
                                              'competencias': comp, 'inserciones': ins or ['civica_etica_integridad']})
                target['avisos'].append(f'{len(cai)} destrezas de Cívica (CAI) estaban dentro de "{area["area"]}"; se movieron a su propia asignatura.')

    # Prefijos con errata respecto del prefijo de la asignatura (RCS.H -> CS.H, ECS.F/S.F -> CS.F, CA -> ECA, E.G -> EG).
    for asig in asignaturas.values():
        main = dominant_prefix([d['codigo'] for c in asig['criterios'] for d in c['destrezas']])
        if not main or main == 'CAI':
            continue
        for crit in asig['criterios']:
            for d in crit['destrezas']:
                q = SKILL_RX.match(d['codigo']).group(1) if SKILL_RX.match(d['codigo']) else None
                if not q or q == main:
                    continue
                if main.endswith(q) or q.endswith(main) or q.replace('.', '') == main.replace('.', ''):
                    fixed = main + d['codigo'][len(q):]
                    asig['avisos'].append(f'Código "{d["codigo"]}" corregido a "{fixed}" (prefijo con error en el archivo).')
                    d['codigo'] = fixed

    # Destrezas repetidas en varios bloques: se conserva la primera aparición.
    for asig in asignaturas.values():
        seen = set()
        dropped = 0
        for crit in asig['criterios']:
            unique = []
            for d in crit['destrezas']:
                if d['codigo'] in seen:
                    dropped += 1
                    continue
                seen.add(d['codigo'])
                unique.append(d)
            crit['destrezas'] = unique
        asig['criterios'] = [c for c in asig['criterios'] if c['destrezas']]
        if dropped:
            asig['avisos'].append(f'{dropped} destrezas aparecían repetidas en más de un criterio; se planifican una sola vez.')
        all_codes = [d['codigo'] for c in asig['criterios'] for d in c['destrezas']]
        asig['prefijo'] = asig['prefijo'] or dominant_prefix(all_codes)
        asig['id'] = re.sub(r'[^a-z]+', '_', asig['nombre'].lower().translate(str.maketrans('áéíóúñ', 'aeioun'))).strip('_')
        asig['subniveles'] = sorted({d['subnivel'] for c in asig['criterios'] for d in c['destrezas']})
        asig['total_destrezas'] = len(all_codes)
        asig['estado'] = 'incompleta' if len(all_codes) < 5 else ('con_avisos' if asig['avisos'] or any('nota' in c for c in asig['criterios']) else 'completa')
        if asig['estado'] == 'incompleta':
            asig['avisos'].insert(0, f'El archivo solo trae {len(all_codes)} destreza(s) de esta asignatura: no se puede planificar con él.')

    # Objetivos por asignatura según su prefijo (O.LL -> LL).
    for obj in data.get('objetivos', []):
        code, text = (obj.get('code') or '').strip(), clean(obj.get('text'))
        m = re.match(r'^O\.([A-Z]{1,4}(?:\.[A-Z]{1,2})?)\.(\d)\.(\d+)$', code)
        if not m or not text:
            continue
        for asig in asignaturas.values():
            prefixes = {SKILL_RX.match(d['codigo']).group(1) for c in asig['criterios'] for d in c['destrezas'] if SKILL_RX.match(d['codigo'])}
            if m.group(1) in prefixes:
                asig.setdefault('objetivos', [])
                if all(o['codigo'] != code for o in asig['objetivos']):
                    asig['objetivos'].append({'codigo': code, 'descripcion': text})
    for asig in asignaturas.values():
        asig.setdefault('objetivos', [])
    return list(asignaturas.values()), avisos


def normalize_inicial(data):
    """Inicial no tiene códigos oficiales de destreza: se organiza por ámbito y edad, sin códigos."""
    ambitos = []
    for area in data['areas']:
        objetivos, destrezas, avisos = [], [], []
        for block in area['criterios']:
            text = clean(block.get('text'))
            if text and 'Objetivo de aprendizaje del ámbito' not in text and text not in objetivos:
                objetivos.append(text)
            for raw in block.get('destrezas', []):
                t = clean(raw.get('text'))
                if not t:
                    continue
                if t[:1].islower() and destrezas:
                    destrezas[-1]['descripcion'] += ' ' + t
                    continue
                edad = '3_4' if '3-4' in (raw.get('grado') or '') else '4_5'
                if any(d['descripcion'] == t and d['edad'] == edad for d in destrezas):
                    continue
                comp, ins = tags_of(raw)
                destrezas.append({'codigo': None, 'edad': edad, 'descripcion': t, 'competencias': comp, 'inserciones': ins})
        avisos.append('Los códigos del archivo (D.IN2…, OBJ.IN2…) no son oficiales y se repetían; se omiten. Las destrezas se agrupan por ámbito y edad.')
        ambitos.append({
            'id': re.sub(r'[^a-z]+', '_', area['area'].lower().translate(str.maketrans('áéíóúñ', 'aeioun'))).strip('_'),
            'nombre': area['area'],
            'objetivos': objetivos,
            'destrezas': destrezas,
            'avisos': avisos,
        })
    return ambitos


def main(src_dir, out_dir, ids=None):
    src_dir, out_dir = Path(src_dir), Path(out_dir)
    for cid, filename in SOURCES.items():
        if cid not in (ids or ['adaptaciones_jovenes_adultos', 'superior', 'bachillerato']):
            continue
        path = next(src_dir.glob(f'*{filename}'))
        data = json.loads(path.read_text(encoding='utf-8'))
        base = {
            'id': cid,
            'titulo': TITULOS[cid],
            'fuente': data.get('fuente', ''),
            'nivel': data.get('nivel', ''),
            'subnivel': data.get('subnivel', ''),
            'grados': data.get('grados', []),
            'origen': 'JSON entregado por la institución (extracción externa); normalizado y validado por normalize_priorizados.py',
        }
        if cid == 'inicial':
            base['edades'] = [{'id': '3_4', 'nombre': '3 a 4 años'}, {'id': '4_5', 'nombre': '4 a 5 años'}]
            base['ambitos'] = normalize_inicial(data)
        else:
            base['subniveles'] = SUBNIVELES
            base['asignaturas'], base['avisos'] = normalize_coded(data, cid)
        (out_dir / f'{cid}.json').write_text(json.dumps(base, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3:] or None)
