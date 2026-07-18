# RECOMENDACIONES PRODUCCION - WebNotas

## Estado Actual
- **Usuario Admin:** admin@webnotas.com (rol: admin)
- **Password:** Cristo01
- **Proyecto Supabase:** ykokuwkvplifbjxgdveu

---

## 1. SEGURIDAD INMEDIATA

### Ejecutar en Supabase SQL Editor:
Archivo: `PRODUCCION_SEGURIDAD.sql`

Este script:
- Actualiza el rol del admin a 'admin'
- Limpia politicas RLS duplicadas/obsoletas
- Crea buckets de storage (si no existen)
- Establece politicas de storage seguras
- Refuerza RLS en todas las tablas
- Crea politicas seguras por tabla

---

## 2. CAMBIAR PASSWORD DEL ADMIN

En Supabase Dashboard:
1. Authentication → Users → admin@webnotas.com
2. Click en "Reset password" o cambiar password directamente

O usar la app: Login → Perfil → Cambiar contrasena

---

## 3. CONFIGURACION RECOMENDADA

### Supabase Dashboard:

#### Authentication → Providers → Email
- [x] Enable email sign-in
- [x] Disable sign-up (solo admins pueden crear usuarios)
- [ ] Enable auto-confirm (NO para produccion)

#### Authentication → RLS
- [x] Enable Row Level Security on all tables

#### Settings → API
- Mantener el proyecto en el plan FREE ( hasta 500MB DB, 1GB storage, 50k monthly active users)

---

## 4. COSTOS SUPABASE (Plan Free es suficiente)

| Recurso | Limite Free | Suficiente para |
|---------|-------------|-----------------|
| Base de datos | 500 MB | 10,000 estudiantes |
| Storage | 1 GB | Fotos y archivos |
| Auth | 50k MAU | 1-50 docentes |
| API Requests | 60k/min | Uso normal escolar |
| Bandwidth | 5 GB/mes | App escolar |

**Costo real: $0 USD/mes** para una escuela pequena/grande.

### Si necesitas mas (escuela muy grande):
- Plan Pro: $25/mes
- Pay-as-you-go: segun uso

---

## 5. DESPLIEGUE FRONTEND

### Opciones gratuitas/de bajo costo:

#### A. Supabase Hosting (mas facil)
- Conectar repo de GitHub
- Deploy automatico desde main
- Dominio personalizado opcional

#### B. Vercel (gratis)
- Conectar repo de GitHub
- SSL automatico
- Dominio: `webnotas-tudominio.vercel.app` (gratis)

#### C. Netlify (gratis)
- Similar a Vercel
- SSL automatico

#### D. Cloudflare Pages (gratis)
- Muy rapido
- SSL automatico
- CDN global gratis

---

## 6. VARIABLES DE ENTORNO (Production)

```env
VITE_SUPABASE_URL=https://ykokuwkvplifbjxgdveu.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_CBUK56HIo7g0mfA8HneTnQ_bcO2bTPk
```

**NUNCA** exponer la `sb_secret_*` en el frontend.

---

## 7. CHECKLIST PRODUCCION

- [x] Unico usuario admin configurado
- [x] Password fuerte (Cristo01 + simbolos recomendados)
- [ ] RLS verificado y funcionando
- [ ] Storage policies configuradas
- [ ] Email notifications configuradas (supabase)
- [ ] Dominio personalizado (opcional)
- [ ] SSL certificado (automatico con Vercel/Netlify)
- [ ] Backup automatico (Supabase lo hace automaticamente en Free)
- [ ] Monitoreo de uso (Dashboard Supabase)

---

## 8. LIMITES DE USUARIOS SUGERIDOS

Para el plan FREE:
- **1 admin** (admin@webnotas.com)
- **Hasta 20-30 docentes** (rol teacher)

Los docentes pueden:
- Ver/editar calificaciones
- Ver estudiantes de sus cursos
- No pueden eliminar cursos ni estudiantes
- No pueden acceder a configuraciones del sistema

---

## 9. RESPALDOS

Supabase hace respaldos automaticos:
- Plan Free: Backups diarios (7 dias retention)
- Plan Pro: Backups por hora (30 dias retention)

Para restaurar: Dashboard → Database → Backups

---

## 10. MONITOREO

Dashboard Supabase → Logs:
- Query performance
- Auth events
- Storage usage
- API requests

Si ves anomalias, revisar logs de authentication para detectar accesos no autorizados.
