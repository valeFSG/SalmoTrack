# SalmoTrack

Sistema de gestión de producción y cosecha para centros de cultivo de salmón, desarrollado en PL/SQL sobre Oracle Database.

**Asignatura:** Taller de Base de Datos (005V) — DUOC UC
**Autoras:** Valentina Santana · Nicol González

---

## Descripción

SalmoTrack automatiza el registro de biomasa, alimentación, monitoreo sanitario y cosecha en centros de cultivo de salmón, reemplazando el uso de planillas manuales separadas por centro. El sistema calcula indicadores como el factor de conversión alimenticia (FCA), genera alertas sanitarias automáticas ante brotes de caligus, y mantiene un historial de auditoría de los cambios de estado de cada jaula.

## Problema que resuelve

Antes de SalmoTrack, cada centro registraba biomasa, mortalidad y alimento a mano, generando:
- Descuadres entre lo sembrado y lo cosechado
- Errores en el cálculo del factor de conversión alimenticia (FCA)
- Retrasos en detectar brotes sanitarios a tiempo

## Tecnologías utilizadas

- **Oracle Database** (probado en Oracle 19c)
- **PL/SQL**
- **Oracle SQL Developer** como entorno de desarrollo

## Modelo de datos

Normalizado en tercera forma normal (3FN), con 9 tablas:

**Principales:**
- `CENTRO_CULTIVO` — centros de cultivo marino
- `JAULA` — jaulas de cultivo, con su biomasa y estado
- `LOTE_ALIMENTACION` — entregas de alimento por jaula
- `MONITOREO_SANITARIO` — registros de mortalidad y nivel de caligus
- `COSECHA` — registros de cosecha hacia planta de proceso
- `AUDITORIA_JAULA` — historial de cambios de estado de una jaula

**Catálogo** (para evitar redundancia de texto repetido):
- `ESPECIE`
- `PROVEEDOR`
- `PLANTA_PROCESO`

## Componentes PL/SQL

### Tipos de datos compuestos
- `r_resumen_jaula` (RECORD) — agrupa id, especie, biomasa, alimento, mortalidad y FCA de una jaula
- `t_alertas_sanitarias` (VARRAY(50)) — almacena los `id_jaula` en alerta de caligus

### Cursores
- `c_centros` — cursor sin parámetros, trae todos los centros
- `c_jaulas_centro(p_id_centro)` — cursor con parámetro, con JOIN entre `JAULA` y `ESPECIE`
- Ciclo anidado (maestro-detalle) para generar el reporte de FCA por centro y jaula

### Excepciones
- Predefinidas de Oracle: `NO_DATA_FOUND`, `ZERO_DIVIDE`
- Definidas por el usuario: `exc_biomasa_invalida` (-20001), `exc_calculo_biomasa` (-20002), `exc_monitoreo_invalido` (-20003)

### Package `pkg_gestion_cultivo`
Agrupa toda la lógica del sistema:

| Objeto | Tipo | Descripción |
|---|---|---|
| `actualizar_biomasa_jaula` | Procedimiento | Valida y actualiza la biomasa de una jaula |
| `registrar_monitoreo_sanitario` | Procedimiento | Registra un monitoreo sanitario y descuenta mortalidad |
| `registrar_cosecha` | Procedimiento | Registra una cosecha y descuenta biomasa |
| `calcular_fca` | Función | Retorna el factor de conversión alimenticia de una jaula |
| `reporte_fca_por_centro` | Procedimiento | Imprime el reporte de FCA agrupado por centro y jaula |
| `revisar_alertas_caligus` | Procedimiento | Detecta jaulas en alerta de caligus por centro |

### Triggers
- `trg_alerta_caligus` — `AFTER INSERT` en `MONITOREO_SANITARIO`; si `nivel_caligus > 3`, cambia el estado de la jaula a `'EN TRATAMIENTO'`
- `trg_auditoria_jaula` — `AFTER UPDATE OF estado` en `JAULA`; registra el cambio en `AUDITORIA_JAULA`

Ambos triggers actúan en cadena: un solo `INSERT` en monitoreo sanitario puede disparar automáticamente el cambio de estado y su registro de auditoría, sin intervención manual.

## Cómo ejecutar el proyecto

1. Abre SQL Developer y conéctate a tu esquema de Oracle.
2. Ejecuta el script completo (`salmotrack.sql`) con **Ejecutar Script (F5)**, no con "Ejecutar Sentencia" — el script contiene múltiples bloques separados por `/`.
3. El script, en orden:
   - Limpia el esquema (por si ya existían las tablas)
   - Crea las tablas de catálogo y principales, con sus índices
   - Carga datos de prueba (mínimo 10 registros por tabla principal)
   - Crea el package `pkg_gestion_cultivo` (spec + body)
   - Crea los triggers
4. Para ver el reporte de FCA:
```sql
   SET SERVEROUTPUT ON;
   BEGIN
       pkg_gestion_cultivo.reporte_fca_por_centro;
   END;
   /
```
5. Para ver las alertas sanitarias por centro:
```sql
   BEGIN
       pkg_gestion_cultivo.revisar_alertas_caligus(1);
   END;
   /
```

