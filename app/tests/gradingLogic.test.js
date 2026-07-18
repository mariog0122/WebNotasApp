import { describe, it, expect } from 'vitest'
import {
    isProjectDefinition,
    getProjectValue,
    calculateStudentAverages
} from '../src/lib/gradingLogic'

describe('gradingLogic.js', () => {
    describe('isProjectDefinition', () => {
        it('debería retornar true para definiciones SUMATIVA con "proyecto" en el nombre', () => {
            const def = { category: 'SUMATIVA', name: 'Proyecto Interdisciplinario' }
            expect(isProjectDefinition(def)).toBe(true)
        })

        it('debería retornar false para definiciones no SUMATIVA', () => {
            const def = { category: 'INDIVIDUAL', name: 'Proyectos 1' }
            expect(isProjectDefinition(def)).toBe(false)
        })

        it('debería retornar false para SUMATIVA sin "proyecto" en el nombre', () => {
            const def = { category: 'SUMATIVA', name: 'Examen del Trimestre' }
            expect(isProjectDefinition(def)).toBe(false)
        })
    })

    describe('getProjectValue', () => {
        it('debería calcular el promedio de notas de proyecto correctamente', () => {
            const projectSettingsSubjects = new Set(['sub1', 'sub2', 'sub3'])
            const projectSubjectGrades = {
                'student1': { 'sub1': 8.5, 'sub2': 9.0, 'sub3': 7.5 }
            }

            const result = getProjectValue(projectSettingsSubjects, projectSubjectGrades, 'student1', 'sub1')

            expect(result).toBe(8.333333333333334) // (8.5 + 9.0 + 7.5) / 3
        })

        it('debería retornar null si no hay subject_ids seleccionados', () => {
            const projectSettingsSubjects = new Set()
            const projectSubjectGrades = { 'student1': { 'sub1': 8.5 } }

            const result = getProjectValue(projectSettingsSubjects, projectSubjectGrades, 'student1')

            expect(result).toBeNull()
        })

        it('debería retornar null si el subjectId no está en projectSettingsSubjects', () => {
            const projectSettingsSubjects = new Set(['sub1'])
            const projectSubjectGrades = {}

            const result = getProjectValue(projectSettingsSubjects, projectSubjectGrades, 'student1', 'sub2')

            expect(result).toBeNull()
        })

        it('debería ignorar valores NaN en el cálculo', () => {
            const projectSettingsSubjects = new Set(['sub1', 'sub2'])
            const projectSubjectGrades = {
                'student1': { 'sub1': 8.0, 'sub2': 'inválido' }
            }

            const result = getProjectValue(projectSettingsSubjects, projectSubjectGrades, 'student1', 'sub1')

            expect(result).toBe(8.0)
        })
    })

    describe('calculateStudentAverages', () => {
        it('debería calcular promedios correctamente', () => {
            const studentGrades = {
                'def1': 8.0, // INDIVIDUAL
                'def2': 9.0, // INDIVIDUAL
                'def3': 7.5, // GRUPAL
                'def4': 8.5, // REFUERZO
                'def5': 9.5, // SUMATIVA
            }

            const gradeDefinitions = [
                { id: 'def1', category: 'INDIVIDUAL' },
                { id: 'def2', category: 'INDIVIDUAL' },
                { id: 'def3', category: 'GRUPAL' },
                { id: 'def4', category: 'REFUERZO' },
                { id: 'def5', category: 'SUMATIVA' },
            ]

            const result = calculateStudentAverages(studentGrades, gradeDefinitions)

            expect(result.avgIndividual).toBe(8.5) // (8.0 + 9.0) / 2
            expect(result.avgGroup).toBe(7.5)
            expect(result.avgSum).toBe(9.5)
            expect(result.formative).toBeCloseTo(8.166, 2) // (8.5 + 7.5 + 8.5) / 3
            expect(result.weightedFormative).toBeCloseTo(5.716, 2) // 8.166 * 0.70
            expect(result.weightedSummative).toBeCloseTo(2.85, 2) // 9.5 * 0.30
            expect(result.total).toBeCloseTo(8.566, 2) // 5.716 + 2.85
        })

        it('debería retornar null para totales si no hay datos', () => {
            const result = calculateStudentAverages({}, [])

            expect(result.avgIndividual).toBeNull()
            expect(result.avgGroup).toBeNull()
            expect(result.formative).toBeNull()
            expect(result.avgSum).toBeNull()
            expect(result.total).toBeNull()
        })

        it('debería usar projectValue para SUMATIVA si es proyecto', () => {
            const studentGrades = {
                'def1': 8.0, // SUMATIVA - Proyecto
            }

            const gradeDefinitions = [
                { id: 'def1', category: 'SUMATIVA', name: 'Proyecto Interdisciplinario' },
            ]

            const result = calculateStudentAverages(studentGrades, gradeDefinitions, 9.0)

            expect(result.avgSum).toBe(9.0) // Debería usar projectValue
        })

        it('debería manejar calificaciones faltantes', () => {
            const studentGrades = {
                'def1': 8.0, // INDIVIDUAL
                // def2 faltante
            }

            const gradeDefinitions = [
                { id: 'def1', category: 'INDIVIDUAL' },
                { id: 'def2', category: 'INDIVIDUAL' },
            ]

            const result = calculateStudentAverages(studentGrades, gradeDefinitions)

            expect(result.avgIndividual).toBe(8.0) // Solo cuenta def1
        })
    })
})
