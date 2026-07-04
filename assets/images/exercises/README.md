# Imágenes 2D de ejercicios — cómo agregar assets

La app muestra una miniatura por ejercicio (en la lista y en el detalle). Carga
la imagen **desde esta carpeta**, 100% offline. Si un archivo no está, cae de
forma automática a un ícono coloreado con el color del grupo muscular — la app
sigue funcionando sin ninguna imagen.

## Convención de nombres (obligatoria)

```
assets/images/exercises/<slug>.webp
```

El `<slug>` es el identificador del ejercicio (campo `slug` en
`assets/data/exercises.json`). Ejemplos:

```
assets/images/exercises/press-banca-con-barra.webp
assets/images/exercises/sentadilla-con-barra.webp
assets/images/exercises/dominadas.webp
```

## Recomendaciones

- Formato **WebP** (mejor compresión que JPG/PNG a igual calidad).
- Relación **1:1** (cuadrada); la miniatura recorta con `BoxFit.cover`.
- Objetivo: **< 60 KB por imagen** para que el APK quede liviano.
- Fuentes válidas: fotos propias, o bancos con licencia de uso comercial.

## Cómo se agrega

1. Poné el `.webp` con el nombre correcto en esta carpeta.
2. Recompilá (`flutter build apk ...`). Aparece solo, sin tocar código.
