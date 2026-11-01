
SET SERVEROUTPUT ON;

-- -----------------------------------------------------
-- 0. ESTADO INICIAL: cómo parten los datos
-- -----------------------------------------------------
SELECT id_jaula, id_centro, numero_jaula, capacidad_max_peces, estado
  FROM jaula ORDER BY id_jaula;

SELECT id_siembra, id_jaula, cantidad_peces, estado
  FROM siembra ORDER BY id_siembra;


-- -----------------------------------------------------
-- 1. PROCEDIMIENTO SIN PARÁMETROS: reporte general
-- -----------------------------------------------------
EXEC pkg_salmotrack.pr_reporte_jaulas;


-- -----------------------------------------------------
-- 2. PROCEDIMIENTO CON PARÁMETROS: siembra válida
--    Esperado: siembra 3 creada, jaula 2 pasa a EN_CULTIVO
-- -----------------------------------------------------
DECLARE
  v_id siembra.id_siembra%TYPE;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(
      p_id_jaula        => 2,
      p_id_especie      => 2,
      p_cantidad_peces  => 6000,
      p_peso_promedio_g => 70,
      p_id_siembra      => v_id);
  DBMS_OUTPUT.PUT_LINE('Siembra creada: ' || v_id);
  COMMIT;
END;
/


-- -----------------------------------------------------
-- 3. VALIDACIÓN: el procedimiento rechaza una regla rota
--    Esperado: ORA-20005 (excede capacidad de la jaula 1 = 12000)
--    Nota: la jaula 1 está EN_COSECHA, así que primero salta ORA-20004.
--    Para mostrar capacidad usamos la jaula 3? No: está en centro inactivo.
--    Por eso mostramos el error de jaula ocupada:
-- -----------------------------------------------------
DECLARE
  v_id NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(1, 1, 1000, 70, SYSDATE, v_id);
EXCEPTION
  WHEN pkg_salmotrack.e_jaula_no_disponible THEN
    DBMS_OUTPUT.PUT_LINE('Regla aplicada: ' || SQLERRM);
END;
/


-- -----------------------------------------------------
-- 4. FUNCIONES DENTRO DE UN SELECT
-- -----------------------------------------------------
SELECT s.id_siembra, s.estado, s.cantidad_peces,
       pkg_salmotrack.fn_peces_cosechados_siembra(s.id_siembra) AS cosechados,
       s.cantidad_peces
         - pkg_salmotrack.fn_peces_cosechados_siembra(s.id_siembra) AS restantes,
       pkg_salmotrack.fn_dias_cultivo(s.id_siembra) AS dias_cultivo
  FROM siembra s
 ORDER BY s.id_siembra;

-- Función sin parámetros
SELECT pkg_salmotrack.fn_total_peces_en_cultivo AS peces_en_el_agua FROM dual;


-- -----------------------------------------------------
-- 5. TODO JUNTO: cosecha final de la siembra 1 (quedan 8000)
--    Procedimiento + función + trigger
--    Esperado: siembra 1 COSECHADA, jaula 1 VACIA, historial registra el cambio
-- -----------------------------------------------------
DECLARE
  v_c NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_cosecha(
      p_id_siembra     => 1,
      p_id_planta      => 1,
      p_cantidad_peces => 8000,
      p_peso_total_kg  => 32000,
      p_fecha_cosecha  => DATE '2026-10-28',
      p_id_cosecha     => v_c);
  COMMIT;
END;
/

SELECT id_jaula, estado FROM jaula ORDER BY id_jaula;

SELECT id_historial, id_jaula, estado_anterior, estado_nuevo,
       TO_CHAR(fecha_cambio, 'DD/MM/YYYY HH24:MI') AS fecha
  FROM historial_estado_jaula
 ORDER BY id_historial;


-- -----------------------------------------------------
-- 6. PACKAGE: lo privado no se ve desde fuera
--    Esperado: PLS-00302
-- -----------------------------------------------------
DECLARE
  v_m  VARCHAR2(200);
  v_ok BOOLEAN;
BEGIN
  v_ok := pkg_salmotrack.fn_transicion_valida('VACIA', 'EN_CULTIVO', v_m);
END;
/


-- -----------------------------------------------------
-- 7. TRIGGERS DE COSECHA
-- -----------------------------------------------------
-- Nivel de sentencia: no se puede borrar (ORA-20014)
DELETE FROM cosecha WHERE id_cosecha = 1;

-- Nivel de fila: no se puede saltar un estado (ORA-20015)
UPDATE cosecha SET estado = 'ENTREGADA' WHERE id_cosecha = 1;

-- Cambio permitido
UPDATE cosecha SET estado = 'EN_PROCESO' WHERE id_cosecha = 1;
COMMIT;


-- -----------------------------------------------------
-- 8. ESTADO DE LOS OBJETOS (si el profe lo pide)
-- -----------------------------------------------------
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'TRIGGER')
 ORDER BY object_type, object_name;