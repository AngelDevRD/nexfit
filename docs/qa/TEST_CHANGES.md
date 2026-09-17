# Cambios de tests aprobados por el supervisor

Formato (una linea por cambio aprobado, ligada al hash EXACTO del contenido nuevo):

`- APPROVED-BY: OPUS | TASK: <ID> | FILE: <ruta> | SHA256: <hash normalizado LF o DELETED>`

Solo el supervisor (Opus) agrega lineas aqui. Cualquier cambio de este archivo o de
`test/.test-lock.json` hecho por el ejecutor = REJECTED automatico.

## Registro

- APPROVED-BY: OPUS | TASK: T-C1 | FILE: test/security/account_guard_concurrency_test.dart | SHA256: b5e16ae8dddb56a9382a5dd1fa29e6a00d727a1b725c379bec709d8452793f7d
- APPROVED-BY: OPUS | TASK: T-H7 | FILE: test/screens/start_workout_screen_test.dart | SHA256: 26cc6bb7d39555d8cbd428186976fa4312e6dea9fa7cccb8cedf707fbcc363fc
- APPROVED-BY: OPUS | TASK: T-H3 | FILE: tools/qa/coverage_exceptions.txt | SHA256: 0c7f5544b0e3db46c90180cf4fa0d4c85b53284af65b279f56ad53744774fe7d
