# Waypoint Movement

[Especificación completa en Notion](https://app.notion.com/p/3e50e17f0d368135ac19ea41609b13c3)

[Movement Families Roadmap](https://app.notion.com/p/3e50e17f0d36810a889de2595b8f30b4)

Para probar en UEFN:

1. Compila Verse y coloca `waypoint_preview_device` en el nivel.
2. Asigna tres props dedicados a `Targets`, sin otro controlador que los mueva.
3. Configura `Bounds.Center` y sus dimensiones; coloca los props dentro de los bounds con padding.
4. Ajusta `Configuration` en Details y deja `RunChecks = true`.
5. Inicia la partida y comprueba el mensaje `Waypoint checks PASSED` antes del movimiento.

El default usa destinos aleatorios con jitter. Prueba también `Loop` y `PingPong` con jitter cero.
`ViewPlane` conserva Forward; `GroundPlane` conserva Up. `GroundPlane`/`Volume` necesitan un Depth mayor que dos veces EdgePadding.

Compilación UEFN verificada sin errores ni warnings. Checks de runtime y aceptación visual pendientes de ejecutar en la isla.
La implementación Entity actual no mueve y no existe una implementación Guard local. La familia no cambia esos contratos.
