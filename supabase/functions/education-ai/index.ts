import { createClient } from 'npm:@supabase/supabase-js@2.49.8'
import { createEducationAIHandler } from './handler.js'
import { GeminiEducationAIProvider } from './providers/GeminiEducationAIProvider.js'
import { OpenAIEducationAIProvider } from './providers/OpenAIEducationAIProvider.js'

Deno.serve(createEducationAIHandler({
  createClient,
  env: (name: string) => Deno.env.get(name),
  providers: { gemini: GeminiEducationAIProvider, openai: OpenAIEducationAIProvider },
}))
