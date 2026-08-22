# Fondo galáctico animado del login

> Esta especificación queda incorporada y ampliada por `2026-08-09-logreva-brand-and-login-design.md`. La implementación debe seguir el documento combinado.

## Objetivo

Reemplazar únicamente el Canvas de estrellas existente en el panel izquierdo del login por un fondo galáctico digital, sobrio y empresarial. El cambio no alterará textos, tipografías, colores de contenido, posiciones, formulario, logo, tarjetas ni comportamiento de autenticación.

## Contexto técnico confirmado

- La aplicación real utiliza Vue 3, Vite y JavaScript, no React con TypeScript.
- El login se encuentra en `app/src/views/Login.vue`.
- El panel izquierdo se muestra únicamente desde el breakpoint `lg`; en móvil permanece oculto.
- Tailwind CSS ya está configurado.
- No se instalarán dependencias nuevas ni se utilizará Three.js.
- El Canvas actual dibuja 300 estrellas y mantiene su ciclo de vida dentro de `Login.vue`; esa responsabilidad se extraerá a un componente visual aislado.

## Enfoque aprobado

Se usará una solución híbrida de Canvas 2D y CSS:

- Canvas 2D para partículas, estrellas fugaces, meteoros pequeños y flujos de energía.
- CSS para la base navy y una nebulosa digital extremadamente sutil.
- Un único ciclo de `requestAnimationFrame` coordinará todos los elementos animados.

Este enfoque ofrece más control y menor carga de DOM que una solución basada en numerosos elementos HTML, sin justificar el peso de una librería 3D.

## Componente

Se creará `app/src/components/ui/GalaxyBackground.vue`.

El componente será exclusivamente decorativo:

- `position: absolute`
- `inset: 0`
- `overflow: hidden`
- `pointer-events: none`
- `aria-hidden="true"`

`Login.vue` importará el componente y lo colocará donde actualmente se encuentra el Canvas. El contenido existente conservará `position: relative` y `z-index: 10`.

## Composición visual

### Nebulosa

Dos degradados radiales de baja opacidad crearán una atmósfera azul/cyan abstracta. Se moverán lentamente mediante transformaciones y variaciones leves de opacidad. No se utilizarán fotografías, vídeos, GIF ni texturas pesadas.

### Campo de partículas

El Canvas mantendrá entre 40 y 70 partículas, ajustadas al tamaño visible del panel:

- Capa posterior: puntos pequeños, tenues y lentos.
- Capa media: puntos cyan y azules con movimiento moderado.
- Capa frontal: pocas partículas brillantes con glow limitado.

Cada partícula tendrá fase, velocidad, opacidad y oscilación propias para evitar patrones repetitivos.

### Meteoros y estrellas fugaces

Los meteoros pequeños aparecerán de forma espaciada y viajarán principalmente de arriba-derecha hacia abajo-izquierda. Una minoría usará la diagonal opuesta.

Solo podrá existir una estrella fugaz destacada simultáneamente. Su siguiente aparición se programará aleatoriamente entre cuatro y ocho segundos después de terminar la anterior. La cabeza, cola, degradado y glow se dibujarán en Canvas para evitar líneas blancas planas.

### Flujos de energía

Se dibujarán pocas curvas Bézier en la zona inferior y el lateral derecho. Tendrán pulso lento y partículas pequeñas desplazándose a lo largo de las curvas. No invadirán la zona principal de lectura.

### Zona segura de contenido

El área central ocupada por marca, título, descripción y tarjeta tendrá una reducción de luminosidad. Las partículas brillantes y las trayectorias principales evitarán esa zona; los elementos de fondo que la atraviesen tendrán opacidad limitada.

## Interacción y profundidad

El movimiento del puntero se normalizará respecto al panel. Las capas decorativas recibirán desplazamientos distintos, con un máximo total de 8 px. Los textos, tarjetas y controles nunca se moverán.

Se suavizará la transición hacia la posición objetivo para evitar saltos. Al salir el puntero del panel, el parallax regresará gradualmente al centro.

## Rendimiento

- Un solo `requestAnimationFrame`.
- Cantidad máxima fija de partículas; no se crearán objetos por cuadro.
- Reutilización de estructuras y degradados cuando sea posible.
- Resolución del Canvas ajustada al tamaño CSS y `devicePixelRatio` limitado a 1.5.
- Redimensionamiento gestionado sin iniciar ciclos de animación adicionales.
- Pausa completa cuando `document.hidden` sea verdadero.
- Sin filtros CSS costosos aplicados a decenas de elementos.

El objetivo es mantener movimiento fluido en escritorio sin aumentar materialmente el bundle.

## Accesibilidad

El componente consultará `prefers-reduced-motion: reduce`.

En ese modo:

- no habrá estrellas fugaces;
- no habrá parallax;
- no se ejecutará un ciclo continuo de animación;
- se dibujará una composición estática de partículas y curvas tenues;
- la nebulosa permanecerá estática.

El Canvas será decorativo y quedará oculto para tecnologías de asistencia.

## Ciclo de vida y limpieza

Al montar, el componente configurará Canvas, observación de tamaño, preferencia de movimiento, visibilidad de documento y eventos de puntero.

Al desmontar:

- ejecutará `cancelAnimationFrame()` si existe un cuadro pendiente;
- cancelará temporizadores pendientes;
- eliminará todos los `addEventListener()` registrados;
- desconectará `ResizeObserver`;
- eliminará listeners del `MediaQueryList`.

No se almacenarán handlers personalizados sobre nodos DOM.

## Integración

En `Login.vue` se eliminarán exclusivamente:

- `canvasRef`;
- `animationId`;
- `initCanvas()`;
- el montaje y desmontaje asociados al Canvas actual;
- la etiqueta `<canvas>` existente.

Se conservarán sin cambios los flujos de inicio de sesión, recuperación y actualización de contraseña. La suscripción de Supabase seguirá perteneciendo a `Login.vue`.

## Verificación

1. Ejecutar la suite Vitest existente.
2. Compilar la aplicación con Vite.
3. Ejecutar los E2E relevantes del login y navegación pública.
4. Revisar visualmente a 1440 × 900 y 1024 × 768.
5. Confirmar que a menos de `lg` el login conserva su aspecto actual.
6. Verificar `prefers-reduced-motion`.
7. Comprobar que no aparece overflow horizontal.
8. Navegar fuera del login y confirmar que no quedan cuadros de animación ni listeners activos.
9. Confirmar que no existen errores de consola ni cambios de layout.

## Fuera de alcance

- Renombrar EduCore o modificar contenido de marca.
- Rediseñar el formulario o el panel derecho.
- Mostrar el panel galáctico en móvil.
- Añadir sonido, vídeo, WebGL, Three.js o nuevas dependencias.
- Cambiar la autenticación o sus estados.
