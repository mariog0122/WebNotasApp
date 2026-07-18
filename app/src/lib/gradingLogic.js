/**
 * Lógica pura para el cálculo de promedios escolares (WebNotas)
 * Independiente de los componentes Vue para permitir Testing Unitario.
 */

export function isProjectDefinition(def) {
    return def.category === 'SUMATIVA' && String(def.name || '').toLowerCase().includes('proyecto');
}

export function getProjectValue(projectSettingsSubjects, projectSubjectGrades, studentId, subjectId) {
    if (!subjectId) return null;
    if (!projectSettingsSubjects.has(subjectId)) return null;

    // Compute average from selected subjects
    const selectedSubjectIds = Array.from(projectSettingsSubjects);
    if (selectedSubjectIds.length === 0) return null;

    let sum = 0;
    let count = 0;
    selectedSubjectIds.forEach(subId => {
        const val = projectSubjectGrades?.[studentId]?.[subId];
        const parsed = parseFloat(val);
        if (!isNaN(parsed)) {
            sum += parsed;
            count++;
        }
    });

    if (count === 0) return null;
    return sum / count;
}

/**
 * Calculates student averages based on the defined columns and grades.
 * 
 * @param {Object} studentGrades Map of definition_id -> score for the student
 * @param {Array} gradeDefinitions Array of all grade definitions for the course subject
 * @param {Number|null} projectValue Optional precalculated project value for SUMATIVA
 * 
 * @returns {Object} Averages breakdown
 */
export function calculateStudentAverages(studentGrades, gradeDefinitions, projectValue = null) {
    const getAvg = (categories) => {
        const categoryDefs = gradeDefinitions.filter(d => categories.includes(d.category));
        if (categoryDefs.length === 0) return null;
        let sum = 0, count = 0;

        categoryDefs.forEach(d => {
            let val = parseFloat(studentGrades[d.id]);

            if (categories.includes('SUMATIVA') && isProjectDefinition(d)) {
                if (projectValue !== null) val = projectValue;
            }

            if (!isNaN(val)) {
                sum += val;
                count++;
            }
        });

        return count > 0 ? (sum / count) : null;
    };

    const avgIndividual = getAvg(['INDIVIDUAL']);
    const avgGroup = getAvg(['GRUPAL']);
    const avgRefuerzo = getAvg(['REFUERZO']);
    const avgSum = getAvg(['SUMATIVA']);

    const formativeParts = [avgIndividual, avgGroup, avgRefuerzo].filter(v => v !== null && v !== undefined && !isNaN(v));

    const avgFormative = formativeParts.length > 0
        ? (formativeParts.reduce((s, v) => s + v, 0) / formativeParts.length)
        : null;

    const weightedFormative = avgFormative !== null ? (avgFormative * 0.70) : null;
    const weightedSummative = avgSum !== null ? (avgSum * 0.30) : null;

    const total = (weightedFormative !== null && weightedSummative !== null)
        ? (weightedFormative + weightedSummative)
        : null;

    return {
        avgIndividual,
        avgGroup,
        formative: avgFormative,
        avgSum,
        weightedFormative,
        weightedSummative,
        total
    };
}
