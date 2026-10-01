import { describe, it, expect } from 'vitest'
import {
  computeFinalAnnual,
  computeFinalObservation,
  computeTrimesterObservation,
  truncate2
} from '../src/lib/reporting'

describe('Reglas de Negocio LOEI Ecuador - Cálculos Finales y Supletorios', () => {
  describe('computeFinalAnnual', () => {
    it('mantiene la nota original si el promedio es mayor o igual a 7.00', () => {
      expect(computeFinalAnnual(7.00, null)).toBe(7.00)
      expect(computeFinalAnnual(8.50, null)).toBe(8.50)
      expect(computeFinalAnnual(10.00, 9.5)).toBe(10.00)
    })

    it('devuelve el promedio sin modificar si no se rindió supletorio (sVal nulo o vacío)', () => {
      expect(computeFinalAnnual(6.50, null)).toBe(6.50)
      expect(computeFinalAnnual(5.20, '')).toBe(5.20)
      expect(computeFinalAnnual(4.50, undefined)).toBe(4.50)
    })

    it('impide rendir supletorio y no altera la nota si p es menor a 4.01 (reprobación directa)', () => {
      expect(computeFinalAnnual(4.00, 10.00)).toBe(4.00)
      expect(computeFinalAnnual(3.50, 8.00)).toBe(3.50)
      expect(computeFinalAnnual(2.00, 9.00)).toBe(2.00)
      expect(computeFinalAnnual(0, 10.00)).toBe(0)
    })

    it('permite supletorio en el rango legal 4.01 a 6.99 y topa la nota final a 7.00 al aprobar', () => {
      // Caso frontera inferior exacto
      expect(computeFinalAnnual(4.01, 7.00)).toBe(7)
      expect(computeFinalAnnual(4.01, 9.50)).toBe(7)
      expect(computeFinalAnnual(4.01, 10.00)).toBe(7)

      // Caso intermedio
      expect(computeFinalAnnual(5.50, 8.00)).toBe(7)
      expect(computeFinalAnnual(6.00, 7.25)).toBe(7)

      // Caso frontera superior
      expect(computeFinalAnnual(6.99, 7.00)).toBe(7)
      expect(computeFinalAnnual(6.99, 9.00)).toBe(7)
    })

    it('mantiene el promedio reprobado original si el supletorio no alcanza 7.00', () => {
      expect(computeFinalAnnual(4.50, 6.99)).toBe(4.50)
      expect(computeFinalAnnual(5.00, 5.00)).toBe(5.00)
      expect(computeFinalAnnual(6.00, 6.50)).toBe(6.00)
    })

    it('maneja valores inválidos o nulos devolviendo null', () => {
      expect(computeFinalAnnual(null, 8)).toBeNull()
      expect(computeFinalAnnual(undefined, 8)).toBeNull()
      expect(computeFinalAnnual(NaN, 8)).toBeNull()
    })
  })

  describe('computeFinalObservation', () => {
    it('indica PROMOVIDO para promedio aprobado sin supletorio', () => {
      const finalAnnual = computeFinalAnnual(8.25, null)
      expect(computeFinalObservation(8.25, null, finalAnnual)).toBe('PROMOVIDO')
    })

    it('advierte dejar en blanco casillero supletorio si p >= 7 pero se ingresó nota de supletorio', () => {
      const finalAnnual = computeFinalAnnual(7.50, 8.0)
      expect(computeFinalObservation(7.50, 8.0, finalAnnual)).toBe('DEJE EN BLANCO EL CASILLERO SUPLETORIO')
    })

    it('marca reprobación directa si el promedio anual es menor a 4.01', () => {
      const p = 4.00
      const finalAnnual = computeFinalAnnual(p, null)
      expect(computeFinalObservation(p, null, finalAnnual)).toBe('NO PUEDE RENDIR SUPLETORIO;REPRUEBA EL GRADO')

      // Aun si alguien colocó una nota en el casillero
      expect(computeFinalObservation(p, 8.0, finalAnnual)).toBe('NO PUEDE RENDIR SUPLETORIO;REPRUEBA EL GRADO')
    })

    it('marca SUPLETORIO cuando el alumno está en rango 4.01 a 6.99 y aún no rinde', () => {
      expect(computeFinalObservation(4.01, null, 4.01)).toBe('SUPLETORIO')
      expect(computeFinalObservation(5.50, null, 5.50)).toBe('SUPLETORIO')
      expect(computeFinalObservation(6.99, null, 6.99)).toBe('SUPLETORIO')
    })

    it('indica PROMOVIDO cuando el supletorio es aprobado (sVal >= 7, finalAnnual = 7)', () => {
      const p = 5.20
      const s = 7.50
      const finalAnnual = computeFinalAnnual(p, s)
      expect(finalAnnual).toBe(7)
      expect(computeFinalObservation(p, s, finalAnnual)).toBe('PROMOVIDO')
    })

    it('indica NO PROMOVIDO cuando el supletorio es reprobado (sVal < 7)', () => {
      const p = 5.20
      const s = 6.00
      const finalAnnual = computeFinalAnnual(p, s)
      expect(finalAnnual).toBe(5.20)
      expect(computeFinalObservation(p, s, finalAnnual)).toBe('NO PROMOVIDO')
    })
  })

  describe('computeTrimesterObservation', () => {
    it('retorna APROBADO para notas parciales de trimestre mayores o iguales a 7.00', () => {
      expect(computeTrimesterObservation(7.00)).toBe('APROBADO')
      expect(computeTrimesterObservation(8.50)).toBe('APROBADO')
      expect(computeTrimesterObservation(10.00)).toBe('APROBADO')
    })

    it('retorna REQUIERE REFUERZO para notas menores a 7.00 sin declarar supletorios prematuros', () => {
      expect(computeTrimesterObservation(6.99)).toBe('REQUIERE REFUERZO')
      expect(computeTrimesterObservation(5.00)).toBe('REQUIERE REFUERZO')
      expect(computeTrimesterObservation(3.50)).toBe('REQUIERE REFUERZO')
      expect(computeTrimesterObservation(0)).toBe('REQUIERE REFUERZO')
    })

    it('retorna cadena vacía para valores nulos o inválidos', () => {
      expect(computeTrimesterObservation(null)).toBe('')
      expect(computeTrimesterObservation(undefined)).toBe('')
      expect(computeTrimesterObservation(NaN)).toBe('')
    })
  })

  describe('truncate2', () => {
    it('trunca a 2 decimales sin redondear hacia arriba', () => {
      expect(truncate2(7.899)).toBe(7.89)
      expect(truncate2(4.019)).toBe(4.01)
      expect(truncate2(9.999)).toBe(9.99)
      expect(truncate2(null)).toBeNull()
    })
  })
})
