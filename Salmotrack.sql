/* ============================================================
   SALMOTRACK - SISTEMA DE GESTIÓN DE PRODUCCIÓN Y COSECHA
   PARA CENTROS DE CULTIVO DE SALMÓN
   ============================================================ */


/* ============================================================
   LIMPIEZA DEL ESQUEMA
   Permite ejecutar nuevamente el script sin errores por tablas
   previamente existentes.
   ============================================================ */

BEGIN
    FOR T IN (
        SELECT TABLE_NAME
        FROM USER_TABLES
        WHERE TABLE_NAME IN (
            'AUDITORIA_JAULA',
            'COSECHA',
            'MONITOREO_SANITARIO',
            'LOTE_ALIMENTACION',
            'JAULA',
            'CENTRO_CULTIVO',
            'PROVEEDOR',
            'PLANTA_PROCESO',
            'ESPECIE'
        )
    ) LOOP
        EXECUTE IMMEDIATE
            'DROP TABLE ' || T.TABLE_NAME || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/


/* ============================================================
   ESPECIE (catalogo -> elimina dependencia transitiva en JAULA)
   ============================================================ */

CREATE TABLE ESPECIE (
    id_especie      NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre_especie  VARCHAR2(50) NOT NULL,

    CONSTRAINT pk_especie
        PRIMARY KEY (id_especie),

    CONSTRAINT uk_especie_nombre
        UNIQUE (nombre_especie)
);


/* ============================================================
   PROVEEDOR (catalogo -> elimina dependencia transitiva en LOTE)
   ============================================================ */

CREATE TABLE PROVEEDOR (
    id_proveedor      NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre_proveedor  VARCHAR2(100) NOT NULL,

    CONSTRAINT pk_proveedor
        PRIMARY KEY (id_proveedor),

    CONSTRAINT uk_proveedor_nombre
        UNIQUE (nombre_proveedor)
);


/* ============================================================
   PLANTA_PROCESO (catalogo -> elimina dependencia transitiva en COSECHA)
   ============================================================ */

CREATE TABLE PLANTA_PROCESO (
    id_planta      NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre_planta  VARCHAR2(100) NOT NULL,

    CONSTRAINT pk_planta_proceso
        PRIMARY KEY (id_planta),

    CONSTRAINT uk_planta_nombre
        UNIQUE (nombre_planta)
);


/* ============================================================
   CENTRO_CULTIVO
   ============================================================ */

CREATE TABLE CENTRO_CULTIVO (
    id_centro             NUMBER GENERATED ALWAYS AS IDENTITY,
    nombre                VARCHAR2(100) NOT NULL,
    ubicacion             VARCHAR2(150) NOT NULL,
    capacidad_maxima_kg   NUMBER NOT NULL,

    CONSTRAINT pk_centro_cultivo
        PRIMARY KEY (id_centro),

    CONSTRAINT uk_centro_nombre
        UNIQUE (nombre),

    CONSTRAINT ck_centro_capacidad
        CHECK (capacidad_maxima_kg > 0)
);


/* ============================================================
   JAULA
   ============================================================ */

CREATE TABLE JAULA (
    id_jaula        NUMBER GENERATED ALWAYS AS IDENTITY,
    id_centro       NUMBER NOT NULL,
    id_especie      NUMBER NOT NULL,
    fecha_siembra   DATE NOT NULL,
    biomasa_actual  NUMBER NOT NULL,
    estado          VARCHAR2(30) DEFAULT 'ACTIVA' NOT NULL,

    CONSTRAINT pk_jaula
        PRIMARY KEY (id_jaula),

    CONSTRAINT fk_jaula_centro
        FOREIGN KEY (id_centro)
        REFERENCES CENTRO_CULTIVO (id_centro),

    CONSTRAINT fk_jaula_especie
        FOREIGN KEY (id_especie)
        REFERENCES ESPECIE (id_especie),

    CONSTRAINT ck_jaula_biomasa
        CHECK (biomasa_actual >= 0),

    CONSTRAINT ck_jaula_estado
        CHECK (estado IN ('ACTIVA', 'EN TRATAMIENTO', 'COSECHADA'))
);


/* ============================================================
   LOTE_ALIMENTACION
   ============================================================ */

CREATE TABLE LOTE_ALIMENTACION (
    id_lote       NUMBER GENERATED ALWAYS AS IDENTITY,
    id_jaula      NUMBER NOT NULL,
    fecha         DATE NOT NULL,
    kg_alimento   NUMBER NOT NULL,
    id_proveedor  NUMBER NOT NULL,

    CONSTRAINT pk_lote_alimentacion
        PRIMARY KEY (id_lote),

    CONSTRAINT fk_lote_jaula
        FOREIGN KEY (id_jaula)
        REFERENCES JAULA (id_jaula),

    CONSTRAINT fk_lote_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES PROVEEDOR (id_proveedor),

    CONSTRAINT ck_lote_kg_alimento
        CHECK (kg_alimento > 0)
);


/* ============================================================
   MONITOREO_SANITARIO
   ============================================================ */

CREATE TABLE MONITOREO_SANITARIO (
    id_registro    NUMBER GENERATED ALWAYS AS IDENTITY,
    id_jaula       NUMBER NOT NULL,
    fecha          DATE NOT NULL,
    mortalidad     NUMBER NOT NULL,
    nivel_caligus  NUMBER NOT NULL,
    tratamiento    VARCHAR2(100),

    CONSTRAINT pk_monitoreo_sanitario
        PRIMARY KEY (id_registro),

    CONSTRAINT fk_monitoreo_jaula
        FOREIGN KEY (id_jaula)
        REFERENCES JAULA (id_jaula),

    CONSTRAINT ck_monitoreo_mortalidad
        CHECK (mortalidad >= 0),

    CONSTRAINT ck_monitoreo_caligus
        CHECK (nivel_caligus >= 0)
);


/* ============================================================
   COSECHA
   ============================================================ */

CREATE TABLE COSECHA (
    id_cosecha     NUMBER GENERATED ALWAYS AS IDENTITY,
    id_jaula       NUMBER NOT NULL,
    fecha          DATE NOT NULL,
    kg_cosechados  NUMBER NOT NULL,
    id_planta      NUMBER NOT NULL,

    CONSTRAINT pk_cosecha
        PRIMARY KEY (id_cosecha),

    CONSTRAINT fk_cosecha_jaula
        FOREIGN KEY (id_jaula)
        REFERENCES JAULA (id_jaula),

    CONSTRAINT fk_cosecha_planta
        FOREIGN KEY (id_planta)
        REFERENCES PLANTA_PROCESO (id_planta),

    CONSTRAINT ck_cosecha_kg
        CHECK (kg_cosechados > 0)
);


/* ============================================================
   AUDITORIA_JAULA (para el trigger de auditoria que veremos despues)
   ============================================================ */

CREATE TABLE AUDITORIA_JAULA (
    id_auditoria     NUMBER GENERATED ALWAYS AS IDENTITY,
    id_jaula         NUMBER NOT NULL,
    fecha_cambio     DATE NOT NULL,
    estado_anterior  VARCHAR2(30),
    estado_nuevo     VARCHAR2(30),

    CONSTRAINT pk_auditoria_jaula
        PRIMARY KEY (id_auditoria),

    CONSTRAINT fk_auditoria_jaula
        FOREIGN KEY (id_jaula)
        REFERENCES JAULA (id_jaula)
);


/* ============================================================
   INDICES PARA FOREIGN KEYS
   ============================================================ */

CREATE INDEX idx_jaula_centro
    ON JAULA (id_centro);

CREATE INDEX idx_jaula_especie
    ON JAULA (id_especie);

CREATE INDEX idx_lote_jaula
    ON LOTE_ALIMENTACION (id_jaula);

CREATE INDEX idx_lote_proveedor
    ON LOTE_ALIMENTACION (id_proveedor);

CREATE INDEX idx_monitoreo_jaula
    ON MONITOREO_SANITARIO (id_jaula);

CREATE INDEX idx_cosecha_jaula
    ON COSECHA (id_jaula);

CREATE INDEX idx_cosecha_planta
    ON COSECHA (id_planta);

CREATE INDEX idx_auditoria_jaula
    ON AUDITORIA_JAULA (id_jaula);


/* ============================================================
   DATOS DE PRUEBA
   Se capturan los IDs generados por IDENTITY con RETURNING INTO
   para poder referenciarlos en las tablas hijas.
   ============================================================ */

DECLARE
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

    v_especie   t_ids;
    v_proveedor t_ids;
    v_planta    t_ids;
    v_centro    t_ids;
    v_jaula     t_ids;
BEGIN
    -- ESPECIE
    INSERT INTO ESPECIE (nombre_especie) VALUES ('Salmón Atlántico') RETURNING id_especie INTO v_especie(1);
    INSERT INTO ESPECIE (nombre_especie) VALUES ('Salmón Coho')      RETURNING id_especie INTO v_especie(2);
    INSERT INTO ESPECIE (nombre_especie) VALUES ('Trucha')           RETURNING id_especie INTO v_especie(3);

    -- PROVEEDOR
    INSERT INTO PROVEEDOR (nombre_proveedor) VALUES ('AlimentSur SpA')      RETURNING id_proveedor INTO v_proveedor(1);
    INSERT INTO PROVEEDOR (nombre_proveedor) VALUES ('NutriSalmón Ltda')    RETURNING id_proveedor INTO v_proveedor(2);
    INSERT INTO PROVEEDOR (nombre_proveedor) VALUES ('Pesquera Los Lagos')  RETURNING id_proveedor INTO v_proveedor(3);

    -- PLANTA_PROCESO
    INSERT INTO PLANTA_PROCESO (nombre_planta) VALUES ('Planta Puerto Montt') RETURNING id_planta INTO v_planta(1);
    INSERT INTO PLANTA_PROCESO (nombre_planta) VALUES ('Planta Chiloé')       RETURNING id_planta INTO v_planta(2);
    INSERT INTO PLANTA_PROCESO (nombre_planta) VALUES ('Planta Calbuco')      RETURNING id_planta INTO v_planta(3);

    -- CENTRO_CULTIVO
    INSERT INTO CENTRO_CULTIVO (nombre, ubicacion, capacidad_maxima_kg)
        VALUES ('Centro Reloncaví', 'Reloncaví, Los Lagos', 50000) RETURNING id_centro INTO v_centro(1);
    INSERT INTO CENTRO_CULTIVO (nombre, ubicacion, capacidad_maxima_kg)
        VALUES ('Centro Chiloé Sur', 'Chiloé, Los Lagos', 40000) RETURNING id_centro INTO v_centro(2);
    INSERT INTO CENTRO_CULTIVO (nombre, ubicacion, capacidad_maxima_kg)
        VALUES ('Centro Calbuco', 'Calbuco, Los Lagos', 35000) RETURNING id_centro INTO v_centro(3);

    -- JAULA (10 jaulas repartidas en los 3 centros)
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(1), v_especie(1), DATE '2026-01-15', 12000) RETURNING id_jaula INTO v_jaula(1);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(1), v_especie(1), DATE '2026-02-01', 9000) RETURNING id_jaula INTO v_jaula(2);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(1), v_especie(2), DATE '2026-02-10', 7500) RETURNING id_jaula INTO v_jaula(3);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(1), v_especie(1), DATE '2026-03-01', 11000) RETURNING id_jaula INTO v_jaula(4);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(2), v_especie(3), DATE '2026-01-20', 8000) RETURNING id_jaula INTO v_jaula(5);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(2), v_especie(3), DATE '2026-01-25', 8500) RETURNING id_jaula INTO v_jaula(6);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(2), v_especie(2), DATE '2026-02-05', 6000) RETURNING id_jaula INTO v_jaula(7);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(3), v_especie(1), DATE '2026-01-18', 9500) RETURNING id_jaula INTO v_jaula(8);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(3), v_especie(1), DATE '2026-02-12', 10200) RETURNING id_jaula INTO v_jaula(9);
    INSERT INTO JAULA (id_centro, id_especie, fecha_siembra, biomasa_actual)
        VALUES (v_centro(3), v_especie(3), DATE '2026-02-20', 7000) RETURNING id_jaula INTO v_jaula(10);

    -- LOTE_ALIMENTACION
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(1), DATE '2026-08-01', 500, v_proveedor(1));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(1), DATE '2026-08-15', 480, v_proveedor(1));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(2), DATE '2026-08-05', 300, v_proveedor(2));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(3), DATE '2026-08-10', 250, v_proveedor(2));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(4), DATE '2026-08-12', 400, v_proveedor(1));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(5), DATE '2026-08-03', 280, v_proveedor(2));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(6), DATE '2026-08-06', 260, v_proveedor(2));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(7), DATE '2026-08-08', 220, v_proveedor(1));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(8), DATE '2026-08-11', 350, v_proveedor(3));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(9), DATE '2026-08-14', 370, v_proveedor(3));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(10), DATE '2026-08-16', 240, v_proveedor(3));
    INSERT INTO LOTE_ALIMENTACION (id_jaula, fecha, kg_alimento, id_proveedor) VALUES (v_jaula(2), DATE '2026-08-20', 310, v_proveedor(1));

    -- MONITOREO_SANITARIO
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(1), DATE '2026-08-20', 15, 1, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(2), DATE '2026-08-20', 8, 4, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(3), DATE '2026-08-21', 5, 2, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(4), DATE '2026-08-21', 10, 0, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(5), DATE '2026-08-22', 6, 5, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(6), DATE '2026-08-22', 4, 1, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(7), DATE '2026-08-23', 3, 6, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(8), DATE '2026-08-23', 12, 2, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(9), DATE '2026-08-24', 7, 0, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(10), DATE '2026-08-24', 9, 4, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(1), DATE '2026-08-27', 5, 2, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento) VALUES (v_jaula(8), DATE '2026-08-28', 6, 1, NULL);
    INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento)
VALUES (1, SYSDATE, 3, 5, NULL);

COMMIT;
    -- COSECHA
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(1), DATE '2026-08-30', 2000, v_planta(1));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(2), DATE '2026-08-30', 1500, v_planta(1));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(3), DATE '2026-08-31', 1200, v_planta(3));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(4), DATE '2026-09-01', 1800, v_planta(1));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(5), DATE '2026-09-01', 900, v_planta(2));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(6), DATE '2026-09-02', 1000, v_planta(2));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(7), DATE '2026-09-02', 700, v_planta(2));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(8), DATE '2026-09-03', 1300, v_planta(3));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(9), DATE '2026-09-03', 1400, v_planta(3));
    INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta) VALUES (v_jaula(10), DATE '2026-09-04', 950, v_planta(3));

    COMMIT;
END;
/


/* ============================================================
   VERIFICACION RAPIDA
   ============================================================ */

SELECT * FROM CENTRO_CULTIVO;
SELECT * FROM JAULA;
SELECT * FROM LOTE_ALIMENTACION;
SELECT * FROM MONITOREO_SANITARIO;
SELECT * FROM COSECHA;

/* ============================================================
   PACKAGE SPEC: pkg_gestion_cultivo
   RECORD, VARRAY, excepciones y firmas de subprogramas
   ============================================================ */

CREATE OR REPLACE PACKAGE pkg_gestion_cultivo AS

    c_umbral_caligus CONSTANT NUMBER := 3;

    TYPE r_resumen_jaula IS RECORD (
        id_jaula           JAULA.id_jaula%TYPE,
        nombre_especie     ESPECIE.nombre_especie%TYPE,
        biomasa_actual     JAULA.biomasa_actual%TYPE,
        total_alimento_kg  NUMBER,
        total_mortalidad   NUMBER,
        fca                NUMBER
    );

    TYPE t_alertas_sanitarias IS VARRAY(50) OF NUMBER;

    exc_biomasa_invalida    EXCEPTION;
    exc_calculo_biomasa     EXCEPTION;
    exc_monitoreo_invalido  EXCEPTION;
    PRAGMA EXCEPTION_INIT(exc_biomasa_invalida, -20001);
    PRAGMA EXCEPTION_INIT(exc_calculo_biomasa, -20002);
    PRAGMA EXCEPTION_INIT(exc_monitoreo_invalido, -20003);

    PROCEDURE actualizar_biomasa_jaula(p_id_jaula NUMBER, p_delta_kg NUMBER);
    PROCEDURE registrar_monitoreo_sanitario(p_id_jaula NUMBER, p_fecha DATE, p_mortalidad NUMBER, p_nivel_caligus NUMBER, p_tratamiento VARCHAR2);
    PROCEDURE registrar_cosecha(p_id_jaula NUMBER, p_fecha DATE, p_kg_cosechados NUMBER, p_id_planta NUMBER);
    FUNCTION calcular_fca(p_id_jaula NUMBER) RETURN NUMBER;
    PROCEDURE reporte_fca_por_centro;
    PROCEDURE revisar_alertas_caligus(p_id_centro NUMBER);

END pkg_gestion_cultivo;
/


/* ============================================================
   PACKAGE BODY: pkg_gestion_cultivo
   ============================================================ */

CREATE OR REPLACE PACKAGE BODY pkg_gestion_cultivo AS

    PROCEDURE actualizar_biomasa_jaula(p_id_jaula NUMBER, p_delta_kg NUMBER) IS
        v_biomasa_actual   NUMBER;
        v_capacidad_maxima NUMBER;
        v_biomasa_nueva    NUMBER;
    BEGIN
        SELECT j.biomasa_actual, c.capacidad_maxima_kg
        INTO v_biomasa_actual, v_capacidad_maxima
        FROM JAULA j JOIN CENTRO_CULTIVO c ON j.id_centro = c.id_centro
        WHERE j.id_jaula = p_id_jaula;

        v_biomasa_nueva := v_biomasa_actual + p_delta_kg;

        IF v_biomasa_nueva < 0 OR v_biomasa_nueva > v_capacidad_maxima THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Biomasa inválida para la jaula ' || p_id_jaula || ': ' || v_biomasa_nueva);
        END IF;

        UPDATE JAULA SET biomasa_actual = v_biomasa_nueva WHERE id_jaula = p_id_jaula;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No se encontró la jaula ' || p_id_jaula || ' o su centro.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20002, 'Error al actualizar biomasa: ' || SQLERRM);
    END actualizar_biomasa_jaula;

    PROCEDURE registrar_monitoreo_sanitario(p_id_jaula NUMBER, p_fecha DATE, p_mortalidad NUMBER,
                                             p_nivel_caligus NUMBER, p_tratamiento VARCHAR2) IS
        v_existe NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_existe FROM JAULA WHERE id_jaula = p_id_jaula;

        IF v_existe = 0 OR p_mortalidad < 0 OR p_nivel_caligus < 0 THEN
            RAISE exc_monitoreo_invalido;
        END IF;

        INSERT INTO MONITOREO_SANITARIO (id_jaula, fecha, mortalidad, nivel_caligus, tratamiento)
        VALUES (p_id_jaula, p_fecha, p_mortalidad, p_nivel_caligus, p_tratamiento);

        actualizar_biomasa_jaula(p_id_jaula, -p_mortalidad);
        COMMIT;

    EXCEPTION
        WHEN exc_monitoreo_invalido THEN
            RAISE_APPLICATION_ERROR(-20003, 'Registro de monitoreo inválido para la jaula ' || p_id_jaula);
    END registrar_monitoreo_sanitario;

    PROCEDURE registrar_cosecha(p_id_jaula NUMBER, p_fecha DATE, p_kg_cosechados NUMBER, p_id_planta NUMBER) IS
    BEGIN
        INSERT INTO COSECHA (id_jaula, fecha, kg_cosechados, id_planta)
        VALUES (p_id_jaula, p_fecha, p_kg_cosechados, p_id_planta);

        actualizar_biomasa_jaula(p_id_jaula, -p_kg_cosechados);
        COMMIT;
    END registrar_cosecha;

    FUNCTION calcular_fca(p_id_jaula NUMBER) RETURN NUMBER IS
        v_total_alimento  NUMBER;
        v_total_cosechado NUMBER;
    BEGIN
        SELECT NVL(SUM(kg_alimento), 0) INTO v_total_alimento
        FROM LOTE_ALIMENTACION WHERE id_jaula = p_id_jaula;

        SELECT NVL(SUM(kg_cosechados), 0) INTO v_total_cosechado
        FROM COSECHA WHERE id_jaula = p_id_jaula;

        RETURN v_total_alimento / NULLIF(v_total_cosechado, 0);
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            RETURN NULL;
    END calcular_fca;

    PROCEDURE reporte_fca_por_centro IS
        CURSOR c_centros IS
            SELECT id_centro, nombre FROM CENTRO_CULTIVO;

        CURSOR c_jaulas_centro(p_id_centro NUMBER) IS
            SELECT j.id_jaula, e.nombre_especie, j.biomasa_actual
            FROM JAULA j JOIN ESPECIE e ON j.id_especie = e.id_especie
            WHERE j.id_centro = p_id_centro;

        v_resumen r_resumen_jaula;
    BEGIN
        FOR centro IN c_centros LOOP
            DBMS_OUTPUT.PUT_LINE('=== Centro: ' || centro.nombre || ' ===');

            FOR jaula IN c_jaulas_centro(centro.id_centro) LOOP
                v_resumen.id_jaula := jaula.id_jaula;
                v_resumen.nombre_especie := jaula.nombre_especie;
                v_resumen.biomasa_actual := jaula.biomasa_actual;

                SELECT NVL(SUM(kg_alimento), 0) INTO v_resumen.total_alimento_kg
                FROM LOTE_ALIMENTACION WHERE id_jaula = jaula.id_jaula;

                SELECT NVL(SUM(mortalidad), 0) INTO v_resumen.total_mortalidad
                FROM MONITOREO_SANITARIO WHERE id_jaula = jaula.id_jaula;

                v_resumen.fca := calcular_fca(jaula.id_jaula);

                DBMS_OUTPUT.PUT_LINE('  Jaula ' || v_resumen.id_jaula || ' (' || v_resumen.nombre_especie ||
                    ') - Alimento: ' || v_resumen.total_alimento_kg ||
                    ' kg | Mortalidad: ' || v_resumen.total_mortalidad ||
                    ' | FCA: ' || NVL(TO_CHAR(v_resumen.fca), 'N/D'));
            END LOOP;
        END LOOP;
    END reporte_fca_por_centro;

    PROCEDURE revisar_alertas_caligus(p_id_centro NUMBER) IS
        CURSOR c_monitoreo_centro(p_centro NUMBER) IS
            SELECT m.id_jaula, m.nivel_caligus
            FROM MONITOREO_SANITARIO m
            JOIN JAULA j ON j.id_jaula = m.id_jaula
            WHERE j.id_centro = p_centro
            AND m.nivel_caligus > c_umbral_caligus;

        v_alertas t_alertas_sanitarias := t_alertas_sanitarias();
    BEGIN
        FOR reg IN c_monitoreo_centro(p_id_centro) LOOP
            v_alertas.EXTEND;
            v_alertas(v_alertas.LAST) := reg.id_jaula;
        END LOOP;

        IF v_alertas.COUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Centro ' || p_id_centro || ': sin alertas de caligus.');
        ELSE
            FOR i IN 1..v_alertas.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('ALERTA: Jaula ' || v_alertas(i) || ' sobre umbral de caligus (Centro ' || p_id_centro || ')');
            END LOOP;
        END IF;
    END revisar_alertas_caligus;

END pkg_gestion_cultivo;
/


/* ============================================================
   TRIGGERS
   RN-004: alerta automatica por brote de caligus
   RN-005: auditoria de cambios de estado de la jaula
   ============================================================ */

CREATE OR REPLACE TRIGGER trg_alerta_caligus
AFTER INSERT ON MONITOREO_SANITARIO
FOR EACH ROW
WHEN (NEW.nivel_caligus > 3)
BEGIN
    UPDATE JAULA SET estado = 'EN TRATAMIENTO' WHERE id_jaula = :NEW.id_jaula;
END;
/

CREATE OR REPLACE TRIGGER trg_auditoria_jaula
AFTER UPDATE OF estado ON JAULA
FOR EACH ROW
WHEN (NEW.estado != OLD.estado)
BEGIN
    INSERT INTO AUDITORIA_JAULA (id_jaula, fecha_cambio, estado_anterior, estado_nuevo)
    VALUES (:NEW.id_jaula, SYSDATE, :OLD.estado, :NEW.estado);
END;
/


/* ============================================================
   PRUEBAS
   ============================================================ */

SET SERVEROUTPUT ON;

BEGIN
    pkg_gestion_cultivo.reporte_fca_por_centro;
END;
/

BEGIN
    pkg_gestion_cultivo.revisar_alertas_caligus(1);
    pkg_gestion_cultivo.revisar_alertas_caligus(2);
    pkg_gestion_cultivo.revisar_alertas_caligus(3);
END;
/

SELECT * FROM JAULA WHERE estado = 'EN TRATAMIENTO';
SELECT * FROM AUDITORIA_JAULA ORDER BY fecha_cambio;

SELECT id_jaula, estado FROM JAULA WHERE estado = 'EN TRATAMIENTO';

SELECT * FROM AUDITORIA_JAULA ORDER BY fecha_cambio;