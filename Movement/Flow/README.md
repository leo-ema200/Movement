# Flow

Movimiento orgánico mediante decisiones de rumbo independientes y curvas abiertas dentro de Box.
**Pendiente:** compilar después de reabrir UEFN, ejecutar los checks Verse y aceptar visualmente el experimento Sleep.

[Especificación completa en Notion](https://app.notion.com/p/3e60e17f0d368142acdff587caa72dfe)

## Prueba en UEFN

1. Reabre el proyecto: el build observado todavía buscaba los cinco archivos eliminados de Orbit.
2. Compila y coloca `flow_preview_device`. Asigna tres props dedicados a `Targets`.
3. Ajusta `Center`, `Width`, `Height` y `Depth` al espacio real. Los props deben iniciar dentro del Box.
4. Deja `RunChecks=true`. Espera `Flow checks PASSED` antes de evaluar los props. Los casos negativos imprimen errores esperados.
5. Con `Targets` vacío se ejecutan únicamente los checks. `PreviewSeconds` cancela los Runs después de 60 s por defecto.
6. Prueba cada fila con Speed 350 y 900; mantén el mismo orden de Targets y los mismos spawns.

| Variante | HeadingDegrees | SpreadDegrees | TurnDistance | Persistence | SideSwitchChance | Randomness |
|---|---:|---:|---:|---:|---:|---:|
| A: casi vertical | 90 | 2 | 350 | 0.30 | 0.70 | 0.70 |
| B: vertical irregular | 90 | 25 | 250 | 0.25 | 0.65 | 0.80 |
| C: S asimétrica | 0 | 60 | 380 | 0.15 | 1 | 0.70 |
| D: impredecible | 90 | 150 | 180 | 0.25 | 0.55 | 1 |
| E: casi recto | 15 | 0 | 500 | 0.25 | 0.65 | 0 |

E redondea retornos diagonales en bounds; Heading=0 produce rectas horizontales. La aleatoriedad cero permite clones deliberados.

[Preview geométrico A–E, tres índices por fila](flow_paths.svg). Es un modelo numérico, no una captura de Fortnite.

## Experimento Sleep

`ExperimentalSleep=true` ejecuta **Sleep(0.1) antes de cada MoveTo usado para una curva**.
Compara ON/OFF con `Seed=12345`, mismos spawns, mismo índice y mismo movimiento del jugador.
Speed representa la velocidad durante MoveTo; las esperas reducen la media real. No se compensan acelerando.

**Si aparecen pausas visibles o empeora el handoff, eliminar esta técnica de la versión aceptada.**
La aceptación depende de tu prueba visual. No se añadió Sleep a Linear ni a Waypoint.

## Uso desde un controlador

```verse
using { ScenarioRun.TargetBehavior.Movement.Flow }

Behavior := flow_movement{
    Configuration := flow_configuration{}
    Playspace := option{GetPlayspace()}
}
Behavior.Run(TargetObject, TargetIndex, Bounds)
```

El controlador debe cancelar el Run anterior antes de ocultar, destruir, reposicionar o reiniciar la target.
Configuration y Behavior pueden compartirse; cada Run crea su propio PRNG y estado.

## Bounds y jugador

- ViewPlane usa Left/Up y conserva Forward; GroundPlane usa Left/Forward y conserva Up.
- Todos los controles se planifican dentro del Box. La curva se mantiene dentro por convexidad.
- PlayerClearance=150 cm sigue a todos los jugadores activos: esfera en frontal, cilindro en suelo.
- El preview conecta Playspace automáticamente; fuera del preview debes suministrarlo. Clearance=0 desactiva la protección explícitamente.
- La ruta se comprueba antes de cada MoveTo, después del Sleep. Una invasión puede forzar espera/replanificación.
- Incluye tamaño de mesh y holgura de movimiento en Clearance. No se garantiza evitar a un jugador que entra/teletransporta durante un tramo ya iniciado.
- No hay navegación de Guard, evasión del mundo ni separación entre targets.

## Rangos

Los campos numéricos de Flow usan `@editable_number` con límites y ToolTip. Runtime normaliza valores fuera de rango y sustituye NaN/Inf por defaults. Padding y longitud se adaptan a los bounds sin rechazar combinaciones normales.

Speed 10–2000; padding 0–1000000; heading 0–360; spread 0–180; TurnDistance 25–2000; Persistence 0–0.95; SideSwitchChance/Randomness 0–1; Seed 0–2147483646; PlayerClearance 0–2000. Unidades: cm, cm/s y grados.

## Evidencia

Modelo numérico: 45000 curvas, 495000 puntos de curva, 5845831 cuerdas; error máximo 1.99999898 cm, duración máxima 0.11999862 s. También independencia de streams, tangentes y exclusión de discos estáticos.

Los checks Verse ejercitan Run real con mocks, un objeto target y behavior compartidos, cancelación y orden Sleep/MoveTo. Están preparados, **no ejecutados en Fortnite ni certificados por compilación final**. El build quedó bloqueado por referencias eliminadas de Orbit; el usuario asumió compilación y prueba manual.

No se requiere Python para ejecutar Flow. Los auxiliares temporales de diagnóstico fueron retirados.

