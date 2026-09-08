# Documentos legales de NexFit

Este directorio tiene los 3 documentos que exige Google Play antes de publicar:

- `PRIVACIDAD.md` — política de privacidad.
- `TERMINOS.md` — términos de uso.
- `borrado-de-cuenta.html` — página web de borrado de cuenta sin reinstalar la
  app (requisito separado de Play, aparte del borrado in-app que ya existe en
  Ajustes → Cuenta).

Ninguno está publicado todavía. Nada de esto se desplegó ni se configuró como
parte de esta tarea.

## Cómo publicarlos (GitHub Pages, gratis)

1. En la configuración del repo en GitHub: **Settings → Pages**.
2. **Source**: `Deploy from a branch`. **Branch**: `master`, carpeta `/docs`.
3. Guardar. GitHub sirve el contenido de `docs/` en
   `https://<usuario-o-org>.github.io/<repo>/`.
4. Con esa configuración, las URLs públicas quedan:
   - Privacidad: `https://<usuario-o-org>.github.io/<repo>/legal/PRIVACIDAD.html`
     (GitHub Pages sirve los `.md` como HTML renderizado con Jekyll por
     defecto; si preferís servirlos como texto plano, agregá un `.nojekyll` en
     `docs/` o convertí los `.md` a `.html` antes de publicar).
   - Términos: `https://<usuario-o-org>.github.io/<repo>/legal/TERMINOS.html`
   - Borrado de cuenta: `https://<usuario-o-org>.github.io/<repo>/legal/borrado-de-cuenta.html`
     (esta ya es `.html` puro, sin dependencias externas, se sirve tal cual).

Si el repo es privado, GitHub Pages con el plan gratis solo lo publica para
cuentas Pro/Team/Enterprise -- para un repo privado en plan free, la
alternativa gratis más simple es mover estos 3 archivos a un repo público
aparte (o a un Gist/Netlify/Vercel) y linkear desde ahí.

## Dónde van estas URLs una vez que existan

1. **`lib/core/legal_urls.dart`** — reemplazar `<URL_PRIVACIDAD>` y
   `<URL_TERMINOS>` por las URLs reales. Estos dos botones ya están enlazados
   en Ajustes → Acerca de.
2. **Ficha de Play Console**:
   - App content → Privacy policy: la URL de `PRIVACIDAD.md`.
   - Data safety form: puede pedir la misma URL de privacidad.
   - Account deletion (Data safety → "Request account deletion"): la URL de
     `borrado-de-cuenta.html`.

## Placeholders pendientes en estos documentos

Buscar `<EMAIL_DE_CONTACTO>` en `PRIVACIDAD.md`, `TERMINOS.md` y
`borrado-de-cuenta.html`, y `<URL_PRIVACIDAD>`/`<URL_TERMINOS>` en
`borrado-de-cuenta.html` -- reemplazar todos antes de publicar.
