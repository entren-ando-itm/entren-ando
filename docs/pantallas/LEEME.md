# Pantallas del diseño (ENT-12)

Son las pantallas aprobadas, exportadas del lienzo "Pantallas Entren-Ando" (390 × 844, tamaño de
celular). Cada una está en modo claro y oscuro. **Antes de programar o diseñar una pantalla, abre su
PNG y cópiala tal cual con los componentes de `lib/core/componentes`.**

| Pantalla | Claro | Oscuro | Historias | Componentes principales |
| --- | --- | --- | --- | --- |
| Inicio de sesión | `01_inicio_sesion.png` | `01_inicio_sesion_oscuro.png` | ENT-41, ENT-42 | `CampoTexto`, `Casilla`, `BotonPrincipal(grande: true)`, `BotonTexto` |
| Hoy | `02_hoy.png` | `02_hoy_oscuro.png` | ENT-20, ENT-40 | `EncabezadoPantalla`, `Pastilla(chica)`, `BotonPrincipal`, franjas con `Tarjeta(nivel: 1–4)` |
| Ejercicio y temporizador | `03_ejercicio.png` | `03_ejercicio_oscuro.png` | ENT-19, ENT-49, ENT-59 | `BotonCircular`, `BotonChico`, `NumeroConUnidad`, `BarraProgreso`, `BotonSecundario(nivel: 2)` |
| Calendario semáforo | `04_calendario.png` | `04_calendario_oscuro.png` | ENT-60 | `CirculoDia`, `PuntoSemaforo`, `ElementoLeyenda` |
| Calendario: tocar un día | `05_calendario_tocar_dia.png` | `05_calendario_tocar_dia_oscuro.png` | ENT-70 | `mostrarHojaInferior`, `EncabezadoHoja`, `FilaOpcion` |
| Comidas | `06_comidas.png` | `06_comidas_oscuro.png` | ENT-45, ENT-65 | `NumeroConUnidad(tamano: 104)`, `BarraSegmentos`, `Tarjeta` |
| Perfil y ajustes | `07_perfil.png` | `07_perfil_oscuro.png` | ENT-18, ENT-43, ENT-51 | `AvatarIniciales`, `TarjetaDato`, `Pastilla`, `GrupoFilas`, `FilaAjuste`, `SelectorSegmentos` |
| Premium | `08_premium.png` | `08_premium_oscuro.png` | ENT-52 | `EncabezadoPantalla(estiloTitulo: displaySmall)`, `BotonPrincipal(grande: true)` |
| Inicio de sesión sin red | `09_inicio_sesion_sin_red.png` | — | ENT-14, ENT-41 | `Aviso.sinRed`, botón desactivado |
| Comidas sin red | `10_comidas_sin_red.png` | — | ENT-14, ENT-65 | `InsigniaSinRed`, `Aviso.sinRed`, botón de cámara desactivado |

## Si tu pantalla no está aquí

1. Ármala con las mismas piezas: colores del tema, letra Barlow, superficies sólidas sin bordes ni
   sombras, margen de 28 a los lados y un solo botón principal.
2. Toma como modelo la pantalla más parecida de esta carpeta (por ejemplo, una lista se ve como las
   comidas; un formulario, como el inicio de sesión).
3. Antes del Pull Request, avísale a Pablo: él la agrega al lienzo y a esta carpeta para que quede
   como referencia.

Las reglas completas están en AGENTS.md, sección "Diseño visual". En la app puedes ver todos los
componentes en Perfil → Modo de prueba → "Ver componentes del diseño".
