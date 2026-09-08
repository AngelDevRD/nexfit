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

El email de contacto ya está resuelto (angeldnielgs@gmail.com) en los 3
documentos. Quedan las URLs, que no se pueden resolver hasta publicar
`PRIVACIDAD.md` y `TERMINOS.md` (ver "Cómo publicarlos" arriba). Checklist
completo, generado con
`grep -rn "URL_PRIVACIDAD\|URL_TERMINOS\|URL_BORRADO_DE_CUENTA" docs/ lib/`
-- si agregás o quitás una aparición, volvé a correr ese grep y actualizá
esta lista, no la edites de memoria:

- [ ] `lib/core/legal_urls.dart:11` -- `LegalUrls.privacyPolicy`
- [ ] `lib/core/legal_urls.dart:12` -- `LegalUrls.termsOfUse`
- [ ] `docs/legal/borrado-de-cuenta.html:134` -- `href` del link a Privacidad
- [ ] `docs/legal/borrado-de-cuenta.html:135` -- `href` del link a Términos
- [ ] `docs/legal/PRIVACIDAD.md:135` -- mención de la URL de borrado de
      cuenta en "Tus derechos" (ya entre backticks, sobrevive al renderizado
      Markdown mientras siga pendiente)
- [ ] `docs/legal/PLAY_DATA_SAFETY.md:28` -- mención de la misma URL en la
      sección 1.3 del borrador de Data safety. **Ojo**: hoy está entre
      `<` `>` sueltos, igual que estaba `PRIVACIDAD.md:135` antes de
      corregirlo -- Markdown la va a tragar como HTML crudo al publicar y
      desaparece de la página renderizada. No se corrigió en esta tarea
      (quedó fuera del alcance pedido); corregirla con el mismo tratamiento
      de backticks antes de publicar `PLAY_DATA_SAFETY.md` en algún lado.
- [ ] `docs/legal/PLAY_DATA_SAFETY.md:110` -- ya está en su propia lista de
      "Placeholders pendientes" (entre backticks, no tiene el problema de
      arriba)
