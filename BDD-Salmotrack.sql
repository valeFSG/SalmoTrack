DROP TABLE planta_proceso CASCADE CONSTRAINTS;
DROP TABLE centro_cultivo CASCADE CONSTRAINTS;
DROP TABLE jaula CASCADE CONSTRAINTS;
DROP TABLE especie CASCADE CONSTRAINTS;
DROP TABLE historial_estado_jaula CASCADE CONSTRAINTS;
DROP TABLE cosecha CASCADE CONSTRAINTS;
DROP TABLE SIEMBRA CASCADE CONSTRAINTS;

-- ======== TABLAS ========

CREATE TABLE planta_proceso(
    id_planta   NUMBER  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR2 (100)  NOT NULL UNIQUE,
    comuna      VARCHAR2 (60)   NOT NULL,
    capacidad_tn_dia NUMBER     NOT NULL
        CHECK (capacidad_tn_dia > 0)
);

CREATE TABLE centro_cultivo (
    id_centro        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre           VARCHAR2(100) NOT NULL,
    comuna           VARCHAR2(60)  NOT NULL,
    region           VARCHAR2(60)  NOT NULL,
    estado           VARCHAR2(15)
        DEFAULT 'ACTIVO' -- por defecto activo
        CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    fecha_inicio_op  DATE       NOT NULL
);

CREATE TABLE especie ( -- especie cultivada
    id_especie         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_comun       VARCHAR2(60)  NOT NULL UNIQUE,
    nombre_cientifico  VARCHAR2(100) NOT NULL
);

CREATE TABLE jaula ( 
    id_jaula           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_centro          NUMBER        NOT NULL 
        REFERENCES centro_cultivo(id_centro), -- referencia a id centro cultivo
    id_especie        NUMBER        NOT NULL
        REFERENCES especie(id_especie),
    numero_jaula       NUMBER(3)     NOT NULL,
    capacidad_max_peces NUMBER(9)    NOT NULL
        CHECK (capacidad_max_peces > 0), -- capacidad de peces minimo 1
    volumen_m3         NUMBER(10,2)  NOT NULL
        CHECK (volumen_m3 > 0), -- volumen minimo 1
    estado             VARCHAR2(15)  
        DEFAULT 'VACIA' NOT NULL -- por defecto vacia
        CHECK (estado IN ('VACIA','EN_CULTIVO','EN_COSECHA','CUARENTENA','MANTENCION')), -- checkeo de estados especificos

    CONSTRAINT uq_jaula_centro_numero UNIQUE (id_centro, numero_jaula)
);
  
-- Siembra: un ciclo de cultivo de una jaula
CREATE TABLE siembra (
    id_siembra         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_jaula           NUMBER       NOT NULL
        REFERENCES jaula(id_jaula), -- referencia a id jaula
    id_especie         NUMBER       NOT NULL
        REFERENCES especie(id_especie), -- referencia a id jaula
    fecha_siembra      DATE         NOT NULL,
    cantidad_peces     NUMBER(9)    NOT NULL
        CHECK (cantidad_peces > 0), -- cantidad minima de peces: 1
    peso_promedio_g    NUMBER(7,2)  NOT NULL
        CHECK (peso_promedio_g > 0), -- peso minimo: 1
    fecha_cierre       DATE, 
    estado             VARCHAR2(15) NOT NULL
        CHECK (estado IN ('ABIERTA','COSECHADA','CERRADA')), -- checkeo de estados especificos

    -- restricción que involucra múltiples columnas debe ir al final de la tabla - se asegura que la fecha de cierre sea posterior a la de siembra
    CONSTRAINT chk_fecha_cierre CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_siembra)
);
 
-- Historial de cambios de estado de las jaulas (lo alimentará un trigger)
CREATE TABLE historial_estado_jaula (
    id_historial    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_jaula        NUMBER        NOT NULL
        REFERENCES jaula (id_jaula),
    estado_anterior VARCHAR2(15),
    estado_nuevo    VARCHAR2(15)  NOT NULL,
    fecha_cambio    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);
 

-- Cosecha enviada a la planta de proceso
CREATE TABLE cosecha (
    id_cosecha      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY ,
    id_siembra      NUMBER        NOT NULL
        REFERENCES siembra (id_siembra), -- referencia a id siembra
    id_planta       NUMBER        NOT NULL
        REFERENCES planta_proceso (id_planta), -- referencia a id planta proceso
    fecha_cosecha   DATE          NOT NULL,
    cantidad_peces  NUMBER(9)     NOT NULL
        CHECK (cantidad_peces > 0), -- capacidad de peces minimo 1
    peso_total_kg   NUMBER(12,2)  NOT NULL
        CHECK (peso_total_kg > 0), -- capacidad de peso minimo 1
    estado          VARCHAR2(12)  
    DEFAULT 'PROGRAMADA' NOT NULL -- por defecto en programada
    CHECK (estado IN ('PROGRAMADA','EN_PROCESO','ENTREGADA'))  -- checkeo de estados especificos
);



-- ======================================================== PACKAGE ========================================================


CREATE OR REPLACE PACKAGE pkg_salmotrack AS
 
    -- ======== EXCEPCIONES ========

    e_jaula_no_existe       EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_jaula_no_existe,       -20001);
    e_centro_no_existe      EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_centro_no_existe,      -20002);
    e_centro_inactivo       EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_centro_inactivo,       -20003);
    e_jaula_no_disponible   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_jaula_no_disponible,   -20004);
    e_capacidad_excedida    EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_capacidad_excedida,    -20005);
    e_transicion_invalida   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_transicion_invalida,   -20006);
    e_siembra_no_existe     EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_siembra_no_existe,     -20007);
    e_siembra_no_abierta    EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_siembra_no_abierta,    -20008);
    e_fecha_invalida        EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fecha_invalida,        -20009);
    e_cosecha_excede_peces  EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_cosecha_excede_peces,  -20010);
    e_planta_no_existe      EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_planta_no_existe,      -20011);
    e_planta_sin_capacidad  EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_planta_sin_capacidad,  -20012);
    e_especie_no_existe       EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_especie_no_existe,       -20013);
    e_cosecha_no_eliminable   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_cosecha_no_eliminable,   -20014);
    e_estado_cosecha_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_estado_cosecha_invalido, -20015);


    -- ======== TIPO COMPUESTO ========

    -- Resumen del estado de una siembra (lo devuelve fn_resumen_siembra)
    TYPE t_resumen_siembra IS RECORD (
        id_siembra          siembra.id_siembra%TYPE,
        id_jaula            siembra.id_jaula%TYPE,
        estado              siembra.estado%TYPE,
        peces_sembrados     siembra.cantidad_peces%TYPE,
        peces_cosechados    NUMBER,
        peces_restantes     NUMBER,
        peso_cosechado_kg   NUMBER
    );
 

    -- ======== FUNCIONES ========

    -- Total de peces cosechados de una siembra (0 si no hay cosechas)
    FUNCTION fn_peces_cosechados_siembra (
        p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN NUMBER;
 
    -- Dias de cultivo: hasta fecha_cierre o hasta hoy si sigue abierta
    FUNCTION fn_dias_cultivo (
        p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN NUMBER;

    -- Resumen de la siembra con variable compuesta
    FUNCTION fn_resumen_siembra (
      p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN t_resumen_siembra;

    -- Total de peces que siguen en el agua
    FUNCTION fn_total_peces_en_cultivo RETURN NUMBER;

    -- ======== PROCEDIMIENTOS ========

    -- reporte de todas las jaulas
    PROCEDURE pr_reporte_jaulas;

    -- Cambia el estado de una jaula validando la transicion
    PROCEDURE pr_cambiar_estado_jaula (
        p_id_jaula     IN jaula.id_jaula%TYPE,
        p_nuevo_estado IN jaula.estado%TYPE
    );
 
    -- Abre una siembra en una jaula vacia y la pasa a EN_CULTIVO
    PROCEDURE pr_registrar_siembra (
        p_id_jaula        IN  jaula.id_jaula%TYPE,
        p_id_especie      IN  especie.id_especie%TYPE,
        p_cantidad_peces  IN  siembra.cantidad_peces%TYPE,
        p_peso_promedio_g IN  siembra.peso_promedio_g%TYPE,
        p_fecha_siembra   IN  siembra.fecha_siembra%TYPE DEFAULT SYSDATE,
        p_id_siembra      OUT siembra.id_siembra%TYPE
    );
 
    /* Registra una cosecha hacia una planta. Si se cosechan todos los peces,
       cierra la siembra (COSECHADA) y deja la jaula VACIA */
    PROCEDURE pr_registrar_cosecha (
        p_id_siembra     IN  siembra.id_siembra%TYPE,
        p_id_planta      IN  planta_proceso.id_planta%TYPE,
        p_cantidad_peces IN  cosecha.cantidad_peces%TYPE,
        p_peso_total_kg  IN  cosecha.peso_total_kg%TYPE,
        p_fecha_cosecha  IN  cosecha.fecha_cosecha%TYPE DEFAULT SYSDATE,
        p_id_cosecha     OUT cosecha.id_cosecha%TYPE
    );
 
END pkg_salmotrack;
/

-- ======================================================== BODY PACKAGE ========================================================


CREATE OR REPLACE PACKAGE BODY pkg_salmotrack AS
 
    g_cosechas_sesion NUMBER := 0;
    

    -- ======== FUNCIONES ========

    FUNCTION fn_total_peces_en_cultivo RETURN NUMBER IS
      v_total NUMBER;
    BEGIN
      SELECT NVL(SUM(s.cantidad_peces - NVL(c.cosechados, 0)), 0)
        INTO v_total
        FROM siembra s
        LEFT JOIN (SELECT id_siembra, SUM(cantidad_peces) AS cosechados
                     FROM cosecha
                    GROUP BY id_siembra) c
          ON c.id_siembra = s.id_siembra
       WHERE s.estado = 'ABIERTA';
      RETURN v_total;
    END fn_total_peces_en_cultivo;


    FUNCTION fn_transicion_valida (
        p_estado_actual IN  jaula.estado%TYPE,
        p_estado_nuevo  IN  jaula.estado%TYPE,
        p_motivo        OUT VARCHAR2
        ) RETURN BOOLEAN IS
    BEGIN
        p_motivo := NULL;  -- si la transicion es valida, queda sin motivo

        -- 1. Faltan datos
        IF p_estado_actual IS NULL OR p_estado_nuevo IS NULL THEN
            p_motivo := 'El estado actual y el nuevo estado son obligatorios.';
            RETURN FALSE;
        END IF;

        -- 2. El estado nuevo no existe
        IF p_estado_nuevo NOT IN ('VACIA', 'EN_CULTIVO', 'EN_COSECHA', 'CUARENTENA', 'MANTENCION') THEN
            p_motivo := p_estado_nuevo || ' no es un estado valido de jaula.';
            RETURN FALSE;
        END IF;

        -- 3. Mismo estado
        IF p_estado_actual = p_estado_nuevo THEN
            p_motivo := 'La jaula ya esta en estado ' || p_estado_actual || '.';
            RETURN FALSE;
        END IF;

        -- 4. Transiciones permitidas segun el estado actual
        IF p_estado_actual = 'VACIA' THEN
            IF p_estado_nuevo IN ('EN_CULTIVO', 'MANTENCION') THEN
                RETURN TRUE;
            END IF;

            p_motivo := 'Desde vacia solo se puede pasar a en cultivo o mantencion.';
        ELSIF p_estado_actual = 'EN_CULTIVO' THEN
            IF p_estado_nuevo IN ('EN_COSECHA', 'CUARENTENA') THEN
                RETURN TRUE;
            END IF;

            p_motivo := 'Desde en cultivo solo se puede pasar a en cosecha o cuarentena.';
        ELSIF p_estado_actual = 'EN_COSECHA' THEN
            IF p_estado_nuevo IN ('VACIA', 'EN_CULTIVO') THEN
                RETURN TRUE;
            END IF;

            p_motivo := 'Desde en cosecha solo se puede pasar a vacia o en cultivo.';
        ELSIF p_estado_actual = 'CUARENTENA' THEN
            IF p_estado_nuevo IN ('EN_CULTIVO', 'EN_COSECHA') THEN
                RETURN TRUE;
            END IF;

            p_motivo := 'Desde cuarentena solo se puede pasar a en cultivo o en cosecha.';
        ELSIF p_estado_actual = 'MANTENCION' THEN
            IF p_estado_nuevo = 'VACIA' THEN
                RETURN TRUE;
            END IF;

            p_motivo := 'Desde mantencion solo se puede pasar a vacia.';
        ELSE
            -- El estado actual guardado no es reconocido
            p_motivo := 'El estado actual ' || p_estado_actual || ' no es reconocido.';
        END IF;

        RETURN FALSE;
    END fn_transicion_valida;


    FUNCTION fn_peces_cosechados_siembra (
        p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(cantidad_peces), 0)
          INTO v_total
          FROM cosecha
         WHERE id_siembra = p_id_siembra;
        RETURN v_total;
    END fn_peces_cosechados_siembra;
 

    FUNCTION fn_dias_cultivo (
        p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN NUMBER IS
        v_dias NUMBER;
    BEGIN
        SELECT TRUNC(NVL(fecha_cierre, SYSDATE)) - TRUNC(fecha_siembra)
          INTO v_dias
          FROM siembra
         WHERE id_siembra = p_id_siembra;
        RETURN v_dias;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007, 'La siembra ' || p_id_siembra || ' no existe.');
    END fn_dias_cultivo;
 
    FUNCTION fn_resumen_siembra (
      p_id_siembra IN siembra.id_siembra%TYPE
    ) RETURN t_resumen_siembra IS
      v_res t_resumen_siembra;
    BEGIN
      SELECT id_siembra, id_jaula, estado, cantidad_peces
        INTO v_res.id_siembra, v_res.id_jaula, v_res.estado, v_res.peces_sembrados
        FROM siembra
       WHERE id_siembra = p_id_siembra;

      SELECT NVL(SUM(cantidad_peces), 0), NVL(SUM(peso_total_kg), 0)
        INTO v_res.peces_cosechados, v_res.peso_cosechado_kg
        FROM cosecha
       WHERE id_siembra = p_id_siembra;

      v_res.peces_restantes := v_res.peces_sembrados - v_res.peces_cosechados;
      RETURN v_res;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RAISE_APPLICATION_ERROR(-20007, 'La siembra ' || p_id_siembra || ' no existe.');
    END fn_resumen_siembra;

    -- ======== PROCEDIMIENTOS ========

    PROCEDURE pr_traza (p_mensaje IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[SALMOTRACK] ' || p_mensaje);
    END pr_traza;


    PROCEDURE pr_reporte_jaulas IS
      CURSOR c_jaulas IS
          SELECT c.nombre AS centro, j.id_jaula, j.numero_jaula, j.estado, s.id_siembra
            FROM jaula j
            JOIN centro_cultivo c ON c.id_centro = j.id_centro
            LEFT JOIN siembra s ON s.id_jaula = j.id_jaula AND s.estado = 'ABIERTA'
           ORDER BY c.nombre, j.numero_jaula;
      v_res    t_resumen_siembra;
      v_jaulas NUMBER := 0;
    BEGIN
        pr_traza('===== REPORTE DE JAULAS =====');
        FOR r IN c_jaulas LOOP
            IF r.id_siembra IS NULL THEN
                pr_traza(r.centro || ' | Jaula ' || r.numero_jaula || ' | ' || r.estado
                         || ' | sin siembra abierta');
            ELSE
                v_res := fn_resumen_siembra(r.id_siembra);
                pr_traza(r.centro || ' | Jaula ' || r.numero_jaula || ' | ' || r.estado
                         || ' | Siembra ' || r.id_siembra
                         || ' | restantes: ' || v_res.peces_restantes
                         || ' | dias: ' || fn_dias_cultivo(r.id_siembra));
            END IF;
            v_jaulas := v_jaulas + 1;
        END LOOP;
        pr_traza('Jaulas revisadas: ' || v_jaulas
                 || ' | Peces en cultivo: ' || fn_total_peces_en_cultivo);
    END pr_reporte_jaulas;


    PROCEDURE pr_cambiar_estado_jaula (
        p_id_jaula     IN jaula.id_jaula%TYPE,
        p_nuevo_estado IN jaula.estado%TYPE
    ) IS
        v_estado_actual jaula.estado%TYPE;
        v_abiertas      NUMBER;
        v_motivo        VARCHAR2 (200);
    BEGIN
        -- Bloquea la fila para que nadie mas cambie la jaula a la vez
        BEGIN
            SELECT estado
              INTO v_estado_actual
              FROM jaula
             WHERE id_jaula = p_id_jaula
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'La jaula ' || p_id_jaula || ' no existe.');
        END;
 
        IF NOT fn_transicion_valida(v_estado_actual, p_nuevo_estado, v_motivo) THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Transicion no permitida (' || v_estado_actual || ' -> ' || p_nuevo_estado || '): ' || v_motivo);
        END IF;
 
        -- Coherencia entre el estado de la jaula y sus siembras
        SELECT COUNT(*)
          INTO v_abiertas
          FROM siembra
         WHERE id_jaula = p_id_jaula
           AND estado   = 'ABIERTA';
 
        IF p_nuevo_estado = 'EN_CULTIVO' AND v_abiertas = 0 THEN
            RAISE_APPLICATION_ERROR(-20006,
                'La jaula ' || p_id_jaula || ' no puede pasar a EN_CULTIVO sin una siembra abierta.');
        ELSIF p_nuevo_estado IN ('VACIA', 'MANTENCION') AND v_abiertas > 0 THEN
            RAISE_APPLICATION_ERROR(-20006,
                'La jaula ' || p_id_jaula || ' tiene una siembra abierta; no puede pasar a ' || p_nuevo_estado || '.');
        END IF;
 
        UPDATE jaula
           SET estado = p_nuevo_estado
         WHERE id_jaula = p_id_jaula;
 
        pr_traza('Jaula ' || p_id_jaula || ': ' || v_estado_actual || ' -> ' || p_nuevo_estado);
    END pr_cambiar_estado_jaula;
 
    PROCEDURE pr_registrar_siembra (
        p_id_jaula        IN  jaula.id_jaula%TYPE,
        p_id_especie      IN  especie.id_especie%TYPE,
        p_cantidad_peces  IN  siembra.cantidad_peces%TYPE,
        p_peso_promedio_g IN  siembra.peso_promedio_g%TYPE,
        p_fecha_siembra   IN  siembra.fecha_siembra%TYPE DEFAULT SYSDATE,
        p_id_siembra      OUT siembra.id_siembra%TYPE
    ) IS
        v_estado_jaula  jaula.estado%TYPE;
        v_capacidad     jaula.capacidad_max_peces%TYPE;
        v_estado_centro centro_cultivo.estado%TYPE;
        v_existe        NUMBER;
    BEGIN
        BEGIN
            SELECT j.estado, j.capacidad_max_peces, c.estado
              INTO v_estado_jaula, v_capacidad, v_estado_centro
              FROM jaula j
              JOIN centro_cultivo c ON c.id_centro = j.id_centro
             WHERE j.id_jaula = p_id_jaula
               FOR UPDATE OF j.estado;
               
            SELECT COUNT(*)
                INTO v_existe FROM especie 
                WHERE id_especie = p_id_especie;
                    IF v_existe = 0 THEN
                        RAISE_APPLICATION_ERROR(-20013, 'La especie ' || p_id_especie || ' no existe.');
                    END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'La jaula ' || p_id_jaula || ' no existe.');
        END;
 
        IF v_estado_centro IS NULL OR v_estado_centro <> 'ACTIVO' THEN
            RAISE_APPLICATION_ERROR(-20003, 'El centro de la jaula ' || p_id_jaula || ' no esta ACTIVO.');
        END IF;
 
        IF v_estado_jaula <> 'VACIA' THEN
            RAISE_APPLICATION_ERROR(-20004,
                'La jaula ' || p_id_jaula || ' no esta disponible (estado actual: ' || v_estado_jaula || ').');
        END IF;
 
        IF p_cantidad_peces > v_capacidad THEN
            RAISE_APPLICATION_ERROR(-20005,
                'La siembra (' || p_cantidad_peces || ' peces) excede la capacidad de la jaula (' || v_capacidad || ').');
        END IF;
 
        INSERT INTO siembra (id_jaula, id_especie, fecha_siembra, cantidad_peces, peso_promedio_g, estado)
        VALUES (p_id_jaula, p_id_especie, TRUNC(p_fecha_siembra), p_cantidad_peces, p_peso_promedio_g, 'ABIERTA')
        RETURNING id_siembra INTO p_id_siembra;
 
        pr_traza('Siembra ' || p_id_siembra || ' registrada en la jaula ' || p_id_jaula
                 || ' (' || p_cantidad_peces || ' peces)');
 
        pr_cambiar_estado_jaula(p_id_jaula, 'EN_CULTIVO');
    END pr_registrar_siembra;
 
    PROCEDURE pr_registrar_cosecha (
        p_id_siembra     IN  siembra.id_siembra%TYPE,
        p_id_planta      IN  planta_proceso.id_planta%TYPE,
        p_cantidad_peces IN  cosecha.cantidad_peces%TYPE,
        p_peso_total_kg  IN  cosecha.peso_total_kg%TYPE,
        p_fecha_cosecha  IN  cosecha.fecha_cosecha%TYPE DEFAULT SYSDATE,
        p_id_cosecha     OUT cosecha.id_cosecha%TYPE
    ) IS
        v_siembra        siembra%ROWTYPE;
        v_capacidad_tn   planta_proceso.capacidad_tn_dia%TYPE;
        v_tn_programadas NUMBER;
        v_cosechados     NUMBER;
        v_estado_jaula   jaula.estado%TYPE;
    BEGIN
        -- 1. La siembra debe existir y estar abierta
        BEGIN
            SELECT *
              INTO v_siembra
              FROM siembra
             WHERE id_siembra = p_id_siembra
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20007, 'La siembra ' || p_id_siembra || ' no existe.');
        END;
 
        IF v_siembra.estado <> 'ABIERTA' THEN
            RAISE_APPLICATION_ERROR(-20008,
                'La siembra ' || p_id_siembra || ' no esta ABIERTA (estado actual: ' || v_siembra.estado || ').');
        END IF;
 
        IF TRUNC(p_fecha_cosecha) < TRUNC(v_siembra.fecha_siembra) THEN
            RAISE_APPLICATION_ERROR(-20009, 'La fecha de cosecha es anterior a la fecha de siembra.');
        END IF;
 
        -- 2. La planta debe existir
        BEGIN
            SELECT capacidad_tn_dia
              INTO v_capacidad_tn
              FROM planta_proceso
             WHERE id_planta = p_id_planta;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20011, 'La planta ' || p_id_planta || ' no existe.');
        END;
 
        -- 3. No se pueden cosechar mas peces de los que quedan
        v_cosechados := fn_peces_cosechados_siembra(p_id_siembra);
        IF p_cantidad_peces > v_siembra.cantidad_peces - v_cosechados THEN
            RAISE_APPLICATION_ERROR(-20010,
                'Se intentan cosechar ' || p_cantidad_peces || ' peces pero solo quedan '
                || (v_siembra.cantidad_peces - v_cosechados) || '.');
        END IF;
 
        -- 4. La planta no puede superar su capacidad diaria (toneladas)
        SELECT NVL(SUM(peso_total_kg), 0) / 1000
          INTO v_tn_programadas
          FROM cosecha
         WHERE id_planta = p_id_planta
           AND TRUNC(fecha_cosecha) = TRUNC(p_fecha_cosecha);
 
        IF v_tn_programadas + p_peso_total_kg / 1000 > v_capacidad_tn THEN
            RAISE_APPLICATION_ERROR(-20012,
                'La planta ' || p_id_planta || ' supera su capacidad diaria de ' || v_capacidad_tn || ' toneladas.');
        END IF;
 
        -- 5. Registrar la cosecha
        INSERT INTO cosecha (id_siembra, id_planta, fecha_cosecha, cantidad_peces, peso_total_kg)
        VALUES (p_id_siembra, p_id_planta, TRUNC(p_fecha_cosecha), p_cantidad_peces, p_peso_total_kg)
        RETURNING id_cosecha INTO p_id_cosecha;
 
        -- 6. Actualizar estados: la jaula pasa a EN_COSECHA con la primera cosecha
        SELECT estado
          INTO v_estado_jaula
          FROM jaula
         WHERE id_jaula = v_siembra.id_jaula
           FOR UPDATE;
 
        IF v_estado_jaula IN ('EN_CULTIVO', 'CUARENTENA') THEN
            pr_cambiar_estado_jaula(v_siembra.id_jaula, 'EN_COSECHA');
        END IF;
 
        -- Si ya no quedan peces: se cierra la siembra y la jaula queda vacia
        IF v_cosechados + p_cantidad_peces = v_siembra.cantidad_peces THEN
            UPDATE siembra
               SET estado       = 'COSECHADA',
                   fecha_cierre = TRUNC(p_fecha_cosecha)
             WHERE id_siembra = p_id_siembra;
 
            pr_cambiar_estado_jaula(v_siembra.id_jaula, 'VACIA');
        END IF;
 
        -- Se incrementa al final: solo cuenta si todo lo anterior salio bien
        g_cosechas_sesion := g_cosechas_sesion + 1;
        pr_traza('Cosecha ' || p_id_cosecha || ' registrada: ' || p_cantidad_peces
                 || ' peces, ' || p_peso_total_kg || ' kg (cosechas en la sesion: '
                 || g_cosechas_sesion || ')');
    END pr_registrar_cosecha;
 
END pkg_salmotrack;
/

CREATE OR REPLACE TRIGGER trg_jaula_historial
AFTER INSERT OR UPDATE OF estado ON jaula
FOR EACH ROW
BEGIN
    IF INSERTING OR :OLD.estado <> :NEW.estado THEN
          INSERT INTO historial_estado_jaula (id_jaula, estado_anterior, estado_nuevo)
          VALUES (:NEW.id_jaula, :OLD.estado, :NEW.estado);
    END IF;
END;
/

  -- NIVEL DE SENTENCIA: prohibe eliminar cosechas (trazabilidad)
CREATE OR REPLACE TRIGGER trg_cosecha_no_eliminar
BEFORE DELETE ON cosecha
BEGIN
      RAISE_APPLICATION_ERROR(-20014, 
          'No se permite eliminar cosechas: son parte de la trazabilidad del cultivo.');
END;
/

  -- NIVEL DE FILA: el estado de una cosecha solo avanza PROGRAMADA -> EN_PROCESO -> ENTREGADA
CREATE OR REPLACE TRIGGER trg_cosecha_estado
BEFORE UPDATE OF estado ON cosecha
FOR EACH ROW 
WHEN (NEW.estado <> OLD.estado)
BEGIN
    IF NOT (   (:OLD.estado = 'PROGRAMADA' AND :NEW.estado = 'EN_PROCESO')
            OR (:OLD.estado = 'EN_PROCESO' AND :NEW.estado = 'ENTREGADA')) THEN
        RAISE_APPLICATION_ERROR(-20015,
            'Cambio de estado de cosecha no permitido: ' || :OLD.estado || ' -> ' || :NEW.estado);
    END IF;
END;
/


-- ======================================================== INSERTS ========================================================


--  PLANTA_PROCESO 
INSERT INTO planta_proceso (nombre, comuna, capacidad_tn_dia)
VALUES ('Planta Chinquihue', 'Puerto Montt', 50);

INSERT INTO planta_proceso (nombre, comuna, capacidad_tn_dia)
VALUES ('Planta Calbuco Sur', 'Calbuco', 40);



--  CENTRO_CULTIVO 
INSERT INTO centro_cultivo (nombre, comuna, region, estado, fecha_inicio_op)
VALUES ('Centro Reloncaví', 'Cochamó', 'Los Lagos', 'ACTIVO', DATE '2020-03-15');

INSERT INTO centro_cultivo (nombre, comuna, region, estado, fecha_inicio_op)
VALUES ('Centro Quellón Norte', 'Quellón', 'Los Lagos', 'INACTIVO', DATE '2018-09-01');



--  ESPECIE 
INSERT INTO especie (nombre_comun, nombre_cientifico)
VALUES ('Salmón del Atlántico', 'Salmo salar');

INSERT INTO especie (nombre_comun, nombre_cientifico)
VALUES ('Trucha arcoíris', 'Oncorhynchus mykiss');



--  JAULA 
INSERT INTO jaula (id_centro, id_especie, numero_jaula, capacidad_max_peces, volumen_m3, estado)
VALUES (1, 1, 1, 12000, 8500.50, 'EN_COSECHA');

INSERT INTO jaula (id_centro, id_especie, numero_jaula, capacidad_max_peces, volumen_m3, estado)
VALUES (1, 2, 2, 8000, 6000.00, 'VACIA');

INSERT INTO jaula (id_centro, id_especie, numero_jaula, capacidad_max_peces, volumen_m3, estado)
VALUES (2, 1, 1, 10000, 7000.00, 'VACIA');
COMMIT;

SELECT id_jaula, id_centro, estado FROM jaula;



--  SIEMBRA 
-- Siembra 1: abierta, jaula 1 (cosecha parcial en curso)
INSERT INTO siembra (id_jaula, id_especie, fecha_siembra, cantidad_peces, peso_promedio_g, fecha_cierre, estado)
VALUES (1, 1, DATE '2026-03-10', 10000, 80.50, NULL, 'ABIERTA');



-- Siembra 2: ya cosechada y cerrada, jaula 2
INSERT INTO siembra (id_jaula, id_especie, fecha_siembra, cantidad_peces, peso_promedio_g, fecha_cierre, estado)
VALUES (2, 2, DATE '2025-06-01', 5000, 60.00, DATE '2026-01-20', 'COSECHADA');



--  HISTORIAL_ESTADO_JAULA 
INSERT INTO historial_estado_jaula (id_jaula, estado_anterior, estado_nuevo)
VALUES (1, 'EN_CULTIVO', 'EN_COSECHA');

INSERT INTO historial_estado_jaula (id_jaula, estado_anterior, estado_nuevo)
VALUES (2, 'EN_COSECHA', 'VACIA');



--  COSECHA 
-- Cosecha parcial de la siembra 1 (2.000 de 10.000 peces, 8 tn < 50 tn de la planta)
INSERT INTO cosecha (id_siembra, id_planta, fecha_cosecha, cantidad_peces, peso_total_kg, estado)
VALUES (1, 1, DATE '2026-10-20', 2000, 8000.00, 'PROGRAMADA');



-- Cosecha total de la siembra 2 (5.000 peces, 25 tn < 40 tn de la planta)
INSERT INTO cosecha (id_siembra, id_planta, fecha_cosecha, cantidad_peces, peso_total_kg, estado)
VALUES (2, 2, DATE '2026-01-20', 5000, 25000.00, 'ENTREGADA');

COMMIT;
