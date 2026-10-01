/**
 * LOGREVA — Intelligence Pinia Store
 * Gestiona el estado reactivo del Teacher Cockpit, sesiones diagnósticas,
 * agrupamiento pedagógico y tutoría socrática.
 */

import { defineStore } from 'pinia'
import { intelligenceService } from '../services/intelligenceService'
import { evaluateSocraticInteraction } from '../utils/pedagogyEngine'
import { SocraticService } from '../services/socraticService'

export const useIntelligenceStore = defineStore('intelligence', {
  state: () => ({
    isLoading: false,
    selectedCourseId: null,
    selectedSubjectId: null,
    selectedSubject: 'Matemática',
    coursesList: [],
    subjectsList: [],
    cockpitData: null,
    loadError: '',
    
    // Sesión de Diagnóstico del Estudiante
    currentSession: {
      isActive: false,
      items: [],
      currentIndex: 0,
      userAnswers: {},
      sessionResults: null,
      score: 0
    },

    // Tutor Socrático
    socraticDrawer: {
      isOpen: false,
      currentItemContext: null,
      hintLevel: 0,
      messages: []
    },

    // Feature Flag institucional
    isFeatureEnabled: false
  }),

  getters: {
    radarOverview: (state) => state.cockpitData?.radarStats || [],
    pedagogicalGroups: (state) => state.cockpitData?.pedagogicalGroups || [],
    currentDiagnosticItem: (state) => {
      const { items, currentIndex } = state.currentSession
      return items[currentIndex] || null
    },
    isLastDiagnosticItem: (state) => {
      const { items, currentIndex } = state.currentSession
      return currentIndex >= items.length - 1
    }
  },

  actions: {
    /**
     * Carga los cursos reales de la institución activa
     */
    async loadInstitutionCourses(schoolId) {
      if (!schoolId) return
      this.loadError = ''
      try {
        const courses = await intelligenceService.getCourses(schoolId)
        this.coursesList = courses
        if (courses.length > 0 && !this.selectedCourseId) {
          this.selectedCourseId = courses[0].id
          await this.loadCourseSubjects(courses[0].id, schoolId)
        }
      } catch (err) {
        console.error('Error cargando cursos en store:', err)
        this.coursesList = []
        this.loadError = 'No se pudieron cargar los cursos de la institución.'
      }
    },

    /**
     * Carga las asignaturas reales de un curso
     */
    async loadCourseSubjects(courseId, schoolId) {
      if (!courseId) {
        this.subjectsList = []
        return
      }
      try {
        const subs = await intelligenceService.getSubjectsForCourse(courseId, schoolId)
        this.subjectsList = subs
        if (subs.length > 0) {
          this.selectedSubjectId = subs[0].course_subject_id
          this.selectedSubject = subs[0].name
        }
      } catch (err) {
        console.error('Error cargando materias en store:', err)
        this.subjectsList = []
        this.loadError = 'No se pudieron cargar las asignaturas del curso.'
      }
    },

    /**
     * Carga los datos del Cockpit docente para un curso con datos reales
     */
    async loadCockpit(courseId = null, schoolId = null, subjectName = null) {
      this.isLoading = true
      this.loadError = ''
      try {
        const activeCourse = courseId || this.selectedCourseId
        const activeSubject = subjectName || this.selectedSubject || 'Matemática'
        const data = await intelligenceService.getTeacherCockpitData(activeCourse, schoolId, activeSubject)
        this.cockpitData = data
      } catch (err) {
        console.error('Error cargando cockpit de inteligencia:', err)
        this.cockpitData = null
        this.loadError = 'No se pudo cargar la información del Panel Docente.'
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Sincroniza calificaciones reales hacia el grafo competencial
     */
    async syncFromGrades(schoolId, courseId, courseSubjectId) {
      this.isLoading = true
      try {
        const res = await intelligenceService.syncCourseGapsFromGrades({
          schoolId,
          courseId,
          courseSubjectId
        })
        await this.loadCockpit(courseId, schoolId, this.selectedSubject)
        return res
      } catch (err) {
        console.error('Error sincronizando notas:', err)
        throw err
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Inicia una sesión diagnóstica adaptativa
     */
    async startDiagnosticSession(subject, schoolId, gradeLevel) {
      this.isLoading = true
      try {
        const items = await intelligenceService.getDiagnosticItems(subject, { schoolId, gradeLevel })
        this.currentSession = {
          isActive: true,
          items,
          currentIndex: 0,
          userAnswers: {},
          sessionResults: null,
          score: 0
        }
      } catch (err) {
        console.error('Error iniciando sesión diagnóstica:', err)
        this.currentSession = {
          isActive: false,
          items: [],
          currentIndex: 0,
          userAnswers: {},
          sessionResults: null,
          score: 0
        }
        throw err
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Registra la respuesta del estudiante al ítem actual
     */
    async submitAnswer(answerKey, studentId, schoolId) {
      const currentItem = this.currentDiagnosticItem
      if (!currentItem) return

      const result = await intelligenceService.submitDiagnosticAnswer({
        schoolId,
        studentId,
        assessmentItemId: currentItem.id,
        answer: answerKey
      })

      const isCorrect = result.is_correct === true
      const score = Number(result.score) || 0

      this.currentSession.userAnswers[currentItem.id] = {
        selected: answerKey,
        isCorrect,
        score
      }

      if (this.isLastDiagnosticItem) {
        this.finishDiagnosticSession()
      } else {
        this.currentSession.currentIndex++
      }
    },

    /**
     * Finaliza la sesión diagnóstica y calcula el resumen
     */
    finishDiagnosticSession() {
      const answers = Object.values(this.currentSession.userAnswers)
      const correctCount = answers.filter(a => a.isCorrect).length
      const total = this.currentSession.items.length
      const percentage = total > 0 ? Math.round((correctCount / total) * 100) : 0

      this.currentSession.sessionResults = {
        totalItems: total,
        correctAnswers: correctCount,
        percentage,
        recommendation: percentage >= 70 
          ? '¡Excelente dominio conceptual! Se recomienda avanzar a retos de aplicación autónoma.'
          : 'Se han detectado áreas de refuerzo. Te sugerimos repasar con las microintervenciones sugeridas.'
      }
      this.currentSession.isActive = false
    },

    /**
     * Abre el Drawer Socrático para el ítem actual
     */
    openSocraticTutor(itemContext = null) {
      this.socraticDrawer.isOpen = true
      this.socraticDrawer.currentItemContext = itemContext || this.currentDiagnosticItem
      this.socraticDrawer.hintLevel = 0
      this.socraticDrawer.messages = [
        {
          id: 1,
          sender: 'ai',
          text: '¡Hola! Estoy aquí para acompañarte en tu razonamiento sin darte la respuesta directa. ¿Qué parte del ejercicio te gustaría analizar primero?'
        }
      ]
    },

    closeSocraticTutor() {
      this.socraticDrawer.isOpen = false
    },

    /**
     * Procesa un mensaje del estudiante aplicando guardrails socráticos y RAG
     */
    async sendSocraticMessage(userText) {
      if (!userText || !userText.trim()) return

      // Añadir mensaje del usuario de inmediato
      this.socraticDrawer.messages.push({
        id: Date.now(),
        sender: 'user',
        text: userText
      })

      // Mensaje de carga transitorio
      const loadingMsgId = Date.now() + 1
      this.socraticDrawer.messages.push({
        id: loadingMsgId,
        sender: 'ai',
        text: 'Pensando...',
        isLoading: true
      })

      try {
        const result = await SocraticService.generateSocraticGuidance({
          userText,
          itemContext: this.socraticDrawer.currentItemContext,
          hintLevel: this.socraticDrawer.hintLevel,
          schoolId: this.cockpitData?.schoolId || null,
          studentId: this.currentSession?.studentId || null
        })

        this.socraticDrawer.hintLevel = result.nextHintLevel

        // Reemplazar mensaje de carga con respuesta real
        const index = this.socraticDrawer.messages.findIndex(m => m.id === loadingMsgId)
        if (index !== -1) {
          this.socraticDrawer.messages[index] = {
            id: loadingMsgId,
            sender: 'ai',
            text: result.reply,
            isAntiCheatApplied: result.isDirectAnswerPrevented,
            misconception: result.detectedMisconception
          }
        }
      } catch (err) {
        console.warn('Fallo en SocraticService, usando fallback local:', err)
        const fallbackEval = evaluateSocraticInteraction(
          userText,
          this.socraticDrawer.currentItemContext,
          this.socraticDrawer.hintLevel
        )
        this.socraticDrawer.hintLevel = fallbackEval.nextHintLevel
        const index = this.socraticDrawer.messages.findIndex(m => m.id === loadingMsgId)
        if (index !== -1) {
          this.socraticDrawer.messages[index] = {
            id: loadingMsgId,
            sender: 'ai',
            text: fallbackEval.reply
          }
        }
      }
    },

    /**
     * Verifica si la capa de Inteligencia está activada para la institución
     */
    async verifyFeatureFlag(schoolId) {
      this.isFeatureEnabled = await intelligenceService.checkModuleEnabled({ schoolId })
      return this.isFeatureEnabled
    }
  }
})
