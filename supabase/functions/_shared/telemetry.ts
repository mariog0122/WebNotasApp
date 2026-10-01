// Shared telemetry and alerting helper for Supabase Edge Functions (Deno runtime)

export interface EdgeFunctionErrorOptions {
  schoolId?: string | null
  userId?: string | null
  statusCode?: number
  metadata?: Record<string, unknown>
}

export function toEdgeErrorCode(error: unknown): string {
  const candidate = error instanceof Error ? error.message : String(error || '')
  return /^[A-Z0-9_]{1,80}$/.test(candidate)
    ? candidate
    : 'UNEXPECTED_EDGE_FUNCTION_ERROR'
}

export async function reportEdgeFunctionError(
  adminClient: any,
  functionName: string,
  error: unknown,
  options: EdgeFunctionErrorOptions = {}
): Promise<{ success: boolean; alertTriggered?: boolean; error?: string }> {
  try {
    const errorCode = toEdgeErrorCode(error)
    const statusCode = options.statusCode || 500

    const { data, error: rpcError } = await adminClient.rpc('record_edge_function_error', {
      p_function_name: functionName,
      p_error_message: errorCode,
      p_status_code: statusCode,
      p_school_id: options.schoolId || null,
      p_user_id: options.userId || null,
      p_metadata: options.metadata || {},
    })

    if (rpcError) {
      console.warn(`[EdgeTelemetry] Fallback direct insert for ${functionName}:`, rpcError.message)
      await adminClient.from('edge_function_error_events').insert({
        function_name: functionName,
        error_message: errorCode,
        status_code: statusCode,
        school_id: options.schoolId || null,
        user_id: options.userId || null,
        metadata: options.metadata || {},
      }).catch(() => undefined)
      return { success: false, error: rpcError.message }
    }

    if (data?.alert_triggered) {
      console.error(`🚨 [CRITICAL ALERT] Burst of 500 errors detected in Edge Function "${functionName}" (${data.recent_count_15m} errors in last 15 min)!`)
    }

    return { success: true, alertTriggered: Boolean(data?.alert_triggered) }
  } catch (err) {
    console.warn('[EdgeTelemetry] Unexpected failure recording edge function error:', err)
    return { success: false }
  }
}
