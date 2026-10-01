import { afterEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import PlanningFeedbackModal from '../src/components/planning/PlanningFeedbackModal.vue'
import FeedbackActionButtons from '../src/components/planning/FeedbackActionButtons.vue'
import { renderComponent } from './helpers/renderComponent'

let mounted
afterEach(() => mounted?.unmount())

describe('feedback confirms persistence before changing the interface', () => {
  it('keeps the modal and text available after failure, then closes on successful retry', async () => {
    const submit = vi.fn().mockRejectedValueOnce(new Error('Denied')).mockResolvedValueOnce({ success: true })
    const close = vi.fn()
    mounted = renderComponent(PlanningFeedbackModal, { show: true, targetId: 'plan', onSubmitFeedback: submit, onClose: close })
    const state = mounted.state
    state.commentText = 'Usar materiales del entorno'
    await state.onSubmit()
    await nextTick()
    expect(close).not.toHaveBeenCalled()
    expect(state.submissionError).toContain('No se pudo enviar')
    expect(state.submitting).toBe(false)
    await state.onSubmit()
    expect(submit).toHaveBeenLastCalledWith(expect.objectContaining({ comment: 'Usar materiales del entorno' }))
    expect(close).toHaveBeenCalledTimes(1)
  })

  it('does not show a positive checkmark or duplicate a request while the server is pending', async () => {
    let resolve
    const submit = vi.fn().mockImplementation(() => new Promise(done => { resolve = done }))
    mounted = renderComponent(FeedbackActionButtons, { targetId: 'plan', onSubmitFeedback: submit })
    const state = mounted.state
    const pending = state.onPositiveClick()
    await nextTick()
    await state.onPositiveClick()
    expect(submit).toHaveBeenCalledTimes(1)
    expect(state.submitting).toBe(true)
    expect(state.submittedPositive).toBe(false)
    resolve({ success: true })
    await pending
    await nextTick()
    expect(state.submittedPositive).toBe(true)
  })

  it('allows retrying a positive rating after the server rejects it', async () => {
    const submit = vi.fn().mockRejectedValue(new Error('Denied'))
    mounted = renderComponent(FeedbackActionButtons, { targetId: 'plan', onSubmitFeedback: submit })
    const state = mounted.state
    await state.onPositiveClick()
    await nextTick()
    expect(state.submitting).toBe(false)
    expect(state.submittedPositive).toBe(false)
  })
})
