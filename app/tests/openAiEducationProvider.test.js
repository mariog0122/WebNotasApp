import { afterEach, describe, expect, it, vi } from 'vitest'
import { OpenAIEducationAIProvider } from '../../supabase/functions/education-ai/providers/OpenAIEducationAIProvider.js'

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

describe('OpenAI education provider runtime limits', () => {
  it('sets an output limit and parses the required JSON response', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({ choices: [{ message: { content: '{"title":"Ficha segura"}' } }] }),
    }))
    vi.stubGlobal('fetch', fetchMock)
    const provider = new OpenAIEducationAIProvider('synthetic-key', 'gpt-5-mini')

    await expect(provider.generateResource({ resourceType: 'ficha', topicTitle: 'Fracciones', subjectName: 'Matemáticas', gradeYear: '6to', dcdDescriptions: [] }))
      .resolves.toEqual({ title: 'Ficha segura' })

    const options = fetchMock.mock.calls[0][1]
    const body = JSON.parse(options.body)
    expect(body.model).toBe('gpt-5-mini')
    expect(body.max_completion_tokens).toBe(3000)
    expect(options.signal).toBeInstanceOf(AbortSignal)
  })

  it('aborts an unresponsive provider after 25 seconds', async () => {
    vi.useFakeTimers()
    vi.stubGlobal('fetch', vi.fn((_url, options) => new Promise((_resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')))
    })))
    const provider = new OpenAIEducationAIProvider('synthetic-key', 'gpt-5-mini')
    const pending = provider.generateResource({ resourceType: 'ficha', topicTitle: 'Fracciones', subjectName: 'Matemáticas', gradeYear: '6to', dcdDescriptions: [] })

    const assertion = expect(pending).rejects.toMatchObject({ name: 'AbortError' })
    await vi.advanceTimersByTimeAsync(25_000)
    await assertion
  })
})
