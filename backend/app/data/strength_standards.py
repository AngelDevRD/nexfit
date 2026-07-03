# Umbrales aproximados de fuerza relativa (peso levantado / peso corporal) por nivel.
# Referencia general de la industria del fitness -- NO proviene de un dataset poblacional
# verificado ni de estudios citados. Sirve como v1 hasta contar con datos reales de usuarios
# (ver .ai/CONTEXT.md, backlog Fase 3).
# Niveles: beginner, novice, intermediate, advanced, elite -- percentiles aprox 5/20/50/80/95.

STRENGTH_STANDARDS = {
    "press-banca-barra": {
        "male": [0.5, 0.75, 1.0, 1.5, 2.0],
        "female": [0.25, 0.4, 0.6, 0.9, 1.2],
    },
    "sentadilla-barra": {
        "male": [0.75, 1.0, 1.5, 2.0, 2.5],
        "female": [0.5, 0.75, 1.0, 1.5, 2.0],
    },
    "peso-muerto-convencional": {
        "male": [1.0, 1.25, 1.75, 2.25, 2.75],
        "female": [0.6, 0.9, 1.25, 1.75, 2.25],
    },
}

LEVEL_LABELS = ["beginner", "novice", "intermediate", "advanced", "elite"]
LEVEL_PERCENTILES = [5, 20, 50, 80, 95]
