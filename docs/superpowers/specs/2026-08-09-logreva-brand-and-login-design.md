# Identidad global LOGREVA y fondo galáctico del login

## Objetivo

Sustituir la identidad visible de EduCore/WebNotas por LOGREVA en toda la aplicación y mejorar el login con un fondo galáctico digital ligero. El resultado debe presentar una marca institucional ecuatoriana coherente, premium y preparada para comercialización, sin modificar los flujos de autenticación ni rediseñar los módulos internos.

Este documento incorpora y sustituye, para efectos de implementación, la especificación aislada `2026-08-09-login-galaxy-background-design.md`.

## Contexto técnico

- La aplicación utiliza Vue 3, Vite y JavaScript.
- Tailwind CSS ya está configurado.
- El login se encuentra en `app/src/views/Login.vue`.
- El panel visual izquierdo del login se oculta por debajo del breakpoint `lg` y continuará oculto.
- No se instalarán dependencias nuevas.
- No se utilizarán Three.js, WebGL, vídeos, GIF ni imágenes externas pesadas.
- El repositorio contiene cambios sin confirmar que deben preservarse.

## Sistema de marca aprobado

### Nombre y descriptor

- Marca principal: `LOGREVA`.
- Descriptor de marca: `GESTIÓN EDUCATIVA`.
- Descriptor comercial secundario cuando el contexto lo requiera: `SaaS educativo`.
- Presentación institucional completa: `LOGREVA · Gestión Educativa`.

El descriptor principal evita depender del término técnico “SaaS” y comunica inmediatamente la categoría a rectores, administradores y propietarios de instituciones.

### Isotipo Arquitecta

El isotipo aprobado combina una L sólida azul tinta con un check cyan independiente. La L debe reconocerse antes que el gesto de logro; no llevará contenedor, escudo, gradiente, sombra ni glow.

Geometría maestra en un `viewBox="0 0 72 72"`:

```svg
<path d="M10 7H21V42C21 49.5 24.5 53 32 53H37V64H30C16.5 64 10 57.5 10 44V7Z" fill="currentColor" />
<path d="M27 39L37 50L57 18L66 24L38 67L18 45L27 39Z" fill="var(--logreva-accent, #079AB7)" />
```

Antes de producir los activos finales se permite un ajuste óptico menor de uno o dos puntos en vértices o separación, siempre que no cambie la construcción aprobada.

### Wordmark

- `LOGREVA` en mayúsculas, peso alto y espaciado moderado.
- La V puede usar el color de acento en aplicaciones amplias.
- En tamaños pequeños, el wordmark se usa en un solo color para conservar legibilidad.
- No se añadirá una fuente externa; se utilizará la tipografía ya cargada por la aplicación y ajustes de peso/espaciado.

### Colores

- Azul tinta principal: `#0B1530`.
- Cyan institucional: `#079AB7`.
- Cyan luminoso para fondos oscuros: `#22D3EE`.
- Blanco: `#FFFFFF`.

En superficies claras se usa L azul tinta y check cyan. En superficies oscuras se usa L blanca y check cyan luminoso.

## Componentes y activos

### `BrandLogo.vue`

Se creará `app/src/components/ui/BrandLogo.vue` como fuente visual reutilizable. Admitirá:

- variante horizontal con isotipo, wordmark y descriptor;
- variante compacta con isotipo y wordmark;
- variante de solo isotipo;
- modo claro y modo oscuro;
- tamaño controlado por clases del consumidor;
- etiqueta accesible `Logreva, gestión educativa` cuando sea informativo;
- modo decorativo con `aria-hidden="true"` cuando el texto adyacente ya identifique la marca.

El componente no impondrá márgenes ni posiciones a sus consumidores.

### Activos públicos

La misma geometría maestra generará:

- `app/public/logreva-mark.svg`;
- `app/public/favicon.svg`;
- `app/public/pwa-192x192.png`;
- `app/public/pwa-512x512.png`;
- `app/public/apple-touch-icon.png`.

Los PNG tendrán fondo azul tinta y el isotipo blanco/cyan centrado con margen seguro. No se reutilizarán iconos antiguos bajo el nombre nuevo.

### Constantes de marca

Se creará `app/src/lib/brand.js` para concentrar:

- nombre y descriptor;
- texto accesible del logo;
- año de copyright;
- teléfono comercial `593989121871`;
- URL de WhatsApp para solicitar demo;
- mensaje prellenado: `Hola, quiero solicitar una demostración de LOGREVA para mi institución educativa.`

No se duplicará el número o mensaje entre Login y Pricing.

## Login

### Panel izquierdo en escritorio

El panel conservará sus dimensiones y estructura. El contenido será:

```text
LOGREVA
GESTIÓN EDUCATIVA

Gestión Académica
Centralizada

Donde cada institución logra su excelencia académica.

Control académico en tiempo real
Trazabilidad lista para auditoría
Reportes claros para decidir mejor
```

Los beneficios usarán checks vectoriales discretos. Se mantendrá una zona visual limpia detrás de marca, título, párrafo, beneficios y tarjeta.

La tarjeta inferior será:

```text
Acceso Seguro
Autenticación protegida con Supabase Auth y sesiones JWT.
```

No se afirmarán certificaciones o garantías no verificadas.

### Panel derecho

El estado normal mostrará:

```text
Bienvenido a Logreva
Ingresa tus credenciales institucionales
```

Se conservarán inputs, validación, recuperación y actualización de contraseña. Tras el enlace de recuperación aparecerá:

```text
¿No tienes cuenta? Solicita una demo
```

`Solicita una demo` abrirá WhatsApp en una pestaña nueva, con `rel="noopener noreferrer"` y el mensaje definido en `brand.js`.

El enlace a planes se mostrará como:

```text
Ver Planes, Precios y Seguridad
```

El pie del login será:

```text
© 2026 Logreva · Términos · Privacidad
Creado en Ecuador para Latinoamérica 🇪🇨
```

Los enlaces usarán las rutas existentes `/terminos` y `/privacidad`.

### Móvil

El panel galáctico continuará oculto. El encabezado móvil usará `BrandLogo` y el formulario conservará su estructura. La demo, planes y pie legal permanecerán visibles sin producir overflow horizontal.

## Fondo galáctico

Se creará `app/src/components/ui/GalaxyBackground.vue`, exclusivamente decorativo, con `position: absolute`, `inset: 0`, `overflow: hidden`, `pointer-events: none` y `aria-hidden="true"`.

### Capas

- Base navy existente.
- Nebulosa CSS sutil mediante dos degradados radiales.
- Entre 40 y 70 partículas Canvas distribuidas en tres profundidades.
- Meteoros digitales pequeños con cola degradada.
- Una estrella fugaz destacada cada cuatro a ocho segundos; nunca más de una simultánea.
- Curvas Bézier de energía limitadas principalmente al tercio inferior y lateral derecho.
- Partículas pequeñas viajando sobre las curvas.

### Movimiento

- Un solo ciclo `requestAnimationFrame`.
- Parallax suavizado máximo de 8 px, aplicado solo a elementos decorativos.
- Diferentes velocidades por profundidad.
- Pausa total cuando la pestaña no esté visible.
- Límite de `devicePixelRatio` de 1.5.
- No se crearán objetos nuevos en cada cuadro.

### Movimiento reducido

Con `prefers-reduced-motion: reduce`:

- no habrá ciclo continuo;
- no habrá parallax ni estrellas fugaces;
- se dibujará una escena estática de baja intensidad;
- la nebulosa no se animará.

### Limpieza

Al desmontar, el componente cancelará `requestAnimationFrame`, eliminará listeners de puntero y visibilidad, desconectará `ResizeObserver` y retirará el listener de `MediaQueryList`.

## Aplicación global

### Metadatos y PWA

- Título: `LOGREVA — Gestión educativa para instituciones`.
- Descripción: `Plataforma de gestión educativa para centralizar estudiantes, cursos, calificaciones, reportes y trazabilidad institucional.`
- PWA `name`: `LOGREVA Gestión Educativa`.
- PWA `short_name`: `LOGREVA`.
- Descripción PWA alineada con el metadato principal.
- `theme_color`: azul tinta de marca.

### Pantalla de carga y navegación

La pantalla de carga mostrará LOGREVA. La barra lateral conservará como protagonista el nombre y logo de la institución cliente. Su descriptor secundario será `LOGREVA · Gestión Académica`; si falta nombre institucional, el fallback será `Logreva`.

### Planes

La página de planes usará `BrandLogo`, LOGREVA en encabezado, maqueta, JSON-LD, contacto comercial y pie. Los comentarios internos no son contenido visible, pero pueden actualizarse cuando describan explícitamente la marca anterior.

No se modificarán precios, límites, beneficios ni lógica comercial.

### Legales

Términos y privacidad sustituirán EduCore por Logreva sin inventar razón social, domicilio, registro de marca o certificaciones inexistentes. Las fechas actuales se conservarán salvo que el contenido sustantivo cambie más allá del nombre.

### Otros textos visibles

- Mensajes PWA y errores visibles usarán `[Logreva]`.
- El kicker `Sistema de Notas` de reportes se sustituirá por `Logreva · Gestión Académica`.
- El README de la aplicación se actualizará a LOGREVA.

## Compatibilidad e identificadores internos

El identificador `webnotas-auth-token` se conservará para evitar cerrar sesiones existentes. También pueden permanecer nombres históricos en migraciones, rutas de archivos, comentarios puramente técnicos o registros de compilación que no se muestren al usuario.

No se renombrarán tablas, buckets, claves de configuración, variables de entorno ni rutas del proyecto por razones de compatibilidad.

## Verificación

### Contratos automatizados

- No quedan apariciones visibles de EduCore o WebNotas en vistas, metadatos, PWA o navegación.
- `webnotas-auth-token` continúa sin cambios.
- `BrandLogo.vue` expone variantes accesibles.
- `GalaxyBackground.vue` contiene limpieza completa y movimiento reducido.
- Login importa ambos componentes y ya no contiene el motor Canvas antiguo.
- CTA de demo usa la constante compartida y enlace externo seguro.
- Favicon y manifest apuntan a activos LOGREVA.

### Pruebas de ejecución

1. Ejecutar toda la suite Vitest.
2. Compilar con Vite.
3. Ejecutar el presupuesto de bundle.
4. Ejecutar Playwright completo.
5. Verificar login a 1440 × 900, 1024 × 768 y 360 × 800.
6. Verificar tema de movimiento reducido.
7. Confirmar ausencia de overflow horizontal y errores de consola.
8. Confirmar que login, recuperación y actualización de contraseña mantienen su comportamiento.
9. Confirmar que WhatsApp, planes, términos y privacidad navegan correctamente.
10. Inspeccionar iconos PWA a 192 y 512 px.

## Despliegue

El rebranding y la animación cambian archivos del frontend; después de aprobar la verificación local será necesario generar un nuevo paquete y volver a desplegar en Hostinger. No se realizará el despliegue sin una solicitud explícita posterior del usuario.

## Fuera de alcance

- Comprar o conectar un dominio.
- Registrar la marca en SENADI.
- Cambiar precios o condiciones comerciales.
- Rediseñar módulos internos.
- Cambiar autenticación, base de datos o RLS.
- Mostrar la galaxia en móvil.
- Crear perfiles sociales o campañas.
