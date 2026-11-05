SET SERVEROUTPUT ON;

-- P1: siembra de 9.000 peces en la jaula 2 (capacidad 8.000)
DECLARE v_s NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(p_id_jaula => 2, p_id_especie => 2,
      p_cantidad_peces => 9000, p_peso_promedio_g => 70, p_id_siembra => v_s);
EXCEPTION WHEN pkg_salmotrack.e_capacidad_excedida THEN
  DBMS_OUTPUT.PUT_LINE('P1: ' || SQLERRM);
END;
/

-- P2: siembra en la jaula 3 (centro inactivo)
DECLARE v_s NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(p_id_jaula => 3, p_id_especie => 1,
      p_cantidad_peces => 1000, p_peso_promedio_g => 70, p_id_siembra => v_s);
EXCEPTION WHEN pkg_salmotrack.e_centro_inactivo THEN
  DBMS_OUTPUT.PUT_LINE('P2: ' || SQLERRM);
END;
/

-- P3: siembra en la jaula 1 (EN_COSECHA)
DECLARE v_s NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(p_id_jaula => 1, p_id_especie => 1,
      p_cantidad_peces => 1000, p_peso_promedio_g => 70, p_id_siembra => v_s);
EXCEPTION WHEN pkg_salmotrack.e_jaula_no_disponible THEN
  DBMS_OUTPUT.PUT_LINE('P3: ' || SQLERRM);
END;
/

-- P4: siembra válida de 6.000 peces en la jaula 2
DECLARE v_s NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_siembra(p_id_jaula => 2, p_id_especie => 2,
      p_cantidad_peces => 6000, p_peso_promedio_g => 70, p_id_siembra => v_s);
  DBMS_OUTPUT.PUT_LINE('P4: siembra ' || v_s || ' creada');
END;
/

-- P5: cosecha de 9.000 peces de la siembra 1 (quedan 8.000)
DECLARE v_c NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_cosecha(p_id_siembra => 1, p_id_planta => 1,
      p_cantidad_peces => 9000, p_peso_total_kg => 36000, p_id_cosecha => v_c);
EXCEPTION WHEN pkg_salmotrack.e_cosecha_excede_peces THEN
  DBMS_OUTPUT.PUT_LINE('P5: ' || SQLERRM);
END;
/

-- P6: cosecha de 45 tn en la planta 2 (capacidad 40 tn/día)
DECLARE v_c NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_cosecha(p_id_siembra => 1, p_id_planta => 2,
      p_cantidad_peces => 1000, p_peso_total_kg => 45000, p_id_cosecha => v_c);
EXCEPTION WHEN pkg_salmotrack.e_planta_sin_capacidad THEN
  DBMS_OUTPUT.PUT_LINE('P6: ' || SQLERRM);
END;
/

-- P7: cosecha parcial de 3.000 peces de la siembra 1
DECLARE v_c NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_cosecha(p_id_siembra => 1, p_id_planta => 1,
      p_cantidad_peces => 3000, p_peso_total_kg => 12000, p_id_cosecha => v_c);
  DBMS_OUTPUT.PUT_LINE('P7: cosecha ' || v_c || ' registrada; quedan '
      || (10000 - pkg_salmotrack.fn_peces_cosechados_siembra(1)) || ' peces');
END;
/

-- P8: cosecha final de 5.000 peces de la siembra 1
DECLARE v_c NUMBER;
BEGIN
  pkg_salmotrack.pr_registrar_cosecha(p_id_siembra => 1, p_id_planta => 1,
      p_cantidad_peces => 5000, p_peso_total_kg => 20000, p_id_cosecha => v_c);
  DBMS_OUTPUT.PUT_LINE('P8: cosecha ' || v_c || ' registrada');
END;
/
SELECT id_siembra, estado, fecha_cierre FROM siembra WHERE id_siembra = 1;
SELECT id_jaula, estado FROM jaula WHERE id_jaula = 1;

-- P9: procedimiento y función sin parámetros
BEGIN
  pkg_salmotrack.pr_reporte_jaulas;
  DBMS_OUTPUT.PUT_LINE('P9: total en cultivo = ' || pkg_salmotrack.fn_total_peces_en_cultivo);
END;
/

-- P10: funciones dentro de un SELECT
SELECT s.id_siembra, s.estado, s.cantidad_peces,
       pkg_salmotrack.fn_peces_cosechados_siembra(s.id_siembra) AS cosechados,
       pkg_salmotrack.fn_dias_cultivo(s.id_siembra)             AS dias_cultivo
  FROM siembra s;


ROLLBACK;