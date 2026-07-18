/**
 * Errores técnicos (Supabase / PostgREST / red) → mensajes claros en español.
 */
export function translateError(error) {
    if (!error) return 'Ha ocurrido un error inesperado.';

    const statusCode = typeof error === 'object' && error !== null ? error.statusCode : undefined
    if (statusCode === 403) {
        return 'Acceso denegado. Si acabas de registrarte, verifica tu correo antes de entrar.'
    }

    const msg = typeof error === 'string' ? error : error.message || String(error);
    const lowerMsg = msg.toLowerCase();

    const dictionary = [
        { match: 'invalid login credentials', reply: 'El correo o la contraseña son incorrectos.' },
        { match: 'user not found', reply: 'Usuario no encontrado.' },
        { match: 'password should be at least', reply: 'La contraseña debe tener al menos 6 caracteres.' },
        { match: 'email rate limit exceeded', reply: 'Demasiados intentos. Por favor, espera unos minutos e inténtalo de nuevo.' },
        { match: 'duplicate key value violates unique constraint', reply: 'Ya existe un registro con estos datos únicos (ej. identificación o correo).' },
        { match: 'network error', reply: 'Error de red. Verifica tu conexión a internet.' },
        {
            match: 'failed to fetch',
            reply:
                'No se pudo contactar a Supabase (red o URL incorrecta). Revisa en app/.env.local que VITE_SUPABASE_URL sea la de tu proyecto (p. ej. https://TU_REF.supabase.co) y que VITE_SUPABASE_ANON_KEY sea la clave publishable de ese mismo proyecto en el panel. Reinicia npm run dev tras cambiar el .env.',
        },
        { match: 'jwt expired', reply: 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.' },
        { match: 'authentication failed', reply: 'Fallo de autenticación. Verifica tus credenciales.' },
        { match: 'could not find the table', reply: 'Falta ejecutar migraciones o tablas en la base de datos.' },
        { match: 'email not verified', reply: 'Debes verificar tu correo antes de iniciar sesión.' }
    ];

    for (const item of dictionary) {
        if (lowerMsg.includes(item.match)) {
            return item.reply;
        }
    }

    // Fallback to original message if not found, but we could also return a generic error.
    return msg;
}
