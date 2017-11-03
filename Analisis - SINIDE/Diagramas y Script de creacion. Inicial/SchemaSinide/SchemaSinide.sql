--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.17
-- Dumped by pg_dump version 9.3.17
-- Started on 2017-09-26 17:07:41

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 8 (class 2615 OID 36318)
-- Name: codigos; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA codigos;


ALTER SCHEMA codigos OWNER TO postgres;

--
-- TOC entry 1 (class 3079 OID 11750)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 3694 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- TOC entry 2 (class 3079 OID 72104)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 3695 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- TOC entry 845 (class 1247 OID 36325)
-- Name: dblink_pkey_results; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE dblink_pkey_results AS (
	"position" integer,
	colname text
);


ALTER TYPE public.dblink_pkey_results OWNER TO postgres;

--
-- TOC entry 406 (class 1255 OID 36326)
-- Name: agrega_campo(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION agrega_campo(character varying, character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
BEGIN 
--agregar y llenar el campo id_p para poner el id_personal que acaba de insertar
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name=$2)=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN '|| $2 ||' integer;';
RETURN $1||'.'||$2||' agregada '; END IF; 
RETURN $1||'.'||$2||' ya existia ';
END;
$_$;


ALTER FUNCTION public.agrega_campo(character varying, character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 178 (class 1259 OID 36327)
-- Name: alumno; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno (
    id_alumno integer NOT NULL,
    id_persona integer NOT NULL,
    c_indigena smallint,
    centro_encierro character varying,
    c_nivel_alcanzado_madre smallint,
    c_nivel_alcanzado_padre smallint,
    id_unidad_servicio integer NOT NULL,
    c_beneficio_alimentario smallint,
    c_beneficio_plan smallint,
    c_transporte smallint
);


ALTER TABLE public.alumno OWNER TO postgres;

--
-- TOC entry 407 (class 1255 OID 36333)
-- Name: alumno_parecido(integer, character varying, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION alumno_parecido(par_ictipodoc integer, par_snrodoc character varying, par_sapellido character varying, par_iidunidadservicio integer, par_blncasesensitive boolean) RETURNS SETOF alumno
    LANGUAGE plpgsql STRICT ROWS 50
    AS $$
DECLARE 
	var_sApellido character varying;
BEGIN

IF par_blnCaseSensitive = FALSE THEN
	SELECT lower(par_sApellido) INTO var_sApellido;
ELSE
	var_sApellido = par_sApellido;
END IF;
--Ojo. Estas reglas tambien aplican a persona_parecida.

RETURN QUERY SELECT alumno.*
	FROM alumno 
	JOIN persona USING (id_persona)
	WHERE persona.c_tipo_documento = par_iCTipoDoc AND 
	persona.nro_documento = par_sNroDoc AND 
	alumno.id_unidad_servicio = par_iIdunidadservicio AND
	--Solo Evaluo 1 vez diferencia_caracteres. Por eso no uso el operador logico AND
	CASE WHEN length(persona.apellidos)<=4 THEN
		--Apellido hasta 4 caracteres con al menos 1 diferencia.
		CASE WHEN diferencia_caracteres(
			CASE WHEN par_blnCaseSensitive = FALSE THEN 
				lower(persona.apellidos) 
			ELSE persona.apellidos END 
			,var_sApellido) <= 1  THEN true ELSE  false END
	ELSE
		--Apellido mas de 4 caracteres con al menos 3 diferencia identifican un parecido.
		CASE WHEN diferencia_caracteres(
			CASE WHEN par_blnCaseSensitive = FALSE THEN 
				lower(persona.apellidos) 
			ELSE persona.apellidos END
		,var_sApellido) <= 3  THEN true ELSE false END
	END = true;
END;
$$;


ALTER FUNCTION public.alumno_parecido(par_ictipodoc integer, par_snrodoc character varying, par_sapellido character varying, par_iidunidadservicio integer, par_blncasesensitive boolean) OWNER TO postgres;

--
-- TOC entry 408 (class 1255 OID 36334)
-- Name: articular(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION articular() RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN


/*******************************ARTICULACION*****************************************************
PROBADO EN SINIDEDEV
Articular las tablas de sinide(esquema public) con las de padron(esquema padron) 
haciendo update de las que estan e insert de las que faltan, en este orden:

1-public.establecimiento con padron.establecimiento
2-public.institucion con padron.localizacion, establecimiento, localizacion_domicilio, domicilio 
3-public.unidad_servicio con padron.oferta_local, oferta_tipo
4-public.oferta_local con padron.oferta_local, ol de public tiene id_unidad_servicio, por eso esta articulacion es posterior a la de us

*/
--1) ESTABLECIMIENTO----------------------------------------------------------------------------------------------------
--actualizo datos para id_establecimiento que existen en ambas

RAISE NOTICE 'Actualizando Establecimientos...';
UPDATE public.establecimiento desinide SET nombre = depadron.nombre,
c_sector = depadron.c_sector, c_dependencia = depadron.c_dependencia, fecha_creacion = depadron.fecha_creacion, 
c_confesional = depadron.c_confesional, c_arancelado = depadron.c_arancelado, c_categoria = depadron.c_categoria, 
id_responsable = depadron.id_responsable, c_estado = depadron.c_estado, 
fecha_actualizacion = depadron.fecha_actualizacion, fecha_baja = depadron.fecha_baja, fecha_alta = depadron.fecha_alta
FROM (
SELECT id_establecimiento, cue, nombre, c_sector, c_dependencia, fecha_creacion, --estan en padron y sinide
       c_confesional, c_arancelado, c_categoria, id_responsable, c_estado, 
       fecha_actualizacion, fecha_baja, fecha_alta
FROM padron.establecimiento join (select id_establecimiento from public.establecimiento)e using (id_establecimiento)
except --estan en sinide y padron y tiene alguna diferencia
SELECT id_establecimiento, cue, nombre, c_sector, c_dependencia, fecha_creacion,--estan en padron 
       c_confesional, c_arancelado, c_categoria, id_responsable, c_estado, 
       fecha_actualizacion, fecha_baja, fecha_alta
FROM public.establecimiento 
) depadron
WHERE desinide.id_establecimiento=depadron.id_establecimiento;
--inserta establecimientos en sinide que estan en padron y faltan en sinide
RAISE NOTICE 'Insertando Establecimientos nuevos...';

INSERT INTO public.establecimiento(id_establecimiento, cue, nombre, c_sector, c_dependencia, fecha_creacion, 
c_confesional, c_arancelado, c_categoria, id_responsable, c_estado, fecha_actualizacion, fecha_baja, fecha_alta)
(SELECT id_establecimiento, cue, nombre, c_sector, c_dependencia, fecha_creacion, --estan en padron
c_confesional, c_arancelado, c_categoria, id_responsable, c_estado,fecha_actualizacion, fecha_baja, fecha_alta
FROM padron.establecimiento 
except --estan en padron y no en sinide
SELECT id_establecimiento, cue, nombre, c_sector, c_dependencia, fecha_creacion,
c_confesional, c_arancelado, c_categoria, id_responsable, c_estado, fecha_actualizacion, fecha_baja, fecha_alta
FROM public.establecimiento);
--2) INSTITUCION--------------------------------------------------------------------------------------------------------
--actualizar instituciones con lo que está en localizacion
RAISE NOTICE 'Actualizando Instituciones...';

UPDATE public.institucion y SET
codigo_jurisdiccional=x.codigo_jurisdiccional, nombre=x.nombre, c_sector=x.c_sector,
c_dependencia=x.c_dependencia, c_confesional=x.c_confesional, c_arancelado=x.c_arancelado,
c_categoria=x.c_categoria, c_ambito=x.c_ambito, c_alternancia=x.c_alternancia,
c_per_funcionamiento=x.c_per_funcionamiento, calle=x.calle, nro=x.nro, barrio=x.barrio,
referencia=x.referencia, calle_fondo=x.calle_fondo, calle_derecha=x.calle_derecha,
calle_izquierda=x.calle_izquierda, cod_postal=x.cod_postal, telefono_cod_area=x.telefono_cod_area,
telefono=x.telefono, c_localidad=x.c_localidad, email=x.email, c_estado=x.c_estado,
c_cooperadora=x.c_cooperadora
FROM (
SELECT l.id_localizacion, e.cue||l.anexo, l.codigo_jurisdiccional, l.nombre, e.c_sector, 
e.c_dependencia, e.c_confesional, e.c_arancelado, e.c_categoria, l.c_ambito, l.c_alternancia, 
l.c_per_funcionamiento, d.calle, d.nro, d.barrio, d.referencia, d.calle_fondo, d. calle_derecha, 
d.calle_izquierda,d.cod_postal, l.telefono_cod_area, l.telefono, d.c_localidad, l.email, 
l.c_estado, l.c_cooperadora 
from padron.localizacion l
join padron.establecimiento e using (id_establecimiento)
join (select * from padron.localizacion_domicilio where c_tipo_dom=1) ld using (id_localizacion)
join padron.domicilio d using (id_domicilio)
join public.institucion on l.id_localizacion=id_institucion
EXCEPT
SELECT id_institucion, cueanexo, codigo_jurisdiccional, nombre, c_sector, 
c_dependencia, c_confesional, c_arancelado, c_categoria, c_ambito, c_alternancia, 
c_per_funcionamiento, calle, nro, barrio, referencia, calle_fondo, calle_derecha, 
calle_izquierda, cod_postal, telefono_cod_area, telefono, c_localidad, email, 
c_estado, c_cooperadora  FROM public.institucion
) x
where x.id_localizacion= y.id_institucion;
-- agregar en instituciones localizaciones que no estan 
RAISE NOTICE 'Insertando Instituciones nuevas...';

INSERT INTO institucion(id_institucion, cueanexo, codigo_jurisdiccional, nombre, 
c_sector, c_dependencia, c_confesional, c_arancelado, c_categoria, 
c_ambito, c_alternancia, c_per_funcionamiento, 
calle, nro, barrio, referencia, calle_fondo, calle_derecha, calle_izquierda, cod_postal, 
telefono_cod_area, telefono, c_localidad, email, c_estado, c_cooperadora, id_establecimiento)
(SELECT l.id_localizacion, e.cue||l.anexo, codigo_jurisdiccional, l.nombre,
e.c_sector, e.c_dependencia, e.c_confesional, e.c_arancelado, e.c_categoria,  
l.c_ambito, l.c_alternancia, l.c_per_funcionamiento, 
d.calle, d.nro, d.barrio, d.referencia, calle_fondo, d. calle_derecha, d.calle_izquierda,d.cod_postal, 
l.telefono_cod_area, l.telefono, d.c_localidad, l.email, l.c_estado, l.c_cooperadora, l.id_establecimiento
FROM padron.localizacion l
left join padron.establecimiento e using (id_establecimiento)
left join (select * from padron.localizacion_domicilio where c_tipo_dom=1) ld using (id_localizacion)
left join padron.domicilio d using (id_domicilio)
join
(SELECT id_localizacion FROM padron.localizacion --estan en localizacion
except
select id_institucion from public.institucion) u on l.id_localizacion=u.id_localizacion); --estan en institucion
--3) UNIDAD_SERVICIO--------------------------------------------------------------------------------------------------------
--actualizar unidad_servicio con lo que está en oferta_local 
RAISE NOTICE 'Actualizando Unidades de Servicio...';

update unidad_servicio us set c_estado=cambios.c_est, c_subvencion=cambios.c_sub, c_jornada=cambios.c_jor
from
(select us.id_institucion, us.c_nivel_servicio, us.c_estado, ol.c_est, 
us.c_subvencion,ol.c_sub, us.c_jornada, ol.c_jor  
from public.unidad_servicio us 
join 
(select id_localizacion, c_nivel_servicio, min(c_estado) as c_est, 
max(c_subvencion) as c_sub, max(c_jornada) as c_jor
from padron.oferta_local
join codigos.oferta_tipo using (c_oferta) group by 1,2) ol
on us.id_institucion=ol.id_localizacion and us.c_nivel_servicio=ol.c_nivel_servicio -- estan en ol y us
where us.c_estado<>ol.c_est or us.c_subvencion<>ol.c_sub or us.c_jornada<>ol.c_jor -- tienen alguna de estas vbles distintas
) cambios
where us.id_institucion=cambios.id_institucion and us.c_nivel_servicio=cambios.c_nivel_servicio;


--agregar en unidad_servicio ofertas_locales que no están 
RAISE NOTICE 'Insertando Unidades de Servicio nuevas...';

INSERT INTO unidad_servicio(id_institucion, c_nivel_servicio, c_estado, c_subvencion, c_jornada,c_alternancia,c_cooperadora, c_ciclo_lectivo)
select distinct id_localizacion, c_nivel_servicio, min(c_estado), max(c_subvencion), max(c_jornada),--max y min tal como estaba en la carga inicial -!!la de public no tiene id_localizacion
max(c_alternancia), max(c_cooperadora), min(ciclo_lect) from
(select distinct ol.id_localizacion, ot.c_nivel_servicio, ol.c_estado, ol.c_subvencion, ol.c_jornada, 
case when l.c_alternancia in (-1,-2) then null else l.c_alternancia end, 
case when l.c_cooperadora in (-2) then null else l.c_cooperadora end,
extract (year from now()) as ciclo_lect --21/12/15 agrego c_ciclo_lectivo 
from padron.oferta_local ol 
join codigos.oferta_tipo ot using (c_oferta)
join (select id_localizacion, c_nivel_servicio from padron.oferta_local join codigos.oferta_tipo using (c_oferta)--!!la de public no tiene id_localizacion--estan en oferta_local
      except
     select us.id_institucion, us.c_nivel_servicio from public.unidad_servicio us) ne --estan en unidad de servicio  
     on ol.id_localizacion=ne.id_localizacion and ot.c_nivel_servicio=ne.c_nivel_servicio
join padron.localizacion l on l.id_localizacion=ol.id_localizacion
where c_oferta not in (106,107) order by 1) o
WHERE c_nivel_servicio in (1003,1004,3003,1002,1001)
group by 1,2;

--4) OFERTA_LOCAL--------------------------------------------------------------------------------------------------------
--actualizo datos para id_oferta_local que existen en ambas
RAISE NOTICE 'Actualizando Ofertas Locales...';

UPDATE public.oferta_local desinide SET --c_oferta = depadron.c_oferta, --hay una que paso de 999 a 100
c_estado = depadron.c_estado, c_subvencion = depadron.c_subvencion, fecha_creacion = depadron.fecha_creacion, 
c_jornada = depadron.c_jornada, fecha_actualizacion = depadron.fecha_actualizacion, fecha_baja = depadron.fecha_baja,
fecha_alta = depadron.fecha_alta, matricula_total = depadron. matricula_total, codigo_jurisdiccional = depadron.codigo_jurisdiccional
FROM
(SELECT id_oferta_local, c_estado, c_subvencion, fecha_creacion, 
c_jornada, fecha_actualizacion, fecha_baja, fecha_alta, matricula_total, codigo_jurisdiccional
FROM padron.oferta_local join (select id_oferta_local from public.oferta_local)e using (id_oferta_local)
except
SELECT id_oferta_local, c_estado, c_subvencion, fecha_creacion, 
c_jornada, fecha_actualizacion, fecha_baja, fecha_alta, matricula_total, codigo_jurisdiccional--, id_unidad_servicio
FROM public.oferta_local) depadron
WHERE desinide.id_oferta_local= depadron.id_oferta_local;
--actualizo datos para id_oferta_local que existen en ambas y cambia c_oferta

UPDATE public.oferta_local desinide SET c_oferta = depadron.c_oferta, --hay una que paso de 999 a 100
id_unidad_servicio = null
FROM
(SELECT id_oferta_local, c_oferta
FROM padron.oferta_local join (select id_oferta_local from public.oferta_local)e using (id_oferta_local)
except
SELECT id_oferta_local, c_oferta
FROM public.oferta_local) depadron
WHERE desinide.id_oferta_local= depadron.id_oferta_local;
--inserta en sinide las que estan en padron y faltan en sinide
RAISE NOTICE 'Insertando Ofertas Locales nuevas...';

INSERT INTO oferta_local(id_oferta_local, c_oferta, c_estado, c_subvencion, fecha_creacion, c_jornada,
fecha_actualizacion, fecha_baja, fecha_alta, matricula_total,codigo_jurisdiccional)
(SELECT id_oferta_local, c_oferta, c_estado, c_subvencion, fecha_creacion, 
c_jornada, fecha_actualizacion, fecha_baja, fecha_alta, matricula_total, codigo_jurisdiccional
FROM padron.oferta_local where c_oferta not in (106,107)
except
SELECT id_oferta_local, c_oferta, c_estado, c_subvencion, fecha_creacion, 
c_jornada, fecha_actualizacion, fecha_baja, fecha_alta, matricula_total, codigo_jurisdiccional--, id_unidad_servicio
FROM public.oferta_local);
--actualiza id_unidad_servicio en public.oferta_local para las que la tienen en null porque se insertaron recien o cambiaron c_oferta
RAISE NOTICE 'Vinculando Ofertas Locales a Unidades de Servicio...';
UPDATE public.oferta_local SET id_unidad_servicio=id_us FROM
(select id_oferta_local as id_ol, id_unidad_servicio as id_us from
(select ol.id_oferta_local, id_localizacion, c_oferta, c_nivel_servicio as c_ns from public.oferta_local ol
join codigos.oferta_tipo using (c_oferta)
join (select id_oferta_local, id_localizacion from padron.oferta_local) pad_ol using (id_oferta_local)) sini_con_loc
join public.unidad_servicio on id_institucion=id_localizacion and c_nivel_servicio=c_ns) ids
WHERE id_oferta_local=id_ol and id_unidad_servicio is null;


UPDATE institucion SET c_provincia = cast(substring(cueanexo,1,2) as smallint) where c_provincia is null;
----------------------

--titulaciones de primario para unidad de servicio

alter table titulacion add column agregado_pri boolean;
alter table titulacion add column agregado_ini boolean;
	
INSERT INTO titulacion(id_unidad_servicio, c_dicta,id_nombre_titulacion, agregado_pri)
select distinct  id_unidad_servicio,1,id_nombre_titulacion, true
from
(select distinct id_unidad_servicio,1,id_nombre_titulacion
FROM unidad_servicio, nombre_titulacion 
 where c_nivel_servicio =1002 and trim(nombre)='Primario - Común'
except
select distinct id_unidad_servicio,1,id_nombre_titulacion
FROM titulacion)z;


update titulacion set c_duracion_en=1, c_organizacion_plan=2, c_organizacion_cursada=1,c_certificacion=11
where id_unidad_servicio in (select id_unidad_servicio from unidad_servicio where c_nivel_servicio=1002) and agregado_pri;

update titulacion set confirmado=true
where id_unidad_servicio in (select id_unidad_servicio from unidad_servicio where c_nivel_servicio=1002) and agregado_pri;


update titulacion set duracion=(case when maxof=105 then 7 else 6 end) from 
(select id_unidad_servicio,max(c_oferta) as maxof from oferta_local
join unidad_servicio using (id_unidad_servicio)
 where c_nivel_servicio=1002
group by id_unidad_servicio)z where titulacion.id_unidad_servicio=z.id_unidad_servicio and agregado_pri;

--
	
INSERT INTO titulacion(id_unidad_servicio, c_dicta,id_nombre_titulacion, agregado_ini)
select distinct  id_unidad_servicio,1,id_nombre_titulacion, true
from
(select distinct id_unidad_servicio,1,id_nombre_titulacion
FROM unidad_servicio, nombre_titulacion 
 where c_nivel_servicio =1001 and trim(nombre)='Inicial - Común'
except
select distinct id_unidad_servicio,1,id_nombre_titulacion
FROM titulacion)z;

update titulacion set c_duracion_en=1, c_organizacion_plan=1, c_organizacion_cursada=1,c_certificacion=11
where id_unidad_servicio in (select id_unidad_servicio from unidad_servicio where c_nivel_servicio=1001) and agregado_ini;

update titulacion set confirmado=true
where id_unidad_servicio in (select id_unidad_servicio from unidad_servicio where c_nivel_servicio=1001) and agregado_ini;

update titulacion set duracion=6 
where id_unidad_servicio in (select id_unidad_servicio from unidad_servicio where c_nivel_servicio=1001) and agregado_ini;


alter table titulacion drop column agregado_pri;
alter table titulacion drop column agregado_ini;

-------------------

--inserta en la tabla datos_unidad_servicio
insert into datos_unidad_servicio (id_unidad_servicio)
(select id_unidad_servicio from unidad_servicio
except
select id_unidad_servicio from datos_unidad_servicio);

--inserta en la tabla datos_institucion
insert into datos_institucion (id_institucion)
(select id_institucion from institucion
except
select id_institucion from datos_institucion);


END;
$$;


ALTER FUNCTION public.articular() OWNER TO postgres;

--
-- TOC entry 409 (class 1255 OID 36336)
-- Name: cambios_alumno(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION cambios_alumno() RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN
--pongo id_us para los que estan inscriptos
update alumno a set id_unidad_servicio= id_us
from
(select id_alumno as id_alu, id_institucion, t.id_titulacion, t.id_unidad_servicio as id_us
from alumno a
left join alumno_inscripcion ai using (id_alumno)
left join titulacion t on ai.id_titulacion=t.id_titulacion 
) aa where id_alu=id_alumno and a.id_unidad_servicio is null;

--pongo id_us para los que no estan inscriptos y la institucion tiene una sola unidad de servicio
update alumno a set id_unidad_servicio= id_us from
(select id_institucion as id_i, sum(id_unidad_servicio) as id_us from unidad_servicio 
group by id_institucion HAVING count (id_unidad_servicio)=1) ius 
where a.id_unidad_servicio is null and a.id_institucion=id_i;

--uso los datos del esquema transferencia
IF (SELECT count(*) FROM information_schema.columns 
WHERE table_schema||'.'||table_name = 'transferencia.alumnos_chaco220515' and column_name='id_a')<>0
THEN EXECUTE 'update alumno a set id_unidad_servicio= id_us from transferencia.alumnos_chaco220515
where id_alumno=id_a and id_unidad_servicio is null;'; END IF; 

IF (SELECT count(*) FROM information_schema.columns 
WHERE table_schema||'.'||table_name = 'transferencia.alumnos_jujuy010715' and column_name='id_a')<>0
THEN EXECUTE 'update alumno a set id_unidad_servicio= id_us from transferencia.alumnos_jujuy010715
where id_alumno=id_a and id_unidad_servicio is null;' ;END IF; 

IF (SELECT count(*) FROM information_schema.columns 
WHERE table_schema||'.'||table_name = 'transferencia.alumnos_misiones010615' and column_name='id_a')<>0
THEN EXECUTE 'update alumno a set id_unidad_servicio= id_us from transferencia.alumnos_misiones010615
where id_alumno=id_a and id_unidad_servicio is null;' ;END IF; 

IF (SELECT count(*) FROM information_schema.columns 
WHERE table_schema||'.'||table_name = 'transferencia.alumnos_neuquen100715' and column_name='id_a')<>0
THEN EXECUTE 'update alumno a set id_unidad_servicio= id_us from transferencia.alumnos_neuquen100715
where id_alumno=id_a and id_unidad_servicio is null;' ;END IF; 

--para los que quedan y tienen solo una unidad de servicio si se quita ini y pri 
update alumno a set id_unidad_servicio= id_us from
(select c_provincia, id_institucion, us.id_unidad_servicio as id_us, c_nivel_servicio, id_alumno 
from alumno a 
join institucion using (id_institucion)
join unidad_servicio us using(id_institucion)
where a.id_unidad_servicio is null and c_nivel_servicio not in ('1001','1002')) x
where a.id_unidad_servicio is null and a.id_alumno=x.id_alumno;

--para los que quedan y tienen solo ini y pri
update alumno a set id_unidad_servicio= id_us from
(select c_provincia, id_institucion, us.id_unidad_servicio as id_us, c_nivel_servicio, id_alumno 
from alumno a 
join institucion using (id_institucion)
join unidad_servicio us using(id_institucion)
where a.id_unidad_servicio is null and c_nivel_servicio not in ('1003','1004','3003')) x
where a.id_unidad_servicio is null and a.id_alumno=x.id_alumno;

--elimino los registros de alumno que no tienen unidad de servicio
DELETE FROM alumno where id_unidad_servicio is null;

END;
$$;


ALTER FUNCTION public.cambios_alumno() OWNER TO postgres;

--
-- TOC entry 412 (class 1255 OID 36337)
-- Name: control_carga_inicial(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION control_carga_inicial(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
BEGIN 
	if $1 ilike '%alumnos%' or $1 ilike '%autoridades%' or $1 ilike '%usuarios%' then
		--control sobre numero de documento
		EXECUTE 'ALTER TABLE '||$1||' add column nro_documento_ok boolean DEFAULT true;';
		EXECUTE 'UPDATE '||$1||' SET nro_documento_ok=false WHERE char_length(nro_documento) NOT IN (7,8);';	
		RAISE NOTICE 'CONTROL NUMERO DE DOCUMENTO';
		--control apellido vacio
		EXECUTE 'ALTER TABLE '||$1||' add column apellido_ok boolean DEFAULT true;';
		EXECUTE 'UPDATE '||$1||' SET apellido_ok=false WHERE apellidos is null;';
		RAISE NOTICE 'CONTROL SIN APELLIDO - ESTOS REGISTROS NO SE CARGAN';
		--cuil a revisar
		EXECUTE 'ALTER TABLE  '||$1||' add column cuil_ok boolean DEFAULT true;';
		EXECUTE 'UPDATE  '||$1||'  SET cuil_ok=false WHERE char_length(cuil)<>11;';
		RAISE NOTICE 'CONTROL CUIL';
		end if;	
	if $1 ilike '%alumnos%' or $1 ilike '%caja_curr%' then
		--sin nombre de seccion
		EXECUTE 'ALTER TABLE '||$1||' add column seccion_nombre_ok boolean DEFAULT true;';
		EXECUTE 'UPDATE '||$1||' SET seccion_nombre_ok=false WHERE seccion_nombre is null;';
	RAISE NOTICE 'CONTROL SIN NOMBRE DE SECCION - ESTOS REGISTROS NO SE CARGAN';
	end if;
	RETURN 'CONTROLES LISTO';
END; $_$;


ALTER FUNCTION public.control_carga_inicial(character varying) OWNER TO postgres;

--
-- TOC entry 413 (class 1255 OID 36338)
-- Name: corrige_id_nec(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION corrige_id_nec(integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	cambiadas smallint;
begin
select count(*) from espacio_curricular where id_nombre_espacio_curricular=$2 into cambiadas; 
update espacio_curricular set id_nombre_espacio_curricular=$1 where id_nombre_espacio_curricular=$2; 
IF (SELECT count(*) FROM espacio_curricular WHERE id_nombre_espacio_curricular=$2)=0 THEN EXECUTE 
'delete from nombre_espacio_curricular where id_nombre_espacio_curricular='||$2; 
return $2||' eliminado, '||cambiadas||' registros de espacio_curricular pasados a '||$1;
END IF; 
return 'no se puede eliminar, existen registros en nombre_espacio_curricular';
end;
$_$;


ALTER FUNCTION public.corrige_id_nec(integer, integer) OWNER TO postgres;

--
-- TOC entry 414 (class 1255 OID 36339)
-- Name: crea_tabla_transferencia_alumnos(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_alumnos(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.alumnos_'||$1;
	EXECUTE 'CREATE TABLE '||_nombretabla||'(cueanexo character varying, nivel_servicio character varying, 
	apellidos character varying, nombres character varying, 
	tipo_documento character varying, nro_documento character varying, 
	emisor_doc character varying, alumno_indigena character varying, 
	alumno_centro_encierro character varying, alumno_nivel_alcanzado_madre character varying, 
	alumno_nivel_alcanzado_padre character varying, cuil character varying, 
	fecha_nacimiento character varying, localidad_nacimiento character varying, 
	lugar_nacimiento character varying, pais_nacimiento character varying, 
	nacionalidad character varying, sexo character varying, 
	email character varying, cod_area_telefono character varying, 
	nro_telefono character varying, estado_civil character varying, 
	calle character varying, nro character varying, 
	barrio character varying, localidad character varying, 
	referencia character varying, cod_postal character varying, 
	titulo_nombre character varying, espacio_curricular_nombre character varying, 
	anio_de_estudio character varying, seccion_nombre character varying, 
	seccion_turno character varying, seccion_tipo character varying, 
	alumno_legajo character varying, alumno_fecha_insc character varying, 
	alumno_anio_ingreso character varying, alumno_cursa character varying, 
	alumno_fines character varying, alumno_otros_datos character varying, 
	alumno_tipo_baja_inscripcion character varying, alumno_fecha_baja_inscripcion character varying, 
	cueanexo_destino character varying, alumno_motivo_baja_inscripcion character varying, 
	observaciones character varying, alumno_fecha_egreso character varying, 
	libro_matriz character varying, acta character varying, folio character varying, 
	fecha_emision_titulo character varying, recursante character varying, nota character varying, 
	condicion_aprobacion character varying, fecha_nota character varying, cueanexo_donde_curso character varying);';
	EXECUTE 'CREATE INDEX '||$1||'alumnos_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END; $_$;


ALTER FUNCTION public.crea_tabla_transferencia_alumnos(character varying) OWNER TO postgres;

--
-- TOC entry 415 (class 1255 OID 36340)
-- Name: crea_tabla_transferencia_alumnos_v2(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_alumnos_v2(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.alumnos_'||$1;
	EXECUTE 'CREATE TABLE '||_nombretabla||'(cueanexo character varying, nivel_servicio character varying, 
	apellidos character varying, nombres character varying, 
	tipo_documento character varying, nro_documento character varying, 
	emisor_doc character varying, alumno_indigena character varying, 
	alumno_centro_encierro character varying, alumno_nivel_alcanzado_madre character varying, 
	alumno_nivel_alcanzado_padre character varying, cuil character varying, 
	fecha_nacimiento character varying, 
	provincia_nacimiento character varying, departamento_nacimiento character varying, localidad_nacimiento character varying, 
	lugar_nacimiento character varying, pais_nacimiento character varying, 
	nacionalidad character varying, sexo character varying, 
	email character varying, cod_area_telefono character varying, 
	nro_telefono character varying, estado_civil character varying, 
	calle character varying, nro character varying, 
	barrio character varying, 
	pais character varying, provincia character varying, departamento character varying, localidad character varying, 
	referencia character varying, cod_postal character varying, 
	titulo_nombre character varying, espacio_curricular_nombre character varying, 
	anio_de_estudio character varying, seccion_nombre character varying, 
	seccion_turno character varying, seccion_tipo character varying, 
	seccion_trayecto_formativo character varying,
	alumno_legajo character varying, alumno_fecha_insc character varying, 
	alumno_anio_ingreso character varying, alumno_cursa character varying, 
	alumno_fines character varying, alumno_otros_datos character varying, 
	alumno_tipo_baja_inscripcion character varying, alumno_fecha_baja_inscripcion character varying, 
	cueanexo_destino character varying, alumno_motivo_baja_inscripcion character varying, 
	observaciones character varying, alumno_fecha_egreso character varying, 
	libro_matriz character varying, acta character varying, folio character varying, 
	fecha_emision_titulo character varying, recursante character varying, nota character varying, 
	condicion_aprobacion character varying, fecha_nota character varying, cueanexo_donde_curso character varying);';
	EXECUTE 'CREATE INDEX '||$1||'alumnos_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END; $_$;


ALTER FUNCTION public.crea_tabla_transferencia_alumnos_v2(character varying) OWNER TO postgres;

--
-- TOC entry 416 (class 1255 OID 36341)
-- Name: crea_tabla_transferencia_autoridades(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_autoridades(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.autoridades_'||$1;
	EXECUTE 'create table '||_nombretabla||'	(cueanexo character varying,	nivel_servicio character varying,
	apellidos character varying,	nombres character varying,	tipo_documento character varying,
	nro_documento character varying,	emisor_doc character varying,
	cargo character varying,	firma_analitico character varying,	cuil character varying,
	fecha_nacimiento character varying,	localidad_nacimiento character varying,
	lugar_nacimiento character varying,	pais_nacimiento character varying,	nacionalidad character varying,
	sexo character varying,		email character varying,	cod_area_telefono character varying,
	nro_telefono character varying,		estado_civil character varying,		calle character varying,
	nro character varying,	barrio character varying,
	localidad character varying,	referencia character varying,
	cod_postal character varying);';
	EXECUTE 'CREATE INDEX '||$1||'autoridades_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END;
$_$;


ALTER FUNCTION public.crea_tabla_transferencia_autoridades(character varying) OWNER TO postgres;

--
-- TOC entry 417 (class 1255 OID 36342)
-- Name: crea_tabla_transferencia_caja_curr(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_caja_curr(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.caja_curr_'||$1;
	EXECUTE 'create table '||_nombretabla||'	(	cueanexo character varying,	nivel_servicio character varying,
	titulo_nombre character varying,	nombre_abreviado character varying,	titulo_carrera character varying,
	titulo_cod_titulo character varying,	titulo_certificacion character varying,	titulo_vigente_este_anio character varying,
	condicion_ingreso character varying,	titulo_cohorte_implementacion character varying,	titulo_cohorte_finalizacion character varying,
	titulo_tipo_formacion character varying,	titulo_tipo character varying,	titulo_a_termino character varying,
	titulo_orientacion character varying,	titulo_organizacion_plan character varying,	titulo_organizacion_cursada_titulo character varying,
	titulo_forma_dictado character varying,	titulo_tiene_titulo_intermedio character varying,	titulo_carga_horaria_en character varying,
	titulo_carga_horaria character varying,		titulo_edad_minima character varying,	titulo_tiene_articulacion character varying,
	titulo_tiene_articulacion_univ character varying,	titulo_nro_infod character varying,	titulo_inscripto_inet character varying,
	titulo_duracion_en character varying,	titulo_duracion character varying,	espacio_curricular_nombre character varying,
	espacio_curricular_campo_formacion character varying,	anio_de_estudio character varying,	seccion_nombre character varying,
	seccion_tipo character varying,	seccion_plazas character varying,	seccion_organizacion_cursada character varying,
	seccion_turno character varying,	comision_trayecto_formativo character varying,	espacio_curricular_trayecto_formativo character varying,
	espacio_curricular_dictado character varying,	espacio_curricular_obligatoriedad character varying,	espacio_curricular_carga_horaria_en character varying,
	espacio_curricular_carga_horaria_semanal character varying,	espacio_curricular_duracion_en character varying,	espacio_curricular_duracion character varying,
	espacio_curricular_escala_numerica character varying,	espacio_curricular_nota_minima character varying,	titulo_norma_aprob_jur_tipo character varying,
	titulo_norma_aprob_jur_nro character varying,	titulo_norma_aprob_jur_anio character varying,	titulo_norma_val_nac_tipo character varying,
	titulo_norma_val_nac_nro character varying,	titulo_norma_val_nac_anio character varying,	titulo_norma_ratif_jur_tipo character varying,
	titulo_norma_ratif_jur_nro character varying,	titulo_norma_ratif_jur_anio character varying,	titulo_norma_homologacion_tipo character varying,
	titulo_norma_homologacion_nro character varying,	titulo_norma_homologacion_anio character varying);';
	EXECUTE 'CREATE INDEX '||$1||'caja_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END;
$_$;


ALTER FUNCTION public.crea_tabla_transferencia_caja_curr(character varying) OWNER TO postgres;

--
-- TOC entry 418 (class 1255 OID 36343)
-- Name: crea_tabla_transferencia_caja_curr_v2(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_caja_curr_v2(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.caja_curr_'||$1;
	EXECUTE 'create table '||_nombretabla||'	(	cueanexo character varying,	nivel_servicio character varying,
	titulo_nombre character varying,	nombre_abreviado character varying,	titulo_carrera character varying,
	titulo_cod_titulo character varying,	titulo_certificacion character varying,	titulo_vigente_este_anio character varying,
	condicion_ingreso character varying,	titulo_cohorte_implementacion character varying,	titulo_cohorte_finalizacion character varying,
	titulo_tipo_formacion character varying,	titulo_tipo character varying,	titulo_a_termino character varying,
	titulo_orientacion character varying,	titulo_organizacion_plan character varying,	titulo_organizacion_cursada_titulo character varying,
	titulo_forma_dictado character varying,	titulo_tiene_titulo_intermedio character varying,	titulo_carga_horaria_en character varying,
	titulo_carga_horaria character varying,		titulo_edad_minima character varying,	titulo_tiene_articulacion character varying,
	titulo_tiene_articulacion_univ character varying,	titulo_nro_infod character varying,	titulo_inscripto_inet character varying,
	titulo_duracion_en character varying,	titulo_duracion character varying,	espacio_curricular_nombre character varying,
	espacio_curricular_campo_formacion character varying,	anio_de_estudio character varying,	seccion_nombre character varying,
	seccion_tipo character varying,	
	seccion_trayecto_formativo character varying,
	seccion_plazas character varying,	seccion_organizacion_cursada character varying,
	seccion_turno character varying,	comision_trayecto_formativo character varying,	espacio_curricular_trayecto_formativo character varying,
	espacio_curricular_dictado character varying,	espacio_curricular_obligatoriedad character varying,	espacio_curricular_carga_horaria_en character varying,
	espacio_curricular_carga_horaria_semanal character varying,	espacio_curricular_duracion_en character varying,	espacio_curricular_duracion character varying,
	espacio_curricular_escala_numerica character varying,	espacio_curricular_nota_minima character varying,	titulo_norma_aprob_jur_tipo character varying,
	titulo_norma_aprob_jur_nro character varying,	titulo_norma_aprob_jur_anio character varying,	titulo_norma_val_nac_tipo character varying,
	titulo_norma_val_nac_nro character varying,	titulo_norma_val_nac_anio character varying,	titulo_norma_ratif_jur_tipo character varying,
	titulo_norma_ratif_jur_nro character varying,	titulo_norma_ratif_jur_anio character varying,	titulo_norma_homologacion_tipo character varying,
	titulo_norma_homologacion_nro character varying,	titulo_norma_homologacion_anio character varying);';
	EXECUTE 'CREATE INDEX '||$1||'caja_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END;
$_$;


ALTER FUNCTION public.crea_tabla_transferencia_caja_curr_v2(character varying) OWNER TO postgres;

--
-- TOC entry 410 (class 1255 OID 36344)
-- Name: crea_tabla_transferencia_usuarios(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crea_tabla_transferencia_usuarios(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombretabla varchar;
BEGIN 
	_nombretabla:='transferencia.usuarios_'||$1;
	EXECUTE 'create table '||_nombretabla||'	(cueanexo character varying,	nivel_servicio character varying,
	apellidos character varying,	nombres character varying,	tipo_documento character varying,
	nro_documento character varying,	cuil character varying,
	fecha_nacimiento character varying,	email character varying,	cod_area_telefono character varying,
	nro_telefono character varying,		usuario_nombre character varying,
	usuario_pass character varying, editar character varying,	emitir character varying,	ver character varying,
	descargar character varying);';
	EXECUTE 'CREATE INDEX '||$1||'usuarios_cueanexo_nivel_servicio_idx  ON '||_nombretabla||'  USING btree  (cueanexo, nivel_servicio);';
	return _nombretabla||' creada';
END;
$_$;


ALTER FUNCTION public.crea_tabla_transferencia_usuarios(character varying) OWNER TO postgres;

--
-- TOC entry 421 (class 1255 OID 36345)
-- Name: crear_ficticio(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION crear_ficticio(pcia character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$
declare 
	p_provincia character varying :=$1;
	v_cue character varying;
	v_cueanexo character varying;
	v_nom_provincia character varying;
	v_localidad integer;
begin 

v_cue:='99000'||p_provincia;
v_cueanexo:= v_cue||'00';
select nombre INTO v_nom_provincia  from codigos.provincia_tipo where cod_provincia=p_provincia;

IF (p_provincia='02') THEN
 v_localidad:=1;
ELSE
 select c_localidad INTO v_localidad from codigos.localidad_tipo where (nombre ilike '%DESCONOCIDO%' or nombre ilike '%NO FIGURA EN TABLA%') and substr(cod_localidad,1,2)=p_provincia limit 1;
END IF;



INSERT INTO establecimiento(cue, nombre, c_sector, c_dependencia, fecha_creacion, 
            c_confesional, c_arancelado, c_categoria, id_responsable, c_estado) 
    VALUES (v_cue, 'Carga reservada al Ministerio de Educación Nación. '||v_nom_provincia, 1, -2, now(), 
            -2, -2, -2, -2, 1);

---

ALTER TABLE institucion DROP CONSTRAINT institucion_id_establecimiento_fkey;
ALTER TABLE institucion ALTER COLUMN id_establecimiento DROP NOT NULL;

INSERT INTO institucion( nombre, c_sector, c_dependencia, 
            c_confesional, c_arancelado, c_categoria, c_ambito, c_alternancia, c_per_funcionamiento, 
            c_localidad, c_estado, c_cooperadora, c_provincia, cueanexo)
    VALUES ('Carga reservada al Ministerio de Educación Nación. '||v_nom_provincia, 1, -2,
            -2, -2, -2, -2, -2, -2, 
            v_localidad, 1, -2, 99, v_cueanexo);
--localidad se toma de un departamento, localidad desconocida

update institucion set id_establecimiento=est
from
(select id_establecimiento est from establecimiento where cue=v_cue) x
where cueanexo=v_cueanexo;

ALTER TABLE institucion
  ADD CONSTRAINT institucion_id_establecimiento_fkey FOREIGN KEY (id_establecimiento)
      REFERENCES establecimiento (id_establecimiento) MATCH SIMPLE
      ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE institucion ALTER COLUMN id_establecimiento SET NOT NULL;

-----
ALTER TABLE unidad_servicio DROP CONSTRAINT unidad_servicio_id_institucion_fkey;
ALTER TABLE unidad_servicio ALTER COLUMN id_institucion DROP NOT NULL;


INSERT INTO unidad_servicio(c_nivel_servicio, c_estado, c_subvencion, c_jornada, c_alternancia, c_cooperadora, c_ciclo_lectivo)
    VALUES (1003, 1, -2, -2, -2, -2, 2016);

INSERT INTO unidad_servicio(c_nivel_servicio, c_estado, c_subvencion, c_jornada, c_alternancia, c_cooperadora, c_ciclo_lectivo)
    VALUES (1004, 1, -2, -2, -2, -2, 2016);

INSERT INTO unidad_servicio(c_nivel_servicio, c_estado, c_subvencion, c_jornada, c_alternancia, c_cooperadora, c_ciclo_lectivo)
    VALUES (3003, 1, -2, -2, -2, -2, 2016);

update unidad_servicio set id_institucion=inst
from
(select id_institucion inst from institucion where cueanexo=v_cueanexo) x
where id_institucion is null;

ALTER TABLE unidad_servicio
  ADD CONSTRAINT unidad_servicio_id_institucion_fkey FOREIGN KEY (id_institucion)
      REFERENCES institucion (id_institucion) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE unidad_servicio ALTER COLUMN id_institucion SET NOT NULL;

end;
$_$;


ALTER FUNCTION public.crear_ficticio(pcia character varying) OWNER TO postgres;

--
-- TOC entry 422 (class 1255 OID 36346)
-- Name: create_dblink_schema(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION create_dblink_schema(strconn character varying, strschema character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN create_dblink_schema(strconn, strschema, strschema);
END;
$$;


ALTER FUNCTION public.create_dblink_schema(strconn character varying, strschema character varying) OWNER TO postgres;

--
-- TOC entry 423 (class 1255 OID 36347)
-- Name: create_dblink_schema(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION create_dblink_schema(strconn character varying, strremoteschema character varying, strlocalschema character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
tablas record;
columnas record;
sqlcreate text;
flag boolean;
BEGIN


PERFORM schema_name FROM information_schema.schemata WHERE schema_name ILIKE strlocalschema;
IF NOT FOUND THEN
    EXECUTE 'CREATE SCHEMA '||strlocalschema;
END IF;

FOR tablas IN (SELECT * FROM dblink(strconn, 'SELECT table_name FROM information_schema.tables WHERE table_schema = '''||strremoteschema||''' ORDER BY 1') as x (table_name character varying)) LOOP
    PERFORM table_name FROM information_schema.views WHERE table_schema ILIKE strlocalschema AND table_name ILIKE tablas.table_name;
    IF FOUND THEN
        EXECUTE 'DROP VIEW '||strlocalschema||'.'||tablas.table_name||' CASCADE; ';
    END IF;
    sqlcreate := 'CREATE VIEW '||strlocalschema||'.'||tablas.table_name;
    sqlcreate := sqlcreate||' AS SELECT * FROM dblink('''||strconn||''',''select * from '||strremoteschema||'.'||tablas.table_name||''') as tab(';
    flag := false;
	FOR columnas IN (SELECT * FROM dblink(strconn, 'select column_name, data_type, character_maximum_length FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = '''||strremoteschema||''' AND table_name = '''||tablas.table_name||''' ORDER BY ordinal_position')as y (column_name character varying, data_type character varying, character_maximum_length integer)) LOOP
		IF flag THEN sqlcreate := sqlcreate||', '; ELSE flag := true; END IF;
		sqlcreate := sqlcreate||' "'||columnas.column_name || '" ' || columnas.data_type;
		IF (columnas.character_maximum_length IS NOT NULL) THEN sqlcreate := sqlcreate || '(' || columnas.character_maximum_length || ')'; END IF;
	END LOOP;
    sqlcreate := sqlcreate||');';
    RAISE NOTICE '%',sqlcreate;
    EXECUTE sqlcreate;
END LOOP;

RETURN true;
END;
$$;


ALTER FUNCTION public.create_dblink_schema(strconn character varying, strremoteschema character varying, strlocalschema character varying) OWNER TO postgres;

--
-- TOC entry 424 (class 1255 OID 36348)
-- Name: dblink(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink(text) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_record';


ALTER FUNCTION public.dblink(text) OWNER TO postgres;

--
-- TOC entry 425 (class 1255 OID 36349)
-- Name: dblink(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink(text, boolean) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_record';


ALTER FUNCTION public.dblink(text, boolean) OWNER TO postgres;

--
-- TOC entry 426 (class 1255 OID 36350)
-- Name: dblink(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink(text, text) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_record';


ALTER FUNCTION public.dblink(text, text) OWNER TO postgres;

--
-- TOC entry 427 (class 1255 OID 36351)
-- Name: dblink(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink(text, text, boolean) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_record';


ALTER FUNCTION public.dblink(text, text, boolean) OWNER TO postgres;

--
-- TOC entry 428 (class 1255 OID 36352)
-- Name: dblink_build_sql_delete(text, int2vector, integer, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_build_sql_delete(text, int2vector, integer, text[]) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_build_sql_delete';


ALTER FUNCTION public.dblink_build_sql_delete(text, int2vector, integer, text[]) OWNER TO postgres;

--
-- TOC entry 429 (class 1255 OID 36353)
-- Name: dblink_build_sql_insert(text, int2vector, integer, text[], text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_build_sql_insert(text, int2vector, integer, text[], text[]) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_build_sql_insert';


ALTER FUNCTION public.dblink_build_sql_insert(text, int2vector, integer, text[], text[]) OWNER TO postgres;

--
-- TOC entry 430 (class 1255 OID 36354)
-- Name: dblink_build_sql_update(text, int2vector, integer, text[], text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_build_sql_update(text, int2vector, integer, text[], text[]) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_build_sql_update';


ALTER FUNCTION public.dblink_build_sql_update(text, int2vector, integer, text[], text[]) OWNER TO postgres;

--
-- TOC entry 431 (class 1255 OID 36355)
-- Name: dblink_cancel_query(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_cancel_query(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_cancel_query';


ALTER FUNCTION public.dblink_cancel_query(text) OWNER TO postgres;

--
-- TOC entry 432 (class 1255 OID 36356)
-- Name: dblink_close(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_close(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_close';


ALTER FUNCTION public.dblink_close(text) OWNER TO postgres;

--
-- TOC entry 433 (class 1255 OID 36357)
-- Name: dblink_close(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_close(text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_close';


ALTER FUNCTION public.dblink_close(text, boolean) OWNER TO postgres;

--
-- TOC entry 434 (class 1255 OID 36358)
-- Name: dblink_close(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_close(text, text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_close';


ALTER FUNCTION public.dblink_close(text, text) OWNER TO postgres;

--
-- TOC entry 435 (class 1255 OID 36359)
-- Name: dblink_close(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_close(text, text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_close';


ALTER FUNCTION public.dblink_close(text, text, boolean) OWNER TO postgres;

--
-- TOC entry 436 (class 1255 OID 36360)
-- Name: dblink_connect(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_connect(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_connect';


ALTER FUNCTION public.dblink_connect(text) OWNER TO postgres;

--
-- TOC entry 437 (class 1255 OID 36361)
-- Name: dblink_connect(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_connect(text, text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_connect';


ALTER FUNCTION public.dblink_connect(text, text) OWNER TO postgres;

--
-- TOC entry 482 (class 1255 OID 36362)
-- Name: dblink_connect_u(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_connect_u(text) RETURNS text
    LANGUAGE c STRICT SECURITY DEFINER
    AS '$libdir/dblink', 'dblink_connect';


ALTER FUNCTION public.dblink_connect_u(text) OWNER TO postgres;

--
-- TOC entry 483 (class 1255 OID 36363)
-- Name: dblink_connect_u(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_connect_u(text, text) RETURNS text
    LANGUAGE c STRICT SECURITY DEFINER
    AS '$libdir/dblink', 'dblink_connect';


ALTER FUNCTION public.dblink_connect_u(text, text) OWNER TO postgres;

--
-- TOC entry 438 (class 1255 OID 36364)
-- Name: dblink_current_query(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_current_query() RETURNS text
    LANGUAGE c
    AS '$libdir/dblink', 'dblink_current_query';


ALTER FUNCTION public.dblink_current_query() OWNER TO postgres;

--
-- TOC entry 439 (class 1255 OID 36365)
-- Name: dblink_disconnect(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_disconnect() RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_disconnect';


ALTER FUNCTION public.dblink_disconnect() OWNER TO postgres;

--
-- TOC entry 440 (class 1255 OID 36366)
-- Name: dblink_disconnect(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_disconnect(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_disconnect';


ALTER FUNCTION public.dblink_disconnect(text) OWNER TO postgres;

--
-- TOC entry 441 (class 1255 OID 36367)
-- Name: dblink_error_message(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_error_message(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_error_message';


ALTER FUNCTION public.dblink_error_message(text) OWNER TO postgres;

--
-- TOC entry 442 (class 1255 OID 36368)
-- Name: dblink_exec(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_exec(text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_exec';


ALTER FUNCTION public.dblink_exec(text) OWNER TO postgres;

--
-- TOC entry 419 (class 1255 OID 36369)
-- Name: dblink_exec(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_exec(text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_exec';


ALTER FUNCTION public.dblink_exec(text, boolean) OWNER TO postgres;

--
-- TOC entry 420 (class 1255 OID 36370)
-- Name: dblink_exec(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_exec(text, text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_exec';


ALTER FUNCTION public.dblink_exec(text, text) OWNER TO postgres;

--
-- TOC entry 398 (class 1255 OID 36371)
-- Name: dblink_exec(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_exec(text, text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_exec';


ALTER FUNCTION public.dblink_exec(text, text, boolean) OWNER TO postgres;

--
-- TOC entry 399 (class 1255 OID 36372)
-- Name: dblink_fetch(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_fetch(text, integer) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_fetch';


ALTER FUNCTION public.dblink_fetch(text, integer) OWNER TO postgres;

--
-- TOC entry 411 (class 1255 OID 36373)
-- Name: dblink_fetch(text, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_fetch(text, integer, boolean) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_fetch';


ALTER FUNCTION public.dblink_fetch(text, integer, boolean) OWNER TO postgres;

--
-- TOC entry 443 (class 1255 OID 36374)
-- Name: dblink_fetch(text, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_fetch(text, text, integer) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_fetch';


ALTER FUNCTION public.dblink_fetch(text, text, integer) OWNER TO postgres;

--
-- TOC entry 444 (class 1255 OID 36375)
-- Name: dblink_fetch(text, text, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_fetch(text, text, integer, boolean) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_fetch';


ALTER FUNCTION public.dblink_fetch(text, text, integer, boolean) OWNER TO postgres;

--
-- TOC entry 445 (class 1255 OID 36376)
-- Name: dblink_get_connections(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_get_connections() RETURNS text[]
    LANGUAGE c
    AS '$libdir/dblink', 'dblink_get_connections';


ALTER FUNCTION public.dblink_get_connections() OWNER TO postgres;

--
-- TOC entry 446 (class 1255 OID 36377)
-- Name: dblink_get_pkey(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_get_pkey(text) RETURNS SETOF dblink_pkey_results
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_get_pkey';


ALTER FUNCTION public.dblink_get_pkey(text) OWNER TO postgres;

--
-- TOC entry 447 (class 1255 OID 36378)
-- Name: dblink_get_result(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_get_result(text) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_get_result';


ALTER FUNCTION public.dblink_get_result(text) OWNER TO postgres;

--
-- TOC entry 448 (class 1255 OID 36379)
-- Name: dblink_get_result(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_get_result(text, boolean) RETURNS SETOF record
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_get_result';


ALTER FUNCTION public.dblink_get_result(text, boolean) OWNER TO postgres;

--
-- TOC entry 449 (class 1255 OID 36380)
-- Name: dblink_is_busy(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_is_busy(text) RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_is_busy';


ALTER FUNCTION public.dblink_is_busy(text) OWNER TO postgres;

--
-- TOC entry 450 (class 1255 OID 36381)
-- Name: dblink_open(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_open(text, text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_open';


ALTER FUNCTION public.dblink_open(text, text) OWNER TO postgres;

--
-- TOC entry 451 (class 1255 OID 36382)
-- Name: dblink_open(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_open(text, text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_open';


ALTER FUNCTION public.dblink_open(text, text, boolean) OWNER TO postgres;

--
-- TOC entry 452 (class 1255 OID 36383)
-- Name: dblink_open(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_open(text, text, text) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_open';


ALTER FUNCTION public.dblink_open(text, text, text) OWNER TO postgres;

--
-- TOC entry 453 (class 1255 OID 36384)
-- Name: dblink_open(text, text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_open(text, text, text, boolean) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_open';


ALTER FUNCTION public.dblink_open(text, text, text, boolean) OWNER TO postgres;

--
-- TOC entry 454 (class 1255 OID 36385)
-- Name: dblink_send_query(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dblink_send_query(text, text) RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/dblink', 'dblink_send_query';


ALTER FUNCTION public.dblink_send_query(text, text) OWNER TO postgres;

--
-- TOC entry 455 (class 1255 OID 36386)
-- Name: diferencia_caracteres(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION diferencia_caracteres(par_stexto1 character varying, par_stexto2 character varying) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE 
var_sTexto1 character varying;
var_sTexto2 character varying;
var_vAux char[];
var_iCant1 integer default 0;
var_iCant2 integer default 0;
var_iDiffCant integer default 0;
var_cX char;
var_sRegExp varchar default '';
BEGIN

--Version utilizada en biblioteca de testing: 3

var_sTexto1 = par_sTexto1;
var_sTexto2 = par_sTexto2;
--Esta función tiene una optimizacíon ya que borra todo de una, solo procesa los caracteres diferentes
SELECT replace(var_sTexto1, ' ', '') INTO var_sTexto1;
SELECT replace(var_sTexto2, ' ', '') INTO var_sTexto2;
FOR var_cX IN select distinct(unnest(string_to_array(var_sTexto1, NULL))) LOOP
	var_sRegExp := '[^'||var_cX||']';
	select length(regexp_replace(var_sTexto1, var_sRegExp, '', 'g')) INTO var_iCant1;
	select length(regexp_replace(var_sTexto2, var_sRegExp, '', 'g')) INTO var_iCant2;
	var_iDiffCant := var_iDiffCant + abs(var_iCant1-var_iCant2);
	SELECT replace(var_sTexto1, var_cX, '') INTO var_sTexto1;
	SELECT replace(var_sTexto2, var_cX, '') INTO var_sTexto2;
END LOOP;
--restantes
SELECT var_iDiffCant + length(var_sTexto2) INTO var_iDiffCant;
RETURN var_iDiffCant;
END;
$$;


ALTER FUNCTION public.diferencia_caracteres(par_stexto1 character varying, par_stexto2 character varying) OWNER TO postgres;

--
-- TOC entry 456 (class 1255 OID 36387)
-- Name: es_parecido(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION es_parecido(campo text, texto text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$ 
DECLARE
parece boolean:=true;
_campo text;
_texto text;
registro record;
BEGIN
_campo=lower(translate ($1, 'áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ', 'aeiouAEIOUaeiouAEIOUÑ'));
_texto=lower(translate ($2, 'áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ', 'aeiouAEIOUaeiouAEIOUÑ'));
 
FOR registro IN select regexp_split_to_table(_texto, ' ') as texto1
    LOOP
         IF _campo ilike '%'||registro.texto1||'%' THEN parece= (parece and true); ELSE parece= (parece and false); END IF;
   END LOOP; 
return parece;
END;
$_$;


ALTER FUNCTION public.es_parecido(campo text, texto text) OWNER TO postgres;

--
-- TOC entry 457 (class 1255 OID 36388)
-- Name: insert_en_alumno(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_alumno(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;  
	id_desde integer;
	id_hasta integer;  	
	total integer;
BEGIN 

desde:=(select count(*) from alumno);
id_desde:=(select max(id_alumno) from alumno)+1;
IF desde is null then desde:=0; end if;

EXECUTE 'INSERT INTO public.alumno(id_persona, id_unidad_servicio, c_indigena, centro_encierro, 
c_nivel_alcanzado_madre, c_nivel_alcanzado_padre)
SELECT distinct t.id_p, t.id_us,alumno_indigena::smallint, alumno_centro_encierro, 
       alumno_nivel_alcanzado_madre::smallint, alumno_nivel_alcanzado_padre::smallint
FROM '||$1||' t
join (SELECT id_p, id_us FROM '||$1||' except SELECT id_persona, id_unidad_servicio FROM public.alumno) e 
on e.id_p=t.id_p and e.id_us=t.id_us	
WHERE t.id_p is not null and t.id_us is not null;';

IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_a')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_a integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_a=id_alumno from public.alumno a where id_p=id_persona and id_us=id_unidad_servicio;';
hasta:=(select count(*) from alumno);
id_hasta:=(select max(id_alumno) from alumno);
EXECUTE 'select count (*) from (select distinct id_p, id_i from '||$1||')z;' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'alumno',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN ALUMNO';
END;
$_$;


ALTER FUNCTION public.insert_en_alumno(character varying) OWNER TO postgres;

--
-- TOC entry 459 (class 1255 OID 36389)
-- Name: insert_en_alumno_inscripcion(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_alumno_inscripcion(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	id_desde integer;
	id_hasta integer;  
	total integer;	
BEGIN 
DROP TABLE IF EXISTS casos;
desde:=(select count(*) from alumno_inscripcion);
id_desde:=(select max(id_alumno_inscripcion) from alumno_inscripcion)+1;
IF desde is null then desde:=0; end if;

create temp table casos (id_a integer,id_t integer);
EXECUTE 'INSERT INTO casos(SELECT id_a, id_t FROM '||$1||' except SELECT id_alumno, id_titulacion FROM public.alumno_inscripcion);
INSERT INTO alumno_inscripcion(id_alumno, c_grado_nivel_servicio, id_titulacion,c_cursa,c_estado_inscripcion, 
inscripcion_avanzada, id_seccion_curricular,c_recursante,c_ciclo_lectivo)

SELECT distinct t.id_a, max(c_gns), t.id_t, min(alumno_cursa::smallint),1, false, min(id_sc::integer), 
2,2015 --estoy inscribiendo a todos como regulares , no recursantes y en ciclo lect 2015
FROM '||$1||' t
join casos e 
on e.id_a=t.id_a and e.id_t=t.id_t	
where t.id_a is not null and t.id_t is not null and nivel_servicio::smallint in (1001,1002,1003,1004,3003) and c_gns is not null
group by t.id_a, t.id_t;';

IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_ai')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_ai integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_ai=id_alumno_inscripcion from public.alumno_inscripcion a where id_t=id_titulacion and id_a=id_alumno;';

hasta:=(select count(*) from alumno_inscripcion);
id_hasta:=(select max(id_alumno_inscripcion) from alumno_inscripcion);
EXECUTE 'select count (*) from (select distinct id_a, id_t from '||$1||')z;' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'alumno_inscripcion',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN ALUMNO_INSCRIPCION';
END;
$_$;


ALTER FUNCTION public.insert_en_alumno_inscripcion(character varying) OWNER TO postgres;

--
-- TOC entry 460 (class 1255 OID 36390)
-- Name: insert_en_autoridad(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_autoridad(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	id_desde integer;
	id_hasta integer;  	
	total integer;
BEGIN 
desde:=(select count(*) from autoridad);
id_desde:=(select max(id_autoridad) from autoridad)+1;
IF desde is null then desde:=0; end if;
EXECUTE
'INSERT INTO autoridad(id_persona, id_institucion, id_nombre_cargo)
SELECT distinct t.id_p, t.id_i, cargo::smallint from '||$1||' t
join (SELECT id_p, id_i FROM '||$1||' except SELECT id_persona, id_institucion FROM public.autoridad) e 
on e.id_p=t.id_p and e.id_i=t.id_i	
where t.id_i is not null and t.id_p is not null;';
hasta:=(select count(*) from autoridad);
id_hasta:=(select max(id_autoridad) from autoridad);
EXECUTE 'select count(distinct nro_documento) from '||$1||';' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'autoridad',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN AUTORIDAD';
END;
$_$;


ALTER FUNCTION public.insert_en_autoridad(character varying) OWNER TO postgres;

--
-- TOC entry 461 (class 1255 OID 36391)
-- Name: insert_en_espacio_curricular(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_espacio_curricular(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	id_desde integer;
	id_hasta integer;  	  
	total integer;
BEGIN 
desde:=(select count(*) from espacio_curricular);
id_desde:=(select max(id_espacio_curricular) from espacio_curricular)+1;
IF desde is null then desde:=0; end if;
if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO espacio_curricular(id_titulacion, c_grado_nivel_servicio, id_nombre_espacio_curricular, c_trayecto_formativo)
	SELECT distinct t.id_t, t.c_gns, t.id_nec, 
	case when nivel_servicio::smallint in (1003,3003) then -1 /*no corresponde para secundaria*/
	     when nivel_servicio::smallint =1004 then 2 /*sin info para superior*/end as tray_form
	FROM '||$1||' t
	join (SELECT id_t, c_gns, id_nec::smallint/*, espacio_curricular_trayecto_formativo::smallint*/ FROM '||$1||' except 
	SELECT id_titulacion, c_grado_nivel_servicio, id_nombre_espacio_curricular/*, c_trayecto_formativo*/ FROM espacio_curricular) e 
	on e.id_t=t.id_t and e.c_gns=t.c_gns and e.id_nec=t.id_nec /*and e.espacio_curricular_trayecto_formativo=t.espacio_curricular_trayecto_formativo::smallint*/
	where t.id_t is not null and t.c_gns is not null and t.id_nec is not null;';
else --para cuando se carga desde caja_curr
	EXECUTE 'INSERT INTO espacio_curricular(id_titulacion, c_grado_nivel_servicio, id_nombre_espacio_curricular, c_trayecto_formativo,
	c_dictado, c_obligatoriedad, c_carga_horaria_en, carga_horaria_semanal, c_duracion_en, duracion, c_escala_numerica, nota_minima)
	SELECT distinct t.id_t, t.c_gns, t.id_nec, 
	case when nivel_servicio::smallint in (1003,3003) then -1 /*no corresponde para secundaria*/
	     when nivel_servicio::smallint =1004 then 2 /*sin info para superior*/end as tray_form,
	espacio_curricular_dictado::smallint,espacio_curricular_obligatoriedad::smallint,espacio_curricular_carga_horaria_en::smallint,
	espacio_curricular_carga_horaria_semanal::smallint,espacio_curricular_duracion_en::smallint,espacio_curricular_duracion::smallint,
	espacio_curricular_escala_numerica::smallint,espacio_curricular_nota_minima::smallint
	FROM '||$1||' t
	join (SELECT id_t, c_gns, id_nec::smallint/*, espacio_curricular_trayecto_formativo::smallint*/ FROM '||$1||' except 
	SELECT id_titulacion, c_grado_nivel_servicio, id_nombre_espacio_curricular/*, c_trayecto_formativo*/ FROM espacio_curricular) e 
	on e.id_t=t.id_t and e.c_gns=t.c_gns and e.id_nec=t.id_nec /*and e.espacio_curricular_trayecto_formativo=t.espacio_curricular_trayecto_formativo::smallint*/
	where t.id_t is not null and t.c_gns is not null and t.id_nec is not null;';
end if;

--agregar y llenar campo con id de espacio_curricular que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_ec')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_ec integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_ec=id_espacio_curricular 
from public.espacio_curricular where id_titulacion=id_t and c_grado_nivel_servicio=c_gns 
and id_nombre_espacio_curricular = id_nec::smallint/* and c_trayecto_formativo=espacio_curricular_trayecto_formativo::smallint*/;';

hasta:=(select count(*) from espacio_curricular);
id_hasta:=(select max(id_espacio_curricular) from espacio_curricular);
EXECUTE 'select count (*) from (select distinct id_t, c_gns, id_nec from '||$1||')z;' INTO total;

INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'espacio_curricular',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN ESPACIO CURRICULAR';
END;
$_$;


ALTER FUNCTION public.insert_en_espacio_curricular(character varying) OWNER TO postgres;

--
-- TOC entry 462 (class 1255 OID 36392)
-- Name: insert_en_nombre_espacio_curricular(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_nombre_espacio_curricular(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;  
	id_desde integer;
	id_hasta integer;  	
	total integer;
	_letras varchar := '''%[A-Z]%''';
	_origen varchar := '''áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ''';
	_destino varchar :='''aeiouAEIOUaeiouAEIOUÑ''';
BEGIN 
desde:=(select count(*) from nombre_espacio_curricular);
id_desde:=(select max(id_nombre_espacio_curricular) from nombre_espacio_curricular)+1;
IF desde is null then desde:=0; end if;
--quito los grados que no son numeros, para poder obtener grado nivel servicio
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='anio_de_estudio_original')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN anio_de_estudio_original character varying;'; END IF; 
EXECUTE 'UPDATE '||$1||' set anio_de_estudio_original=anio_de_estudio';
EXECUTE 'UPDATE '||$1||' set anio_de_estudio=null;';
EXECUTE 'update '||$1||' set anio_de_estudio=anio_de_estudio_original::smallint where anio_de_estudio_original not similar to '||_letras||';';
--agregar y llenar campo con codigo de grado_nivel_servicio
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='c_gns')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN c_gns smallint;'; END IF; 
EXECUTE 'UPDATE '||$1||' set c_gns=c_grado_nivel_servicio
from codigos.grado_nivel_servicio_tipo where c_grado=anio_de_estudio::smallint and c_nivel_servicio=nivel_servicio::smallint
and nivel_servicio::smallint in (1001,1002,1003,1004,3003) and anio_de_estudio is not null;';

if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO public.nombre_espacio_curricular(nombre)
	(SELECT trim(upper(translate (espacio_curricular_nombre,'||_origen||','||_destino||'))) FROM '||$1||' 
	where espacio_curricular_nombre is not null 
	except
	select trim(upper(translate (nombre,'||_origen||','||_destino||'))) from public.nombre_espacio_curricular);';
else --para cuando se carga desde caja_curr POR AHORA SON IGUALES
	EXECUTE 'INSERT INTO public.nombre_espacio_curricular(nombre)
	(SELECT trim(upper(translate (espacio_curricular_nombre,'||_origen||','||_destino||'))) FROM '||$1||' 
	where espacio_curricular_nombre is not null 
	except
	select trim(upper(translate (nombre,'||_origen||','||_destino||'))) from public.nombre_espacio_curricular);';
end if;

--agregar y llenar campo con id de nombre_espacio_curricular que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_nec')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_nec integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_nec=id_nombre_espacio_curricular from public.nombre_espacio_curricular a where 
trim(upper(translate (espacio_curricular_nombre,'||_origen||','||_destino||')))=trim(upper(translate (nombre,'||_origen||','||_destino||')));';

hasta:=(select count(*) from nombre_espacio_curricular);
id_hasta:=(select max(id_nombre_espacio_curricular) from nombre_espacio_curricular);
EXECUTE 'select count(distinct espacio_curricular_nombre) from '||$1||';' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'nombre_espacio_curricular',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN NOMBRE_ESPACIO_CURRICULAR';
END;
$_$;


ALTER FUNCTION public.insert_en_nombre_espacio_curricular(character varying) OWNER TO postgres;

--
-- TOC entry 463 (class 1255 OID 36393)
-- Name: insert_en_nombre_titulacion(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_nombre_titulacion(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;  
	id_desde integer;
	id_hasta integer;  	
	total integer;
	_tablaalu varchar;  
	_caja varchar :='caja_curr';  
	_alu varchar :='alumnos'; 
	_origen varchar := '''áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ''';
	_destino varchar :='''aeiouAEIOUaeiouAEIOUÑ''';
BEGIN 
desde:=(select count(*) from nombre_titulacion);
id_desde:=(select max(id_nombre_titulacion) from nombre_titulacion)+1;
IF desde is null then desde:=0; end if;

--agregar y llenar campo con id de institucion
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_i')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_i integer;'; END IF; 
EXECUTE 'update '||$1||' p set id_i=id_institucion from public.institucion i where p.cueanexo=i.cueanexo;';

--agregar y llenar campo con id de unidad_servicio
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_us')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_us integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_us=id_unidad_servicio
from public.unidad_servicio where id_institucion=id_i and c_nivel_servicio=nivel_servicio::smallint;';

if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO public.nombre_titulacion(nombre)
	(SELECT trim(upper(translate (titulo_nombre,'||_origen||','||_destino||'))) FROM '||$1||' where titulo_nombre is not null 
	except
	select trim(upper(translate (nombre,'||_origen||','||_destino||'))) from public.nombre_titulacion);';
else --para cuando se carga desde caja_curr	
	EXECUTE 'INSERT INTO nombre_titulacion(c_carrera, nombre, nombre_abreviado, cod_titulo)
	(select distinct titulo_carrera::smallint, c.titulo_nombre,c.nombre_abreviado,c.titulo_cod_titulo::smallint 
	from '||$1||' c join
	(SELECT trim(upper(translate (titulo_nombre,'||_origen||','||_destino||'))) as titulo_nombre FROM '||$1||' where titulo_nombre is not null
	except select trim(upper(translate (nombre,'||_origen||','||_destino||'))) from public.nombre_titulacion) 
	e on trim(c.titulo_nombre)=trim(e.titulo_nombre));';
end if;

--agregar y llenar campo con id de nombre_titulacion que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_nt')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_nt integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_nt=id_nombre_titulacion from public.nombre_titulacion a where 
trim(upper(translate (titulo_nombre,'||_origen||','||_destino||')))=trim(upper(translate (nombre,'||_origen||','||_destino||')));';

hasta:=(select count(*) from nombre_titulacion);
id_hasta:=(select max(id_nombre_titulacion) from nombre_titulacion);
EXECUTE 'select count(distinct titulo_nombre) from '||$1||';' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'nombre_titulacion',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN NOMBRE_TITULACION';
END;
$_$;


ALTER FUNCTION public.insert_en_nombre_titulacion(character varying) OWNER TO postgres;

--
-- TOC entry 458 (class 1255 OID 36394)
-- Name: insert_en_persona(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_persona(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	id_desde integer;
	id_hasta integer;  
	total integer;
BEGIN 
desde:=(select count(*) from persona); --para saber cuantas personas se insertan
id_desde:=(select max(id_persona) from persona)+1;
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantas personas se insertan

--agregar y llenar campo con id de institucion, repito esto aqui (esta en insert de nombre titulacion) porque de aqui parte la migracion de autoridades
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_i')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_i integer;'; END IF; 
EXECUTE 'update '||$1||' p set id_i=id_institucion from public.institucion i where p.cueanexo=i.cueanexo;';

--insertar en public.persona
EXECUTE 'INSERT INTO public.persona(apellidos, nombres, c_tipo_documento, nro_documento,  
cuit_cuil, fecha_nacimiento, c_localidad_nacimiento, lugar_nacimiento, c_pais_nacimiento, c_nacionalidad, c_sexo, 
email, cod_area_telefono, nro_telefono, c_estado_civil, calle, nro, barrio, c_localidad, referencia, cod_postal)

SELECT t.apellidos, t.nombres, max(tipo_documento)::smallint as tipo_documento,
case when nro_documento_ok then t.nro_documento else null end as dni, 
max(case when cuil_ok then cuil else null end) as cuil, max(date(fecha_nacimiento)) as fecha_nacimiento, 
max(localidad_nacimiento)::integer as localidad_nacimiento, max(lugar_nacimiento) as lugar_nacimiento,
max(pais_nacimiento)::smallint as pais_nacimiento, max(nacionalidad)::smallint as nacionalidad, max(sexo)::smallint as sexo,
max(email) as email, max(cod_area_telefono) as cod_area_telefono, max(nro_telefono) as nro_telefono, 
max(estado_civil)::smallint estado_civil ,max(calle) as calle, 
max(nro) as nro, max(barrio) as barrio ,max(localidad)::integer as localidad ,max(referencia) as referencia, max(cod_postal) as cod_postal
FROM '||$1||' t
join (SELECT nro_documento,apellidos, nombres FROM '||$1||' except SELECT nro_documento, apellidos, nombres from public.persona) e 
on e.nro_documento=t.nro_documento and e.apellidos=t.apellidos and t.nombres=e.nombres
WHERE nro_documento_ok and apellido_ok
group by  t.apellidos, t.nombres,t.nro_documento,t.nro_documento_ok;';

--agregar y llenar el campo id_p para poner el id_personal que acaba de insertar
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_p')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_p integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' s set id_p=id_persona from public.persona p where s.nro_documento=p.nro_documento;';

hasta:=(select count(*) from persona); --para saber cuantas personas se insertan
id_hasta:=(select max(id_persona) from persona);
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct apellidos, nombres, tipo_documento::smallint,
case when nro_documento_ok then t.nro_documento else null end as dni, 
case when cuil_ok then cuil else null end as cuil, date(fecha_nacimiento), 
localidad_nacimiento, lugar_nacimiento,pais_nacimiento, nacionalidad, sexo,
email, cod_area_telefono, nro_telefono, estado_civil,calle, 
nro, barrio,localidad,referencia, cod_postal
FROM '||$1||' t)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'persona',hasta-desde,total, id_desde, id_hasta); 
--mostrar cantidad de insertados
RETURN hasta-desde||' REGISTROS CARGADOS EN PERSONA';

END;
$_$;


ALTER FUNCTION public.insert_en_persona(character varying) OWNER TO postgres;

--
-- TOC entry 466 (class 1255 OID 36395)
-- Name: insert_en_seccion(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_seccion(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer; 
	id_desde integer;
	id_hasta integer;  
	total integer;
BEGIN 
desde:=(select count(*) from seccion);
id_desde:=(select max(id_seccion) from seccion)+1;
IF desde is null then desde:=0; end if;
ALTER TABLE public.seccion add column grado character varying;

if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO seccion(id_institucion, nombre, c_tipo_seccion,id_espacio_curricular,grado)
	select distinct t.id_i, trim(t.seccion_nombre) as seccion_nombre, t.seccion_tipo::smallint, id_ec,anio_de_estudio from '||$1||' t
	join (select id_i, trim(seccion_nombre) as nseccion ,seccion_tipo::smallint from '||$1||'
	except select id_institucion, nombre, c_tipo_seccion from public.seccion) e
	on e.id_i=t.id_i and trim(e.nseccion)=trim(t.seccion_nombre) and e.seccion_tipo=t.seccion_tipo::smallint 
	where seccion_nombre_ok and t.id_i is not null and t.seccion_tipo is not null';	
else	--para cuando se carga desde caja_curr	
	EXECUTE 'INSERT INTO seccion(id_institucion, nombre, c_tipo_seccion, plazas, c_organizacion_cursada, id_espacio_curricular,grado)
	select distinct t.id_i, trim(t.seccion_nombre) as seccion_nombre, t.seccion_tipo::smallint, seccion_plazas::smallint, 
	seccion_organizacion_cursada::smallint, id_ec, anio_de_estudio from '||$1||' t
	join (select id_i, trim(seccion_nombre) as nseccion ,seccion_tipo::smallint from '||$1||'
	except select id_institucion, nombre, c_tipo_seccion from public.seccion) e
	on e.id_i=t.id_i and trim(e.nseccion)=trim(t.seccion_nombre) and e.seccion_tipo=t.seccion_tipo::smallint 
	where seccion_nombre_ok and t.id_i is not null and t.seccion_tipo is not null';

end if;

--agregar y llenar campo con id de seccion que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_s')=0
THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_s integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_s=id_seccion
from public.seccion where id_institucion=id_i and nombre= trim(seccion_nombre) and c_tipo_seccion= seccion_tipo::smallint;';-- and anio_de_estudio=grado;';	

EXECUTE 'create temp table para_id_sec (s_ integer, i_ integer, n_ character varying, t_ smallint, g_ smallint);
insert into para_id_sec (select id_seccion as s_, id_institucion as i_,nombre as n_, c_tipo_seccion as t_, c_grado as g_ from public.seccion s
join seccion_curricular using(id_seccion)
join codigos.grado_nivel_servicio_tipo using (c_grado_nivel_servicio));
	
UPDATE '||$1||' t set id_s=s_ from para_id_sec a
where id_i = i_ and trim(seccion_nombre) = n_ and seccion_tipo::smallint = t_ and anio_de_estudio::smallint = g_ and id_s is null;';

hasta:=(select count(*) from seccion);
id_hasta:=(select max(id_seccion) from seccion);
EXECUTE 'select count (*) from (select distinct id_i, trim(seccion_nombre) ,seccion_tipo, c_gns from '||$1||')z;' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'seccion',hasta-desde,total, id_desde, id_hasta); 
ALTER TABLE public.seccion drop column grado;
RETURN hasta-desde||' REGISTROS CARGADOS EN SECCION';
END;
$_$;


ALTER FUNCTION public.insert_en_seccion(character varying) OWNER TO postgres;

--
-- TOC entry 467 (class 1255 OID 36396)
-- Name: insert_en_seccion_curricular(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_seccion_curricular(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	id_desde integer;
	id_hasta integer;  	  
	total integer;
BEGIN 
desde:=(select count(*) from seccion_curricular);
id_desde:=(select max(id_seccion_curricular) from seccion_curricular)+1;
IF desde is null then desde:=0; end if;

if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO seccion_curricular(id_seccion, id_titulacion, c_grado_nivel_servicio, c_turno, c_trayecto_formativo)
	select distinct t.id_s, t.id_t, t.c_gns, t.seccion_turno::smallint, -2 from '||$1||' t
	join  (SELECT id_s, id_t, c_gns, seccion_turno::smallint FROM '||$1||' except 
	SELECT id_seccion, id_titulacion, c_grado_nivel_servicio, c_turno FROM public.seccion_curricular) e 
	on e.id_s=t.id_s and e.id_t=t.id_t and e.c_gns=t.c_gns and e.seccion_turno::smallint=t.seccion_turno::smallint
	where t.id_s is not null and t.id_t is not null;';
else	--para cuando se carga desde caja_curr	
	--por ahora son iguales, la v2 del excel incluye ademas seccion_trayecto formativo, modificar
	
	EXECUTE 'INSERT INTO seccion_curricular(id_seccion, id_titulacion, c_grado_nivel_servicio, c_turno, c_trayecto_formativo)
	select distinct t.id_s, t.id_t, t.c_gns, t.seccion_turno::smallint, -2 from '||$1||' t
	join  (SELECT id_s, id_t, c_gns, seccion_turno::smallint FROM '||$1||' except 
	SELECT id_seccion, id_titulacion, c_grado_nivel_servicio, c_turno FROM public.seccion_curricular) e 
	on e.id_s=t.id_s and e.id_t=t.id_t and e.c_gns=t.c_gns and e.seccion_turno::smallint=t.seccion_turno::smallint
	where t.id_s is not null and t.id_t is not null;';
end if;

--agregar y llenar campo con id de seccion curricular que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_sc')=0
THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_sc integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_sc=id_seccion_curricular from public.seccion_curricular where 
id_seccion=id_s and id_titulacion=id_t and c_grado_nivel_servicio=c_gns and c_turno=seccion_turno::smallint;';	

hasta:=(select count(*) from seccion_curricular);
id_hasta:=(select max(id_seccion_curricular) from seccion_curricular);
EXECUTE 'select count (*) from (select distinct  id_s, id_t, c_gns, seccion_turno from '||$1||')z;' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'seccion_curricular',hasta-desde,total, id_desde, id_hasta);  
RETURN hasta-desde||' REGISTROS CARGADOS EN SECCION_CURRICULAR';
END;
$_$;


ALTER FUNCTION public.insert_en_seccion_curricular(character varying) OWNER TO postgres;

--
-- TOC entry 468 (class 1255 OID 36397)
-- Name: insert_en_titulacion(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_titulacion(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;  
	id_desde integer;
	id_hasta integer;  	
	total integer;
BEGIN 
desde:=(select count(*) from titulacion);
id_desde:=(select max(id_titulacion) from titulacion)+1;
IF desde is null then desde:=0; end if;

if $1 ilike '%alumnos%' then --para cuando se carga desde alumnos
	EXECUTE 'INSERT INTO titulacion(id_unidad_servicio, id_nombre_titulacion, c_organizacion_plan, c_organizacion_cursada,c_duracion_en)
	SELECT distinct t.id_us, t.id_nt, case when nivel_servicio::smallint =1003 then 1 end as org_plan,
	case when nivel_servicio::smallint =1003 then 3 /*division*/
	     when nivel_servicio::smallint =1004 then 2 /*comision*/end as org_cur, case when nivel_servicio::smallint =1003 then 1 end as dur_en
	FROM '||$1||' t
	join (SELECT id_us, id_nt FROM '||$1||' except SELECT id_unidad_servicio, id_nombre_titulacion FROM public.titulacion) e 
	on e.id_us=t.id_us and e.id_nt=t.id_nt	
	where t.id_us is not null and t.id_nt is not null;';
else --para cuando se carga desde caja_curr
	EXECUTE 'INSERT INTO titulacion(id_unidad_servicio, id_nombre_titulacion,
	c_certificacion, c_dicta, c_condicion, cohorte, cohorte_finalizacion, c_tipo_formacion, 
	c_tipo_titulo, c_a_termino, c_orientacion, c_organizacion_plan, c_organizacion_cursada, 
	c_dictado, c_tiene_tit_int, carga_horaria, c_carga_horaria_en, edad_minima, c_articulacion_tit, 
	c_articulacion_univ, nro_infod, c_inscripto_inet, duracion, c_duracion_en)
	SELECT distinct t.id_us, t.id_nt, titulo_certificacion::smallint,titulo_vigente_este_anio::smallint,
	condicion_ingreso::smallint,titulo_cohorte_implementacion::smallint,titulo_cohorte_finalizacion::smallint,
	titulo_tipo_formacion::smallint,titulo_tipo::smallint,titulo_a_termino::smallint,titulo_orientacion::smallint,
	titulo_organizacion_plan::smallint,titulo_organizacion_cursada_titulo::smallint,
	titulo_forma_dictado::smallint,titulo_tiene_titulo_intermedio::smallint,titulo_carga_horaria::smallint,
	titulo_carga_horaria_en::smallint,titulo_edad_minima::smallint,titulo_tiene_articulacion::smallint,
	titulo_tiene_articulacion_univ::smallint,titulo_nro_infod,titulo_inscripto_inet::smallint,titulo_duracion::integer,
	titulo_duracion_en::smallint
	FROM '||$1||' t 
	join (SELECT id_us, id_nt FROM '||$1||' except SELECT id_unidad_servicio, id_nombre_titulacion FROM public.titulacion) e 
	on e.id_us=t.id_us and e.id_nt=t.id_nt
	where t.id_us is not null and t.id_nt is not null;';
end if;

--agregar y llenar campo con id de titulacion que se acaba de agregar o ya existia
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_t')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_t integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' set id_t=id_titulacion from public.titulacion where id_unidad_servicio=id_us and id_nombre_titulacion=id_nt;';

hasta:=(select count(*) from titulacion);
id_hasta:=(select max(id_titulacion) from titulacion);
EXECUTE 'select count (*) from (select distinct id_us, id_nt from '||$1||')z;' INTO total;
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'titulacion',hasta-desde,total, id_desde, id_hasta); 
RETURN hasta-desde||' REGISTROS CARGADOS EN TITULACION';
END;
$_$;


ALTER FUNCTION public.insert_en_titulacion(character varying) OWNER TO postgres;

--
-- TOC entry 469 (class 1255 OID 36398)
-- Name: insert_en_usuario(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_usuario(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	total integer;
BEGIN 
desde:=(select count(*) from app.usuario); --para saber cuantos usuarios se insertan
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantos usuarios se insertan
--insertar en app.usuario
EXECUTE ' INSERT INTO app.usuario(username, password, activo, email, id_persona)
SELECT distinct usuario_nombre,md5(usuario_pass), true, email, id_p FROM '||$1||' where id_p not in (select id_persona from app.usuario)
and usuario_nombre not in (select username from app.usuario) and id_i is not null';
--agregar y llenar el campo id_u para poner el id_usuario que acaba de insertar
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_u')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_u integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' s set id_u=id_usuario from app.usuario where id_p=id_persona';
--agregar y llenar el campo id_us con la unidad de servicio
IF (SELECT count(*) FROM information_schema.columns WHERE table_schema||'.'||table_name = $1 and column_name='id_us')=0
	THEN EXECUTE 'ALTER TABLE '||$1||' ADD COLUMN id_us integer;'; END IF; 
EXECUTE 'UPDATE '||$1||' s set id_us=id_unidad_servicio
from public.unidad_servicio where id_institucion=id_i and c_nivel_servicio=nivel_servicio::smallint;';

hasta:=(select count(*) from app.usuario); --para saber cuantos usuarios se insertan
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct usuario_nombre,usuario_pass, true, email, id_p FROM '||$1||' t)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'usuario',hasta-desde,total); 
--mostrar cantidad de insertados
RETURN hasta-desde||' REGISTROS CARGADOS EN APP.USUARIO';
END;
$_$;


ALTER FUNCTION public.insert_en_usuario(character varying) OWNER TO postgres;

--
-- TOC entry 470 (class 1255 OID 36399)
-- Name: insert_en_usuario_perfil_referencia(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_en_usuario_perfil_referencia(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	desde integer;
	hasta integer;
	total integer;
	editar integer;
	emitir integer;
	ver integer;
	descargar integer;
BEGIN 
desde:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantos usuarios_perfil_referencia se insertan
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantos usuarios_perfil_referencia se insertan
--insertar en app.usuario_perfil_referencia perfil editar
EXECUTE ' INSERT INTO app.usuario_perfil_referencia(id_usuario, c_perfil, id_referencia1)
SELECT distinct id_u, 200, id_us from '||$1||' where id_u is not null and id_us is not null and editar is not null
except select distinct id_usuario, c_perfil, id_referencia1 from app.usuario_perfil_referencia;';
hasta:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantas usuario_perfil_referencia se insertan
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct id_u, id_us FROM '||$1||' t where editar is not null)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'usuario_perfil_referencia - editar',hasta-desde,total); 
--insertados para editar
editar:= hasta-desde;

desde:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantos usuarios_perfil_referencia se insertan
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantos usuarios_perfil_referencia se insertan
--insertar en app.usuario_perfil_referencia perfil emitir
EXECUTE ' INSERT INTO app.usuario_perfil_referencia(id_usuario, c_perfil, id_referencia1)
SELECT distinct id_u, 210, id_us from '||$1||' where id_u is not null and id_us is not null and emitir is not null
except select distinct id_usuario, c_perfil, id_referencia1 from app.usuario_perfil_referencia;';
hasta:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantas usuario_perfil_referencia se insertan
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct id_u, id_us FROM '||$1||' t where emitir is not null)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'usuario_perfil_referencia - emitir',hasta-desde,total); 
--insertados para emitir
emitir:= hasta-desde;

desde:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantos usuarios_perfil_referencia se insertan
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantos usuarios_perfil_referencia se insertan
--insertar en app.usuario_perfil_referencia perfil ver
EXECUTE ' INSERT INTO app.usuario_perfil_referencia(id_usuario, c_perfil, id_referencia1)
SELECT distinct id_u, 300, id_us from '||$1||' where id_u is not null and id_us is not null and ver is not null
except select distinct id_usuario, c_perfil, id_referencia1 from app.usuario_perfil_referencia;';
hasta:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantas usuario_perfil_referencia se insertan
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct id_u, id_us FROM '||$1||' t where ver is not null)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'usuario_perfil_referencia - ver',hasta-desde,total); 
--insertados para ver
ver:= hasta-desde;

desde:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantos usuarios_perfil_referencia se insertan
IF desde is null then desde:=0; end if; --si la tabla esta vacia, para saber cuantos usuarios_perfil_referencia se insertan
--insertar en app.usuario_perfil_referencia perfil descargar
EXECUTE ' INSERT INTO app.usuario_perfil_referencia(id_usuario, c_perfil, id_referencia1)
SELECT distinct id_u, 470, id_us from '||$1||' where id_u is not null and id_us is not null and descargar is not null
except select distinct id_usuario, c_perfil, id_referencia1 from app.usuario_perfil_referencia;';
hasta:=(select count(*) from app.usuario_perfil_referencia); --para saber cuantas usuario_perfil_referencia se insertan
--para calcular el total y compararlo con la cantidad de insertados
EXECUTE 'select count (*) from (SELECT distinct id_u, id_us FROM '||$1||' t where descargar is not null)z;' INTO total;
--insertar total e insertados
INSERT INTO transferencia.registros_insertados VALUES (now(),$1,'usuario_perfil_referencia - descargar',hasta-desde,total); 
--insertados para descargar
descargar:= hasta-desde;

--mostrar cantidad de insertados
RETURN 'REGISTROS CARGADOS EN APP.USUARIO_PERFIL_REFERENCIA editar('||editar||'), emitir ('||emitir||'),descargar ('||descargar||');';

END;
$_$;


ALTER FUNCTION public.insert_en_usuario_perfil_referencia(character varying) OWNER TO postgres;

--
-- TOC entry 474 (class 1255 OID 36400)
-- Name: limpieza_carga_inicial(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION limpieza_carga_inicial(character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_origen varchar := '''áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ''';
	_destino varchar := '''aeiouAEIOUaeiouAEIOUÑ''';
	_punto varchar := '''.''';
	_guion varchar := '''-''';
	_nada varchar:='''''';
BEGIN 
	if $1 ilike '%alumnos%' or $1 ilike '%autoridades%' or $1 ilike '%usuarios%' then
		EXECUTE 'UPDATE '||$1||' SET nro_documento = (translate(nro_documento,'||_punto||','||_nada||'));';
		EXECUTE 'UPDATE '||$1||' SET cuil = (translate(cuil,'||_guion||','||_nada||'));';
		EXECUTE 'UPDATE '||$1||' SET apellidos = upper(translate (trim(apellidos),'|| _origen||','||_destino||'));';
		EXECUTE 'UPDATE '||$1||' SET nombres = upper(translate (trim(nombres),'|| _origen||','||_destino||'));';
	end if;	
	if $1 ilike '%alumnos%' or $1 ilike '%caja_curr%' then	
		EXECUTE 'UPDATE '||$1||' SET seccion_nombre = upper(translate (trim(seccion_nombre),'|| _origen||','||_destino||'));';
		EXECUTE 'UPDATE '||$1||' SET titulo_nombre = upper(translate (trim(titulo_nombre),'|| _origen||','||_destino||'));';
		EXECUTE 'UPDATE '||$1||' SET espacio_curricular_nombre = upper(translate (trim(espacio_curricular_nombre),'|| _origen||','||_destino||'));';
	end if;
	RETURN 'LIMPIEZA LISTO';
END;
$_$;


ALTER FUNCTION public.limpieza_carga_inicial(character varying) OWNER TO postgres;

--
-- TOC entry 475 (class 1255 OID 36401)
-- Name: llamar_usuario_director(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION llamar_usuario_director() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
 l RECORD;
BEGIN
FOR l IN
    SELECT cx, ns FROM lista
LOOP
    EXECUTE 'SELECT public.usuario_director('''||l.cx||'''::text,'||l.ns||'::smallint)';
END LOOP;
RETURN TRUE;
END;
$$;


ALTER FUNCTION public.llamar_usuario_director() OWNER TO postgres;

--
-- TOC entry 476 (class 1255 OID 36402)
-- Name: llenar_desde_csv(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION llenar_desde_csv(character varying, character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombreorigen varchar;
BEGIN 
	_nombreorigen:=''''||$2||''' delimiter '||''';'''||' CSV HEADER;';
	EXECUTE 'COPY '||$1||' FROM '''||$2|| ''' delimiter '||''';'''||' CSV HEADER;';
	RETURN _nombreorigen||' cargada en '||$1;
END;
$_$;


ALTER FUNCTION public.llenar_desde_csv(character varying, character varying) OWNER TO postgres;

--
-- TOC entry 477 (class 1255 OID 36403)
-- Name: llenar_desde_csv_latin1(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION llenar_desde_csv_latin1(character varying, character varying) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
	_nombreorigen varchar;
	_latin1 varchar := '''LATIN1''';
BEGIN 
	_nombreorigen:=''''||$2||''' delimiter '||''';'''||' CSV HEADER;';
	EXECUTE 'COPY '||$1||' FROM '''||$2|| ''' delimiter '||''';'''||' CSV HEADER ENCODING '||_latin1||';';
	RETURN _nombreorigen||' cargada en '||$1;
END;
$_$;


ALTER FUNCTION public.llenar_desde_csv_latin1(character varying, character varying) OWNER TO postgres;

--
-- TOC entry 478 (class 1255 OID 36404)
-- Name: validar_cuit(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION validar_cuit(character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	res bigint;
	dig bigint;
	num bigint;
	cuit alias for $1;
	
begin
	if length(cuit) != 11 or substr(cuit, 1, 2) = '00' then
		return false;
	end if;
	res = 0;
	for i in 1..10 loop
		num := (substr(cuit, i, 1));
		if (i = 1 or i = 7) then res := res + num * 5;
		elsif (I = 2 OR I = 8) then res := res + num * 4;
		elsif (I = 3 OR I = 9) then res := res + num * 3;
		elsif (I = 4 OR I = 10) then res := res + num * 2;
		elsif (I = 5) then res := res + num * 7;
		elsif (I = 6) then res := res + num * 6;
		end if;
	end loop;
	dig := 11 - mod(res,11);
	if dig = 11 then 
		dig := 0;
	end if;
	if dig = (substr(cuit,11,1))::smallint then
		return true;
	else
		return false;
	end if;
end;
$_$;


ALTER FUNCTION public.validar_cuit(character varying) OWNER TO postgres;

--
-- TOC entry 179 (class 1259 OID 36405)
-- Name: persona; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE persona (
    id_persona integer NOT NULL,
    apellidos character varying NOT NULL,
    nombres character varying,
    c_tipo_documento smallint,
    nro_documento character varying,
    cuit_cuil character varying(11),
    fecha_nacimiento date,
    c_localidad_nacimiento integer,
    lugar_nacimiento character varying,
    c_pais_nacimiento smallint,
    c_nacionalidad smallint,
    c_sexo smallint,
    email character varying(250),
    cod_area_telefono character varying,
    nro_telefono character varying,
    c_estado_civil smallint,
    calle character varying,
    nro character varying,
    barrio character varying,
    c_localidad integer,
    referencia character varying,
    cod_postal character varying,
    c_pais_domicilio smallint,
    c_provincia_nacimiento integer,
    CONSTRAINT persona_apellidos_check CHECK ((upper((apellidos)::text) ~ similar_escape('[A-ZÁÇÉÍÑÓÚÜ. '']{0,}'::text, NULL::text))),
    CONSTRAINT persona_cuit_cuil_check CHECK (((cuit_cuil IS NULL) OR validar_cuit(cuit_cuil))),
    CONSTRAINT persona_nombres_check CHECK ((upper((nombres)::text) ~ similar_escape('[A-ZÁÇÉÍÑÓÚÜ. '']{0,}'::text, NULL::text)))
);


ALTER TABLE public.persona OWNER TO postgres;

--
-- TOC entry 479 (class 1255 OID 36414)
-- Name: persona_parecida(integer, character varying, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION persona_parecida(par_ictipodoc integer, par_snrodoc character varying, par_sapellido character varying, par_blncasesensitive boolean) RETURNS SETOF persona
    LANGUAGE plpgsql STRICT ROWS 50
    AS $$
DECLARE 
	var_sApellido character varying;
BEGIN
IF par_blnCaseSensitive = FALSE THEN
	SELECT lower(par_sApellido) INTO var_sApellido;
ELSE
	var_sApellido = par_sApellido;
END IF;
RETURN QUERY SELECT *
	FROM persona 
	WHERE c_tipo_documento = par_iCTipoDoc AND nro_documento = par_sNroDoc AND 
	--Solo Evaluo 1 vez diferencia_caracteres. Por eso no uso el operador logico AND
	CASE WHEN length(apellidos)<=4 THEN
		--Apellido hasta 4 caracteres con al menos 1 diferencia.
		CASE WHEN diferencia_caracteres(
			CASE WHEN par_blnCaseSensitive = FALSE THEN 
				lower(persona.apellidos) 
			ELSE persona.apellidos END,
			var_sApellido) <= 1  THEN true ELSE  false END
	ELSE
		--Apellido mas de 4 caracteres con al menos 3 diferencia identifican un parecido.
		CASE WHEN diferencia_caracteres(
			CASE WHEN par_blnCaseSensitive = FALSE THEN 
				lower(persona.apellidos) 
			ELSE persona.apellidos END,
			var_sApellido) <= 3  THEN true ELSE false END
	END = true;
END;
$$;


ALTER FUNCTION public.persona_parecida(par_ictipodoc integer, par_snrodoc character varying, par_sapellido character varying, par_blncasesensitive boolean) OWNER TO postgres;

--
-- TOC entry 480 (class 1255 OID 36415)
-- Name: text_to_minusculas_sin_especiales(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION text_to_minusculas_sin_especiales(campo text) RETURNS text
    LANGUAGE plpgsql
    AS $_$ 
BEGIN
return trim(lower(translate (regexp_replace($1, '\s+', ' ', 'g'), 'áéíóúÁÉÍÓÚäëïöüÄËÏÖÜñ', 'aeiouAEIOUaeiouAEIOUÑ')));
END;
$_$;


ALTER FUNCTION public.text_to_minusculas_sin_especiales(campo text) OWNER TO postgres;

--
-- TOC entry 481 (class 1255 OID 36416)
-- Name: usuario_director(text, smallint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION usuario_director(cx text, ns smallint) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$ 
BEGIN
--A. USUARIO
INSERT INTO app.usuario(username, password, activo, email)  VALUES ($1,md5($1), TRUE,null);
--B. PERFIL DE DIRECTOR AL USUARIO DEL CUEANEXO
INSERT INTO app.usuario_perfil_assn(id_usuario, id_perfil) 
select (select id_usuario from app.usuario where username=$1),(select id_perfil from app.perfil where descripcion ='DIRECTOR');
--C. ACCESO A SU UNIDAD DE SERVICIO
INSERT INTO app.acceso_unidad_servicio_assn(id_usuario, id_unidad_servicio)
(select (select id_usuario from app.usuario where username=$1),
(select id_unidad_servicio from unidad_servicio where id_institucion = 
(select id_institucion from institucion where cue||anexo=$1) and c_nivel_servicio=$2));
return true;
END;
$_$;


ALTER FUNCTION public.usuario_director(cx text, ns smallint) OWNER TO postgres;

SET search_path = codigos, pg_catalog;

--
-- TOC entry 180 (class 1259 OID 36568)
-- Name: ambito_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE ambito_tipo (
    c_ambito smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.ambito_tipo OWNER TO postgres;

--
-- TOC entry 181 (class 1259 OID 36574)
-- Name: anio_corrido_edad_teorica_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE anio_corrido_edad_teorica_tipo (
    c_anio_corrido_edad_teorica smallint NOT NULL,
    c_grado_nivel_servicio smallint NOT NULL,
    c_certificacion smallint NOT NULL,
    anio_corrido smallint,
    edad_teorica smallint
);


ALTER TABLE codigos.anio_corrido_edad_teorica_tipo OWNER TO postgres;

--
-- TOC entry 182 (class 1259 OID 36577)
-- Name: area_pedagogica_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE area_pedagogica_tipo (
    c_area_pedagogica smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.area_pedagogica_tipo OWNER TO postgres;

--
-- TOC entry 183 (class 1259 OID 36583)
-- Name: area_tematica_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE area_tematica_tipo (
    c_area_tematica smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.area_tematica_tipo OWNER TO postgres;

--
-- TOC entry 184 (class 1259 OID 36589)
-- Name: articulacion_tit_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE articulacion_tit_tipo (
    c_articulacion_tit smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.articulacion_tit_tipo OWNER TO postgres;

--
-- TOC entry 185 (class 1259 OID 36595)
-- Name: campo_formacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE campo_formacion_tipo (
    c_campo_formacion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint,
    c_area_pedagogica smallint
);


ALTER TABLE codigos.campo_formacion_tipo OWNER TO postgres;

--
-- TOC entry 186 (class 1259 OID 36601)
-- Name: carga_horaria_en_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE carga_horaria_en_tipo (
    c_carga_horaria_en smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.carga_horaria_en_tipo OWNER TO postgres;

--
-- TOC entry 187 (class 1259 OID 36607)
-- Name: carrera_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE carrera_tipo (
    c_carrera smallint NOT NULL,
    descripcion character varying,
    orden smallint,
    c_disciplina smallint,
    cod_carrera smallint
);


ALTER TABLE codigos.carrera_tipo OWNER TO postgres;

--
-- TOC entry 188 (class 1259 OID 36613)
-- Name: categoria_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE categoria_tipo (
    c_categoria smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.categoria_tipo OWNER TO postgres;

--
-- TOC entry 189 (class 1259 OID 36619)
-- Name: certificacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE certificacion_tipo (
    c_certificacion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.certificacion_tipo OWNER TO postgres;

--
-- TOC entry 190 (class 1259 OID 36625)
-- Name: ciclo_lectivo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE ciclo_lectivo_tipo (
    c_ciclo_lectivo smallint NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL
);


ALTER TABLE codigos.ciclo_lectivo_tipo OWNER TO postgres;

--
-- TOC entry 191 (class 1259 OID 36628)
-- Name: condicion_aprobacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE condicion_aprobacion_tipo (
    c_condicion_aprobacion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint,
    descripcion_impresion character varying
);


ALTER TABLE codigos.condicion_aprobacion_tipo OWNER TO postgres;

--
-- TOC entry 192 (class 1259 OID 36634)
-- Name: condicion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE condicion_tipo (
    c_condicion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.condicion_tipo OWNER TO postgres;

--
-- TOC entry 193 (class 1259 OID 36640)
-- Name: conexion_internet_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE conexion_internet_tipo (
    c_conexion_internet smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.conexion_internet_tipo OWNER TO postgres;

--
-- TOC entry 194 (class 1259 OID 36646)
-- Name: cooperadora_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE cooperadora_tipo (
    c_cooperadora smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.cooperadora_tipo OWNER TO postgres;

--
-- TOC entry 195 (class 1259 OID 36652)
-- Name: cursa_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE cursa_tipo (
    c_cursa integer NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.cursa_tipo OWNER TO postgres;

--
-- TOC entry 196 (class 1259 OID 36658)
-- Name: cursa_tipo_c_cursa_seq; Type: SEQUENCE; Schema: codigos; Owner: postgres
--

CREATE SEQUENCE cursa_tipo_c_cursa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE codigos.cursa_tipo_c_cursa_seq OWNER TO postgres;

--
-- TOC entry 3716 (class 0 OID 0)
-- Dependencies: 196
-- Name: cursa_tipo_c_cursa_seq; Type: SEQUENCE OWNED BY; Schema: codigos; Owner: postgres
--

ALTER SEQUENCE cursa_tipo_c_cursa_seq OWNED BY cursa_tipo.c_cursa;


--
-- TOC entry 197 (class 1259 OID 36660)
-- Name: departamento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE departamento_tipo (
    c_departamento integer NOT NULL,
    c_provincia smallint NOT NULL,
    cod_departamento character varying NOT NULL,
    nombre character varying
);


ALTER TABLE codigos.departamento_tipo OWNER TO postgres;

--
-- TOC entry 198 (class 1259 OID 36666)
-- Name: dependencia_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE dependencia_tipo (
    c_dependencia smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.dependencia_tipo OWNER TO postgres;

--
-- TOC entry 199 (class 1259 OID 36672)
-- Name: dicta_cuatrimestre_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE dicta_cuatrimestre_tipo (
    c_dicta_cuatrimestre smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.dicta_cuatrimestre_tipo OWNER TO postgres;

--
-- TOC entry 200 (class 1259 OID 36678)
-- Name: dictado_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE dictado_tipo (
    c_dictado smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.dictado_tipo OWNER TO postgres;

--
-- TOC entry 201 (class 1259 OID 36684)
-- Name: discapacidad_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE discapacidad_tipo (
    c_discapacidad smallint NOT NULL,
    descripcion character varying NOT NULL,
    parent smallint,
    orden smallint
);


ALTER TABLE codigos.discapacidad_tipo OWNER TO postgres;

--
-- TOC entry 202 (class 1259 OID 36690)
-- Name: disciplina_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE disciplina_tipo (
    c_disciplina smallint NOT NULL,
    descripcion character varying,
    orden smallint,
    c_rama smallint,
    cod_disciplina smallint
);


ALTER TABLE codigos.disciplina_tipo OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 36696)
-- Name: docente_integrador_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE docente_integrador_tipo (
    c_docente_integrador smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.docente_integrador_tipo OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 36702)
-- Name: duracion_en_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE duracion_en_tipo (
    c_duracion_en smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.duracion_en_tipo OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 36708)
-- Name: energia_electrica_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE energia_electrica_tipo (
    c_energia_electrica smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.energia_electrica_tipo OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 36714)
-- Name: equipamiento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE equipamiento_tipo (
    c_equipamiento smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.equipamiento_tipo OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 36720)
-- Name: espacio_curricular_duracion_en_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE espacio_curricular_duracion_en_tipo (
    c_espacio_curricular_duracion_en smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.espacio_curricular_duracion_en_tipo OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 36726)
-- Name: espacio_internet_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE espacio_internet_tipo (
    c_espacio_internet smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.espacio_internet_tipo OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 36732)
-- Name: estado_civil_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_civil_tipo (
    c_estado_civil smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.estado_civil_tipo OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 36738)
-- Name: estado_hoja_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_hoja_tipo (
    c_estado_hoja smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.estado_hoja_tipo OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 36744)
-- Name: estado_inscripcion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_inscripcion_tipo (
    c_estado_inscripcion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.estado_inscripcion_tipo OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 36750)
-- Name: estado_operativo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_operativo_tipo (
    c_estado_operativo smallint NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE codigos.estado_operativo_tipo OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 36756)
-- Name: estado_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_tipo (
    c_estado smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.estado_tipo OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 36762)
-- Name: estado_verificacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE estado_verificacion_tipo (
    c_estado_verificacion smallint NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE codigos.estado_verificacion_tipo OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 36768)
-- Name: fines_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE fines_tipo (
    c_fines smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.fines_tipo OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 36774)
-- Name: formato_espacio_curricular_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE formato_espacio_curricular_tipo (
    c_formato_espacio_curricular smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.formato_espacio_curricular_tipo OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 36780)
-- Name: grado_nivel_servicio_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE grado_nivel_servicio_tipo (
    c_grado_nivel_servicio smallint NOT NULL,
    c_grado smallint NOT NULL,
    c_nivel_servicio smallint NOT NULL,
    c_organizacion_plan smallint NOT NULL
);


ALTER TABLE codigos.grado_nivel_servicio_tipo OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 36783)
-- Name: grado_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE grado_tipo (
    c_grado smallint NOT NULL,
    descripcion character varying NOT NULL,
    c_grado_anterior smallint,
    orden smallint,
    numero smallint
);


ALTER TABLE codigos.grado_tipo OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 36789)
-- Name: indigena_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE indigena_tipo (
    c_indigena smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.indigena_tipo OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 36795)
-- Name: jornada_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE jornada_tipo (
    c_jornada smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.jornada_tipo OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 36801)
-- Name: localidad_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE localidad_tipo (
    c_localidad integer NOT NULL,
    c_departamento smallint NOT NULL,
    cod_localidad character varying NOT NULL,
    nombre character varying,
    cod_loc_indec character(8),
    tipo character(1)
);


ALTER TABLE codigos.localidad_tipo OWNER TO postgres;

--
-- TOC entry 3741 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE localidad_tipo; Type: COMMENT; Schema: codigos; Owner: postgres
--

COMMENT ON TABLE localidad_tipo IS 'P paraje
L localidad simple
B baja
C componente
E entidad
ATENCION: quedan nulos';


--
-- TOC entry 222 (class 1259 OID 36807)
-- Name: lugar_funcionamiento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE lugar_funcionamiento_tipo (
    c_lugar_funcionamiento smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.lugar_funcionamiento_tipo OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 36813)
-- Name: mantenimiento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE mantenimiento_tipo (
    c_mantenimiento smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.mantenimiento_tipo OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 36819)
-- Name: modalidad1_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE modalidad1_tipo (
    c_modalidad1 smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.modalidad1_tipo OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 36825)
-- Name: motivo_baja_inscripcion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE motivo_baja_inscripcion_tipo (
    c_motivo_baja_inscripcion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.motivo_baja_inscripcion_tipo OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 36831)
-- Name: nacionalidad_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE nacionalidad_tipo (
    c_nacionalidad smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint,
    c_pais smallint NOT NULL
);


ALTER TABLE codigos.nacionalidad_tipo OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 36837)
-- Name: nivel_alcanzado_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE nivel_alcanzado_tipo (
    c_nivel_alcanzado smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.nivel_alcanzado_tipo OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 36843)
-- Name: nivel_servicio_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE nivel_servicio_tipo (
    c_nivel_servicio smallint NOT NULL,
    descripcion character varying NOT NULL,
    c_modalidad1 smallint
);


ALTER TABLE codigos.nivel_servicio_tipo OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 36849)
-- Name: normativa_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE normativa_tipo (
    c_normativa smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.normativa_tipo OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 36855)
-- Name: obligatoriedad_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE obligatoriedad_tipo (
    c_obligatoriedad smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.obligatoriedad_tipo OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 36861)
-- Name: oferta_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE oferta_tipo (
    c_oferta integer NOT NULL,
    descripcion character varying NOT NULL,
    c_modalidad1 smallint NOT NULL,
    c_oferta_base smallint NOT NULL,
    orden smallint NOT NULL,
    corto character varying,
    c_nivel_titulo integer,
    c_nivel_servicio smallint
);


ALTER TABLE codigos.oferta_tipo OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 36867)
-- Name: oferta_tipo_c_oferta_seq; Type: SEQUENCE; Schema: codigos; Owner: postgres
--

CREATE SEQUENCE oferta_tipo_c_oferta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE codigos.oferta_tipo_c_oferta_seq OWNER TO postgres;

--
-- TOC entry 3753 (class 0 OID 0)
-- Dependencies: 232
-- Name: oferta_tipo_c_oferta_seq; Type: SEQUENCE OWNED BY; Schema: codigos; Owner: postgres
--

ALTER SEQUENCE oferta_tipo_c_oferta_seq OWNED BY oferta_tipo.c_oferta;


--
-- TOC entry 233 (class 1259 OID 36869)
-- Name: operativo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE operativo_tipo (
    c_operativo smallint NOT NULL,
    fecha_inicio date NOT NULL,
    c_ciclo_lectivo smallint NOT NULL,
    c_tipo_operativo smallint NOT NULL
);


ALTER TABLE codigos.operativo_tipo OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 36872)
-- Name: organizacion_cursada_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE organizacion_cursada_tipo (
    c_organizacion_cursada smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.organizacion_cursada_tipo OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 36878)
-- Name: organizacion_plan_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE organizacion_plan_tipo (
    c_organizacion_plan smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.organizacion_plan_tipo OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 36884)
-- Name: orientacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE orientacion_tipo (
    c_orientacion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.orientacion_tipo OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 36890)
-- Name: pais_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE pais_tipo (
    c_pais smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.pais_tipo OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 36896)
-- Name: per_funcionamiento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE per_funcionamiento_tipo (
    c_per_funcionamiento smallint NOT NULL,
    descripcion character varying NOT NULL,
    mes_inicio smallint NOT NULL,
    mes_fin smallint NOT NULL,
    orden smallint
);


ALTER TABLE codigos.per_funcionamiento_tipo OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 36902)
-- Name: provincia_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE provincia_tipo (
    c_provincia smallint NOT NULL,
    cod_provincia character varying,
    nombre character varying,
    seq_min integer,
    seq_max integer
);


ALTER TABLE codigos.provincia_tipo OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 36908)
-- Name: rama_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE rama_tipo (
    c_rama smallint NOT NULL,
    descripcion character varying,
    orden smallint,
    cod_rama smallint
);


ALTER TABLE codigos.rama_tipo OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 36914)
-- Name: requisito_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE requisito_tipo (
    c_requisito smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.requisito_tipo OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 36920)
-- Name: restriccion_internet_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE restriccion_internet_tipo (
    c_restriccion_internet smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.restriccion_internet_tipo OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 36926)
-- Name: sector_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE sector_tipo (
    c_sector smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.sector_tipo OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 36932)
-- Name: servicio_internet_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE servicio_internet_tipo (
    c_servicio_internet smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.servicio_internet_tipo OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 36938)
-- Name: sexo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE sexo_tipo (
    c_sexo smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.sexo_tipo OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 36944)
-- Name: sino_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE sino_tipo (
    c_sino smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.sino_tipo OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 36950)
-- Name: sistema_gestion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE sistema_gestion_tipo (
    c_sistema_gestion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.sistema_gestion_tipo OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 36956)
-- Name: software_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE software_tipo (
    c_software smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.software_tipo OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 36962)
-- Name: subvencion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE subvencion_tipo (
    c_subvencion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint,
    parent smallint
);


ALTER TABLE codigos.subvencion_tipo OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 36968)
-- Name: tipo_actividad_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_actividad_tipo (
    c_tipo_actividad smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_actividad_tipo OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 36974)
-- Name: tipo_baja_inscripcion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_baja_inscripcion_tipo (
    c_tipo_baja_inscripcion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_baja_inscripcion_tipo OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 36980)
-- Name: tipo_beneficio_alimentario_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_beneficio_alimentario_tipo (
    c_tipo_beneficio_alimentario smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_beneficio_alimentario_tipo OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 36986)
-- Name: tipo_beneficio_plan_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_beneficio_plan_tipo (
    c_tipo_beneficio_plan smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_beneficio_plan_tipo OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 36992)
-- Name: tipo_consistencia_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_consistencia_tipo (
    c_tipo_consistencia smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_consistencia_tipo OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 36998)
-- Name: tipo_copia_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_copia_tipo (
    c_tipo_copia smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_copia_tipo OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 37004)
-- Name: tipo_documento_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_documento_tipo (
    c_tipo_documento smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_documento_tipo OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 37010)
-- Name: tipo_formacion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_formacion_tipo (
    c_tipo_formacion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_formacion_tipo OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 37016)
-- Name: tipo_norma_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_norma_tipo (
    c_tipo_norma smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_norma_tipo OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 37022)
-- Name: tipo_operativo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_operativo_tipo (
    c_tipo_operativo smallint NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE codigos.tipo_operativo_tipo OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 37028)
-- Name: tipo_seccion_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_seccion_tipo (
    c_tipo_seccion smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_seccion_tipo OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 37034)
-- Name: tipo_titulo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE tipo_titulo_tipo (
    c_tipo_titulo smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.tipo_titulo_tipo OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 37040)
-- Name: transporte_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE transporte_tipo (
    c_transporte smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.transporte_tipo OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 37046)
-- Name: trayecto_formativo_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE trayecto_formativo_tipo (
    c_trayecto_formativo smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.trayecto_formativo_tipo OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 37052)
-- Name: turno_tipo; Type: TABLE; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE TABLE turno_tipo (
    c_turno smallint NOT NULL,
    descripcion character varying NOT NULL,
    orden smallint
);


ALTER TABLE codigos.turno_tipo OWNER TO postgres;

SET search_path = public, pg_catalog;

--
-- TOC entry 303 (class 1259 OID 37698)
-- Name: actividad_extracurricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE actividad_extracurricular (
    id_actividad_extracurricular integer NOT NULL,
    id_institucion integer NOT NULL,
    nombre character varying NOT NULL,
    c_requisito smallint,
    duracion integer,
    c_duracion_en smallint,
    c_certificado smallint,
    carga_horaria smallint,
    c_carga_horaria_en smallint,
    c_area_tematica smallint
);


ALTER TABLE public.actividad_extracurricular OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 37704)
-- Name: actividad_extracurricular_id_actividad_extracurricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE actividad_extracurricular_id_actividad_extracurricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.actividad_extracurricular_id_actividad_extracurricular_seq OWNER TO postgres;

--
-- TOC entry 3787 (class 0 OID 0)
-- Dependencies: 304
-- Name: actividad_extracurricular_id_actividad_extracurricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE actividad_extracurricular_id_actividad_extracurricular_seq OWNED BY actividad_extracurricular.id_actividad_extracurricular;


--
-- TOC entry 305 (class 1259 OID 37706)
-- Name: alumno_beneficio_alimentario; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_beneficio_alimentario (
    id_alumno_beneficio_alimentario integer NOT NULL,
    id_alumno integer NOT NULL,
    c_tipo_beneficio_alimentario smallint NOT NULL
);


ALTER TABLE public.alumno_beneficio_alimentario OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 37709)
-- Name: alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq OWNER TO postgres;

--
-- TOC entry 3789 (class 0 OID 0)
-- Dependencies: 306
-- Name: alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq OWNED BY alumno_beneficio_alimentario.id_alumno_beneficio_alimentario;


--
-- TOC entry 307 (class 1259 OID 37711)
-- Name: alumno_beneficio_plan; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_beneficio_plan (
    id_alumno_beneficio_plan integer NOT NULL,
    id_alumno integer NOT NULL,
    c_tipo_beneficio_plan smallint NOT NULL
);


ALTER TABLE public.alumno_beneficio_plan OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 37714)
-- Name: alumno_beneficio_plan_id_alumno_beneficio_plan_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_beneficio_plan_id_alumno_beneficio_plan_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_beneficio_plan_id_alumno_beneficio_plan_seq OWNER TO postgres;

--
-- TOC entry 3791 (class 0 OID 0)
-- Dependencies: 308
-- Name: alumno_beneficio_plan_id_alumno_beneficio_plan_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_beneficio_plan_id_alumno_beneficio_plan_seq OWNED BY alumno_beneficio_plan.id_alumno_beneficio_plan;


--
-- TOC entry 309 (class 1259 OID 37716)
-- Name: alumno_discapacidad; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_discapacidad (
    id_alumno_discapacidad integer NOT NULL,
    id_alumno integer NOT NULL,
    c_discapacidad smallint NOT NULL,
    c_docente_integrador smallint
);


ALTER TABLE public.alumno_discapacidad OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 37719)
-- Name: alumno_discapacidad_id_alumno_discapacidad_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_discapacidad_id_alumno_discapacidad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_discapacidad_id_alumno_discapacidad_seq OWNER TO postgres;

--
-- TOC entry 3793 (class 0 OID 0)
-- Dependencies: 310
-- Name: alumno_discapacidad_id_alumno_discapacidad_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_discapacidad_id_alumno_discapacidad_seq OWNED BY alumno_discapacidad.id_alumno_discapacidad;


--
-- TOC entry 265 (class 1259 OID 37064)
-- Name: alumno_espacio_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_espacio_curricular (
    id_alumno_espacio_curricular integer NOT NULL,
    id_espacio_curricular integer NOT NULL,
    id_alumno integer NOT NULL,
    nota character varying,
    c_condicion_aprobacion smallint,
    fecha_nota date,
    id_institucion_cursada integer,
    institucion_imprimir character varying,
    CONSTRAINT cue_anexo_valido CHECK (((institucion_imprimir)::text ~ '^[0-9]{7}|[0-9]{9}$'::text))
);


ALTER TABLE public.alumno_espacio_curricular OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 37721)
-- Name: alumno_espacio_curricular_id_alumno_espacio_curricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_espacio_curricular_id_alumno_espacio_curricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_espacio_curricular_id_alumno_espacio_curricular_seq OWNER TO postgres;

--
-- TOC entry 3795 (class 0 OID 0)
-- Dependencies: 311
-- Name: alumno_espacio_curricular_id_alumno_espacio_curricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_espacio_curricular_id_alumno_espacio_curricular_seq OWNED BY alumno_espacio_curricular.id_alumno_espacio_curricular;


--
-- TOC entry 266 (class 1259 OID 37071)
-- Name: alumno_inscripcion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_inscripcion (
    id_alumno_inscripcion integer NOT NULL,
    id_alumno integer NOT NULL,
    c_grado_nivel_servicio smallint NOT NULL,
    id_titulacion integer NOT NULL,
    legajo character varying,
    fecha_insc date,
    anio_ingreso smallint,
    c_cursa smallint,
    c_fines smallint,
    otros_datos character varying,
    c_tipo_baja_inscripcion smallint,
    fecha_baja date,
    id_institucion_destino integer,
    c_motivo_baja_inscripcion smallint,
    promedio character varying,
    observaciones character varying,
    fecha_egreso date,
    libro_matriz character varying,
    acta character varying,
    folio character varying,
    inscripcion_avanzada boolean NOT NULL,
    c_estado_inscripcion smallint NOT NULL,
    id_seccion_curricular integer,
    c_recursante integer NOT NULL,
    c_ciclo_lectivo smallint NOT NULL
);


ALTER TABLE public.alumno_inscripcion OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 37077)
-- Name: alumno_inscripcion_espacio_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_inscripcion_espacio_curricular (
    id_alumno_inscripcion_espacio_curricular integer NOT NULL,
    id_espacio_curricular integer NOT NULL,
    id_alumno_inscripcion integer NOT NULL,
    id_seccion_curricular integer NOT NULL,
    c_recursante integer,
    fecha_inscripcion date
);


ALTER TABLE public.alumno_inscripcion_espacio_curricular OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 37086)
-- Name: seccion_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE seccion_curricular (
    id_seccion_curricular integer NOT NULL,
    id_seccion integer NOT NULL,
    id_titulacion integer NOT NULL,
    c_grado_nivel_servicio smallint NOT NULL,
    c_turno smallint NOT NULL,
    c_trayecto_formativo smallint NOT NULL
);


ALTER TABLE public.seccion_curricular OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 37089)
-- Name: detalle_alumno_inscripcion_seccion_curricular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_alumno_inscripcion_seccion_curricular AS
 SELECT sc.id_seccion_curricular,
    ai.id_alumno,
    ai.c_estado_inscripcion,
    ai.c_recursante,
    ai.id_titulacion,
    ai.c_grado_nivel_servicio,
    sc.c_trayecto_formativo,
    ai.c_ciclo_lectivo,
    ai.c_cursa
   FROM (alumno_inscripcion ai
     LEFT JOIN seccion_curricular sc USING (id_seccion_curricular))
  WHERE (NOT (EXISTS ( SELECT 1
           FROM alumno_inscripcion_espacio_curricular a
          WHERE (a.id_alumno_inscripcion = ai.id_alumno_inscripcion))))
UNION
 SELECT sc.id_seccion_curricular,
    ai.id_alumno,
    ai.c_estado_inscripcion,
    aiec.c_recursante,
    sc.id_titulacion,
    sc.c_grado_nivel_servicio,
    sc.c_trayecto_formativo,
    ai.c_ciclo_lectivo,
    ai.c_cursa
   FROM ((alumno_inscripcion ai
     JOIN alumno_inscripcion_espacio_curricular aiec USING (id_alumno_inscripcion))
     JOIN seccion_curricular sc ON ((aiec.id_seccion_curricular = sc.id_seccion_curricular)));


ALTER TABLE public.detalle_alumno_inscripcion_seccion_curricular OWNER TO postgres;

--
-- TOC entry 3799 (class 0 OID 0)
-- Dependencies: 270
-- Name: VIEW detalle_alumno_inscripcion_seccion_curricular; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW detalle_alumno_inscripcion_seccion_curricular IS 'Consulta centralizada. 
  Muestra los tipos de inscripciones vigentes por alumno. La primer parte muestra los libres y alumnos inscriptos a la comisión entera.
  (caso comun-secundario sin inscripcion avanzada).
  La segunda parte trae las inscripciones avanzadas o inscripciones a espacios curriculares (como superior o comun-secundario con insc. avanzada)';


--
-- TOC entry 312 (class 1259 OID 37723)
-- Name: detalle_alumno_estado_inscripcion_seccion_curricular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_alumno_estado_inscripcion_seccion_curricular AS
 SELECT a.id_alumno,
    aisc.id_seccion_curricular,
    aisc.c_estado_inscripcion,
    aisc.c_recursante,
    aisc.id_titulacion,
    aisc.c_grado_nivel_servicio,
    aisc.c_trayecto_formativo,
    aisc.c_ciclo_lectivo,
    aisc.c_cursa
   FROM (alumno a
     LEFT JOIN detalle_alumno_inscripcion_seccion_curricular aisc USING (id_alumno));


ALTER TABLE public.detalle_alumno_estado_inscripcion_seccion_curricular OWNER TO postgres;

--
-- TOC entry 3801 (class 0 OID 0)
-- Dependencies: 312
-- Name: VIEW detalle_alumno_estado_inscripcion_seccion_curricular; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW detalle_alumno_estado_inscripcion_seccion_curricular IS 'Muestra el estado de inscripcion de todos los alumnos cargados. Si no tiene inscripcion aisc es null.';


--
-- TOC entry 313 (class 1259 OID 37727)
-- Name: nombre_titulacion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE nombre_titulacion (
    id_nombre_titulacion integer NOT NULL,
    c_carrera smallint,
    nombre character varying NOT NULL,
    nombre_abreviado character varying,
    cod_titulo smallint
);


ALTER TABLE public.nombre_titulacion OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 37291)
-- Name: seccion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE seccion (
    id_seccion integer NOT NULL,
    id_institucion integer NOT NULL,
    nombre character varying NOT NULL,
    c_tipo_seccion smallint NOT NULL,
    plazas smallint,
    fecha_inicio date,
    fecha_fin date,
    c_organizacion_cursada smallint,
    id_espacio_curricular integer
);


ALTER TABLE public.seccion OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 37102)
-- Name: titulacion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE titulacion (
    id_titulacion integer NOT NULL,
    id_unidad_servicio integer NOT NULL,
    id_nombre_titulacion integer NOT NULL,
    descripcion_adicional character varying,
    c_certificacion smallint,
    c_dicta smallint,
    c_condicion smallint,
    cohorte smallint,
    cohorte_finalizacion smallint,
    c_tipo_formacion smallint,
    c_tipo_titulo smallint,
    c_a_termino smallint,
    c_orientacion smallint,
    c_organizacion_plan smallint,
    c_organizacion_cursada smallint,
    c_dictado smallint,
    c_tiene_tit_int smallint,
    carga_horaria smallint,
    c_carga_horaria_en smallint,
    edad_minima smallint,
    c_articulacion_tit smallint,
    c_articulacion_univ smallint,
    nro_infod character varying,
    c_inscripto_inet smallint,
    duracion integer,
    c_duracion_en smallint,
    id_titulacion_normativa_vigente integer,
    es_ciclo_basico_compartido boolean,
    id_titulacion_ciclo_basico integer,
    confirmado boolean DEFAULT false NOT NULL,
    previas smallint
);


ALTER TABLE public.titulacion OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 37733)
-- Name: titulacion_nombre_titulacion; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW titulacion_nombre_titulacion AS
 SELECT titulacion.id_titulacion,
        CASE
            WHEN (titulacion.es_ciclo_basico_compartido = true) THEN titulacion.descripcion_adicional
            ELSE
            CASE
                WHEN ((titulacion.descripcion_adicional IS NOT NULL) AND ((titulacion.descripcion_adicional)::text <> ''::text)) THEN (((((nombre_titulacion.nombre)::text || ' ('::text) || (titulacion.descripcion_adicional)::text) || ')'::text))::character varying
                ELSE nombre_titulacion.nombre
            END
        END AS nombre
   FROM (titulacion
     JOIN nombre_titulacion USING (id_nombre_titulacion));


ALTER TABLE public.titulacion_nombre_titulacion OWNER TO postgres;

--
-- TOC entry 315 (class 1259 OID 37738)
-- Name: alumno_estado_inscripcion_estudio_curricular_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW alumno_estado_inscripcion_estudio_curricular_vista AS
 SELECT alumno.id_alumno,
    persona.id_persona,
    persona.apellidos,
    persona.nombres,
    persona.c_tipo_documento,
    persona.fecha_nacimiento,
    tipo_documento_tipo.descripcion AS tipo_documento_tipo_descripcion,
    persona.nro_documento,
    alumno.id_unidad_servicio,
    aeisc.c_grado_nivel_servicio,
    grado_tipo.c_grado,
        CASE
            WHEN ((grado_nivel_servicio_tipo.c_nivel_servicio = 1001) OR (grado_nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE titulacion_nombre_titulacion.nombre
        END AS nombre_titulacion,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    estado_inscripcion_tipo.c_estado_inscripcion,
    COALESCE(estado_inscripcion_tipo.descripcion, 'No Inscripto'::character varying) AS estado_inscripcion_tipo_descripcion,
    aeisc.c_ciclo_lectivo,
    cursa_tipo.c_cursa,
        CASE
            WHEN (estado_inscripcion_tipo.c_estado_inscripcion <> ALL (ARRAY[1, 2])) THEN ''::character varying
            ELSE cursa_tipo.descripcion
        END AS cursa_tipo_descripcion,
        CASE
            WHEN (estado_inscripcion_tipo.c_estado_inscripcion <> 1) THEN (''::character varying)::text
            ELSE (((((grado_tipo.descripcion)::text || ' '::text) || (s.nombre)::text) || ' Turno '::text) || (tt.descripcion)::text)
        END AS seccion
   FROM ((((((((((((alumno
     LEFT JOIN persona USING (id_persona))
     LEFT JOIN detalle_alumno_estado_inscripcion_seccion_curricular aeisc USING (id_alumno))
     LEFT JOIN codigos.tipo_documento_tipo USING (c_tipo_documento))
     LEFT JOIN codigos.estado_inscripcion_tipo USING (c_estado_inscripcion))
     LEFT JOIN titulacion USING (id_titulacion))
     LEFT JOIN codigos.grado_nivel_servicio_tipo ON ((aeisc.c_grado_nivel_servicio = grado_nivel_servicio_tipo.c_grado_nivel_servicio)))
     LEFT JOIN codigos.grado_tipo ON ((grado_tipo.c_grado = grado_nivel_servicio_tipo.c_grado)))
     LEFT JOIN codigos.cursa_tipo USING (c_cursa))
     LEFT JOIN seccion_curricular seccion_curricular(id_seccion_curricular, id_seccion, id_titulacion_1, c_grado_nivel_servicio, c_turno, c_trayecto_formativo) USING (id_seccion_curricular))
     LEFT JOIN seccion s USING (id_seccion))
     LEFT JOIN codigos.turno_tipo tt USING (c_turno))
     LEFT JOIN titulacion_nombre_titulacion titulacion_nombre_titulacion(id_titulacion_1, nombre) ON ((titulacion_nombre_titulacion.id_titulacion_1 = titulacion.id_titulacion)))
  ORDER BY persona.apellidos, persona.nombres,
        CASE
            WHEN ((grado_nivel_servicio_tipo.c_nivel_servicio = 1001) OR (grado_nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE titulacion_nombre_titulacion.nombre
        END, aeisc.c_grado_nivel_servicio,
        CASE
            WHEN (estado_inscripcion_tipo.c_estado_inscripcion <> 1) THEN (''::character varying)::text
            ELSE (((((grado_tipo.descripcion)::text || ' '::text) || (s.nombre)::text) || ' Turno '::text) || (tt.descripcion)::text)
        END;


ALTER TABLE public.alumno_estado_inscripcion_estudio_curricular_vista OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 37743)
-- Name: alumno_estado_inscripcion_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW alumno_estado_inscripcion_vista AS
 SELECT a.id_alumno,
    a.id_persona,
    a.c_indigena,
    a.centro_encierro,
    a.c_nivel_alcanzado_madre,
    a.c_nivel_alcanzado_padre,
    a.id_unidad_servicio,
    p.apellidos,
    p.nombres,
    p.nro_documento,
    p.fecha_nacimiento,
    tipo_documento_tipo.c_tipo_documento,
    tipo_documento_tipo.descripcion AS tipo_documento_tipo_descripcion,
    sexo_tipo.c_sexo,
    sexo_tipo.descripcion AS sexo_tipo_descripcion,
    COALESCE(alumno_con_preinscripcion.tiene_preinscripcion, false) AS tiene_preinscripcion,
    COALESCE(alumno_con_inscripcion.tiene_inscripcion, false) AS tiene_inscripcion
   FROM (((((alumno a
     JOIN persona p USING (id_persona))
     LEFT JOIN codigos.tipo_documento_tipo USING (c_tipo_documento))
     LEFT JOIN codigos.sexo_tipo USING (c_sexo))
     LEFT JOIN ( SELECT a_1.id_alumno,
            true AS tiene_preinscripcion
           FROM alumno a_1
          WHERE (EXISTS ( SELECT 1
                   FROM alumno_inscripcion a2
                  WHERE ((a2.id_alumno = a_1.id_alumno) AND (a2.c_estado_inscripcion = 104))))) alumno_con_preinscripcion USING (id_alumno))
     LEFT JOIN ( SELECT a_1.id_alumno,
            true AS tiene_inscripcion
           FROM alumno a_1
          WHERE (EXISTS ( SELECT 1
                   FROM alumno_inscripcion a2
                  WHERE ((a2.id_alumno = a_1.id_alumno) AND (a2.c_estado_inscripcion <> 104))))) alumno_con_inscripcion USING (id_alumno));


ALTER TABLE public.alumno_estado_inscripcion_vista OWNER TO postgres;

--
-- TOC entry 317 (class 1259 OID 37748)
-- Name: alumno_inscripcion_historico; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_inscripcion_historico (
    id_alumno_inscripcion_historico integer NOT NULL,
    id_alumno_inscripcion integer NOT NULL,
    c_grado_nivel_servicio smallint NOT NULL,
    c_recursante integer NOT NULL,
    c_estado_inscripcion smallint NOT NULL,
    c_ciclo_lectivo smallint NOT NULL
);


ALTER TABLE public.alumno_inscripcion_historico OWNER TO postgres;

--
-- TOC entry 318 (class 1259 OID 37751)
-- Name: detalle_alumno_historico; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_alumno_historico AS
 SELECT aih.id_alumno_inscripcion,
    aih.id_alumno_inscripcion_historico,
    ai.id_alumno,
    aih.c_estado_inscripcion,
    aih.c_recursante,
    ai.id_titulacion,
    aih.c_grado_nivel_servicio,
    aih.c_ciclo_lectivo,
    ai.c_cursa
   FROM (alumno_inscripcion_historico aih
     JOIN alumno_inscripcion ai USING (id_alumno_inscripcion));


ALTER TABLE public.detalle_alumno_historico OWNER TO postgres;

--
-- TOC entry 319 (class 1259 OID 37756)
-- Name: alumno_historico_incripcion_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW alumno_historico_incripcion_vista AS
 SELECT alumno.id_alumno,
    persona.id_persona,
    persona.apellidos,
    persona.nombres,
    persona.c_tipo_documento,
    persona.fecha_nacimiento,
    tipo_documento_tipo.descripcion AS tipo_documento_tipo_descripcion,
    persona.nro_documento,
    alumno.id_unidad_servicio,
    aeisc.c_grado_nivel_servicio,
    grado_tipo.c_grado,
        CASE
            WHEN ((grado_nivel_servicio_tipo.c_nivel_servicio = 1001) OR (grado_nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE titulacion_nombre_titulacion.nombre
        END AS nombre_titulacion,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    estado_inscripcion_tipo.c_estado_inscripcion,
    estado_inscripcion_tipo.descripcion AS estado_inscripcion_tipo_descripcion,
    aeisc.c_ciclo_lectivo,
    cursa_tipo.c_cursa,
    cursa_tipo.descripcion AS cursa_tipo_descripcion
   FROM (((((((((detalle_alumno_historico aeisc
     JOIN alumno USING (id_alumno))
     JOIN persona USING (id_persona))
     LEFT JOIN codigos.tipo_documento_tipo USING (c_tipo_documento))
     LEFT JOIN codigos.estado_inscripcion_tipo USING (c_estado_inscripcion))
     LEFT JOIN titulacion USING (id_titulacion))
     LEFT JOIN codigos.grado_nivel_servicio_tipo ON ((aeisc.c_grado_nivel_servicio = grado_nivel_servicio_tipo.c_grado_nivel_servicio)))
     LEFT JOIN codigos.grado_tipo ON ((grado_tipo.c_grado = grado_nivel_servicio_tipo.c_grado)))
     LEFT JOIN codigos.cursa_tipo USING (c_cursa))
     LEFT JOIN titulacion_nombre_titulacion titulacion_nombre_titulacion(id_titulacion_1, nombre) ON ((titulacion_nombre_titulacion.id_titulacion_1 = titulacion.id_titulacion)));


ALTER TABLE public.alumno_historico_incripcion_vista OWNER TO postgres;

--
-- TOC entry 320 (class 1259 OID 37761)
-- Name: alumno_id_alumno_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_id_alumno_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_id_alumno_seq OWNER TO postgres;

--
-- TOC entry 3812 (class 0 OID 0)
-- Dependencies: 320
-- Name: alumno_id_alumno_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_id_alumno_seq OWNED BY alumno.id_alumno;


--
-- TOC entry 321 (class 1259 OID 37763)
-- Name: alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq OWNER TO postgres;

--
-- TOC entry 3813 (class 0 OID 0)
-- Dependencies: 321
-- Name: alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq OWNED BY alumno_inscripcion_espacio_curricular.id_alumno_inscripcion_espacio_curricular;


--
-- TOC entry 271 (class 1259 OID 37094)
-- Name: espacio_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE espacio_curricular (
    id_espacio_curricular integer NOT NULL,
    id_titulacion integer NOT NULL,
    c_grado_nivel_servicio smallint NOT NULL,
    id_nombre_espacio_curricular integer NOT NULL,
    c_trayecto_formativo smallint NOT NULL,
    c_dictado smallint,
    c_obligatoriedad smallint,
    c_carga_horaria_en smallint,
    carga_horaria_semanal smallint,
    c_escala_numerica smallint,
    nota_minima smallint,
    orden smallint,
    c_formato_espacio_curricular smallint,
    c_espacio_curricular_duracion_en smallint,
    c_dicta_cuatrimestre smallint,
    c_promocionable smallint,
    nota_promocion smallint,
    nota_cursada smallint
);


ALTER TABLE public.espacio_curricular OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 37117)
-- Name: detalle_seccion_curricular_alumnos_con_todas_notas_cargadas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_seccion_curricular_alumnos_con_todas_notas_cargadas AS
 SELECT seccion_curricular_alumnos.id_seccion_curricular,
    seccion_curricular_alumnos.id_titulacion,
    seccion_curricular_alumnos.id_alumno
   FROM ( SELECT ai.id_seccion_curricular,
            ai.id_alumno,
            ai.id_titulacion,
            ai.c_grado_nivel_servicio,
            ai.c_trayecto_formativo
           FROM detalle_alumno_inscripcion_seccion_curricular ai
          WHERE (ai.c_estado_inscripcion = 1)) seccion_curricular_alumnos
  WHERE (NOT (EXISTS ( SELECT 1
           FROM (titulacion
             JOIN espacio_curricular USING (id_titulacion))
          WHERE (((((titulacion.id_titulacion = seccion_curricular_alumnos.id_titulacion) AND (espacio_curricular.c_grado_nivel_servicio = seccion_curricular_alumnos.c_grado_nivel_servicio)) AND (espacio_curricular.c_trayecto_formativo = seccion_curricular_alumnos.c_trayecto_formativo)) AND (espacio_curricular.c_obligatoriedad = 1)) AND (NOT (EXISTS ( SELECT 1
                   FROM alumno_espacio_curricular aec3
                  WHERE (((aec3.id_alumno = seccion_curricular_alumnos.id_alumno) AND (aec3.id_espacio_curricular = espacio_curricular.id_espacio_curricular)) AND (aec3.nota IS NOT NULL)))))))));


ALTER TABLE public.detalle_seccion_curricular_alumnos_con_todas_notas_cargadas OWNER TO postgres;

--
-- TOC entry 3815 (class 0 OID 0)
-- Dependencies: 276
-- Name: VIEW detalle_seccion_curricular_alumnos_con_todas_notas_cargadas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW detalle_seccion_curricular_alumnos_con_todas_notas_cargadas IS 'Las dos columnas por dato sin usuario y sin permiso 210 se deben a que a nivel sistema es posible dar filtros
  por tabla sino_tipo y este filtro hace la consulta sobre el 0 o 1. Al usuario se le muestra la descripción ya que no hay
  joins con sino_tipo. Concretamente es por motivos de implementación del sistema.';


--
-- TOC entry 322 (class 1259 OID 37765)
-- Name: alumno_inscripcion_estudio_curricular_progreso_carga_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW alumno_inscripcion_estudio_curricular_progreso_carga_vista AS
 SELECT alumno.id_alumno,
    persona.id_persona,
    persona.apellidos,
    persona.nombres,
    persona.c_tipo_documento,
    persona.fecha_nacimiento,
    tipo_documento_tipo.descripcion AS tipo_documento_tipo_descripcion,
    persona.nro_documento,
    titulacion.id_unidad_servicio,
    titulacion.descripcion_adicional AS titulacion_descripcion_adicional,
    seccion_curricular.c_grado_nivel_servicio,
    grado_tipo.c_grado,
        CASE
            WHEN ((grado_nivel_servicio_tipo.c_nivel_servicio = 1001) OR (grado_nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE titulacion_nombre_titulacion.nombre
        END AS nombre_titulacion,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    seccion.id_seccion,
    seccion.nombre AS nombre_seccion,
    tipo_seccion_tipo.c_tipo_seccion,
    tipo_seccion_tipo.descripcion AS seccion_tipo_descripcion,
    turno_tipo.c_turno,
    turno_tipo.descripcion AS turno_tipo_descripcion,
    estado_inscripcion_tipo.c_estado_inscripcion,
    estado_inscripcion_tipo.descripcion AS estado_inscripcion_tipo_descripcion,
    detalle_alumno_inscripcion_seccion_curricular.c_ciclo_lectivo,
    detalle_alumno_inscripcion_seccion_curricular.c_recursante,
        CASE
            WHEN ((detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_alumno IS NOT NULL) AND (estado_inscripcion_tipo.c_estado_inscripcion = 1)) THEN 1
            ELSE 2
        END AS c_todas_notas_cargadas,
        CASE
            WHEN ((detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_alumno IS NOT NULL) AND (estado_inscripcion_tipo.c_estado_inscripcion = 1)) THEN 'Sí'::text
            ELSE 'No'::text
        END AS todas_notas_cargadas
   FROM (((((((((((((detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
     JOIN seccion_curricular USING (id_seccion_curricular))
     JOIN codigos.grado_nivel_servicio_tipo ON ((seccion_curricular.c_grado_nivel_servicio = grado_nivel_servicio_tipo.c_grado_nivel_servicio)))
     JOIN codigos.grado_tipo ON ((grado_tipo.c_grado = grado_nivel_servicio_tipo.c_grado)))
     JOIN titulacion_nombre_titulacion ON ((titulacion_nombre_titulacion.id_titulacion = titulacion.id_titulacion)))
     JOIN seccion USING (id_seccion))
     JOIN codigos.tipo_seccion_tipo USING (c_tipo_seccion))
     JOIN codigos.turno_tipo USING (c_turno))
     JOIN alumno USING (id_alumno))
     JOIN persona USING (id_persona))
     JOIN codigos.tipo_documento_tipo USING (c_tipo_documento))
     JOIN codigos.estado_inscripcion_tipo USING (c_estado_inscripcion))
     LEFT JOIN detalle_seccion_curricular_alumnos_con_todas_notas_cargadas ON (((detalle_alumno_inscripcion_seccion_curricular.id_alumno = detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_alumno) AND (detalle_alumno_inscripcion_seccion_curricular.id_seccion_curricular = detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_seccion_curricular))));


ALTER TABLE public.alumno_inscripcion_estudio_curricular_progreso_carga_vista OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 37080)
-- Name: alumno_inscripcion_extracurricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alumno_inscripcion_extracurricular (
    id_alumno_inscripcion_extracurricular integer NOT NULL,
    id_alumno integer NOT NULL,
    id_actividad_extracurricular integer NOT NULL,
    id_seccion_extracurricular integer NOT NULL,
    legajo character varying,
    fecha_insc date
);


ALTER TABLE public.alumno_inscripcion_extracurricular OWNER TO postgres;

--
-- TOC entry 323 (class 1259 OID 37770)
-- Name: alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq OWNER TO postgres;

--
-- TOC entry 3819 (class 0 OID 0)
-- Dependencies: 323
-- Name: alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq OWNED BY alumno_inscripcion_extracurricular.id_alumno_inscripcion_extracurricular;


--
-- TOC entry 324 (class 1259 OID 37772)
-- Name: alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq OWNER TO postgres;

--
-- TOC entry 3820 (class 0 OID 0)
-- Dependencies: 324
-- Name: alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq OWNED BY alumno_inscripcion_historico.id_alumno_inscripcion_historico;


--
-- TOC entry 325 (class 1259 OID 37774)
-- Name: alumno_inscripcion_id_alumno_inscripcion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alumno_inscripcion_id_alumno_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumno_inscripcion_id_alumno_inscripcion_seq OWNER TO postgres;

--
-- TOC entry 3821 (class 0 OID 0)
-- Dependencies: 325
-- Name: alumno_inscripcion_id_alumno_inscripcion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alumno_inscripcion_id_alumno_inscripcion_seq OWNED BY alumno_inscripcion.id_alumno_inscripcion;


--
-- TOC entry 326 (class 1259 OID 37776)
-- Name: alumno_inscripcion_nombre_apellido_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW alumno_inscripcion_nombre_apellido_vista AS
 SELECT ai.id_alumno_inscripcion,
    ai.id_alumno,
    ai.c_grado_nivel_servicio,
    ai.id_titulacion,
    ai.legajo,
    ai.c_cursa,
    ai.c_estado_inscripcion,
    ai.c_ciclo_lectivo,
    p.apellidos,
    p.nombres,
    p.nro_documento,
    gt.descripcion AS grado_nivel_servicio_descripcion,
    nt.nombre AS titulacion_nombre,
    ct.descripcion AS cursa_tipo_descripcion,
    eit.descripcion AS estado_inscripcion_descripcion,
    a.id_unidad_servicio
   FROM ((((((((alumno_inscripcion ai
     JOIN alumno a USING (id_alumno))
     JOIN persona p USING (id_persona))
     JOIN titulacion USING (id_titulacion))
     JOIN nombre_titulacion nt USING (id_nombre_titulacion))
     JOIN codigos.grado_nivel_servicio_tipo USING (c_grado_nivel_servicio))
     JOIN codigos.grado_tipo gt USING (c_grado))
     JOIN codigos.cursa_tipo ct USING (c_cursa))
     JOIN codigos.estado_inscripcion_tipo eit USING (c_estado_inscripcion));


ALTER TABLE public.alumno_inscripcion_nombre_apellido_vista OWNER TO postgres;

--
-- TOC entry 327 (class 1259 OID 37803)
-- Name: autoridad; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE autoridad (
    id_autoridad integer NOT NULL,
    id_persona integer NOT NULL,
    id_institucion integer NOT NULL,
    id_nombre_cargo smallint NOT NULL
);


ALTER TABLE public.autoridad OWNER TO postgres;

--
-- TOC entry 328 (class 1259 OID 37806)
-- Name: autoridad_id_autoridad_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE autoridad_id_autoridad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.autoridad_id_autoridad_seq OWNER TO postgres;

--
-- TOC entry 3824 (class 0 OID 0)
-- Dependencies: 328
-- Name: autoridad_id_autoridad_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE autoridad_id_autoridad_seq OWNED BY autoridad.id_autoridad;


--
-- TOC entry 329 (class 1259 OID 37808)
-- Name: ciclo_lectivo_tipo_y_sin_definir_text; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW ciclo_lectivo_tipo_y_sin_definir_text AS
 SELECT x.c_ciclo_lectivo
   FROM ( SELECT (ciclo_lectivo_tipo.c_ciclo_lectivo)::text AS c_ciclo_lectivo
           FROM codigos.ciclo_lectivo_tipo
        UNION
         SELECT 'Sin definir'::text AS text) x
  ORDER BY x.c_ciclo_lectivo;


ALTER TABLE public.ciclo_lectivo_tipo_y_sin_definir_text OWNER TO postgres;

--
-- TOC entry 3825 (class 0 OID 0)
-- Dependencies: 329
-- Name: VIEW ciclo_lectivo_tipo_y_sin_definir_text; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW ciclo_lectivo_tipo_y_sin_definir_text IS 'Dado que la pantalla de progreso de carga requiere un tipo adicional en ciclo_lectivo_tipo que sea "Sin Definir" para aquellas 
  unidades de servicio que nunca cerraron el primer operativo que exista en SInIDE, se agrega un registro adicional Sin definir. 
  De esta manera es posible contabilizar / agrupar mediante JOIN con clave c_ciclo_lectivo = "Sin Definir", forzando que en la consulta
  se muestren todos los tipos de ciclo lectivo y los sin definir aun no existan US. Ver ej. jurisdiccion_titulacion_progreso_carga_vista';


--
-- TOC entry 330 (class 1259 OID 37812)
-- Name: consistencia; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE consistencia (
    id_consistencia integer NOT NULL,
    descripcion character varying,
    descripcion_ampliada character varying,
    descripcion_tecnica character varying,
    entidad character varying,
    c_tipo_consistencia smallint NOT NULL
);


ALTER TABLE public.consistencia OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 37109)
-- Name: unidad_servicio; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE unidad_servicio (
    id_unidad_servicio integer NOT NULL,
    id_institucion integer NOT NULL,
    c_nivel_servicio smallint NOT NULL,
    c_estado smallint NOT NULL,
    c_subvencion smallint NOT NULL,
    c_jornada smallint NOT NULL,
    c_alternancia smallint,
    c_cooperadora smallint,
    c_ciclo_lectivo smallint NOT NULL
);


ALTER TABLE public.unidad_servicio OWNER TO postgres;

--
-- TOC entry 331 (class 1259 OID 37823)
-- Name: detalle_espacio_curricular_alumnos_con_nota; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_espacio_curricular_alumnos_con_nota AS
 SELECT ec.id_espacio_curricular,
    aec.id_alumno
   FROM ((( SELECT DISTINCT daisc.id_titulacion
           FROM ((detalle_alumno_inscripcion_seccion_curricular daisc
             JOIN titulacion USING (id_titulacion))
             JOIN unidad_servicio us USING (id_unidad_servicio))
          WHERE (us.c_ciclo_lectivo = daisc.c_ciclo_lectivo)) _titulacion
     JOIN espacio_curricular ec USING (id_titulacion))
     JOIN alumno_espacio_curricular aec USING (id_espacio_curricular))
  WHERE (aec.nota IS NOT NULL);


ALTER TABLE public.detalle_espacio_curricular_alumnos_con_nota OWNER TO postgres;

--
-- TOC entry 332 (class 1259 OID 37828)
-- Name: count_espacio_curricular_alumnos_con_nota; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_espacio_curricular_alumnos_con_nota AS
 SELECT detalle_espacio_curricular_alumnos_con_nota.id_espacio_curricular,
    count(detalle_espacio_curricular_alumnos_con_nota.id_alumno) AS cant_alumnos
   FROM detalle_espacio_curricular_alumnos_con_nota
  GROUP BY detalle_espacio_curricular_alumnos_con_nota.id_espacio_curricular;


ALTER TABLE public.count_espacio_curricular_alumnos_con_nota OWNER TO postgres;

--
-- TOC entry 333 (class 1259 OID 37832)
-- Name: detalle_espacio_curricular_alumnos_inscriptos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_espacio_curricular_alumnos_inscriptos AS
 SELECT ec.id_espacio_curricular,
    daisc.id_alumno
   FROM (((espacio_curricular ec
     JOIN detalle_alumno_inscripcion_seccion_curricular daisc ON (((daisc.c_grado_nivel_servicio = ec.c_grado_nivel_servicio) AND (daisc.id_titulacion = ec.id_titulacion))))
     JOIN titulacion ON ((daisc.id_titulacion = titulacion.id_titulacion)))
     JOIN unidad_servicio USING (id_unidad_servicio))
  WHERE (unidad_servicio.c_ciclo_lectivo = daisc.c_ciclo_lectivo);


ALTER TABLE public.detalle_espacio_curricular_alumnos_inscriptos OWNER TO postgres;

--
-- TOC entry 334 (class 1259 OID 37837)
-- Name: count_espacio_curricular_alumnos_inscriptos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_espacio_curricular_alumnos_inscriptos AS
 SELECT detalle_espacio_curricular_alumnos_inscriptos.id_espacio_curricular,
    count(detalle_espacio_curricular_alumnos_inscriptos.id_alumno) AS cant_alumnos
   FROM detalle_espacio_curricular_alumnos_inscriptos
  GROUP BY detalle_espacio_curricular_alumnos_inscriptos.id_espacio_curricular;


ALTER TABLE public.count_espacio_curricular_alumnos_inscriptos OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 37097)
-- Name: detalle_seccion_curricular_alumnos_con_alguna_nota; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_seccion_curricular_alumnos_con_alguna_nota AS
 SELECT seccion_curricular_alumnos.id_seccion_curricular,
    seccion_curricular_alumnos.id_titulacion,
    seccion_curricular_alumnos.id_alumno
   FROM ( SELECT ai.id_seccion_curricular,
            ai.id_alumno,
            ai.id_titulacion,
            ai.c_grado_nivel_servicio,
            ai.c_trayecto_formativo
           FROM detalle_alumno_inscripcion_seccion_curricular ai
          WHERE (ai.c_estado_inscripcion = 1)) seccion_curricular_alumnos
  WHERE (EXISTS ( SELECT 1
           FROM (alumno_espacio_curricular
             JOIN espacio_curricular USING (id_espacio_curricular))
          WHERE ((((((espacio_curricular.id_titulacion = seccion_curricular_alumnos.id_titulacion) AND (alumno_espacio_curricular.id_alumno = seccion_curricular_alumnos.id_alumno)) AND (espacio_curricular.c_grado_nivel_servicio = seccion_curricular_alumnos.c_grado_nivel_servicio)) AND (espacio_curricular.c_trayecto_formativo = seccion_curricular_alumnos.c_trayecto_formativo)) AND (espacio_curricular.c_obligatoriedad = 1)) AND ((alumno_espacio_curricular.nota IS NOT NULL) OR ((alumno_espacio_curricular.nota)::text <> ''::text)))));


ALTER TABLE public.detalle_seccion_curricular_alumnos_con_alguna_nota OWNER TO postgres;

--
-- TOC entry 335 (class 1259 OID 37841)
-- Name: count_seccion_curricular_alumnos_con_alguna_nota; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_seccion_curricular_alumnos_con_alguna_nota AS
 SELECT detalle_seccion_curricular_alumnos_con_alguna_nota.id_seccion_curricular,
    count(detalle_seccion_curricular_alumnos_con_alguna_nota.id_alumno) AS cant_alumnos
   FROM detalle_seccion_curricular_alumnos_con_alguna_nota
  GROUP BY detalle_seccion_curricular_alumnos_con_alguna_nota.id_seccion_curricular;


ALTER TABLE public.count_seccion_curricular_alumnos_con_alguna_nota OWNER TO postgres;

--
-- TOC entry 336 (class 1259 OID 37845)
-- Name: count_seccion_curricular_alumnos_con_todas_notas_cargadas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_seccion_curricular_alumnos_con_todas_notas_cargadas AS
 SELECT detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_seccion_curricular,
    count(detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_alumno) AS cant_alumnos
   FROM detalle_seccion_curricular_alumnos_con_todas_notas_cargadas
  GROUP BY detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_seccion_curricular;


ALTER TABLE public.count_seccion_curricular_alumnos_con_todas_notas_cargadas OWNER TO postgres;

--
-- TOC entry 296 (class 1259 OID 37283)
-- Name: detalle_alumno_inscripcion_seccion_curricular_regulares; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_alumno_inscripcion_seccion_curricular_regulares AS
 SELECT detalle_alumno_inscripcion_seccion_curricular.id_seccion_curricular,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM detalle_alumno_inscripcion_seccion_curricular
  WHERE (detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = 1);


ALTER TABLE public.detalle_alumno_inscripcion_seccion_curricular_regulares OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 37287)
-- Name: count_seccion_curricular_alumnos_inscriptos_regulares; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_seccion_curricular_alumnos_inscriptos_regulares AS
 SELECT detalle_alumno_inscripcion_seccion_curricular_regulares.id_seccion_curricular,
    count(detalle_alumno_inscripcion_seccion_curricular_regulares.id_alumno) AS cant_alumnos
   FROM detalle_alumno_inscripcion_seccion_curricular_regulares
  GROUP BY detalle_alumno_inscripcion_seccion_curricular_regulares.id_seccion_curricular;


ALTER TABLE public.count_seccion_curricular_alumnos_inscriptos_regulares OWNER TO postgres;

--
-- TOC entry 337 (class 1259 OID 37849)
-- Name: detalle_seccion_curricular_alumnos_regulares_repitientes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_seccion_curricular_alumnos_regulares_repitientes AS
 SELECT detalle_alumno_inscripcion_seccion_curricular.id_seccion_curricular,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM detalle_alumno_inscripcion_seccion_curricular
  WHERE ((detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = 1) AND (detalle_alumno_inscripcion_seccion_curricular.c_recursante = 1));


ALTER TABLE public.detalle_seccion_curricular_alumnos_regulares_repitientes OWNER TO postgres;

--
-- TOC entry 338 (class 1259 OID 37853)
-- Name: count_seccion_curricular_alumnos_regulares_repitientes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_seccion_curricular_alumnos_regulares_repitientes AS
 SELECT detalle_seccion_curricular_alumnos_regulares_repitientes.id_seccion_curricular,
    count(detalle_seccion_curricular_alumnos_regulares_repitientes.id_alumno) AS cant_alumnos
   FROM detalle_seccion_curricular_alumnos_regulares_repitientes
  GROUP BY detalle_seccion_curricular_alumnos_regulares_repitientes.id_seccion_curricular;


ALTER TABLE public.count_seccion_curricular_alumnos_regulares_repitientes OWNER TO postgres;

--
-- TOC entry 339 (class 1259 OID 37857)
-- Name: detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo AS
 SELECT detalle_alumno_inscripcion_seccion_curricular.id_titulacion,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM ((detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
  WHERE ((detalle_alumno_inscripcion_seccion_curricular.c_ciclo_lectivo = unidad_servicio.c_ciclo_lectivo) AND (detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = 1));


ALTER TABLE public.detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo OWNER TO postgres;

--
-- TOC entry 340 (class 1259 OID 37862)
-- Name: count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo AS
 SELECT detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo.id_titulacion,
    count(detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo.id_alumno) AS cant_alumnos
   FROM detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo
  GROUP BY detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo.id_titulacion;


ALTER TABLE public.count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 37866)
-- Name: count_titulacion_espacios_curriculares; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_titulacion_espacios_curriculares AS
 SELECT espacio_curricular.id_titulacion,
    count(espacio_curricular.id_espacio_curricular) AS cant_espacios_curriculares
   FROM espacio_curricular
  GROUP BY espacio_curricular.id_titulacion;


ALTER TABLE public.count_titulacion_espacios_curriculares OWNER TO postgres;

--
-- TOC entry 342 (class 1259 OID 37870)
-- Name: count_titulacion_secciones; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_titulacion_secciones AS
 SELECT seccion_curricular.id_titulacion,
    count(seccion_curricular.id_seccion) AS cant_secciones
   FROM seccion_curricular
  GROUP BY seccion_curricular.id_titulacion;


ALTER TABLE public.count_titulacion_secciones OWNER TO postgres;

--
-- TOC entry 343 (class 1259 OID 37874)
-- Name: count_titulacion_secciones_curriculares; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_titulacion_secciones_curriculares AS
 SELECT seccion_curricular.id_titulacion,
    count(seccion_curricular.id_seccion_curricular) AS cant_secciones_curriculares
   FROM seccion_curricular
  GROUP BY seccion_curricular.id_titulacion;


ALTER TABLE public.count_titulacion_secciones_curriculares OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 37112)
-- Name: count_unidad_servicio_alumnos_con_alguna_nota; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_con_alguna_nota AS
 SELECT titulacion.id_unidad_servicio,
    count(detalle_seccion_curricular_alumnos_con_alguna_nota.id_alumno) AS cant_alumnos
   FROM ((detalle_seccion_curricular_alumnos_con_alguna_nota
     JOIN titulacion USING (id_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_con_alguna_nota OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 37122)
-- Name: count_unidad_servicio_alumnos_con_todas_notas_cargadas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_con_todas_notas_cargadas AS
 SELECT titulacion.id_unidad_servicio,
    count(detalle_seccion_curricular_alumnos_con_todas_notas_cargadas.id_alumno) AS cant_alumnos
   FROM ((detalle_seccion_curricular_alumnos_con_todas_notas_cargadas
     JOIN titulacion USING (id_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_con_todas_notas_cargadas OWNER TO postgres;

--
-- TOC entry 278 (class 1259 OID 37127)
-- Name: detalle_unidad_servicio_alumnos_examen; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_examen AS
 SELECT titulacion.id_unidad_servicio,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM (detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
  WHERE (detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = 1);


ALTER TABLE public.detalle_unidad_servicio_alumnos_examen OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 37132)
-- Name: count_unidad_servicio_alumnos_examen; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_examen AS
 SELECT detalle_unidad_servicio_alumnos_examen.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_examen.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_examen
  GROUP BY detalle_unidad_servicio_alumnos_examen.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_examen OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 37136)
-- Name: detalle_unidad_servicio_alumnos_extracurricular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_extracurricular AS
 SELECT alumno.id_unidad_servicio,
    alumno_inscripcion_extracurricular.id_alumno
   FROM (alumno_inscripcion_extracurricular
     JOIN alumno USING (id_alumno));


ALTER TABLE public.detalle_unidad_servicio_alumnos_extracurricular OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 37140)
-- Name: count_unidad_servicio_alumnos_extracurricular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_extracurricular AS
 SELECT detalle_unidad_servicio_alumnos_extracurricular.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_extracurricular.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_extracurricular
  GROUP BY detalle_unidad_servicio_alumnos_extracurricular.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_extracurricular OWNER TO postgres;

--
-- TOC entry 282 (class 1259 OID 37144)
-- Name: count_unidad_servicio_alumnos_ingresados_al_sistema; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_ingresados_al_sistema AS
 SELECT alumno.id_unidad_servicio,
    count(alumno.id_alumno) AS cant_alumnos
   FROM alumno
  GROUP BY alumno.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_ingresados_al_sistema OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 37199)
-- Name: detalle_unidad_servicio_alumnos_no_inscriptos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_no_inscriptos AS
 SELECT alumno.id_unidad_servicio,
    alumno.id_alumno
   FROM (alumno
     JOIN ( SELECT alumno_1.id_alumno
           FROM alumno alumno_1
        EXCEPT
         SELECT alumno_inscripcion.id_alumno
           FROM alumno_inscripcion) alumnos_no_inscriptos USING (id_alumno));


ALTER TABLE public.detalle_unidad_servicio_alumnos_no_inscriptos OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 37203)
-- Name: count_unidad_servicio_alumnos_no_inscriptos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_no_inscriptos AS
 SELECT detalle_unidad_servicio_alumnos_no_inscriptos.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_no_inscriptos.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_no_inscriptos
  GROUP BY detalle_unidad_servicio_alumnos_no_inscriptos.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_no_inscriptos OWNER TO postgres;

--
-- TOC entry 294 (class 1259 OID 37207)
-- Name: count_unidad_servicio_alumnos_notas_faltantes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_notas_faltantes AS
 SELECT a.id_unidad_servicio,
    count(DISTINCT a.id_alumno) AS cant_alumnos
   FROM ( SELECT alumno.id_unidad_servicio,
            alumno_inscripcion.id_alumno
           FROM (((alumno_inscripcion
             JOIN espacio_curricular USING (id_titulacion))
             JOIN alumno USING (id_alumno))
             LEFT JOIN alumno_espacio_curricular USING (id_alumno, id_espacio_curricular))
          WHERE (alumno_espacio_curricular.nota IS NULL)) a
  GROUP BY a.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_notas_faltantes OWNER TO postgres;

--
-- TOC entry 283 (class 1259 OID 37148)
-- Name: detalle_unidad_servicio_alumnos_regular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_regular AS
 SELECT titulacion.id_unidad_servicio,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM (detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
  WHERE (detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = 2);


ALTER TABLE public.detalle_unidad_servicio_alumnos_regular OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 37153)
-- Name: count_unidad_servicio_alumnos_regular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_regular AS
 SELECT detalle_unidad_servicio_alumnos_regular.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_regular.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_regular
  GROUP BY detalle_unidad_servicio_alumnos_regular.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_regular OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 37878)
-- Name: detalle_unidad_servicio_alumnos_regular_y_examen; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_regular_y_examen AS
 SELECT titulacion.id_unidad_servicio,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno
   FROM (detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
  WHERE (detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion = ANY (ARRAY[1, 2]));


ALTER TABLE public.detalle_unidad_servicio_alumnos_regular_y_examen OWNER TO postgres;

--
-- TOC entry 345 (class 1259 OID 37883)
-- Name: count_unidad_servicio_alumnos_regular_y_examen; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_regular_y_examen AS
 SELECT detalle_unidad_servicio_alumnos_regular_y_examen.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_regular_y_examen.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_regular_y_examen
  GROUP BY detalle_unidad_servicio_alumnos_regular_y_examen.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_regular_y_examen OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 37157)
-- Name: unidad_servicio_operativo; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE unidad_servicio_operativo (
    id_unidad_servicio integer NOT NULL,
    c_operativo smallint NOT NULL,
    c_estado_operativo smallint NOT NULL,
    id_unidad_servicio_operativo integer NOT NULL,
    fecha date
);


ALTER TABLE public.unidad_servicio_operativo OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 37160)
-- Name: unidad_servicio_ultimo_operativo_sin_confirmar; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW unidad_servicio_ultimo_operativo_sin_confirmar AS
 SELECT proximo_c_operativo_sin_confirmar.id_unidad_servicio,
    operativo_tipo.c_operativo,
    operativo_tipo.fecha_inicio,
    operativo_tipo.c_ciclo_lectivo,
    operativo_tipo.c_tipo_operativo
   FROM (( SELECT uso.id_unidad_servicio,
            ( SELECT min(ot.c_operativo) AS min
                   FROM codigos.operativo_tipo ot
                  WHERE (ot.c_operativo > max(uso.c_operativo))) AS c_operativo
           FROM unidad_servicio_operativo uso
          GROUP BY uso.id_unidad_servicio) proximo_c_operativo_sin_confirmar
     JOIN codigos.operativo_tipo USING (c_operativo));


ALTER TABLE public.unidad_servicio_ultimo_operativo_sin_confirmar OWNER TO postgres;

--
-- TOC entry 3860 (class 0 OID 0)
-- Dependencies: 286
-- Name: VIEW unidad_servicio_ultimo_operativo_sin_confirmar; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW unidad_servicio_ultimo_operativo_sin_confirmar IS 'Esta consulta resuelve obtener cual es el operativo que la unidad de servicio esta transitando pero no confirmo aun.
Aplica a todas las unidades de servicio.';


--
-- TOC entry 287 (class 1259 OID 37164)
-- Name: detalle_unidad_servicio_alumnos_sin_condicion_promocion; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW detalle_unidad_servicio_alumnos_sin_condicion_promocion AS
 SELECT unidad_servicio.id_unidad_servicio,
    detalle_alumno_inscripcion_seccion_curricular.id_alumno,
    unidad_servicio.c_ciclo_lectivo,
    unidad_servicio_ultimo_operativo_sin_confirmar.c_operativo
   FROM (((detalle_alumno_inscripcion_seccion_curricular
     JOIN titulacion USING (id_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
     JOIN unidad_servicio_ultimo_operativo_sin_confirmar USING (id_unidad_servicio))
  WHERE (((detalle_alumno_inscripcion_seccion_curricular.c_estado_inscripcion <> ALL (ARRAY[3, 4, 5, 6])) AND (unidad_servicio.c_ciclo_lectivo = detalle_alumno_inscripcion_seccion_curricular.c_ciclo_lectivo)) AND (unidad_servicio_ultimo_operativo_sin_confirmar.c_tipo_operativo = 5));


ALTER TABLE public.detalle_unidad_servicio_alumnos_sin_condicion_promocion OWNER TO postgres;

--
-- TOC entry 3862 (class 0 OID 0)
-- Dependencies: 287
-- Name: VIEW detalle_unidad_servicio_alumnos_sin_condicion_promocion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW detalle_unidad_servicio_alumnos_sin_condicion_promocion IS 'Esta vista tiene por objetivo traer quienes son los alumnos de una unidad de servicio que este
transitando el operativo 5 que no estan en condicion de promocion, o sea el estado de inscripcion
sea distinto a Baja, Salido, Egresado, Último Año. Adeuda materias.
Los codigos de c_estado_inscripcion >= 100 son del historico y no van a existir en alumno_inscripcion
a excepcion del 104 (pre-inscripto), cuya situacion esta contemplada ya que en operativo 5 no hay
inscripciones con estado pre-inscripto.';


--
-- TOC entry 288 (class 1259 OID 37169)
-- Name: count_unidad_servicio_alumnos_sin_condicion_promocion; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_alumnos_sin_condicion_promocion AS
 SELECT detalle_unidad_servicio_alumnos_sin_condicion_promocion.id_unidad_servicio,
    count(detalle_unidad_servicio_alumnos_sin_condicion_promocion.id_alumno) AS cant_alumnos
   FROM detalle_unidad_servicio_alumnos_sin_condicion_promocion
  GROUP BY detalle_unidad_servicio_alumnos_sin_condicion_promocion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_alumnos_sin_condicion_promocion OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 37308)
-- Name: count_unidad_servicio_titulaciones; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_titulaciones AS
 SELECT titulacion.id_unidad_servicio,
    count(titulacion.id_titulacion) AS cant_titulaciones
   FROM titulacion
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_titulaciones OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 37312)
-- Name: count_unidad_servicio_titulaciones_confirmadas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_titulaciones_confirmadas AS
 SELECT titulacion.id_unidad_servicio,
    count(titulacion.id_titulacion) AS cant_titulaciones
   FROM titulacion
  WHERE (titulacion.confirmado = true)
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_titulaciones_confirmadas OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 37316)
-- Name: count_unidad_servicio_titulaciones_en_este_cl; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_titulaciones_en_este_cl AS
 SELECT titulacion.id_unidad_servicio,
    count(titulacion.id_titulacion) AS cant_titulaciones
   FROM titulacion
  WHERE (titulacion.c_dicta = 1)
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_titulaciones_en_este_cl OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 37320)
-- Name: count_unidad_servicio_titulaciones_en_este_cl_confirmadas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_titulaciones_en_este_cl_confirmadas AS
 SELECT titulacion.id_unidad_servicio,
    count(titulacion.id_titulacion) AS cant_titulaciones
   FROM titulacion
  WHERE ((titulacion.c_dicta = 1) AND (titulacion.confirmado = true))
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_titulaciones_en_este_cl_confirmadas OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 37212)
-- Name: count_unidad_servicio_titulaciones_sin_confirmar; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW count_unidad_servicio_titulaciones_sin_confirmar AS
 SELECT titulacion.id_unidad_servicio,
    count(titulacion.id_titulacion) AS cant_titulaciones
   FROM titulacion
  WHERE (titulacion.confirmado IS NOT TRUE)
  GROUP BY titulacion.id_unidad_servicio;


ALTER TABLE public.count_unidad_servicio_titulaciones_sin_confirmar OWNER TO postgres;

--
-- TOC entry 346 (class 1259 OID 37891)
-- Name: datos_institucion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE datos_institucion (
    id_institucion integer NOT NULL,
    c_lugar_funcionamiento smallint,
    c_energia_electrica smallint,
    c_laboratorio_informatica smallint,
    docentes_informatica integer,
    personal_computadora integer,
    c_red smallint,
    c_internet smallint,
    c_servicio_internet smallint,
    c_conexion_internet smallint,
    c_restriccion_internet smallint,
    c_ensenanza_internet smallint,
    c_contenidos_digitales smallint,
    c_espacio_virtual smallint,
    c_mantenimiento smallint,
    c_sistema_gestion smallint,
    c_tiene_computadora smallint,
    sistema_terceros character varying,
    c_biblioteca smallint,
    c_espacio_biblioteca smallint,
    c_internet_area_gestion smallint,
    c_internet_aulas smallint,
    c_internet_biblioteca smallint,
    c_internet_otro_espacio smallint,
    normativa_jurisdiccional character varying,
    cartera_educativa character varying,
    area_dependencia character varying,
    cupon_jurisdiccional boolean
);


ALTER TABLE public.datos_institucion OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 37897)
-- Name: datos_unidad_servicio; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE datos_unidad_servicio (
    id_unidad_servicio integer NOT NULL,
    hora_manana_desde time without time zone,
    hora_manana_hasta time without time zone,
    hora_tarde_desde time without time zone,
    hora_tarde_hasta time without time zone,
    hora_noche_desde time without time zone,
    hora_noche_hasta time without time zone,
    hora_otros_desde time without time zone,
    hora_otros_hasta time without time zone,
    diasclase smallint,
    computadoras_esc_pedagogicos integer,
    computadoras_esc_administrativos integer,
    computadoras_esc_ambos integer,
    computadoras_port_alumnos integer,
    computadoras_port_docentes integer,
    computadoras_esc_pedagogicos_biblioteca integer,
    computadoras_esc_administrativos_biblioteca integer,
    computadoras_esc_ambos_biblioteca integer,
    computadoras_port_alumnos_biblioteca integer,
    computadoras_port_docentes_biblioteca integer
);


ALTER TABLE public.datos_unidad_servicio OWNER TO postgres;

--
-- TOC entry 348 (class 1259 OID 37905)
-- Name: nombre_espacio_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE nombre_espacio_curricular (
    id_nombre_espacio_curricular integer NOT NULL,
    nombre character varying NOT NULL,
    c_campo_formacion smallint
);


ALTER TABLE public.nombre_espacio_curricular OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 37911)
-- Name: espacio_curricular_detalle_y_alumnos_progreso_carga_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW espacio_curricular_detalle_y_alumnos_progreso_carga_vista AS
 SELECT t.id_unidad_servicio,
    t.id_titulacion,
    t.c_organizacion_plan,
    trayecto_formativo_tipo.descripcion AS trayecto_formativo_tipo_descripcion,
    nivel_servicio_tipo.c_nivel_servicio,
        CASE
            WHEN ((nivel_servicio_tipo.c_nivel_servicio = 1001) OR (nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE nt.nombre
        END AS nombre_titulacion,
    ec.c_trayecto_formativo,
    ec.c_grado_nivel_servicio,
    grado_tipo.c_grado,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    nombre_espacio_curricular.nombre AS nombre_espacio_curricular,
    COALESCE(count_espacio_curricular_alumnos_con_nota.cant_alumnos, (0)::bigint) AS cant_alumnos_con_nota,
    COALESCE(count_espacio_curricular_alumnos_inscriptos.cant_alumnos, (0)::bigint) AS cant_alumnos_inscriptos
   FROM (((((((((titulacion t
     JOIN titulacion_nombre_titulacion nt USING (id_titulacion))
     JOIN espacio_curricular ec USING (id_titulacion))
     JOIN codigos.grado_nivel_servicio_tipo USING (c_grado_nivel_servicio))
     JOIN codigos.nivel_servicio_tipo USING (c_nivel_servicio))
     JOIN codigos.grado_tipo USING (c_grado))
     JOIN nombre_espacio_curricular USING (id_nombre_espacio_curricular))
     LEFT JOIN codigos.trayecto_formativo_tipo USING (c_trayecto_formativo))
     LEFT JOIN count_espacio_curricular_alumnos_inscriptos USING (id_espacio_curricular))
     LEFT JOIN count_espacio_curricular_alumnos_con_nota USING (id_espacio_curricular));


ALTER TABLE public.espacio_curricular_detalle_y_alumnos_progreso_carga_vista OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 37916)
-- Name: espacio_curricular_id_espacio_curricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE espacio_curricular_id_espacio_curricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.espacio_curricular_id_espacio_curricular_seq OWNER TO postgres;

--
-- TOC entry 3874 (class 0 OID 0)
-- Dependencies: 350
-- Name: espacio_curricular_id_espacio_curricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE espacio_curricular_id_espacio_curricular_seq OWNED BY espacio_curricular.id_espacio_curricular;


--
-- TOC entry 351 (class 1259 OID 37918)
-- Name: establecimiento; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE establecimiento (
    id_establecimiento integer NOT NULL,
    cue character varying NOT NULL,
    nombre character varying NOT NULL,
    c_sector smallint NOT NULL,
    c_dependencia smallint NOT NULL,
    fecha_creacion date NOT NULL,
    c_confesional smallint NOT NULL,
    c_arancelado smallint NOT NULL,
    c_categoria smallint NOT NULL,
    id_responsable integer NOT NULL,
    c_estado smallint NOT NULL,
    fecha_actualizacion timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone NOT NULL,
    fecha_baja date,
    fecha_alta date
);


ALTER TABLE public.establecimiento OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 37925)
-- Name: establecimiento_id_establecimiento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE establecimiento_id_establecimiento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.establecimiento_id_establecimiento_seq OWNER TO postgres;

--
-- TOC entry 3876 (class 0 OID 0)
-- Dependencies: 352
-- Name: establecimiento_id_establecimiento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE establecimiento_id_establecimiento_seq OWNED BY establecimiento.id_establecimiento;


--
-- TOC entry 353 (class 1259 OID 37927)
-- Name: hoja_papel_moneda; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE hoja_papel_moneda (
    id_hoja_papel_moneda integer NOT NULL,
    id_lote_papel_moneda integer NOT NULL,
    nro_hoja integer NOT NULL,
    c_estado_hoja smallint NOT NULL,
    fecha_impresion date,
    id_alumno_inscripcion integer,
    c_tipo_copia smallint,
    fecha_otorgamiento_analitico date
);


ALTER TABLE public.hoja_papel_moneda OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 37930)
-- Name: hoja_papel_moneda_analitico; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE hoja_papel_moneda_analitico (
    id_hoja_papel_moneda_analitico integer NOT NULL,
    id_hoja_papel_moneda integer NOT NULL,
    analitico character varying
);


ALTER TABLE public.hoja_papel_moneda_analitico OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 37936)
-- Name: hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq OWNER TO postgres;

--
-- TOC entry 3879 (class 0 OID 0)
-- Dependencies: 355
-- Name: hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq OWNED BY hoja_papel_moneda_analitico.id_hoja_papel_moneda_analitico;


--
-- TOC entry 356 (class 1259 OID 37938)
-- Name: hoja_papel_moneda_id_hoja_papel_moneda_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE hoja_papel_moneda_id_hoja_papel_moneda_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hoja_papel_moneda_id_hoja_papel_moneda_seq OWNER TO postgres;

--
-- TOC entry 3880 (class 0 OID 0)
-- Dependencies: 356
-- Name: hoja_papel_moneda_id_hoja_papel_moneda_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE hoja_papel_moneda_id_hoja_papel_moneda_seq OWNED BY hoja_papel_moneda.id_hoja_papel_moneda;


--
-- TOC entry 289 (class 1259 OID 37173)
-- Name: institucion; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE institucion (
    id_institucion integer NOT NULL,
    codigo_jurisdiccional character varying,
    nombre character varying NOT NULL,
    c_sector smallint NOT NULL,
    c_dependencia smallint NOT NULL,
    c_confesional smallint NOT NULL,
    c_arancelado smallint NOT NULL,
    c_categoria smallint NOT NULL,
    c_ambito smallint NOT NULL,
    c_alternancia smallint NOT NULL,
    c_per_funcionamiento smallint NOT NULL,
    calle character varying,
    nro character varying,
    barrio character varying,
    referencia character varying,
    calle_fondo character varying,
    calle_derecha character varying,
    calle_izquierda character varying,
    cod_postal character varying,
    telefono_cod_area character varying,
    telefono character varying,
    c_localidad integer NOT NULL,
    email character varying,
    c_estado smallint,
    c_cooperadora smallint,
    c_provincia smallint,
    cueanexo character(9),
    id_establecimiento integer NOT NULL
);


ALTER TABLE public.institucion OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 37940)
-- Name: institucion_cantidad_alumnos_anio_turno_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW institucion_cantidad_alumnos_anio_turno_vista AS
 SELECT institucion.id_institucion,
    institucion.c_provincia,
    institucion.cueanexo,
    institucion.nombre AS nombre_institucion,
    unidad_servicio.id_unidad_servicio,
    nivel_servicio_tipo.c_nivel_servicio,
    nivel_servicio_tipo.descripcion AS nivel_servicio_tipo_descripcion,
    grado_tipo.c_grado,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    turno_tipo.c_turno,
    turno_tipo.descripcion AS turno_tipo_descripcion,
    count(alumno_inscripcion.id_alumno_inscripcion) AS cantidad_alumnos
   FROM ((((((((((seccion
     JOIN institucion USING (id_institucion))
     JOIN seccion_curricular USING (id_seccion))
     JOIN codigos.grado_nivel_servicio_tipo USING (c_grado_nivel_servicio))
     JOIN codigos.tipo_seccion_tipo USING (c_tipo_seccion))
     JOIN codigos.turno_tipo USING (c_turno))
     JOIN titulacion USING (id_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
     JOIN codigos.nivel_servicio_tipo ON ((unidad_servicio.c_nivel_servicio = nivel_servicio_tipo.c_nivel_servicio)))
     JOIN codigos.grado_tipo ON ((grado_tipo.c_grado = grado_nivel_servicio_tipo.c_grado)))
     LEFT JOIN alumno_inscripcion USING (id_seccion_curricular))
  GROUP BY institucion.id_institucion, institucion.c_provincia, institucion.cueanexo, institucion.nombre, unidad_servicio.id_unidad_servicio, nivel_servicio_tipo.c_nivel_servicio, nivel_servicio_tipo.descripcion, grado_tipo.c_grado, grado_tipo.descripcion, turno_tipo.c_turno, turno_tipo.descripcion;


ALTER TABLE public.institucion_cantidad_alumnos_anio_turno_vista OWNER TO postgres;

--
-- TOC entry 358 (class 1259 OID 37945)
-- Name: institucion_equipamiento; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE institucion_equipamiento (
    id_institucion_equipamiento integer NOT NULL,
    id_institucion integer NOT NULL,
    c_equipamiento smallint NOT NULL,
    c_institucion smallint,
    c_biblioteca smallint
);


ALTER TABLE public.institucion_equipamiento OWNER TO postgres;

--
-- TOC entry 359 (class 1259 OID 37948)
-- Name: institucion_equipamiento_id_institucion_equipamiento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE institucion_equipamiento_id_institucion_equipamiento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.institucion_equipamiento_id_institucion_equipamiento_seq OWNER TO postgres;

--
-- TOC entry 3884 (class 0 OID 0)
-- Dependencies: 359
-- Name: institucion_equipamiento_id_institucion_equipamiento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE institucion_equipamiento_id_institucion_equipamiento_seq OWNED BY institucion_equipamiento.id_institucion_equipamiento;


--
-- TOC entry 360 (class 1259 OID 37950)
-- Name: institucion_id_institucion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE institucion_id_institucion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.institucion_id_institucion_seq OWNER TO postgres;

--
-- TOC entry 3885 (class 0 OID 0)
-- Dependencies: 360
-- Name: institucion_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE institucion_id_institucion_seq OWNED BY institucion.id_institucion;


--
-- TOC entry 361 (class 1259 OID 37952)
-- Name: institucion_software; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE institucion_software (
    id_institucion_software integer NOT NULL,
    id_institucion integer NOT NULL,
    c_software smallint NOT NULL,
    c_tiene smallint NOT NULL
);


ALTER TABLE public.institucion_software OWNER TO postgres;

--
-- TOC entry 362 (class 1259 OID 37955)
-- Name: institucion_software_id_institucion_software_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE institucion_software_id_institucion_software_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.institucion_software_id_institucion_software_seq OWNER TO postgres;

--
-- TOC entry 3887 (class 0 OID 0)
-- Dependencies: 362
-- Name: institucion_software_id_institucion_software_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE institucion_software_id_institucion_software_seq OWNED BY institucion_software.id_institucion_software;


--
-- TOC entry 363 (class 1259 OID 37957)
-- Name: lote_papel_moneda; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE lote_papel_moneda (
    id_lote_papel_moneda integer NOT NULL,
    id_institucion integer NOT NULL,
    nro_serie smallint NOT NULL,
    desde integer NOT NULL,
    hasta integer NOT NULL,
    cantidad smallint NOT NULL
);


ALTER TABLE public.lote_papel_moneda OWNER TO postgres;

--
-- TOC entry 364 (class 1259 OID 37960)
-- Name: lote_papel_moneda_id_lote_papel_moneda_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE lote_papel_moneda_id_lote_papel_moneda_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lote_papel_moneda_id_lote_papel_moneda_seq OWNER TO postgres;

--
-- TOC entry 3889 (class 0 OID 0)
-- Dependencies: 364
-- Name: lote_papel_moneda_id_lote_papel_moneda_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE lote_papel_moneda_id_lote_papel_moneda_seq OWNED BY lote_papel_moneda.id_lote_papel_moneda;


--
-- TOC entry 365 (class 1259 OID 37962)
-- Name: nombre_cargo; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE nombre_cargo (
    id_nombre_cargo integer NOT NULL,
    nombre character varying NOT NULL,
    c_cargo_anterior smallint,
    orden smallint
);


ALTER TABLE public.nombre_cargo OWNER TO postgres;

--
-- TOC entry 366 (class 1259 OID 37968)
-- Name: nombre_cargo_id_nombre_cargo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE nombre_cargo_id_nombre_cargo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nombre_cargo_id_nombre_cargo_seq OWNER TO postgres;

--
-- TOC entry 3891 (class 0 OID 0)
-- Dependencies: 366
-- Name: nombre_cargo_id_nombre_cargo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE nombre_cargo_id_nombre_cargo_seq OWNED BY nombre_cargo.id_nombre_cargo;


--
-- TOC entry 367 (class 1259 OID 37970)
-- Name: nombre_espacio_curricular_id_nombre_espacio_curricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE nombre_espacio_curricular_id_nombre_espacio_curricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nombre_espacio_curricular_id_nombre_espacio_curricular_seq OWNER TO postgres;

--
-- TOC entry 3892 (class 0 OID 0)
-- Dependencies: 367
-- Name: nombre_espacio_curricular_id_nombre_espacio_curricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE nombre_espacio_curricular_id_nombre_espacio_curricular_seq OWNED BY nombre_espacio_curricular.id_nombre_espacio_curricular;


--
-- TOC entry 368 (class 1259 OID 37972)
-- Name: nombre_titulacion_id_nombre_titulacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE nombre_titulacion_id_nombre_titulacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nombre_titulacion_id_nombre_titulacion_seq OWNER TO postgres;

--
-- TOC entry 3893 (class 0 OID 0)
-- Dependencies: 368
-- Name: nombre_titulacion_id_nombre_titulacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE nombre_titulacion_id_nombre_titulacion_seq OWNED BY nombre_titulacion.id_nombre_titulacion;


--
-- TOC entry 369 (class 1259 OID 37974)
-- Name: nombre_titulacion_nivel_servicio_tipo_assn; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE nombre_titulacion_nivel_servicio_tipo_assn (
    id_nombre_titulacion integer NOT NULL,
    c_nivel_servicio smallint NOT NULL
);


ALTER TABLE public.nombre_titulacion_nivel_servicio_tipo_assn OWNER TO postgres;

--
-- TOC entry 370 (class 1259 OID 37977)
-- Name: oferta_local; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE oferta_local (
    id_oferta_local integer NOT NULL,
    c_oferta smallint NOT NULL,
    c_estado smallint NOT NULL,
    c_subvencion smallint NOT NULL,
    fecha_creacion date NOT NULL,
    c_jornada smallint NOT NULL,
    fecha_actualizacion timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone NOT NULL,
    fecha_baja date,
    fecha_alta date,
    matricula_total integer,
    codigo_jurisdiccional character varying,
    id_unidad_servicio integer
);


ALTER TABLE public.oferta_local OWNER TO postgres;

--
-- TOC entry 371 (class 1259 OID 37984)
-- Name: oferta_local_id_oferta_local_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE oferta_local_id_oferta_local_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.oferta_local_id_oferta_local_seq OWNER TO postgres;

--
-- TOC entry 3896 (class 0 OID 0)
-- Dependencies: 371
-- Name: oferta_local_id_oferta_local_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE oferta_local_id_oferta_local_seq OWNED BY oferta_local.id_oferta_local;


--
-- TOC entry 372 (class 1259 OID 37986)
-- Name: operativo_tipo_y_sin_definir_text; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW operativo_tipo_y_sin_definir_text AS
 SELECT x.c_ciclo_lectivo,
    x.c_tipo_operativo
   FROM ( SELECT (operativo_tipo.c_ciclo_lectivo)::text AS c_ciclo_lectivo,
            (operativo_tipo.c_tipo_operativo)::text AS c_tipo_operativo
           FROM codigos.operativo_tipo
        UNION
         SELECT 'Sin definir'::text AS text,
            'Sin definir'::text AS text) x
  ORDER BY x.c_ciclo_lectivo, x.c_tipo_operativo;


ALTER TABLE public.operativo_tipo_y_sin_definir_text OWNER TO postgres;

--
-- TOC entry 3897 (class 0 OID 0)
-- Dependencies: 372
-- Name: VIEW operativo_tipo_y_sin_definir_text; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW operativo_tipo_y_sin_definir_text IS 'Dado que la pantalla de progreso de carga requiere un tipo adicional en operativo_tipo que sea "Sin Definir" para aquellas 
  unidades de servicio que nunca cerraron el primer operativo que exista en SInIDE, se agrega un registro adicional Sin definir. 
  De esta manera es posible contabilizar / agrupar mediante JOIN con clave c_ciclo_lectivo = "Sin Definir", forzando que en la consulta
  se muestren todos los tipos de operativo y los sin definir aun no existan US. Ver ej. jurisdiccion_institucion_usuarios_cargos_progreso_carga_vista';


--
-- TOC entry 373 (class 1259 OID 37990)
-- Name: persona_id_persona_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE persona_id_persona_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.persona_id_persona_seq OWNER TO postgres;

--
-- TOC entry 3899 (class 0 OID 0)
-- Dependencies: 373
-- Name: persona_id_persona_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE persona_id_persona_seq OWNED BY persona.id_persona;


--
-- TOC entry 374 (class 1259 OID 37992)
-- Name: seccion_curricular_espacio_curricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE seccion_curricular_espacio_curricular (
    id_seccion_curricular_espacio_curricular integer NOT NULL,
    id_seccion_curricular integer NOT NULL,
    id_espacio_curricular integer NOT NULL
);


ALTER TABLE public.seccion_curricular_espacio_curricular OWNER TO postgres;

--
-- TOC entry 375 (class 1259 OID 37995)
-- Name: seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq OWNER TO postgres;

--
-- TOC entry 3901 (class 0 OID 0)
-- Dependencies: 375
-- Name: seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq OWNED BY seccion_curricular_espacio_curricular.id_seccion_curricular_espacio_curricular;


--
-- TOC entry 376 (class 1259 OID 37997)
-- Name: seccion_curricular_id_seccion_curricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE seccion_curricular_id_seccion_curricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seccion_curricular_id_seccion_curricular_seq OWNER TO postgres;

--
-- TOC entry 3902 (class 0 OID 0)
-- Dependencies: 376
-- Name: seccion_curricular_id_seccion_curricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE seccion_curricular_id_seccion_curricular_seq OWNED BY seccion_curricular.id_seccion_curricular;


--
-- TOC entry 377 (class 1259 OID 37999)
-- Name: seccion_curricular_progreso_carga_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW seccion_curricular_progreso_carga_vista AS
 SELECT seccion.id_seccion,
    seccion.nombre AS nombre_seccion,
    seccion.id_institucion,
    titulacion.id_unidad_servicio,
    institucion.c_provincia,
    institucion.nombre AS nombre_institucion,
    institucion.cueanexo,
    seccion.nombre,
    tipo_seccion_tipo.c_tipo_seccion,
    tipo_seccion_tipo.descripcion AS seccion_tipo_descripcion,
    seccion.fecha_inicio,
    seccion.fecha_fin,
    nivel_servicio_tipo.c_nivel_servicio,
    nivel_servicio_tipo.descripcion AS nivel_servicio_tipo_descripcion,
    turno_tipo.c_turno,
    turno_tipo.descripcion AS turno_tipo_descripcion,
    seccion_curricular.c_grado_nivel_servicio,
        CASE
            WHEN ((nivel_servicio_tipo.c_nivel_servicio = 1001) OR (nivel_servicio_tipo.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE nombre_titulacion.nombre
        END AS nombre_titulacion,
    grado_tipo.c_grado,
    grado_tipo.descripcion AS grado_tipo_descripcion,
    COALESCE(count_seccion_curricular_alumnos_inscriptos_regulares.cant_alumnos, (0)::bigint) AS cant_alumnos_inscriptos_regulares,
    COALESCE(count_seccion_curricular_alumnos_regulares_repitientes.cant_alumnos, (0)::bigint) AS cant_alumnos_regulares_repitientes,
    COALESCE(count_seccion_curricular_alumnos_con_todas_notas_cargadas.cant_alumnos, (0)::bigint) AS cant_alumnos_con_todas_notas_cargadas
   FROM (((((((((((((seccion
     JOIN institucion USING (id_institucion))
     JOIN seccion_curricular USING (id_seccion))
     JOIN codigos.grado_nivel_servicio_tipo USING (c_grado_nivel_servicio))
     JOIN codigos.tipo_seccion_tipo USING (c_tipo_seccion))
     JOIN codigos.turno_tipo USING (c_turno))
     JOIN titulacion USING (id_titulacion))
     JOIN nombre_titulacion USING (id_nombre_titulacion))
     JOIN unidad_servicio USING (id_unidad_servicio))
     JOIN codigos.nivel_servicio_tipo ON ((unidad_servicio.c_nivel_servicio = nivel_servicio_tipo.c_nivel_servicio)))
     JOIN codigos.grado_tipo ON ((grado_tipo.c_grado = grado_nivel_servicio_tipo.c_grado)))
     LEFT JOIN count_seccion_curricular_alumnos_inscriptos_regulares USING (id_seccion_curricular))
     LEFT JOIN count_seccion_curricular_alumnos_regulares_repitientes USING (id_seccion_curricular))
     LEFT JOIN count_seccion_curricular_alumnos_con_todas_notas_cargadas USING (id_seccion_curricular));


ALTER TABLE public.seccion_curricular_progreso_carga_vista OWNER TO postgres;

--
-- TOC entry 378 (class 1259 OID 38004)
-- Name: seccion_extracurricular; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE seccion_extracurricular (
    id_seccion_extracurricular integer NOT NULL,
    id_seccion integer NOT NULL,
    id_actividad_extracurricular integer NOT NULL,
    c_acepta_ot_inst smallint,
    c_acepta_comunidad smallint,
    c_turno smallint NOT NULL
);


ALTER TABLE public.seccion_extracurricular OWNER TO postgres;

--
-- TOC entry 379 (class 1259 OID 38007)
-- Name: seccion_extracurricular_id_seccion_extracurricular_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE seccion_extracurricular_id_seccion_extracurricular_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seccion_extracurricular_id_seccion_extracurricular_seq OWNER TO postgres;

--
-- TOC entry 3905 (class 0 OID 0)
-- Dependencies: 379
-- Name: seccion_extracurricular_id_seccion_extracurricular_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE seccion_extracurricular_id_seccion_extracurricular_seq OWNED BY seccion_extracurricular.id_seccion_extracurricular;


--
-- TOC entry 380 (class 1259 OID 38009)
-- Name: seccion_id_seccion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE seccion_id_seccion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seccion_id_seccion_seq OWNER TO postgres;

--
-- TOC entry 3906 (class 0 OID 0)
-- Dependencies: 380
-- Name: seccion_id_seccion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE seccion_id_seccion_seq OWNED BY seccion.id_seccion;


--
-- TOC entry 381 (class 1259 OID 38011)
-- Name: titulacion_cantidades_unidad_servicio_progreso_carga_vista; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW titulacion_cantidades_unidad_servicio_progreso_carga_vista AS
 SELECT titulacion.id_unidad_servicio,
    titulacion.id_titulacion,
    titulacion.id_nombre_titulacion,
        CASE
            WHEN ((unidad_servicio.c_nivel_servicio = 1001) OR (unidad_servicio.c_nivel_servicio = 1002)) THEN ''::character varying
            ELSE nombre_titulacion.nombre
        END AS nombre_titulacion,
        CASE
            WHEN (titulacion.confirmado = true) THEN 1
            ELSE 0
        END AS c_confirmado,
        CASE
            WHEN (titulacion.confirmado = true) THEN 'Sí'::text
            ELSE 'No'::text
        END AS confirmado,
    (
        CASE
            WHEN ((titulacion.c_duracion_en = 2) AND (titulacion.duracion <> 0)) THEN ceil(((titulacion.duracion)::double precision / (2.0)::double precision))
            ELSE (titulacion.duracion)::double precision
        END)::integer AS duracion_en_anios,
    titulacion.c_dicta,
    sino_tipo.descripcion AS dicta_tipo_descripcion,
    COALESCE(count_titulacion_espacios_curriculares.cant_espacios_curriculares, (0)::bigint) AS cant_espacios_curriculares,
    COALESCE(count_titulacion_secciones.cant_secciones, (0)::bigint) AS cant_secciones,
    COALESCE(count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo.cant_alumnos, (0)::bigint) AS cant_alumnos_inscriptos_ciclo_lectivo
   FROM ((((((titulacion
     JOIN unidad_servicio USING (id_unidad_servicio))
     JOIN titulacion_nombre_titulacion nombre_titulacion USING (id_titulacion))
     LEFT JOIN codigos.sino_tipo ON ((titulacion.c_dicta = sino_tipo.c_sino)))
     LEFT JOIN count_titulacion_secciones USING (id_titulacion))
     LEFT JOIN count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo USING (id_titulacion))
     LEFT JOIN count_titulacion_espacios_curriculares USING (id_titulacion));


ALTER TABLE public.titulacion_cantidades_unidad_servicio_progreso_carga_vista OWNER TO postgres;

--
-- TOC entry 382 (class 1259 OID 38016)
-- Name: titulacion_id_titulacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE titulacion_id_titulacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.titulacion_id_titulacion_seq OWNER TO postgres;

--
-- TOC entry 3908 (class 0 OID 0)
-- Dependencies: 382
-- Name: titulacion_id_titulacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE titulacion_id_titulacion_seq OWNED BY titulacion.id_titulacion;


--
-- TOC entry 383 (class 1259 OID 38018)
-- Name: titulacion_normativa; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE titulacion_normativa (
    id_titulacion_normativa integer NOT NULL,
    id_titulacion integer NOT NULL,
    c_normativa smallint NOT NULL,
    c_tipo_norma smallint NOT NULL,
    norma_nro character varying NOT NULL,
    norma_anio smallint,
    c_provincia smallint,
    descripcion character varying
);


ALTER TABLE public.titulacion_normativa OWNER TO postgres;

--
-- TOC entry 384 (class 1259 OID 38024)
-- Name: titulacion_normativa_id_titulacion_normativa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE titulacion_normativa_id_titulacion_normativa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.titulacion_normativa_id_titulacion_normativa_seq OWNER TO postgres;

--
-- TOC entry 3910 (class 0 OID 0)
-- Dependencies: 384
-- Name: titulacion_normativa_id_titulacion_normativa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE titulacion_normativa_id_titulacion_normativa_seq OWNED BY titulacion_normativa.id_titulacion_normativa;


--
-- TOC entry 290 (class 1259 OID 37179)
-- Name: unidad_servicio_datos_identificatorios_calculados; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW unidad_servicio_datos_identificatorios_calculados AS
 SELECT unidad_servicio.id_institucion,
    unidad_servicio.id_unidad_servicio,
    (btrim((((COALESCE(institucion.calle, ''::character varying))::text || ' '::text) || (COALESCE(institucion.nro, ''::character varying))::text)))::character varying AS domicilio
   FROM (unidad_servicio
     JOIN institucion USING (id_institucion));


ALTER TABLE public.unidad_servicio_datos_identificatorios_calculados OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 37184)
-- Name: unidad_servicio_definidas_ultimo_operativo_sin_confirmar; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW unidad_servicio_definidas_ultimo_operativo_sin_confirmar AS
 SELECT unidad_servicio_ultimo_operativo_sin_confirmar.id_unidad_servicio,
    unidad_servicio_ultimo_operativo_sin_confirmar.c_operativo,
    unidad_servicio_ultimo_operativo_sin_confirmar.fecha_inicio,
    unidad_servicio_ultimo_operativo_sin_confirmar.c_ciclo_lectivo,
    unidad_servicio_ultimo_operativo_sin_confirmar.c_tipo_operativo
   FROM unidad_servicio_ultimo_operativo_sin_confirmar;


ALTER TABLE public.unidad_servicio_definidas_ultimo_operativo_sin_confirmar OWNER TO postgres;

--
-- TOC entry 3912 (class 0 OID 0)
-- Dependencies: 291
-- Name: VIEW unidad_servicio_definidas_ultimo_operativo_sin_confirmar; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW unidad_servicio_definidas_ultimo_operativo_sin_confirmar IS 'usamos la vista unidad_servicio_ultimo_operativo_sin_confirmar ya que es igual a la anterior, en este momento en la tabla unidad_servicio_operativo estan 
  todas las unidades de servicio. La consulta original requiere una optimización importante dado la ultima versión establecida para la vista
  unidad_servicio_ultimo_operativo_sin_confirmar. Dejo esta vista con el mismo nombre para no tocar las vistas originales.
  Cuando todo esta bien y no haya reclamos, hay que borrar esta vista y ajustar las vistas de estadistica para apuntar a 
  unidad_servicio_ultimo_operativo_sin_confirmar

  Original: Notar que usa fecha_inicio y no es necesario ya que c_operativo es incremental a la par de la fecha de inicio.

  SELECT unidad_servicio_proximo_operativo_sin_confirmar.id_unidad_servicio,
    operativo_tipo.c_operativo,
    operativo_tipo.fecha_inicio,
    operativo_tipo.c_ciclo_lectivo,
    operativo_tipo.c_tipo_operativo
   FROM ( SELECT unidad_servicio.id_unidad_servicio,
            min(operativo_tipo_1.fecha_inicio) AS fecha_inicio
           FROM codigos.operativo_tipo operativo_tipo_1
             CROSS JOIN ( SELECT DISTINCT unidad_servicio_operativo_1.id_unidad_servicio
                   FROM unidad_servicio_operativo unidad_servicio_operativo_1) unidad_servicio
             LEFT JOIN unidad_servicio_operativo ON unidad_servicio_operativo.c_operativo = operativo_tipo_1.c_operativo AND unidad_servicio_operativo.id_unidad_servicio = unidad_servicio.id_unidad_servicio
             LEFT JOIN ( SELECT unidad_servicio_operativo_1.id_unidad_servicio,
                    max(unidad_servicio_operativo_1.c_operativo) AS ultimo_c_operativo_confirmado
                   FROM unidad_servicio_operativo unidad_servicio_operativo_1
                  GROUP BY unidad_servicio_operativo_1.id_unidad_servicio) unidad_servicio_ultimo_operativo_confirmado ON unidad_servicio_ultimo_operativo_confirmado.id_unidad_servicio = unidad_servicio.id_unidad_servicio
          WHERE unidad_servicio_operativo.id_unidad_servicio IS NULL AND unidad_servicio_operativo.c_estado_operativo IS NULL AND operativo_tipo_1.fecha_inicio <= now() AND operativo_tipo_1.c_operativo >= unidad_servicio_ultimo_operativo_confirmado.ultimo_c_operativo_confirmado
          GROUP BY unidad_servicio.id_unidad_servicio) unidad_servicio_proximo_operativo_sin_confirmar
     JOIN codigos.operativo_tipo USING (fecha_inicio);

  comentario anterior: A diferencia de unidad_servicio_ultimo_operativo_sin_confirmar, se muestra el proximo operativo solo de aquellas unidades de servicio
  que ya establecieron algun operativo (existe un registro en unidad_servicio_operativo), para todas las demas, se infiere que estan en 
  sin definir. Esta vista surgió porque se necesita el conteo de ciclo_lectivo-operativo sin definicion.
  Tener en cuenta: Que una vez que la US defina el primer operativo, el ultimo va a ser 2, por lo tanto nunca habrá 2015-1er operativo, ya que
  de null-null pasa a 2015-2do operativo. ';


--
-- TOC entry 385 (class 1259 OID 38026)
-- Name: unidad_servicio_id_unidad_servicio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE unidad_servicio_id_unidad_servicio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidad_servicio_id_unidad_servicio_seq OWNER TO postgres;

--
-- TOC entry 3914 (class 0 OID 0)
-- Dependencies: 385
-- Name: unidad_servicio_id_unidad_servicio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE unidad_servicio_id_unidad_servicio_seq OWNED BY unidad_servicio.id_unidad_servicio;


--
-- TOC entry 386 (class 1259 OID 38028)
-- Name: unidad_servicio_operativo_descripcion; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW unidad_servicio_operativo_descripcion AS
 SELECT unidad_servicio_operativo.id_unidad_servicio,
    unidad_servicio_operativo.c_estado_operativo,
    estado_operativo_tipo.descripcion AS c_estado_operativo_descripcion,
    unidad_servicio_operativo.c_operativo,
    unidad_servicio_operativo.fecha,
    operativo_tipo.fecha_inicio AS c_operativo_fecha_inicio,
    operativo_tipo.c_ciclo_lectivo AS c_operativo_c_ciclo_lectivo,
    operativo_tipo.c_tipo_operativo AS c_operativo_c_tipo_operativo,
    tipo_operativo_tipo.descripcion AS c_operativo_c_tipo_operativo_descripcion
   FROM (((unidad_servicio_operativo
     JOIN codigos.operativo_tipo USING (c_operativo))
     JOIN codigos.estado_operativo_tipo USING (c_estado_operativo))
     JOIN codigos.tipo_operativo_tipo USING (c_tipo_operativo));


ALTER TABLE public.unidad_servicio_operativo_descripcion OWNER TO postgres;

--
-- TOC entry 387 (class 1259 OID 38032)
-- Name: unidad_servicio_operativo_id_unidad_servicio_operativo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE unidad_servicio_operativo_id_unidad_servicio_operativo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unidad_servicio_operativo_id_unidad_servicio_operativo_seq OWNER TO postgres;

--
-- TOC entry 3915 (class 0 OID 0)
-- Dependencies: 387
-- Name: unidad_servicio_operativo_id_unidad_servicio_operativo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE unidad_servicio_operativo_id_unidad_servicio_operativo_seq OWNED BY unidad_servicio_operativo.id_unidad_servicio_operativo;


--
-- TOC entry 388 (class 1259 OID 38044)
-- Name: verificacion_carga; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE verificacion_carga (
    id_verificacion_carga integer NOT NULL,
    id_unidad_servicio integer NOT NULL,
    c_operativo smallint NOT NULL,
    c_estado_verificacion smallint NOT NULL
);


ALTER TABLE public.verificacion_carga OWNER TO postgres;

--
-- TOC entry 389 (class 1259 OID 38047)
-- Name: verificacion_carga_id_verificacion_carga_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE verificacion_carga_id_verificacion_carga_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.verificacion_carga_id_verificacion_carga_seq OWNER TO postgres;

--
-- TOC entry 3917 (class 0 OID 0)
-- Dependencies: 389
-- Name: verificacion_carga_id_verificacion_carga_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE verificacion_carga_id_verificacion_carga_seq OWNED BY verificacion_carga.id_verificacion_carga;


SET search_path = codigos, pg_catalog;

--
-- TOC entry 2821 (class 2604 OID 38213)
-- Name: c_cursa; Type: DEFAULT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY cursa_tipo ALTER COLUMN c_cursa SET DEFAULT nextval('cursa_tipo_c_cursa_seq'::regclass);


--
-- TOC entry 2822 (class 2604 OID 38214)
-- Name: c_oferta; Type: DEFAULT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY oferta_tipo ALTER COLUMN c_oferta SET DEFAULT nextval('oferta_tipo_c_oferta_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- TOC entry 2836 (class 2604 OID 38215)
-- Name: id_actividad_extracurricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular ALTER COLUMN id_actividad_extracurricular SET DEFAULT nextval('actividad_extracurricular_id_actividad_extracurricular_seq'::regclass);


--
-- TOC entry 2816 (class 2604 OID 38216)
-- Name: id_alumno; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno ALTER COLUMN id_alumno SET DEFAULT nextval('alumno_id_alumno_seq'::regclass);


--
-- TOC entry 2837 (class 2604 OID 38217)
-- Name: id_alumno_beneficio_alimentario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_alimentario ALTER COLUMN id_alumno_beneficio_alimentario SET DEFAULT nextval('alumno_beneficio_alimentario_id_alumno_beneficio_alimentari_seq'::regclass);


--
-- TOC entry 2838 (class 2604 OID 38218)
-- Name: id_alumno_beneficio_plan; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_plan ALTER COLUMN id_alumno_beneficio_plan SET DEFAULT nextval('alumno_beneficio_plan_id_alumno_beneficio_plan_seq'::regclass);


--
-- TOC entry 2839 (class 2604 OID 38219)
-- Name: id_alumno_discapacidad; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_discapacidad ALTER COLUMN id_alumno_discapacidad SET DEFAULT nextval('alumno_discapacidad_id_alumno_discapacidad_seq'::regclass);


--
-- TOC entry 2823 (class 2604 OID 38220)
-- Name: id_alumno_espacio_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_espacio_curricular ALTER COLUMN id_alumno_espacio_curricular SET DEFAULT nextval('alumno_espacio_curricular_id_alumno_espacio_curricular_seq'::regclass);


--
-- TOC entry 2825 (class 2604 OID 38221)
-- Name: id_alumno_inscripcion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion ALTER COLUMN id_alumno_inscripcion SET DEFAULT nextval('alumno_inscripcion_id_alumno_inscripcion_seq'::regclass);


--
-- TOC entry 2826 (class 2604 OID 38222)
-- Name: id_alumno_inscripcion_espacio_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular ALTER COLUMN id_alumno_inscripcion_espacio_curricular SET DEFAULT nextval('alumno_inscripcion_espacio_cu_id_alumno_inscripcion_espacio_seq'::regclass);


--
-- TOC entry 2827 (class 2604 OID 38223)
-- Name: id_alumno_inscripcion_extracurricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular ALTER COLUMN id_alumno_inscripcion_extracurricular SET DEFAULT nextval('alumno_inscripcion_extracurri_id_alumno_inscripcion_extracu_seq'::regclass);


--
-- TOC entry 2841 (class 2604 OID 38224)
-- Name: id_alumno_inscripcion_historico; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico ALTER COLUMN id_alumno_inscripcion_historico SET DEFAULT nextval('alumno_inscripcion_historico_id_alumno_inscripcion_historic_seq'::regclass);


--
-- TOC entry 2842 (class 2604 OID 38225)
-- Name: id_autoridad; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY autoridad ALTER COLUMN id_autoridad SET DEFAULT nextval('autoridad_id_autoridad_seq'::regclass);


--
-- TOC entry 2829 (class 2604 OID 38226)
-- Name: id_espacio_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular ALTER COLUMN id_espacio_curricular SET DEFAULT nextval('espacio_curricular_id_espacio_curricular_seq'::regclass);


--
-- TOC entry 2845 (class 2604 OID 38227)
-- Name: id_establecimiento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY establecimiento ALTER COLUMN id_establecimiento SET DEFAULT nextval('establecimiento_id_establecimiento_seq'::regclass);


--
-- TOC entry 2846 (class 2604 OID 38228)
-- Name: id_hoja_papel_moneda; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda ALTER COLUMN id_hoja_papel_moneda SET DEFAULT nextval('hoja_papel_moneda_id_hoja_papel_moneda_seq'::regclass);


--
-- TOC entry 2847 (class 2604 OID 38229)
-- Name: id_hoja_papel_moneda_analitico; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda_analitico ALTER COLUMN id_hoja_papel_moneda_analitico SET DEFAULT nextval('hoja_papel_moneda_analitico_id_hoja_papel_moneda_analitico_seq'::regclass);


--
-- TOC entry 2834 (class 2604 OID 38230)
-- Name: id_institucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion ALTER COLUMN id_institucion SET DEFAULT nextval('institucion_id_institucion_seq'::regclass);


--
-- TOC entry 2848 (class 2604 OID 38231)
-- Name: id_institucion_equipamiento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_equipamiento ALTER COLUMN id_institucion_equipamiento SET DEFAULT nextval('institucion_equipamiento_id_institucion_equipamiento_seq'::regclass);


--
-- TOC entry 2849 (class 2604 OID 38232)
-- Name: id_institucion_software; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_software ALTER COLUMN id_institucion_software SET DEFAULT nextval('institucion_software_id_institucion_software_seq'::regclass);


--
-- TOC entry 2850 (class 2604 OID 38233)
-- Name: id_lote_papel_moneda; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lote_papel_moneda ALTER COLUMN id_lote_papel_moneda SET DEFAULT nextval('lote_papel_moneda_id_lote_papel_moneda_seq'::regclass);


--
-- TOC entry 2851 (class 2604 OID 38234)
-- Name: id_nombre_cargo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_cargo ALTER COLUMN id_nombre_cargo SET DEFAULT nextval('nombre_cargo_id_nombre_cargo_seq'::regclass);


--
-- TOC entry 2843 (class 2604 OID 38235)
-- Name: id_nombre_espacio_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_espacio_curricular ALTER COLUMN id_nombre_espacio_curricular SET DEFAULT nextval('nombre_espacio_curricular_id_nombre_espacio_curricular_seq'::regclass);


--
-- TOC entry 2840 (class 2604 OID 38236)
-- Name: id_nombre_titulacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_titulacion ALTER COLUMN id_nombre_titulacion SET DEFAULT nextval('nombre_titulacion_id_nombre_titulacion_seq'::regclass);


--
-- TOC entry 2853 (class 2604 OID 38237)
-- Name: id_oferta_local; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY oferta_local ALTER COLUMN id_oferta_local SET DEFAULT nextval('oferta_local_id_oferta_local_seq'::regclass);


--
-- TOC entry 2817 (class 2604 OID 38238)
-- Name: id_persona; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona ALTER COLUMN id_persona SET DEFAULT nextval('persona_id_persona_seq'::regclass);


--
-- TOC entry 2835 (class 2604 OID 38239)
-- Name: id_seccion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion ALTER COLUMN id_seccion SET DEFAULT nextval('seccion_id_seccion_seq'::regclass);


--
-- TOC entry 2828 (class 2604 OID 38240)
-- Name: id_seccion_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular ALTER COLUMN id_seccion_curricular SET DEFAULT nextval('seccion_curricular_id_seccion_curricular_seq'::regclass);


--
-- TOC entry 2854 (class 2604 OID 38241)
-- Name: id_seccion_curricular_espacio_curricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular_espacio_curricular ALTER COLUMN id_seccion_curricular_espacio_curricular SET DEFAULT nextval('seccion_curricular_espacio_cu_id_seccion_curricular_espacio_seq'::regclass);


--
-- TOC entry 2855 (class 2604 OID 38242)
-- Name: id_seccion_extracurricular; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular ALTER COLUMN id_seccion_extracurricular SET DEFAULT nextval('seccion_extracurricular_id_seccion_extracurricular_seq'::regclass);


--
-- TOC entry 2831 (class 2604 OID 38243)
-- Name: id_titulacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion ALTER COLUMN id_titulacion SET DEFAULT nextval('titulacion_id_titulacion_seq'::regclass);


--
-- TOC entry 2856 (class 2604 OID 38244)
-- Name: id_titulacion_normativa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion_normativa ALTER COLUMN id_titulacion_normativa SET DEFAULT nextval('titulacion_normativa_id_titulacion_normativa_seq'::regclass);


--
-- TOC entry 2832 (class 2604 OID 38245)
-- Name: id_unidad_servicio; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio ALTER COLUMN id_unidad_servicio SET DEFAULT nextval('unidad_servicio_id_unidad_servicio_seq'::regclass);


--
-- TOC entry 2833 (class 2604 OID 38246)
-- Name: id_unidad_servicio_operativo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio_operativo ALTER COLUMN id_unidad_servicio_operativo SET DEFAULT nextval('unidad_servicio_operativo_id_unidad_servicio_operativo_seq'::regclass);


--
-- TOC entry 2857 (class 2604 OID 38247)
-- Name: id_verificacion_carga; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY verificacion_carga ALTER COLUMN id_verificacion_carga SET DEFAULT nextval('verificacion_carga_id_verificacion_carga_seq'::regclass);


SET search_path = codigos, pg_catalog;

--
-- TOC entry 2866 (class 2606 OID 70277)
-- Name: ambito_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ambito_tipo
    ADD CONSTRAINT ambito_tipo_pkey PRIMARY KEY (c_ambito);


--
-- TOC entry 2870 (class 2606 OID 70279)
-- Name: anio_corrido_edad_teorica_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY anio_corrido_edad_teorica_tipo
    ADD CONSTRAINT anio_corrido_edad_teorica_tipo_pkey PRIMARY KEY (c_anio_corrido_edad_teorica);


--
-- TOC entry 2874 (class 2606 OID 70281)
-- Name: area_pedagogica_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY area_pedagogica_tipo
    ADD CONSTRAINT area_pedagogica_tipo_pkey PRIMARY KEY (c_area_pedagogica);


--
-- TOC entry 2878 (class 2606 OID 70283)
-- Name: area_tematica_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY area_tematica_tipo
    ADD CONSTRAINT area_tematica_tipo_pkey PRIMARY KEY (c_area_tematica);


--
-- TOC entry 2882 (class 2606 OID 70285)
-- Name: articulacion_tit_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY articulacion_tit_tipo
    ADD CONSTRAINT articulacion_tit_pkey PRIMARY KEY (c_articulacion_tit);


--
-- TOC entry 2886 (class 2606 OID 70287)
-- Name: campo_formacion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY campo_formacion_tipo
    ADD CONSTRAINT campo_formacion_tipo_pkey PRIMARY KEY (c_campo_formacion);


--
-- TOC entry 2890 (class 2606 OID 70289)
-- Name: carga_horaria_en_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY carga_horaria_en_tipo
    ADD CONSTRAINT carga_horaria_en_tipo_pkey PRIMARY KEY (c_carga_horaria_en);


--
-- TOC entry 2894 (class 2606 OID 70291)
-- Name: carrera_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY carrera_tipo
    ADD CONSTRAINT carrera_tipo_pkey PRIMARY KEY (c_carrera);


--
-- TOC entry 2898 (class 2606 OID 70293)
-- Name: categoria_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY categoria_tipo
    ADD CONSTRAINT categoria_tipo_pkey PRIMARY KEY (c_categoria);


--
-- TOC entry 2902 (class 2606 OID 70295)
-- Name: certificacion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY certificacion_tipo
    ADD CONSTRAINT certificacion_tipo_pkey PRIMARY KEY (c_certificacion);


--
-- TOC entry 2908 (class 2606 OID 70297)
-- Name: condicion_aprobacion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY condicion_aprobacion_tipo
    ADD CONSTRAINT condicion_aprobacion_tipo_pkey PRIMARY KEY (c_condicion_aprobacion);


--
-- TOC entry 2912 (class 2606 OID 70299)
-- Name: condicion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY condicion_tipo
    ADD CONSTRAINT condicion_tipo_pkey PRIMARY KEY (c_condicion);


--
-- TOC entry 2916 (class 2606 OID 70301)
-- Name: conexion_internet_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY conexion_internet_tipo
    ADD CONSTRAINT conexion_internet_tipo_pkey PRIMARY KEY (c_conexion_internet);


--
-- TOC entry 2920 (class 2606 OID 70303)
-- Name: cooperadora_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cooperadora_tipo
    ADD CONSTRAINT cooperadora_tipo_pkey PRIMARY KEY (c_cooperadora);


--
-- TOC entry 2924 (class 2606 OID 70305)
-- Name: cursa_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cursa_tipo
    ADD CONSTRAINT cursa_tipo_pkey PRIMARY KEY (c_cursa);


--
-- TOC entry 2928 (class 2606 OID 70307)
-- Name: departamento_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departamento_tipo
    ADD CONSTRAINT departamento_pkey PRIMARY KEY (c_departamento);


--
-- TOC entry 2934 (class 2606 OID 70309)
-- Name: dependencia_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dependencia_tipo
    ADD CONSTRAINT dependencia_tipo_pkey PRIMARY KEY (c_dependencia);


--
-- TOC entry 2938 (class 2606 OID 70311)
-- Name: dicta_cuatrimestre_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dicta_cuatrimestre_tipo
    ADD CONSTRAINT dicta_cuatrimestre_tipo_pkey PRIMARY KEY (c_dicta_cuatrimestre);


--
-- TOC entry 2942 (class 2606 OID 70313)
-- Name: dictado_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dictado_tipo
    ADD CONSTRAINT dictado_tipo_pkey PRIMARY KEY (c_dictado);


--
-- TOC entry 2946 (class 2606 OID 70315)
-- Name: discapacidad_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY discapacidad_tipo
    ADD CONSTRAINT discapacidad_tipo_pkey PRIMARY KEY (c_discapacidad);


--
-- TOC entry 2950 (class 2606 OID 70317)
-- Name: disciplina_tipo_descripcion_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY disciplina_tipo
    ADD CONSTRAINT disciplina_tipo_descripcion_key UNIQUE (descripcion);


--
-- TOC entry 2952 (class 2606 OID 70319)
-- Name: disciplina_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY disciplina_tipo
    ADD CONSTRAINT disciplina_tipo_pkey PRIMARY KEY (c_disciplina);


--
-- TOC entry 2954 (class 2606 OID 70321)
-- Name: docente_integrador_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY docente_integrador_tipo
    ADD CONSTRAINT docente_integrador_tipo_pkey PRIMARY KEY (c_docente_integrador);


--
-- TOC entry 2958 (class 2606 OID 70323)
-- Name: duracion_en_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY duracion_en_tipo
    ADD CONSTRAINT duracion_en_tipo_pkey PRIMARY KEY (c_duracion_en);


--
-- TOC entry 2962 (class 2606 OID 70325)
-- Name: energia_electrica_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY energia_electrica_tipo
    ADD CONSTRAINT energia_electrica_tipo_pkey PRIMARY KEY (c_energia_electrica);


--
-- TOC entry 2966 (class 2606 OID 70327)
-- Name: equipamiento_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY equipamiento_tipo
    ADD CONSTRAINT equipamiento_tipo_pkey PRIMARY KEY (c_equipamiento);


--
-- TOC entry 2970 (class 2606 OID 70329)
-- Name: espacio_curricular_duracion_en_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_curricular_duracion_en_tipo
    ADD CONSTRAINT espacio_curricular_duracion_en_tipo_pkey PRIMARY KEY (c_espacio_curricular_duracion_en);


--
-- TOC entry 2974 (class 2606 OID 70331)
-- Name: espacio_internet_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_internet_tipo
    ADD CONSTRAINT espacio_internet_tipo_pkey PRIMARY KEY (c_espacio_internet);


--
-- TOC entry 2978 (class 2606 OID 70333)
-- Name: estado_civil_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_civil_tipo
    ADD CONSTRAINT estado_civil_tipo_pkey PRIMARY KEY (c_estado_civil);


--
-- TOC entry 2982 (class 2606 OID 70335)
-- Name: estado_hoja_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_hoja_tipo
    ADD CONSTRAINT estado_hoja_tipo_pkey PRIMARY KEY (c_estado_hoja);


--
-- TOC entry 2986 (class 2606 OID 70337)
-- Name: estado_inscripcion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_inscripcion_tipo
    ADD CONSTRAINT estado_inscripcion_tipo_pkey PRIMARY KEY (c_estado_inscripcion);


--
-- TOC entry 2995 (class 2606 OID 70339)
-- Name: estado_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_tipo
    ADD CONSTRAINT estado_tipo_pkey PRIMARY KEY (c_estado);


--
-- TOC entry 3004 (class 2606 OID 70341)
-- Name: fines_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fines_tipo
    ADD CONSTRAINT fines_tipo_pkey PRIMARY KEY (c_fines);


--
-- TOC entry 3008 (class 2606 OID 70343)
-- Name: formato_espacio_curricular_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY formato_espacio_curricular_tipo
    ADD CONSTRAINT formato_espacio_curricular_tipo_pkey PRIMARY KEY (c_formato_espacio_curricular);


--
-- TOC entry 3012 (class 2606 OID 70345)
-- Name: grado_nivel_servicio_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY grado_nivel_servicio_tipo
    ADD CONSTRAINT grado_nivel_servicio_tipo_pkey PRIMARY KEY (c_grado_nivel_servicio);


--
-- TOC entry 3017 (class 2606 OID 70347)
-- Name: grado_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY grado_tipo
    ADD CONSTRAINT grado_tipo_pkey PRIMARY KEY (c_grado);


--
-- TOC entry 3022 (class 2606 OID 70349)
-- Name: indigena_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY indigena_tipo
    ADD CONSTRAINT indigena_tipo_pkey PRIMARY KEY (c_indigena);


--
-- TOC entry 3026 (class 2606 OID 70351)
-- Name: jornada_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY jornada_tipo
    ADD CONSTRAINT jornada_tipo_pkey PRIMARY KEY (c_jornada);


--
-- TOC entry 3031 (class 2606 OID 70353)
-- Name: localidad_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY localidad_tipo
    ADD CONSTRAINT localidad_tipo_pkey PRIMARY KEY (c_localidad);


--
-- TOC entry 3033 (class 2606 OID 70355)
-- Name: lugar_funcionamiento_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lugar_funcionamiento_tipo
    ADD CONSTRAINT lugar_funcionamiento_tipo_pkey PRIMARY KEY (c_lugar_funcionamiento);


--
-- TOC entry 3037 (class 2606 OID 70357)
-- Name: mantenimiento_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mantenimiento_tipo
    ADD CONSTRAINT mantenimiento_tipo_pkey PRIMARY KEY (c_mantenimiento);


--
-- TOC entry 3041 (class 2606 OID 70359)
-- Name: modalidad1_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY modalidad1_tipo
    ADD CONSTRAINT modalidad1_tipo_pkey PRIMARY KEY (c_modalidad1);


--
-- TOC entry 3045 (class 2606 OID 70361)
-- Name: motivo_baja_inscripcion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY motivo_baja_inscripcion_tipo
    ADD CONSTRAINT motivo_baja_inscripcion_tipo_pkey PRIMARY KEY (c_motivo_baja_inscripcion);


--
-- TOC entry 3049 (class 2606 OID 70363)
-- Name: nacionalidad_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nacionalidad_tipo
    ADD CONSTRAINT nacionalidad_tipo_pkey PRIMARY KEY (c_nacionalidad);


--
-- TOC entry 3051 (class 2606 OID 70365)
-- Name: nivel_alcanzado_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nivel_alcanzado_tipo
    ADD CONSTRAINT nivel_alcanzado_tipo_pkey PRIMARY KEY (c_nivel_alcanzado);


--
-- TOC entry 3055 (class 2606 OID 70367)
-- Name: nivel_servicio_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nivel_servicio_tipo
    ADD CONSTRAINT nivel_servicio_tipo_pkey PRIMARY KEY (c_nivel_servicio);


--
-- TOC entry 3059 (class 2606 OID 70369)
-- Name: normativa_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY normativa_tipo
    ADD CONSTRAINT normativa_tipo_pkey PRIMARY KEY (c_normativa);


--
-- TOC entry 3063 (class 2606 OID 70371)
-- Name: obligatoriedad_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY obligatoriedad_tipo
    ADD CONSTRAINT obligatoriedad_pkey PRIMARY KEY (c_obligatoriedad);


--
-- TOC entry 3067 (class 2606 OID 70373)
-- Name: oferta_tipo_descripcion_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY oferta_tipo
    ADD CONSTRAINT oferta_tipo_descripcion_key UNIQUE (descripcion);


--
-- TOC entry 3069 (class 2606 OID 70375)
-- Name: oferta_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY oferta_tipo
    ADD CONSTRAINT oferta_tipo_pkey PRIMARY KEY (c_oferta);


--
-- TOC entry 3073 (class 2606 OID 70377)
-- Name: organizacion_cursada_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY organizacion_cursada_tipo
    ADD CONSTRAINT organizacion_cursada_pkey PRIMARY KEY (c_organizacion_cursada);


--
-- TOC entry 3077 (class 2606 OID 70379)
-- Name: organizacion_plan_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY organizacion_plan_tipo
    ADD CONSTRAINT organizacion_plan_pkey PRIMARY KEY (c_organizacion_plan);


--
-- TOC entry 3081 (class 2606 OID 70381)
-- Name: orientacion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orientacion_tipo
    ADD CONSTRAINT orientacion_tipo_pkey PRIMARY KEY (c_orientacion);


--
-- TOC entry 3085 (class 2606 OID 70383)
-- Name: pais_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pais_tipo
    ADD CONSTRAINT pais_tipo_pkey PRIMARY KEY (c_pais);


--
-- TOC entry 3089 (class 2606 OID 70385)
-- Name: per_funcionamiento_tipo_descripcion_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY per_funcionamiento_tipo
    ADD CONSTRAINT per_funcionamiento_tipo_descripcion_key UNIQUE (descripcion);


--
-- TOC entry 3091 (class 2606 OID 70387)
-- Name: per_funcionamiento_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY per_funcionamiento_tipo
    ADD CONSTRAINT per_funcionamiento_tipo_pkey PRIMARY KEY (c_per_funcionamiento);


--
-- TOC entry 2906 (class 2606 OID 70389)
-- Name: pk_ciclo_lectivo_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ciclo_lectivo_tipo
    ADD CONSTRAINT pk_ciclo_lectivo_tipo PRIMARY KEY (c_ciclo_lectivo);


--
-- TOC entry 2991 (class 2606 OID 70391)
-- Name: pk_estado_operativo_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_operativo_tipo
    ADD CONSTRAINT pk_estado_operativo_tipo PRIMARY KEY (c_estado_operativo);


--
-- TOC entry 3000 (class 2606 OID 70393)
-- Name: pk_estado_verificacion_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_verificacion_tipo
    ADD CONSTRAINT pk_estado_verificacion_tipo PRIMARY KEY (c_estado_verificacion);


--
-- TOC entry 3071 (class 2606 OID 70395)
-- Name: pk_operativo_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY operativo_tipo
    ADD CONSTRAINT pk_operativo_tipo PRIMARY KEY (c_operativo);


--
-- TOC entry 3175 (class 2606 OID 70397)
-- Name: pk_tipo_operativo_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_operativo_tipo
    ADD CONSTRAINT pk_tipo_operativo_tipo PRIMARY KEY (c_tipo_operativo);


--
-- TOC entry 3093 (class 2606 OID 70399)
-- Name: provincia_tipo_cod_provincia_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY provincia_tipo
    ADD CONSTRAINT provincia_tipo_cod_provincia_key UNIQUE (cod_provincia);


--
-- TOC entry 3095 (class 2606 OID 70401)
-- Name: provincias_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY provincia_tipo
    ADD CONSTRAINT provincias_pkey PRIMARY KEY (c_provincia);


--
-- TOC entry 3097 (class 2606 OID 70403)
-- Name: rama_tipo_descripcion_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rama_tipo
    ADD CONSTRAINT rama_tipo_descripcion_key UNIQUE (descripcion);


--
-- TOC entry 3099 (class 2606 OID 70405)
-- Name: rama_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rama_tipo
    ADD CONSTRAINT rama_tipo_pkey PRIMARY KEY (c_rama);


--
-- TOC entry 3101 (class 2606 OID 70407)
-- Name: requisito_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisito_tipo
    ADD CONSTRAINT requisito_tipo_pkey PRIMARY KEY (c_requisito);


--
-- TOC entry 3105 (class 2606 OID 70409)
-- Name: restriccion_internet_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY restriccion_internet_tipo
    ADD CONSTRAINT restriccion_internet_tipo_pkey PRIMARY KEY (c_restriccion_internet);


--
-- TOC entry 3109 (class 2606 OID 70411)
-- Name: sector_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sector_tipo
    ADD CONSTRAINT sector_tipo_pkey PRIMARY KEY (c_sector);


--
-- TOC entry 3113 (class 2606 OID 70413)
-- Name: servicio_internet_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY servicio_internet_tipo
    ADD CONSTRAINT servicio_internet_tipo_pkey PRIMARY KEY (c_servicio_internet);


--
-- TOC entry 3118 (class 2606 OID 70415)
-- Name: sexo_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sexo_tipo
    ADD CONSTRAINT sexo_tipo_pkey PRIMARY KEY (c_sexo);


--
-- TOC entry 3122 (class 2606 OID 70417)
-- Name: sino_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sino_tipo
    ADD CONSTRAINT sino_tipo_pkey PRIMARY KEY (c_sino);


--
-- TOC entry 3126 (class 2606 OID 70419)
-- Name: sistema_gestion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sistema_gestion_tipo
    ADD CONSTRAINT sistema_gestion_tipo_pkey PRIMARY KEY (c_sistema_gestion);


--
-- TOC entry 3130 (class 2606 OID 70421)
-- Name: software_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY software_tipo
    ADD CONSTRAINT software_tipo_pkey PRIMARY KEY (c_software);


--
-- TOC entry 3134 (class 2606 OID 70423)
-- Name: subvencion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subvencion_tipo
    ADD CONSTRAINT subvencion_tipo_pkey PRIMARY KEY (c_subvencion);


--
-- TOC entry 3179 (class 2606 OID 70425)
-- Name: tip_seccion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_seccion_tipo
    ADD CONSTRAINT tip_seccion_tipo_pkey PRIMARY KEY (c_tipo_seccion);


--
-- TOC entry 3138 (class 2606 OID 70427)
-- Name: tipo_actividad_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_actividad_tipo
    ADD CONSTRAINT tipo_actividad_tipo_pkey PRIMARY KEY (c_tipo_actividad);


--
-- TOC entry 3142 (class 2606 OID 70429)
-- Name: tipo_baja_inscripcion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_baja_inscripcion_tipo
    ADD CONSTRAINT tipo_baja_inscripcion_tipo_pkey PRIMARY KEY (c_tipo_baja_inscripcion);


--
-- TOC entry 3146 (class 2606 OID 70431)
-- Name: tipo_beneficio_alimentario_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_beneficio_alimentario_tipo
    ADD CONSTRAINT tipo_beneficio_alimentario_tipo_pkey PRIMARY KEY (c_tipo_beneficio_alimentario);


--
-- TOC entry 3150 (class 2606 OID 70433)
-- Name: tipo_beneficio_plan_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_beneficio_plan_tipo
    ADD CONSTRAINT tipo_beneficio_plan_tipo_pkey PRIMARY KEY (c_tipo_beneficio_plan);


--
-- TOC entry 3154 (class 2606 OID 70435)
-- Name: tipo_consistencia_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_consistencia_tipo
    ADD CONSTRAINT tipo_consistencia_tipo_pkey PRIMARY KEY (c_tipo_consistencia);


--
-- TOC entry 3158 (class 2606 OID 70437)
-- Name: tipo_copia_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_copia_tipo
    ADD CONSTRAINT tipo_copia_tipo_pkey PRIMARY KEY (c_tipo_copia);


--
-- TOC entry 3163 (class 2606 OID 70439)
-- Name: tipo_documento_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_documento_tipo
    ADD CONSTRAINT tipo_documento_tipo_pkey PRIMARY KEY (c_tipo_documento);


--
-- TOC entry 3167 (class 2606 OID 70441)
-- Name: tipo_formacion_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_formacion_tipo
    ADD CONSTRAINT tipo_formacion_tipo_pkey PRIMARY KEY (c_tipo_formacion);


--
-- TOC entry 3171 (class 2606 OID 70443)
-- Name: tipo_norma_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_norma_tipo
    ADD CONSTRAINT tipo_norma_tipo_pkey PRIMARY KEY (c_tipo_norma);


--
-- TOC entry 3183 (class 2606 OID 70445)
-- Name: tipo_titulo_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_titulo_tipo
    ADD CONSTRAINT tipo_titulo_tipo_pkey PRIMARY KEY (c_tipo_titulo);


--
-- TOC entry 3187 (class 2606 OID 70447)
-- Name: transporte_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transporte_tipo
    ADD CONSTRAINT transporte_tipo_pkey PRIMARY KEY (c_transporte);


--
-- TOC entry 3191 (class 2606 OID 70449)
-- Name: trayecto_formativo_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY trayecto_formativo_tipo
    ADD CONSTRAINT trayecto_formativo_tipo_pkey PRIMARY KEY (c_trayecto_formativo);


--
-- TOC entry 2868 (class 2606 OID 70451)
-- Name: tuc_ambito_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ambito_tipo
    ADD CONSTRAINT tuc_ambito_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2872 (class 2606 OID 70453)
-- Name: tuc_anio_corrido_edad_teorica_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY anio_corrido_edad_teorica_tipo
    ADD CONSTRAINT tuc_anio_corrido_edad_teorica_tipo_1 UNIQUE (c_grado_nivel_servicio, c_certificacion);


--
-- TOC entry 2876 (class 2606 OID 70455)
-- Name: tuc_area_pedagogica_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY area_pedagogica_tipo
    ADD CONSTRAINT tuc_area_pedagogica_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2880 (class 2606 OID 70457)
-- Name: tuc_area_tematica_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY area_tematica_tipo
    ADD CONSTRAINT tuc_area_tematica_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2884 (class 2606 OID 70459)
-- Name: tuc_articulacion_tit_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY articulacion_tit_tipo
    ADD CONSTRAINT tuc_articulacion_tit_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2888 (class 2606 OID 70461)
-- Name: tuc_campo_formacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY campo_formacion_tipo
    ADD CONSTRAINT tuc_campo_formacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2892 (class 2606 OID 70463)
-- Name: tuc_carga_horaria_en_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY carga_horaria_en_tipo
    ADD CONSTRAINT tuc_carga_horaria_en_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2900 (class 2606 OID 70465)
-- Name: tuc_categoria_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY categoria_tipo
    ADD CONSTRAINT tuc_categoria_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2904 (class 2606 OID 70467)
-- Name: tuc_certificacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY certificacion_tipo
    ADD CONSTRAINT tuc_certificacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2910 (class 2606 OID 70469)
-- Name: tuc_condicion_aprobacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY condicion_aprobacion_tipo
    ADD CONSTRAINT tuc_condicion_aprobacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2914 (class 2606 OID 70471)
-- Name: tuc_condicion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY condicion_tipo
    ADD CONSTRAINT tuc_condicion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2918 (class 2606 OID 70473)
-- Name: tuc_conexion_internet_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY conexion_internet_tipo
    ADD CONSTRAINT tuc_conexion_internet_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2922 (class 2606 OID 70475)
-- Name: tuc_cooperadora_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cooperadora_tipo
    ADD CONSTRAINT tuc_cooperadora_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2926 (class 2606 OID 70477)
-- Name: tuc_cursa_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cursa_tipo
    ADD CONSTRAINT tuc_cursa_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2936 (class 2606 OID 70479)
-- Name: tuc_dependencia_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dependencia_tipo
    ADD CONSTRAINT tuc_dependencia_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2940 (class 2606 OID 70481)
-- Name: tuc_dicta_cuatrimestre_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dicta_cuatrimestre_tipo
    ADD CONSTRAINT tuc_dicta_cuatrimestre_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2944 (class 2606 OID 70483)
-- Name: tuc_dictado_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dictado_tipo
    ADD CONSTRAINT tuc_dictado_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2948 (class 2606 OID 70485)
-- Name: tuc_discapacidad_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY discapacidad_tipo
    ADD CONSTRAINT tuc_discapacidad_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2956 (class 2606 OID 70487)
-- Name: tuc_docente_integrador_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY docente_integrador_tipo
    ADD CONSTRAINT tuc_docente_integrador_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2960 (class 2606 OID 70489)
-- Name: tuc_duracion_en_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY duracion_en_tipo
    ADD CONSTRAINT tuc_duracion_en_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2964 (class 2606 OID 70491)
-- Name: tuc_energia_electrica_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY energia_electrica_tipo
    ADD CONSTRAINT tuc_energia_electrica_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2968 (class 2606 OID 70493)
-- Name: tuc_equipamiento_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY equipamiento_tipo
    ADD CONSTRAINT tuc_equipamiento_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2972 (class 2606 OID 70495)
-- Name: tuc_espacio_curricular_duracion_en_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_curricular_duracion_en_tipo
    ADD CONSTRAINT tuc_espacio_curricular_duracion_en_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2976 (class 2606 OID 70497)
-- Name: tuc_espacio_internet_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_internet_tipo
    ADD CONSTRAINT tuc_espacio_internet_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2980 (class 2606 OID 70499)
-- Name: tuc_estado_civil_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_civil_tipo
    ADD CONSTRAINT tuc_estado_civil_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2984 (class 2606 OID 70501)
-- Name: tuc_estado_hoja_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_hoja_tipo
    ADD CONSTRAINT tuc_estado_hoja_tipo UNIQUE (descripcion);


--
-- TOC entry 2989 (class 2606 OID 70503)
-- Name: tuc_estado_inscripcion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_inscripcion_tipo
    ADD CONSTRAINT tuc_estado_inscripcion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2993 (class 2606 OID 70505)
-- Name: tuc_estado_operativo_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_operativo_tipo
    ADD CONSTRAINT tuc_estado_operativo_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 2997 (class 2606 OID 70507)
-- Name: tuc_estado_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_tipo
    ADD CONSTRAINT tuc_estado_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3002 (class 2606 OID 70509)
-- Name: tuc_estado_verificacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY estado_verificacion_tipo
    ADD CONSTRAINT tuc_estado_verificacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3006 (class 2606 OID 70511)
-- Name: tuc_fines_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fines_tipo
    ADD CONSTRAINT tuc_fines_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3010 (class 2606 OID 70513)
-- Name: tuc_formato_espacio_curricular_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY formato_espacio_curricular_tipo
    ADD CONSTRAINT tuc_formato_espacio_curricular_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3015 (class 2606 OID 70515)
-- Name: tuc_grado_nivel_servicio_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY grado_nivel_servicio_tipo
    ADD CONSTRAINT tuc_grado_nivel_servicio_tipo_1 UNIQUE (c_grado, c_nivel_servicio);


--
-- TOC entry 3020 (class 2606 OID 70517)
-- Name: tuc_grado_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY grado_tipo
    ADD CONSTRAINT tuc_grado_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3024 (class 2606 OID 70519)
-- Name: tuc_indigena_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY indigena_tipo
    ADD CONSTRAINT tuc_indigena_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3028 (class 2606 OID 70521)
-- Name: tuc_jornada_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY jornada_tipo
    ADD CONSTRAINT tuc_jornada_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3035 (class 2606 OID 70523)
-- Name: tuc_lugar_funcionamiento_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lugar_funcionamiento_tipo
    ADD CONSTRAINT tuc_lugar_funcionamiento_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3039 (class 2606 OID 70525)
-- Name: tuc_mantenimiento_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mantenimiento_tipo
    ADD CONSTRAINT tuc_mantenimiento_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3043 (class 2606 OID 70527)
-- Name: tuc_modalidad1_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY modalidad1_tipo
    ADD CONSTRAINT tuc_modalidad1_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3047 (class 2606 OID 70529)
-- Name: tuc_motivo_baja_inscripcion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY motivo_baja_inscripcion_tipo
    ADD CONSTRAINT tuc_motivo_baja_inscripcion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3053 (class 2606 OID 70531)
-- Name: tuc_nivel_alcanzado_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nivel_alcanzado_tipo
    ADD CONSTRAINT tuc_nivel_alcanzado_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3057 (class 2606 OID 70533)
-- Name: tuc_nivel_servicio_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nivel_servicio_tipo
    ADD CONSTRAINT tuc_nivel_servicio_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3061 (class 2606 OID 70535)
-- Name: tuc_normativa_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY normativa_tipo
    ADD CONSTRAINT tuc_normativa_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3065 (class 2606 OID 70537)
-- Name: tuc_obligatoriedad_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY obligatoriedad_tipo
    ADD CONSTRAINT tuc_obligatoriedad_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3075 (class 2606 OID 70539)
-- Name: tuc_organizacion_cursada_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY organizacion_cursada_tipo
    ADD CONSTRAINT tuc_organizacion_cursada_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3079 (class 2606 OID 70541)
-- Name: tuc_organizacion_plan_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY organizacion_plan_tipo
    ADD CONSTRAINT tuc_organizacion_plan_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3083 (class 2606 OID 70543)
-- Name: tuc_orientacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orientacion_tipo
    ADD CONSTRAINT tuc_orientacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3087 (class 2606 OID 70545)
-- Name: tuc_pais_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pais_tipo
    ADD CONSTRAINT tuc_pais_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3103 (class 2606 OID 70547)
-- Name: tuc_requisito_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisito_tipo
    ADD CONSTRAINT tuc_requisito_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3107 (class 2606 OID 70549)
-- Name: tuc_restriccion_internet_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY restriccion_internet_tipo
    ADD CONSTRAINT tuc_restriccion_internet_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3111 (class 2606 OID 70551)
-- Name: tuc_sector_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sector_tipo
    ADD CONSTRAINT tuc_sector_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3115 (class 2606 OID 70553)
-- Name: tuc_servicio_internet_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY servicio_internet_tipo
    ADD CONSTRAINT tuc_servicio_internet_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3120 (class 2606 OID 70555)
-- Name: tuc_sexo_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sexo_tipo
    ADD CONSTRAINT tuc_sexo_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3124 (class 2606 OID 70557)
-- Name: tuc_sino_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sino_tipo
    ADD CONSTRAINT tuc_sino_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3128 (class 2606 OID 70559)
-- Name: tuc_sistema_gestion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sistema_gestion_tipo
    ADD CONSTRAINT tuc_sistema_gestion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3132 (class 2606 OID 70561)
-- Name: tuc_software_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY software_tipo
    ADD CONSTRAINT tuc_software_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3136 (class 2606 OID 70563)
-- Name: tuc_subvencion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subvencion_tipo
    ADD CONSTRAINT tuc_subvencion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3140 (class 2606 OID 70565)
-- Name: tuc_tipo_actividad_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_actividad_tipo
    ADD CONSTRAINT tuc_tipo_actividad_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3144 (class 2606 OID 70567)
-- Name: tuc_tipo_baja_inscripcion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_baja_inscripcion_tipo
    ADD CONSTRAINT tuc_tipo_baja_inscripcion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3148 (class 2606 OID 70569)
-- Name: tuc_tipo_beneficio_alimentario_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_beneficio_alimentario_tipo
    ADD CONSTRAINT tuc_tipo_beneficio_alimentario_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3152 (class 2606 OID 70571)
-- Name: tuc_tipo_beneficio_plan_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_beneficio_plan_tipo
    ADD CONSTRAINT tuc_tipo_beneficio_plan_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3156 (class 2606 OID 70573)
-- Name: tuc_tipo_consistencia_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_consistencia_tipo
    ADD CONSTRAINT tuc_tipo_consistencia_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3160 (class 2606 OID 70575)
-- Name: tuc_tipo_copia_tipo; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_copia_tipo
    ADD CONSTRAINT tuc_tipo_copia_tipo UNIQUE (descripcion);


--
-- TOC entry 3165 (class 2606 OID 70577)
-- Name: tuc_tipo_documento_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_documento_tipo
    ADD CONSTRAINT tuc_tipo_documento_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3169 (class 2606 OID 70579)
-- Name: tuc_tipo_formacion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_formacion_tipo
    ADD CONSTRAINT tuc_tipo_formacion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3173 (class 2606 OID 70581)
-- Name: tuc_tipo_norma_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_norma_tipo
    ADD CONSTRAINT tuc_tipo_norma_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3177 (class 2606 OID 70583)
-- Name: tuc_tipo_operativo_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_operativo_tipo
    ADD CONSTRAINT tuc_tipo_operativo_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3181 (class 2606 OID 70585)
-- Name: tuc_tipo_seccion_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_seccion_tipo
    ADD CONSTRAINT tuc_tipo_seccion_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3185 (class 2606 OID 70587)
-- Name: tuc_tipo_titulo_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tipo_titulo_tipo
    ADD CONSTRAINT tuc_tipo_titulo_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3189 (class 2606 OID 70589)
-- Name: tuc_transporte_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transporte_tipo
    ADD CONSTRAINT tuc_transporte_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3193 (class 2606 OID 70591)
-- Name: tuc_trayecto_formativo_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY trayecto_formativo_tipo
    ADD CONSTRAINT tuc_trayecto_formativo_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3195 (class 2606 OID 70593)
-- Name: tuc_turno_tipo_1; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY turno_tipo
    ADD CONSTRAINT tuc_turno_tipo_1 UNIQUE (descripcion);


--
-- TOC entry 3197 (class 2606 OID 70595)
-- Name: turno_tipo_pkey; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY turno_tipo
    ADD CONSTRAINT turno_tipo_pkey PRIMARY KEY (c_turno);


--
-- TOC entry 2896 (class 2606 OID 70597)
-- Name: unq_carrera_tipo_descripcion; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY carrera_tipo
    ADD CONSTRAINT unq_carrera_tipo_descripcion UNIQUE (descripcion, c_disciplina, cod_carrera);


--
-- TOC entry 2932 (class 2606 OID 70599)
-- Name: unq_departamento_tipo_cod_departamento_key; Type: CONSTRAINT; Schema: codigos; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departamento_tipo
    ADD CONSTRAINT unq_departamento_tipo_cod_departamento_key UNIQUE (cod_departamento);


SET search_path = public, pg_catalog;

--
-- TOC entry 3248 (class 2606 OID 70601)
-- Name: actividad_extracurricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_pkey PRIMARY KEY (id_actividad_extracurricular);


--
-- TOC entry 3251 (class 2606 OID 70603)
-- Name: alumno_beneficio_alimentario_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_beneficio_alimentario
    ADD CONSTRAINT alumno_beneficio_alimentario_pk PRIMARY KEY (id_alumno_beneficio_alimentario);


--
-- TOC entry 3255 (class 2606 OID 70605)
-- Name: alumno_beneficio_plan_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_beneficio_plan
    ADD CONSTRAINT alumno_beneficio_plan_pk PRIMARY KEY (id_alumno_beneficio_plan);


--
-- TOC entry 3259 (class 2606 OID 70607)
-- Name: alumno_discapacidad_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_discapacidad
    ADD CONSTRAINT alumno_discapacidad_pk PRIMARY KEY (id_alumno_discapacidad);


--
-- TOC entry 3199 (class 2606 OID 70609)
-- Name: alumno_espacio_curricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT alumno_espacio_curricular_pkey PRIMARY KEY (id_alumno_espacio_curricular);


--
-- TOC entry 3209 (class 2606 OID 70611)
-- Name: alumno_inscripcion_espacio_curricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT alumno_inscripcion_espacio_curricular_pkey PRIMARY KEY (id_alumno_inscripcion_espacio_curricular);


--
-- TOC entry 3214 (class 2606 OID 70613)
-- Name: alumno_inscripcion_extracurricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular
    ADD CONSTRAINT alumno_inscripcion_extracurricular_pkey PRIMARY KEY (id_alumno_inscripcion_extracurricular);


--
-- TOC entry 3266 (class 2606 OID 70615)
-- Name: alumno_inscripcion_historico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_historico_pkey PRIMARY KEY (id_alumno_inscripcion_historico);


--
-- TOC entry 3204 (class 2606 OID 70617)
-- Name: alumno_inscripcion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_pkey PRIMARY KEY (id_alumno_inscripcion);


--
-- TOC entry 2859 (class 2606 OID 70619)
-- Name: alumno_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_pkey PRIMARY KEY (id_alumno);


--
-- TOC entry 3270 (class 2606 OID 70621)
-- Name: autoridad_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY autoridad
    ADD CONSTRAINT autoridad_pkey PRIMARY KEY (id_autoridad);


--
-- TOC entry 3274 (class 2606 OID 70623)
-- Name: consistencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY consistencia
    ADD CONSTRAINT consistencia_pkey PRIMARY KEY (id_consistencia);


--
-- TOC entry 3276 (class 2606 OID 70625)
-- Name: datos_institucion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_pkey PRIMARY KEY (id_institucion);


--
-- TOC entry 3278 (class 2606 OID 70627)
-- Name: datos_unidad_servicio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY datos_unidad_servicio
    ADD CONSTRAINT datos_unidad_servicio_pkey PRIMARY KEY (id_unidad_servicio);


--
-- TOC entry 3223 (class 2606 OID 70629)
-- Name: espacio_curricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_pkey PRIMARY KEY (id_espacio_curricular);


--
-- TOC entry 3282 (class 2606 OID 70631)
-- Name: establecimiento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY establecimiento
    ADD CONSTRAINT establecimiento_pkey PRIMARY KEY (id_establecimiento);


--
-- TOC entry 3292 (class 2606 OID 70633)
-- Name: hoja_papel_moneda_analitico_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY hoja_papel_moneda_analitico
    ADD CONSTRAINT hoja_papel_moneda_analitico_pkey PRIMARY KEY (id_hoja_papel_moneda_analitico);


--
-- TOC entry 3287 (class 2606 OID 70635)
-- Name: hoja_papel_moneda_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT hoja_papel_moneda_pkey PRIMARY KEY (id_hoja_papel_moneda);


--
-- TOC entry 3294 (class 2606 OID 70637)
-- Name: institucion_equipamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT institucion_equipamiento_pkey PRIMARY KEY (id_institucion_equipamiento);


--
-- TOC entry 3243 (class 2606 OID 70639)
-- Name: institucion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_pkey PRIMARY KEY (id_institucion);


--
-- TOC entry 3298 (class 2606 OID 70641)
-- Name: institucion_software_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY institucion_software
    ADD CONSTRAINT institucion_software_pkey PRIMARY KEY (id_institucion_software);


--
-- TOC entry 3302 (class 2606 OID 70643)
-- Name: lote_papel_moneda_nro_serie_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lote_papel_moneda
    ADD CONSTRAINT lote_papel_moneda_nro_serie_key UNIQUE (nro_serie, desde);


--
-- TOC entry 3304 (class 2606 OID 70645)
-- Name: lote_papel_moneda_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lote_papel_moneda
    ADD CONSTRAINT lote_papel_moneda_pkey PRIMARY KEY (id_lote_papel_moneda);


--
-- TOC entry 3280 (class 2606 OID 70647)
-- Name: materia_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nombre_espacio_curricular
    ADD CONSTRAINT materia_tipo_pkey PRIMARY KEY (id_nombre_espacio_curricular);


--
-- TOC entry 3307 (class 2606 OID 70649)
-- Name: nombre_cargo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nombre_cargo
    ADD CONSTRAINT nombre_cargo_pkey PRIMARY KEY (id_nombre_cargo);


--
-- TOC entry 3312 (class 2606 OID 70651)
-- Name: nombre_titulacion_nivel_servicio_tipo_assn_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nombre_titulacion_nivel_servicio_tipo_assn
    ADD CONSTRAINT nombre_titulacion_nivel_servicio_tipo_assn_pkey PRIMARY KEY (id_nombre_titulacion, c_nivel_servicio);


--
-- TOC entry 3314 (class 2606 OID 70653)
-- Name: oferta_local_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY oferta_local
    ADD CONSTRAINT oferta_local_pkey PRIMARY KEY (id_oferta_local);


--
-- TOC entry 2864 (class 2606 OID 70655)
-- Name: persona_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT persona_pkey PRIMARY KEY (id_persona);


--
-- TOC entry 3326 (class 2606 OID 70657)
-- Name: pk_verificacion_carga; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY verificacion_carga
    ADD CONSTRAINT pk_verificacion_carga PRIMARY KEY (id_verificacion_carga);


--
-- TOC entry 3318 (class 2606 OID 70659)
-- Name: seccion_curricular_espacio_curricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY seccion_curricular_espacio_curricular
    ADD CONSTRAINT seccion_curricular_espacio_curricular_pkey PRIMARY KEY (id_seccion_curricular_espacio_curricular);


--
-- TOC entry 3221 (class 2606 OID 70661)
-- Name: seccion_curricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_pkey PRIMARY KEY (id_seccion_curricular);


--
-- TOC entry 3320 (class 2606 OID 70663)
-- Name: seccion_extracurricular_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_pkey PRIMARY KEY (id_seccion_extracurricular);


--
-- TOC entry 3246 (class 2606 OID 70665)
-- Name: seccion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY seccion
    ADD CONSTRAINT seccion_pkey PRIMARY KEY (id_seccion);


--
-- TOC entry 3322 (class 2606 OID 70667)
-- Name: titulacion_normativa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT titulacion_normativa_pkey PRIMARY KEY (id_titulacion_normativa);


--
-- TOC entry 3232 (class 2606 OID 70669)
-- Name: titulacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_pkey PRIMARY KEY (id_titulacion);


--
-- TOC entry 3264 (class 2606 OID 70671)
-- Name: titulo_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nombre_titulacion
    ADD CONSTRAINT titulo_tipo_pkey PRIMARY KEY (id_nombre_titulacion);


--
-- TOC entry 3253 (class 2606 OID 70673)
-- Name: tuc_alumno_beneficio_alimentario_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_beneficio_alimentario
    ADD CONSTRAINT tuc_alumno_beneficio_alimentario_1 UNIQUE (c_tipo_beneficio_alimentario, id_alumno);


--
-- TOC entry 3257 (class 2606 OID 70675)
-- Name: tuc_alumno_beneficio_plan_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_beneficio_plan
    ADD CONSTRAINT tuc_alumno_beneficio_plan_1 UNIQUE (c_tipo_beneficio_plan, id_alumno);


--
-- TOC entry 3261 (class 2606 OID 70677)
-- Name: tuc_alumno_discapacidad_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_discapacidad
    ADD CONSTRAINT tuc_alumno_discapacidad_1 UNIQUE (c_discapacidad, id_alumno);


--
-- TOC entry 3202 (class 2606 OID 70679)
-- Name: tuc_alumno_espacio_curricular_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT tuc_alumno_espacio_curricular_1 UNIQUE (id_espacio_curricular, id_alumno);


--
-- TOC entry 3207 (class 2606 OID 70681)
-- Name: tuc_alumno_inscripcion_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT tuc_alumno_inscripcion_1 UNIQUE (id_titulacion, id_alumno);


--
-- TOC entry 3212 (class 2606 OID 70683)
-- Name: tuc_alumno_inscripcion_espacio_curricular_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT tuc_alumno_inscripcion_espacio_curricular_1 UNIQUE (id_espacio_curricular, id_alumno_inscripcion);


--
-- TOC entry 3216 (class 2606 OID 70685)
-- Name: tuc_alumno_inscripcion_extracurricular_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular
    ADD CONSTRAINT tuc_alumno_inscripcion_extracurricular_1 UNIQUE (id_seccion_extracurricular, id_alumno);


--
-- TOC entry 3268 (class 2606 OID 70687)
-- Name: tuc_alumno_inscripcion_historico_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT tuc_alumno_inscripcion_historico_1 UNIQUE (id_alumno_inscripcion, c_ciclo_lectivo);


--
-- TOC entry 3226 (class 2606 OID 70689)
-- Name: tuc_espacio_curricular_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT tuc_espacio_curricular_1 UNIQUE (id_titulacion, c_grado_nivel_servicio, id_nombre_espacio_curricular, c_trayecto_formativo);


--
-- TOC entry 3290 (class 2606 OID 70691)
-- Name: tuc_hoja_papel_moneda_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT tuc_hoja_papel_moneda_1 UNIQUE (id_lote_papel_moneda, nro_hoja);


--
-- TOC entry 3296 (class 2606 OID 70693)
-- Name: tuc_institucion_equipamiento_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT tuc_institucion_equipamiento_1 UNIQUE (id_institucion, c_equipamiento);


--
-- TOC entry 3300 (class 2606 OID 70695)
-- Name: tuc_institucion_software_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY institucion_software
    ADD CONSTRAINT tuc_institucion_software_1 UNIQUE (id_institucion, c_software);


--
-- TOC entry 3309 (class 2606 OID 70697)
-- Name: tuc_nombre_cargo_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nombre_cargo
    ADD CONSTRAINT tuc_nombre_cargo_1 UNIQUE (nombre);


--
-- TOC entry 3324 (class 2606 OID 70699)
-- Name: tuc_titulacion_normativa_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT tuc_titulacion_normativa_1 UNIQUE (norma_nro, c_tipo_norma, c_normativa, id_titulacion);


--
-- TOC entry 3235 (class 2606 OID 70701)
-- Name: tuc_unidad_servicio_1; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT tuc_unidad_servicio_1 UNIQUE (id_institucion, c_nivel_servicio);


--
-- TOC entry 3239 (class 2606 OID 70703)
-- Name: unidad_servicio_operativo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY unidad_servicio_operativo
    ADD CONSTRAINT unidad_servicio_operativo_pkey PRIMARY KEY (id_unidad_servicio_operativo);


--
-- TOC entry 3237 (class 2606 OID 70705)
-- Name: unidad_servicio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_pkey PRIMARY KEY (id_unidad_servicio);


--
-- TOC entry 3284 (class 2606 OID 70707)
-- Name: unq_establecimiento_cue_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY establecimiento
    ADD CONSTRAINT unq_establecimiento_cue_key UNIQUE (cue);


SET search_path = codigos, pg_catalog;

--
-- TOC entry 2929 (class 1259 OID 70735)
-- Name: idx_departamento_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_departamento_tipo_1 ON departamento_tipo USING btree (c_departamento, nombre);


--
-- TOC entry 2930 (class 1259 OID 70736)
-- Name: idx_departamento_tipo_2_fk; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_departamento_tipo_2_fk ON departamento_tipo USING btree (c_provincia);


--
-- TOC entry 2987 (class 1259 OID 70737)
-- Name: idx_estado_inscripcion_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_estado_inscripcion_tipo_1 ON estado_inscripcion_tipo USING btree (c_estado_inscripcion, descripcion);


--
-- TOC entry 2998 (class 1259 OID 70738)
-- Name: idx_estado_verificacion_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_estado_verificacion_tipo_1 ON estado_verificacion_tipo USING btree (c_estado_verificacion, descripcion);


--
-- TOC entry 3013 (class 1259 OID 70739)
-- Name: idx_grado_nivel_servicio_tipo_1_fk; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_grado_nivel_servicio_tipo_1_fk ON grado_nivel_servicio_tipo USING btree (c_grado);


--
-- TOC entry 3018 (class 1259 OID 70740)
-- Name: idx_grado_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_grado_tipo_1 ON grado_tipo USING btree (c_grado, descripcion);


--
-- TOC entry 3116 (class 1259 OID 70741)
-- Name: idx_sexo_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_sexo_tipo_1 ON sexo_tipo USING btree (c_sexo, descripcion);


--
-- TOC entry 3161 (class 1259 OID 70742)
-- Name: idx_tipo_documento_tipo_1; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_tipo_documento_tipo_1 ON tipo_documento_tipo USING btree (c_tipo_documento, descripcion);


--
-- TOC entry 3029 (class 1259 OID 70743)
-- Name: localidad_tipo_c_localidad_c_departamento_nombre_tipo_idx; Type: INDEX; Schema: codigos; Owner: postgres; Tablespace: 
--

CREATE INDEX localidad_tipo_c_localidad_c_departamento_nombre_tipo_idx ON localidad_tipo USING btree (c_localidad, c_departamento, nombre, tipo);


SET search_path = public, pg_catalog;

--
-- TOC entry 2860 (class 1259 OID 70744)
-- Name: fki_alumno_id_a_id_p_id_us; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_alumno_id_a_id_p_id_us ON alumno USING btree (id_alumno, id_persona, id_unidad_servicio);


--
-- TOC entry 3285 (class 1259 OID 70745)
-- Name: hoja_papel_moneda_id_lote_papel_moneda_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX hoja_papel_moneda_id_lote_papel_moneda_idx ON hoja_papel_moneda USING btree (id_lote_papel_moneda);


--
-- TOC entry 2861 (class 1259 OID 70746)
-- Name: idx_alumno_1_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_alumno_1_fk ON alumno USING btree (id_persona);


--
-- TOC entry 3200 (class 1259 OID 70747)
-- Name: idx_alumno_espacio_curricular_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_alumno_espacio_curricular_1 ON alumno_espacio_curricular USING btree (id_espacio_curricular, id_alumno);


--
-- TOC entry 3205 (class 1259 OID 70748)
-- Name: idx_alumno_inscripcion_alumno_titulacion; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_alumno_inscripcion_alumno_titulacion ON alumno_inscripcion USING btree (id_alumno, id_titulacion);


--
-- TOC entry 3210 (class 1259 OID 70749)
-- Name: idx_alumno_inscripcion_espacio_curricular_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_alumno_inscripcion_espacio_curricular_1 ON alumno_inscripcion_espacio_curricular USING btree (id_alumno_inscripcion, id_espacio_curricular);


--
-- TOC entry 3271 (class 1259 OID 70750)
-- Name: idx_autoridad_1_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_autoridad_1_fk ON autoridad USING btree (id_institucion);


--
-- TOC entry 3272 (class 1259 OID 70751)
-- Name: idx_autoridad_3_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_autoridad_3_fk ON autoridad USING btree (id_persona);


--
-- TOC entry 3224 (class 1259 OID 70752)
-- Name: idx_espacio_curricular_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_espacio_curricular_1 ON espacio_curricular USING btree (id_titulacion, id_nombre_espacio_curricular);


--
-- TOC entry 3288 (class 1259 OID 70753)
-- Name: idx_hoja_papel_moneda_id_lote_papel_moneda; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_hoja_papel_moneda_id_lote_papel_moneda ON hoja_papel_moneda USING btree (id_lote_papel_moneda);


--
-- TOC entry 3240 (class 1259 OID 70754)
-- Name: idx_institucion_cueanexo; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_institucion_cueanexo ON institucion USING btree (id_institucion, cueanexo);


--
-- TOC entry 3241 (class 1259 OID 70755)
-- Name: idx_institucion_provincia_localidad; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_institucion_provincia_localidad ON institucion USING btree (id_institucion, c_provincia, c_localidad);


--
-- TOC entry 3249 (class 1259 OID 70756)
-- Name: idx_nombre_actividad_extracurricular_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_nombre_actividad_extracurricular_1 ON actividad_extracurricular USING btree (nombre);


--
-- TOC entry 3262 (class 1259 OID 70757)
-- Name: idx_nombre_titulacion_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_nombre_titulacion_1 ON nombre_titulacion USING btree (id_nombre_titulacion, nombre);


--
-- TOC entry 3310 (class 1259 OID 70758)
-- Name: idx_nombre_titulacion_nivel_servicio_tipo_assn; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_nombre_titulacion_nivel_servicio_tipo_assn ON nombre_titulacion_nivel_servicio_tipo_assn USING btree (id_nombre_titulacion, c_nivel_servicio);

ALTER TABLE nombre_titulacion_nivel_servicio_tipo_assn CLUSTER ON idx_nombre_titulacion_nivel_servicio_tipo_assn;


--
-- TOC entry 2862 (class 1259 OID 70759)
-- Name: idx_persona_documento; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_persona_documento ON persona USING btree (c_tipo_documento, nro_documento);


--
-- TOC entry 3244 (class 1259 OID 70760)
-- Name: idx_seccion_4_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_4_fk ON seccion USING btree (id_espacio_curricular);


--
-- TOC entry 3217 (class 1259 OID 70761)
-- Name: idx_seccion_curricular_4_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_curricular_4_fk ON seccion_curricular USING btree (c_grado_nivel_servicio);


--
-- TOC entry 3315 (class 1259 OID 70762)
-- Name: idx_seccion_curricular_espacio_curricular_1_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_curricular_espacio_curricular_1_fk ON seccion_curricular_espacio_curricular USING btree (id_seccion_curricular);


--
-- TOC entry 3316 (class 1259 OID 70763)
-- Name: idx_seccion_curricular_espacio_curricular_2_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_curricular_espacio_curricular_2_fk ON seccion_curricular_espacio_curricular USING btree (id_espacio_curricular);


--
-- TOC entry 3218 (class 1259 OID 70764)
-- Name: idx_seccion_curricular_seccion_titulacion; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_curricular_seccion_titulacion ON seccion_curricular USING btree (id_seccion, id_titulacion);


--
-- TOC entry 3219 (class 1259 OID 70765)
-- Name: idx_seccion_curricular_seccion_titulacion_grado; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_seccion_curricular_seccion_titulacion_grado ON seccion_curricular USING btree (id_seccion, id_titulacion);


--
-- TOC entry 3227 (class 1259 OID 70766)
-- Name: idx_titulacion_17_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_titulacion_17_fk ON titulacion USING btree (id_titulacion_normativa_vigente);


--
-- TOC entry 3228 (class 1259 OID 70767)
-- Name: idx_titulacion_19_fk; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_titulacion_19_fk ON titulacion USING btree (id_titulacion_ciclo_basico);


--
-- TOC entry 3229 (class 1259 OID 70768)
-- Name: idx_titulacion_nombre_titulacion; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_titulacion_nombre_titulacion ON titulacion USING btree (id_titulacion, id_nombre_titulacion);


--
-- TOC entry 3230 (class 1259 OID 70769)
-- Name: idx_titulacion_unidad_servicio; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_titulacion_unidad_servicio ON titulacion USING btree (id_titulacion, id_unidad_servicio);


--
-- TOC entry 3233 (class 1259 OID 70770)
-- Name: idx_unidad_servicio_institucion; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_unidad_servicio_institucion ON unidad_servicio USING btree (id_unidad_servicio, id_institucion);


--
-- TOC entry 3305 (class 1259 OID 70771)
-- Name: nombre_cargo_nombre_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX nombre_cargo_nombre_idx ON nombre_cargo USING btree (nombre);


SET search_path = codigos, pg_catalog;

--
-- TOC entry 3344 (class 2606 OID 70870)
-- Name: anio_corrido_edad_teorica_tipo_c_certificacion_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY anio_corrido_edad_teorica_tipo
    ADD CONSTRAINT anio_corrido_edad_teorica_tipo_c_certificacion_fkey FOREIGN KEY (c_certificacion) REFERENCES certificacion_tipo(c_certificacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3345 (class 2606 OID 70875)
-- Name: anio_corrido_edad_teorica_tipo_c_grado_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY anio_corrido_edad_teorica_tipo
    ADD CONSTRAINT anio_corrido_edad_teorica_tipo_c_grado_nivel_servicio_fkey FOREIGN KEY (c_grado_nivel_servicio) REFERENCES grado_nivel_servicio_tipo(c_grado_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3346 (class 2606 OID 70880)
-- Name: campo_formacion_tipo_c_area_pedagogica_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY campo_formacion_tipo
    ADD CONSTRAINT campo_formacion_tipo_c_area_pedagogica_fkey FOREIGN KEY (c_area_pedagogica) REFERENCES area_pedagogica_tipo(c_area_pedagogica) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3347 (class 2606 OID 70885)
-- Name: carrera_tipo_c_disciplina_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY carrera_tipo
    ADD CONSTRAINT carrera_tipo_c_disciplina_fkey FOREIGN KEY (c_disciplina) REFERENCES disciplina_tipo(c_disciplina) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3357 (class 2606 OID 70890)
-- Name: ciclo_lectivo_tipo_operativo_tipo; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY operativo_tipo
    ADD CONSTRAINT ciclo_lectivo_tipo_operativo_tipo FOREIGN KEY (c_ciclo_lectivo) REFERENCES ciclo_lectivo_tipo(c_ciclo_lectivo);


--
-- TOC entry 3348 (class 2606 OID 70895)
-- Name: departamento_tipo_c_provincia_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY departamento_tipo
    ADD CONSTRAINT departamento_tipo_c_provincia_fkey FOREIGN KEY (c_provincia) REFERENCES provincia_tipo(c_provincia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3349 (class 2606 OID 70900)
-- Name: disciplina_tipo_c_rama_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY disciplina_tipo
    ADD CONSTRAINT disciplina_tipo_c_rama_fkey FOREIGN KEY (c_rama) REFERENCES rama_tipo(c_rama) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3350 (class 2606 OID 70905)
-- Name: grado_nivel_servicio_tipo_c_grado_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY grado_nivel_servicio_tipo
    ADD CONSTRAINT grado_nivel_servicio_tipo_c_grado_fkey FOREIGN KEY (c_grado) REFERENCES grado_tipo(c_grado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3351 (class 2606 OID 70910)
-- Name: grado_nivel_servicio_tipo_c_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY grado_nivel_servicio_tipo
    ADD CONSTRAINT grado_nivel_servicio_tipo_c_nivel_servicio_fkey FOREIGN KEY (c_nivel_servicio) REFERENCES nivel_servicio_tipo(c_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3352 (class 2606 OID 70915)
-- Name: grado_nivel_servicio_tipo_c_organizacion_plan_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY grado_nivel_servicio_tipo
    ADD CONSTRAINT grado_nivel_servicio_tipo_c_organizacion_plan_fkey FOREIGN KEY (c_organizacion_plan) REFERENCES organizacion_plan_tipo(c_organizacion_plan) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3353 (class 2606 OID 70920)
-- Name: localidad_tipo_c_departamento_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY localidad_tipo
    ADD CONSTRAINT localidad_tipo_c_departamento_fkey FOREIGN KEY (c_departamento) REFERENCES departamento_tipo(c_departamento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3354 (class 2606 OID 70925)
-- Name: nacionalidad_tipo_c_pais_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY nacionalidad_tipo
    ADD CONSTRAINT nacionalidad_tipo_c_pais_fkey FOREIGN KEY (c_pais) REFERENCES pais_tipo(c_pais) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3355 (class 2606 OID 70930)
-- Name: nivel_servicio_tipo_c_modalidad1_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY nivel_servicio_tipo
    ADD CONSTRAINT nivel_servicio_tipo_c_modalidad1_fkey FOREIGN KEY (c_modalidad1) REFERENCES modalidad1_tipo(c_modalidad1) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3356 (class 2606 OID 70935)
-- Name: oferta_tipo_c_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY oferta_tipo
    ADD CONSTRAINT oferta_tipo_c_nivel_servicio_fkey FOREIGN KEY (c_nivel_servicio) REFERENCES nivel_servicio_tipo(c_nivel_servicio) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3358 (class 2606 OID 70940)
-- Name: operativo_tipo_c_tipo_operativo_fkey; Type: FK CONSTRAINT; Schema: codigos; Owner: postgres
--

ALTER TABLE ONLY operativo_tipo
    ADD CONSTRAINT operativo_tipo_c_tipo_operativo_fkey FOREIGN KEY (c_tipo_operativo) REFERENCES tipo_operativo_tipo(c_tipo_operativo) ON UPDATE CASCADE ON DELETE CASCADE;


SET search_path = public, pg_catalog;

--
-- TOC entry 3447 (class 2606 OID 70945)
-- Name: actividad_extracurricular_c_area_tematica_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_c_area_tematica_fkey FOREIGN KEY (c_area_tematica) REFERENCES codigos.area_tematica_tipo(c_area_tematica) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3448 (class 2606 OID 70950)
-- Name: actividad_extracurricular_c_carga_horaria_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_c_carga_horaria_en_fkey FOREIGN KEY (c_carga_horaria_en) REFERENCES codigos.carga_horaria_en_tipo(c_carga_horaria_en) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3449 (class 2606 OID 70955)
-- Name: actividad_extracurricular_c_certificado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_c_certificado_fkey FOREIGN KEY (c_certificado) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3450 (class 2606 OID 70960)
-- Name: actividad_extracurricular_c_duracion_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_c_duracion_en_fkey FOREIGN KEY (c_duracion_en) REFERENCES codigos.duracion_en_tipo(c_duracion_en) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3451 (class 2606 OID 70965)
-- Name: actividad_extracurricular_c_requisito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_c_requisito_fkey FOREIGN KEY (c_requisito) REFERENCES codigos.requisito_tipo(c_requisito) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3452 (class 2606 OID 70970)
-- Name: actividad_extracurricular_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY actividad_extracurricular
    ADD CONSTRAINT actividad_extracurricular_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3453 (class 2606 OID 70975)
-- Name: alumno_beneficio_alimentario_c_tipo_beneficio_alimentario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_alimentario
    ADD CONSTRAINT alumno_beneficio_alimentario_c_tipo_beneficio_alimentario_fkey FOREIGN KEY (c_tipo_beneficio_alimentario) REFERENCES codigos.tipo_beneficio_alimentario_tipo(c_tipo_beneficio_alimentario) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3454 (class 2606 OID 70980)
-- Name: alumno_beneficio_alimentario_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_alimentario
    ADD CONSTRAINT alumno_beneficio_alimentario_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3455 (class 2606 OID 70985)
-- Name: alumno_beneficio_plan_c_tipo_beneficio_plan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_plan
    ADD CONSTRAINT alumno_beneficio_plan_c_tipo_beneficio_plan_fkey FOREIGN KEY (c_tipo_beneficio_plan) REFERENCES codigos.tipo_beneficio_plan_tipo(c_tipo_beneficio_plan) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3456 (class 2606 OID 70990)
-- Name: alumno_beneficio_plan_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_beneficio_plan
    ADD CONSTRAINT alumno_beneficio_plan_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3327 (class 2606 OID 70995)
-- Name: alumno_c_beneficio_alimentario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_beneficio_alimentario_fkey FOREIGN KEY (c_beneficio_alimentario) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3328 (class 2606 OID 71000)
-- Name: alumno_c_beneficio_plan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_beneficio_plan_fkey FOREIGN KEY (c_beneficio_plan) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3335 (class 2606 OID 71005)
-- Name: alumno_c_estado_civil_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT alumno_c_estado_civil_fkey FOREIGN KEY (c_estado_civil) REFERENCES codigos.estado_civil_tipo(c_estado_civil) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3329 (class 2606 OID 71010)
-- Name: alumno_c_indigena_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_indigena_fkey FOREIGN KEY (c_indigena) REFERENCES codigos.indigena_tipo(c_indigena) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3336 (class 2606 OID 71015)
-- Name: alumno_c_localidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT alumno_c_localidad_fkey FOREIGN KEY (c_localidad) REFERENCES codigos.localidad_tipo(c_localidad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3337 (class 2606 OID 71020)
-- Name: alumno_c_nacionalidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT alumno_c_nacionalidad_fkey FOREIGN KEY (c_nacionalidad) REFERENCES codigos.nacionalidad_tipo(c_nacionalidad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3330 (class 2606 OID 71025)
-- Name: alumno_c_nivel_alcanzado_madre_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_nivel_alcanzado_madre_fkey FOREIGN KEY (c_nivel_alcanzado_madre) REFERENCES codigos.nivel_alcanzado_tipo(c_nivel_alcanzado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3331 (class 2606 OID 71030)
-- Name: alumno_c_nivel_alcanzado_padre_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_nivel_alcanzado_padre_fkey FOREIGN KEY (c_nivel_alcanzado_padre) REFERENCES codigos.nivel_alcanzado_tipo(c_nivel_alcanzado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3338 (class 2606 OID 71035)
-- Name: alumno_c_sexo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT alumno_c_sexo_fkey FOREIGN KEY (c_sexo) REFERENCES codigos.sexo_tipo(c_sexo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3339 (class 2606 OID 71040)
-- Name: alumno_c_tipo_documento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT alumno_c_tipo_documento_fkey FOREIGN KEY (c_tipo_documento) REFERENCES codigos.tipo_documento_tipo(c_tipo_documento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3332 (class 2606 OID 71045)
-- Name: alumno_c_transporte_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_c_transporte_fkey FOREIGN KEY (c_transporte) REFERENCES codigos.transporte_tipo(c_transporte) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3457 (class 2606 OID 71050)
-- Name: alumno_discapacidad_c_discapacidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_discapacidad
    ADD CONSTRAINT alumno_discapacidad_c_discapacidad_fkey FOREIGN KEY (c_discapacidad) REFERENCES codigos.discapacidad_tipo(c_discapacidad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3458 (class 2606 OID 71055)
-- Name: alumno_discapacidad_c_docente_integrador_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_discapacidad
    ADD CONSTRAINT alumno_discapacidad_c_docente_integrador_fkey FOREIGN KEY (c_docente_integrador) REFERENCES codigos.docente_integrador_tipo(c_docente_integrador) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3459 (class 2606 OID 71060)
-- Name: alumno_discapacidad_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_discapacidad
    ADD CONSTRAINT alumno_discapacidad_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3359 (class 2606 OID 71065)
-- Name: alumno_espacio_curricular_c_condicion_aprobacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT alumno_espacio_curricular_c_condicion_aprobacion_fkey FOREIGN KEY (c_condicion_aprobacion) REFERENCES codigos.condicion_aprobacion_tipo(c_condicion_aprobacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3360 (class 2606 OID 71070)
-- Name: alumno_espacio_curricular_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT alumno_espacio_curricular_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3361 (class 2606 OID 71075)
-- Name: alumno_espacio_curricular_id_espacio_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT alumno_espacio_curricular_id_espacio_curricular_fkey FOREIGN KEY (id_espacio_curricular) REFERENCES espacio_curricular(id_espacio_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3362 (class 2606 OID 71080)
-- Name: alumno_espacio_curricular_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_espacio_curricular
    ADD CONSTRAINT alumno_espacio_curricular_id_institucion_fkey FOREIGN KEY (id_institucion_cursada) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3333 (class 2606 OID 71085)
-- Name: alumno_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES persona(id_persona) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3334 (class 2606 OID 71090)
-- Name: alumno_id_unidad_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno
    ADD CONSTRAINT alumno_id_unidad_servicio_fkey FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3363 (class 2606 OID 71095)
-- Name: alumno_inscripcion_c_ciclo_lectivo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_ciclo_lectivo_fkey FOREIGN KEY (c_ciclo_lectivo) REFERENCES codigos.ciclo_lectivo_tipo(c_ciclo_lectivo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3364 (class 2606 OID 71100)
-- Name: alumno_inscripcion_c_cursa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_cursa_fkey FOREIGN KEY (c_cursa) REFERENCES codigos.cursa_tipo(c_cursa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3365 (class 2606 OID 71105)
-- Name: alumno_inscripcion_c_estado_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_estado_inscripcion_fkey FOREIGN KEY (c_estado_inscripcion) REFERENCES codigos.estado_inscripcion_tipo(c_estado_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3461 (class 2606 OID 71110)
-- Name: alumno_inscripcion_c_estado_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_c_estado_inscripcion_fkey FOREIGN KEY (c_estado_inscripcion) REFERENCES codigos.estado_inscripcion_tipo(c_estado_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3366 (class 2606 OID 71115)
-- Name: alumno_inscripcion_c_fines_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_fines_fkey FOREIGN KEY (c_fines) REFERENCES codigos.fines_tipo(c_fines) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3367 (class 2606 OID 71120)
-- Name: alumno_inscripcion_c_grado_tipo_nivel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_grado_tipo_nivel_fkey FOREIGN KEY (c_grado_nivel_servicio) REFERENCES codigos.grado_nivel_servicio_tipo(c_grado_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3462 (class 2606 OID 71125)
-- Name: alumno_inscripcion_c_grado_tipo_nivel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_c_grado_tipo_nivel_fkey FOREIGN KEY (c_grado_nivel_servicio) REFERENCES codigos.grado_nivel_servicio_tipo(c_grado_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3368 (class 2606 OID 71130)
-- Name: alumno_inscripcion_c_motivo_baja_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_motivo_baja_inscripcion_fkey FOREIGN KEY (c_motivo_baja_inscripcion) REFERENCES codigos.motivo_baja_inscripcion_tipo(c_motivo_baja_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3369 (class 2606 OID 71135)
-- Name: alumno_inscripcion_c_sino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_sino_fkey FOREIGN KEY (c_recursante) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3463 (class 2606 OID 71140)
-- Name: alumno_inscripcion_c_sino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_c_sino_fkey FOREIGN KEY (c_recursante) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3370 (class 2606 OID 71145)
-- Name: alumno_inscripcion_c_tipo_baja_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_c_tipo_baja_inscripcion_fkey FOREIGN KEY (c_tipo_baja_inscripcion) REFERENCES codigos.tipo_baja_inscripcion_tipo(c_tipo_baja_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3375 (class 2606 OID 71150)
-- Name: alumno_inscripcion_esp_curr_id_alumno_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT alumno_inscripcion_esp_curr_id_alumno_inscripcion_fkey FOREIGN KEY (id_alumno_inscripcion) REFERENCES alumno_inscripcion(id_alumno_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3376 (class 2606 OID 71155)
-- Name: alumno_inscripcion_esp_curr_id_espacio_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT alumno_inscripcion_esp_curr_id_espacio_curricular_fkey FOREIGN KEY (id_espacio_curricular) REFERENCES espacio_curricular(id_espacio_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3377 (class 2606 OID 71160)
-- Name: alumno_inscripcion_esp_curr_id_seccion_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT alumno_inscripcion_esp_curr_id_seccion_curricular_fkey FOREIGN KEY (id_seccion_curricular) REFERENCES seccion_curricular(id_seccion_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3378 (class 2606 OID 71165)
-- Name: alumno_inscripcion_espacio_curricular_c_sino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_espacio_curricular
    ADD CONSTRAINT alumno_inscripcion_espacio_curricular_c_sino_fkey FOREIGN KEY (c_recursante) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3379 (class 2606 OID 71170)
-- Name: alumno_inscripcion_extracurricular_id_act_ext_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular
    ADD CONSTRAINT alumno_inscripcion_extracurricular_id_act_ext_fkey FOREIGN KEY (id_actividad_extracurricular) REFERENCES actividad_extracurricular(id_actividad_extracurricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3380 (class 2606 OID 71175)
-- Name: alumno_inscripcion_extracurricular_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular
    ADD CONSTRAINT alumno_inscripcion_extracurricular_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3381 (class 2606 OID 71180)
-- Name: alumno_inscripcion_extracurricular_id_sec_ext_key; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_extracurricular
    ADD CONSTRAINT alumno_inscripcion_extracurricular_id_sec_ext_key FOREIGN KEY (id_seccion_extracurricular) REFERENCES seccion_extracurricular(id_seccion_extracurricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3464 (class 2606 OID 71185)
-- Name: alumno_inscripcion_historico_c_ciclo_lectivo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_historico_c_ciclo_lectivo FOREIGN KEY (c_ciclo_lectivo) REFERENCES codigos.ciclo_lectivo_tipo(c_ciclo_lectivo);


--
-- TOC entry 3465 (class 2606 OID 71190)
-- Name: alumno_inscripcion_historico_id_alumno_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion_historico
    ADD CONSTRAINT alumno_inscripcion_historico_id_alumno_inscripcion_fkey FOREIGN KEY (id_alumno_inscripcion) REFERENCES alumno_inscripcion(id_alumno_inscripcion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3371 (class 2606 OID 71195)
-- Name: alumno_inscripcion_id_alumno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_id_alumno_fkey FOREIGN KEY (id_alumno) REFERENCES alumno(id_alumno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3372 (class 2606 OID 71200)
-- Name: alumno_inscripcion_id_institucion_destino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_id_institucion_destino_fkey FOREIGN KEY (id_institucion_destino) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3373 (class 2606 OID 71205)
-- Name: alumno_inscripcion_id_seccion_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_id_seccion_curricular_fkey FOREIGN KEY (id_seccion_curricular) REFERENCES seccion_curricular(id_seccion_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3374 (class 2606 OID 71210)
-- Name: alumno_inscripcion_id_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alumno_inscripcion
    ADD CONSTRAINT alumno_inscripcion_id_titulacion_fkey FOREIGN KEY (id_titulacion) REFERENCES titulacion(id_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3466 (class 2606 OID 71215)
-- Name: autoridad_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY autoridad
    ADD CONSTRAINT autoridad_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3467 (class 2606 OID 71220)
-- Name: autoridad_id_nombre_cargo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY autoridad
    ADD CONSTRAINT autoridad_id_nombre_cargo_fkey FOREIGN KEY (id_nombre_cargo) REFERENCES nombre_cargo(id_nombre_cargo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3468 (class 2606 OID 71225)
-- Name: autoridad_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY autoridad
    ADD CONSTRAINT autoridad_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES persona(id_persona) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3469 (class 2606 OID 71230)
-- Name: consistencia_c_tipo_consistencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY consistencia
    ADD CONSTRAINT consistencia_c_tipo_consistencia_fkey FOREIGN KEY (c_tipo_consistencia) REFERENCES codigos.tipo_consistencia_tipo(c_tipo_consistencia) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3470 (class 2606 OID 71235)
-- Name: datos_institucion_c_biblioteca_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_biblioteca_fkey FOREIGN KEY (c_biblioteca) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3471 (class 2606 OID 71240)
-- Name: datos_institucion_c_conexion_internet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_conexion_internet_fkey FOREIGN KEY (c_conexion_internet) REFERENCES codigos.conexion_internet_tipo(c_conexion_internet) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3472 (class 2606 OID 71245)
-- Name: datos_institucion_c_contenidos_digitales_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_contenidos_digitales_fkey FOREIGN KEY (c_contenidos_digitales) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3473 (class 2606 OID 71250)
-- Name: datos_institucion_c_energia_electrica_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_energia_electrica_fkey FOREIGN KEY (c_energia_electrica) REFERENCES codigos.energia_electrica_tipo(c_energia_electrica) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3474 (class 2606 OID 71255)
-- Name: datos_institucion_c_ensenanza_internet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_ensenanza_internet_fkey FOREIGN KEY (c_ensenanza_internet) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3475 (class 2606 OID 71260)
-- Name: datos_institucion_c_espacio_biblioteca_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_espacio_biblioteca_fkey FOREIGN KEY (c_espacio_biblioteca) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3476 (class 2606 OID 71265)
-- Name: datos_institucion_c_espacio_virtual_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_espacio_virtual_fkey FOREIGN KEY (c_espacio_virtual) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3477 (class 2606 OID 71270)
-- Name: datos_institucion_c_internet_area_gestion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_internet_area_gestion_fkey FOREIGN KEY (c_internet_area_gestion) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3478 (class 2606 OID 71275)
-- Name: datos_institucion_c_internet_aulas_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_internet_aulas_fkey FOREIGN KEY (c_internet_aulas) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3479 (class 2606 OID 71280)
-- Name: datos_institucion_c_internet_biblioteca_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_internet_biblioteca_fkey FOREIGN KEY (c_internet_biblioteca) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3480 (class 2606 OID 71285)
-- Name: datos_institucion_c_internet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_internet_fkey FOREIGN KEY (c_internet) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3481 (class 2606 OID 71290)
-- Name: datos_institucion_c_internet_otro_espacio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_internet_otro_espacio_fkey FOREIGN KEY (c_internet_otro_espacio) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3482 (class 2606 OID 71295)
-- Name: datos_institucion_c_laboratorio_informatica_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_laboratorio_informatica_fkey FOREIGN KEY (c_laboratorio_informatica) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3483 (class 2606 OID 71300)
-- Name: datos_institucion_c_lugar_funcionamiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_lugar_funcionamiento_fkey FOREIGN KEY (c_lugar_funcionamiento) REFERENCES codigos.lugar_funcionamiento_tipo(c_lugar_funcionamiento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3484 (class 2606 OID 71305)
-- Name: datos_institucion_c_mantenimiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_mantenimiento_fkey FOREIGN KEY (c_mantenimiento) REFERENCES codigos.mantenimiento_tipo(c_mantenimiento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3485 (class 2606 OID 71310)
-- Name: datos_institucion_c_red_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_red_fkey FOREIGN KEY (c_red) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3486 (class 2606 OID 71315)
-- Name: datos_institucion_c_restriccion_internet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_restriccion_internet_fkey FOREIGN KEY (c_restriccion_internet) REFERENCES codigos.restriccion_internet_tipo(c_restriccion_internet) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3487 (class 2606 OID 71320)
-- Name: datos_institucion_c_servicio_internet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_servicio_internet_fkey FOREIGN KEY (c_servicio_internet) REFERENCES codigos.servicio_internet_tipo(c_servicio_internet) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3488 (class 2606 OID 71325)
-- Name: datos_institucion_c_sistema_gestion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_sistema_gestion_fkey FOREIGN KEY (c_sistema_gestion) REFERENCES codigos.sistema_gestion_tipo(c_sistema_gestion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3489 (class 2606 OID 71330)
-- Name: datos_institucion_c_tiene_computadora_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_c_tiene_computadora_fkey FOREIGN KEY (c_tiene_computadora) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3490 (class 2606 OID 71335)
-- Name: datos_institucion_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_institucion
    ADD CONSTRAINT datos_institucion_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3491 (class 2606 OID 71340)
-- Name: datos_unidad_servicio_id_unidad_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY datos_unidad_servicio
    ADD CONSTRAINT datos_unidad_servicio_id_unidad_servicio_fkey FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3387 (class 2606 OID 71345)
-- Name: espacio_curricular_c_carga_horaria_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_carga_horaria_en_fkey FOREIGN KEY (c_carga_horaria_en) REFERENCES codigos.carga_horaria_en_tipo(c_carga_horaria_en) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3388 (class 2606 OID 71350)
-- Name: espacio_curricular_c_dicta_cuatrimestre_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_dicta_cuatrimestre_fkey FOREIGN KEY (c_dicta_cuatrimestre) REFERENCES codigos.dicta_cuatrimestre_tipo(c_dicta_cuatrimestre);


--
-- TOC entry 3389 (class 2606 OID 71355)
-- Name: espacio_curricular_c_dictado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_dictado_fkey FOREIGN KEY (c_dictado) REFERENCES codigos.dictado_tipo(c_dictado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3390 (class 2606 OID 71360)
-- Name: espacio_curricular_c_escala_numerica_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_escala_numerica_fkey FOREIGN KEY (c_escala_numerica) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3391 (class 2606 OID 71365)
-- Name: espacio_curricular_c_espacio_curricular_duracion_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_espacio_curricular_duracion_en_fkey FOREIGN KEY (c_espacio_curricular_duracion_en) REFERENCES codigos.espacio_curricular_duracion_en_tipo(c_espacio_curricular_duracion_en);


--
-- TOC entry 3392 (class 2606 OID 71370)
-- Name: espacio_curricular_c_formato_espacio_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_formato_espacio_curricular_fkey FOREIGN KEY (c_formato_espacio_curricular) REFERENCES codigos.formato_espacio_curricular_tipo(c_formato_espacio_curricular);


--
-- TOC entry 3393 (class 2606 OID 71375)
-- Name: espacio_curricular_c_grado_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_grado_nivel_servicio_fkey FOREIGN KEY (c_grado_nivel_servicio) REFERENCES codigos.grado_nivel_servicio_tipo(c_grado_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3394 (class 2606 OID 71380)
-- Name: espacio_curricular_c_materia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_materia_fkey FOREIGN KEY (id_nombre_espacio_curricular) REFERENCES nombre_espacio_curricular(id_nombre_espacio_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3395 (class 2606 OID 71385)
-- Name: espacio_curricular_c_obligatoriedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_obligatoriedad_fkey FOREIGN KEY (c_obligatoriedad) REFERENCES codigos.obligatoriedad_tipo(c_obligatoriedad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3396 (class 2606 OID 71390)
-- Name: espacio_curricular_c_promocionable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_promocionable_fkey FOREIGN KEY (c_promocionable) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3397 (class 2606 OID 71395)
-- Name: espacio_curricular_c_trayecto_formativo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_c_trayecto_formativo_fkey FOREIGN KEY (c_trayecto_formativo) REFERENCES codigos.trayecto_formativo_tipo(c_trayecto_formativo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3398 (class 2606 OID 71400)
-- Name: espacio_curricular_id_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY espacio_curricular
    ADD CONSTRAINT espacio_curricular_id_titulacion_fkey FOREIGN KEY (id_titulacion) REFERENCES titulacion(id_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3520 (class 2606 OID 71405)
-- Name: estado_verificacion_tipo_verificacion_carga; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY verificacion_carga
    ADD CONSTRAINT estado_verificacion_tipo_verificacion_carga FOREIGN KEY (c_estado_verificacion) REFERENCES codigos.estado_verificacion_tipo(c_estado_verificacion);


--
-- TOC entry 3497 (class 2606 OID 71410)
-- Name: hoja_papel_moneda_analitico_id_hoja_papel_moneda_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda_analitico
    ADD CONSTRAINT hoja_papel_moneda_analitico_id_hoja_papel_moneda_fkey FOREIGN KEY (id_hoja_papel_moneda) REFERENCES hoja_papel_moneda(id_hoja_papel_moneda) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3493 (class 2606 OID 71415)
-- Name: hoja_papel_moneda_c_estado_hoja_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT hoja_papel_moneda_c_estado_hoja_fkey FOREIGN KEY (c_estado_hoja) REFERENCES codigos.estado_hoja_tipo(c_estado_hoja) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3494 (class 2606 OID 71420)
-- Name: hoja_papel_moneda_c_tipo_copia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT hoja_papel_moneda_c_tipo_copia_fkey FOREIGN KEY (c_tipo_copia) REFERENCES codigos.tipo_copia_tipo(c_tipo_copia) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3495 (class 2606 OID 71425)
-- Name: hoja_papel_moneda_id_alumno_inscripcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT hoja_papel_moneda_id_alumno_inscripcion_fkey FOREIGN KEY (id_alumno_inscripcion) REFERENCES alumno_inscripcion(id_alumno_inscripcion) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3496 (class 2606 OID 71430)
-- Name: hoja_papel_moneda_id_lote_papel_moneda_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hoja_papel_moneda
    ADD CONSTRAINT hoja_papel_moneda_id_lote_papel_moneda_fkey FOREIGN KEY (id_lote_papel_moneda) REFERENCES lote_papel_moneda(id_lote_papel_moneda) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3430 (class 2606 OID 71435)
-- Name: institucion_c_alternancia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_alternancia_fkey FOREIGN KEY (c_alternancia) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3431 (class 2606 OID 71440)
-- Name: institucion_c_ambito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_ambito_fkey FOREIGN KEY (c_ambito) REFERENCES codigos.ambito_tipo(c_ambito) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3432 (class 2606 OID 71445)
-- Name: institucion_c_arancelado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_arancelado_fkey FOREIGN KEY (c_arancelado) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3433 (class 2606 OID 71450)
-- Name: institucion_c_categoria_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_categoria_fkey FOREIGN KEY (c_categoria) REFERENCES codigos.categoria_tipo(c_categoria) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3434 (class 2606 OID 71455)
-- Name: institucion_c_confesional_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_confesional_fkey FOREIGN KEY (c_confesional) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3435 (class 2606 OID 71460)
-- Name: institucion_c_cooperadora_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_cooperadora_fkey FOREIGN KEY (c_cooperadora) REFERENCES codigos.cooperadora_tipo(c_cooperadora) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3436 (class 2606 OID 71465)
-- Name: institucion_c_dependencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_dependencia_fkey FOREIGN KEY (c_dependencia) REFERENCES codigos.dependencia_tipo(c_dependencia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3437 (class 2606 OID 71470)
-- Name: institucion_c_estado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_estado_fkey FOREIGN KEY (c_estado) REFERENCES codigos.estado_tipo(c_estado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3438 (class 2606 OID 71475)
-- Name: institucion_c_localidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_localidad_fkey FOREIGN KEY (c_localidad) REFERENCES codigos.localidad_tipo(c_localidad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3439 (class 2606 OID 71480)
-- Name: institucion_c_per_funcionamiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_per_funcionamiento_fkey FOREIGN KEY (c_per_funcionamiento) REFERENCES codigos.per_funcionamiento_tipo(c_per_funcionamiento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3440 (class 2606 OID 71485)
-- Name: institucion_c_provincia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_provincia_fkey FOREIGN KEY (c_provincia) REFERENCES codigos.provincia_tipo(c_provincia) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3441 (class 2606 OID 71490)
-- Name: institucion_c_sector_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_c_sector_fkey FOREIGN KEY (c_sector) REFERENCES codigos.sector_tipo(c_sector) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3498 (class 2606 OID 71495)
-- Name: institucion_equipamiento_c_biblioteca_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT institucion_equipamiento_c_biblioteca_fkey FOREIGN KEY (c_biblioteca) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3499 (class 2606 OID 71500)
-- Name: institucion_equipamiento_c_equipamiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT institucion_equipamiento_c_equipamiento_fkey FOREIGN KEY (c_equipamiento) REFERENCES codigos.equipamiento_tipo(c_equipamiento) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3500 (class 2606 OID 71505)
-- Name: institucion_equipamiento_c_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT institucion_equipamiento_c_institucion_fkey FOREIGN KEY (c_institucion) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3501 (class 2606 OID 71510)
-- Name: institucion_equipamiento_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_equipamiento
    ADD CONSTRAINT institucion_equipamiento_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3442 (class 2606 OID 71515)
-- Name: institucion_id_establecimiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion
    ADD CONSTRAINT institucion_id_establecimiento_fkey FOREIGN KEY (id_establecimiento) REFERENCES establecimiento(id_establecimiento) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3502 (class 2606 OID 71520)
-- Name: institucion_software_c_software_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_software
    ADD CONSTRAINT institucion_software_c_software_fkey FOREIGN KEY (c_software) REFERENCES codigos.software_tipo(c_software) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3503 (class 2606 OID 71525)
-- Name: institucion_software_c_tiene_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_software
    ADD CONSTRAINT institucion_software_c_tiene_fkey FOREIGN KEY (c_tiene) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3504 (class 2606 OID 71530)
-- Name: institucion_software_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY institucion_software
    ADD CONSTRAINT institucion_software_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3505 (class 2606 OID 71535)
-- Name: lote_papel_moneda_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lote_papel_moneda
    ADD CONSTRAINT lote_papel_moneda_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3492 (class 2606 OID 71540)
-- Name: nombre_espacio_curricular_c_campo_formacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_espacio_curricular
    ADD CONSTRAINT nombre_espacio_curricular_c_campo_formacion_fkey FOREIGN KEY (c_campo_formacion) REFERENCES codigos.campo_formacion_tipo(c_campo_formacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3460 (class 2606 OID 71545)
-- Name: nombre_titulacion_c_carrera_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_titulacion
    ADD CONSTRAINT nombre_titulacion_c_carrera_fkey FOREIGN KEY (c_carrera) REFERENCES codigos.carrera_tipo(c_carrera) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3506 (class 2606 OID 71550)
-- Name: nombre_titulacion_nivel_servicio_c_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_titulacion_nivel_servicio_tipo_assn
    ADD CONSTRAINT nombre_titulacion_nivel_servicio_c_nivel_servicio_fkey FOREIGN KEY (c_nivel_servicio) REFERENCES codigos.nivel_servicio_tipo(c_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3507 (class 2606 OID 71555)
-- Name: nombre_titulacion_nivel_servicio_id_nombre_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY nombre_titulacion_nivel_servicio_tipo_assn
    ADD CONSTRAINT nombre_titulacion_nivel_servicio_id_nombre_titulacion_fkey FOREIGN KEY (id_nombre_titulacion) REFERENCES nombre_titulacion(id_nombre_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3508 (class 2606 OID 71560)
-- Name: oferta_local_id_unidad_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY oferta_local
    ADD CONSTRAINT oferta_local_id_unidad_servicio_fkey FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3521 (class 2606 OID 71565)
-- Name: operativo_tipo_verificacion_carga; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY verificacion_carga
    ADD CONSTRAINT operativo_tipo_verificacion_carga FOREIGN KEY (c_operativo) REFERENCES codigos.operativo_tipo(c_operativo);


--
-- TOC entry 3340 (class 2606 OID 71570)
-- Name: persona_c_localidad_nacimiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT persona_c_localidad_nacimiento_fkey FOREIGN KEY (c_localidad_nacimiento) REFERENCES codigos.localidad_tipo(c_localidad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3341 (class 2606 OID 71575)
-- Name: persona_c_pais_domicilio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT persona_c_pais_domicilio_fkey FOREIGN KEY (c_pais_domicilio) REFERENCES codigos.pais_tipo(c_pais) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3342 (class 2606 OID 71580)
-- Name: persona_c_pais_nacimiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT persona_c_pais_nacimiento_fkey FOREIGN KEY (c_pais_nacimiento) REFERENCES codigos.pais_tipo(c_pais) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3343 (class 2606 OID 71585)
-- Name: persona_c_provincia_nacimiento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY persona
    ADD CONSTRAINT persona_c_provincia_nacimiento_fkey FOREIGN KEY (c_provincia_nacimiento) REFERENCES codigos.provincia_tipo(c_provincia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3443 (class 2606 OID 71590)
-- Name: seccion_c_organizacion_cursada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion
    ADD CONSTRAINT seccion_c_organizacion_cursada_fkey FOREIGN KEY (c_organizacion_cursada) REFERENCES codigos.organizacion_cursada_tipo(c_organizacion_cursada) ON UPDATE CASCADE;


--
-- TOC entry 3444 (class 2606 OID 71595)
-- Name: seccion_c_tipo_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion
    ADD CONSTRAINT seccion_c_tipo_seccion_fkey FOREIGN KEY (c_tipo_seccion) REFERENCES codigos.tipo_seccion_tipo(c_tipo_seccion) ON UPDATE CASCADE;


--
-- TOC entry 3382 (class 2606 OID 71600)
-- Name: seccion_curricular_c_grado_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_c_grado_nivel_servicio_fkey FOREIGN KEY (c_grado_nivel_servicio) REFERENCES codigos.grado_nivel_servicio_tipo(c_grado_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3383 (class 2606 OID 71605)
-- Name: seccion_curricular_c_trayecto_formativo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_c_trayecto_formativo_fkey FOREIGN KEY (c_trayecto_formativo) REFERENCES codigos.trayecto_formativo_tipo(c_trayecto_formativo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3384 (class 2606 OID 71610)
-- Name: seccion_curricular_c_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_c_turno_fkey FOREIGN KEY (c_turno) REFERENCES codigos.turno_tipo(c_turno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3509 (class 2606 OID 71615)
-- Name: seccion_curricular_espacio_curricular_id_espacio_curr_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular_espacio_curricular
    ADD CONSTRAINT seccion_curricular_espacio_curricular_id_espacio_curr_fkey FOREIGN KEY (id_espacio_curricular) REFERENCES espacio_curricular(id_espacio_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3510 (class 2606 OID 71620)
-- Name: seccion_curricular_espacio_curricular_id_seccion_curr_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular_espacio_curricular
    ADD CONSTRAINT seccion_curricular_espacio_curricular_id_seccion_curr_fkey FOREIGN KEY (id_seccion_curricular) REFERENCES seccion_curricular(id_seccion_curricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3385 (class 2606 OID 71625)
-- Name: seccion_curricular_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES seccion(id_seccion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3386 (class 2606 OID 71630)
-- Name: seccion_curricular_id_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_curricular
    ADD CONSTRAINT seccion_curricular_id_titulacion_fkey FOREIGN KEY (id_titulacion) REFERENCES titulacion(id_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3511 (class 2606 OID 71635)
-- Name: seccion_extracurricular_c_acepta_comunidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_c_acepta_comunidad_fkey FOREIGN KEY (c_acepta_comunidad) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3512 (class 2606 OID 71640)
-- Name: seccion_extracurricular_c_acepta_ot_inst_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_c_acepta_ot_inst_fkey FOREIGN KEY (c_acepta_ot_inst) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3513 (class 2606 OID 71645)
-- Name: seccion_extracurricular_c_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_c_turno_fkey FOREIGN KEY (c_turno) REFERENCES codigos.turno_tipo(c_turno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3514 (class 2606 OID 71650)
-- Name: seccion_extracurricular_id_actividad_extracurricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_id_actividad_extracurricular_fkey FOREIGN KEY (id_actividad_extracurricular) REFERENCES actividad_extracurricular(id_actividad_extracurricular) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3515 (class 2606 OID 71655)
-- Name: seccion_extracurricular_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion_extracurricular
    ADD CONSTRAINT seccion_extracurricular_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES seccion(id_seccion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3445 (class 2606 OID 71660)
-- Name: seccion_id_espacio_curricular_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion
    ADD CONSTRAINT seccion_id_espacio_curricular_fkey FOREIGN KEY (id_espacio_curricular) REFERENCES espacio_curricular(id_espacio_curricular) ON UPDATE CASCADE;


--
-- TOC entry 3446 (class 2606 OID 71665)
-- Name: seccion_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seccion
    ADD CONSTRAINT seccion_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE;


--
-- TOC entry 3399 (class 2606 OID 71670)
-- Name: titulacion_c_a_termino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_a_termino_fkey FOREIGN KEY (c_a_termino) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3400 (class 2606 OID 71675)
-- Name: titulacion_c_articulacion_tit_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_articulacion_tit_fkey FOREIGN KEY (c_articulacion_tit) REFERENCES codigos.articulacion_tit_tipo(c_articulacion_tit) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3401 (class 2606 OID 71680)
-- Name: titulacion_c_articulacion_univ_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_articulacion_univ_fkey FOREIGN KEY (c_articulacion_univ) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3402 (class 2606 OID 71685)
-- Name: titulacion_c_carga_horaria_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_carga_horaria_en_fkey FOREIGN KEY (c_carga_horaria_en) REFERENCES codigos.carga_horaria_en_tipo(c_carga_horaria_en) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3403 (class 2606 OID 71690)
-- Name: titulacion_c_certificacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_certificacion_fkey FOREIGN KEY (c_certificacion) REFERENCES codigos.certificacion_tipo(c_certificacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3404 (class 2606 OID 71695)
-- Name: titulacion_c_condicion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_condicion_fkey FOREIGN KEY (c_condicion) REFERENCES codigos.condicion_tipo(c_condicion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3405 (class 2606 OID 71700)
-- Name: titulacion_c_dicta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_dicta_fkey FOREIGN KEY (c_dicta) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3406 (class 2606 OID 71705)
-- Name: titulacion_c_dictado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_dictado_fkey FOREIGN KEY (c_dictado) REFERENCES codigos.dictado_tipo(c_dictado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3407 (class 2606 OID 71710)
-- Name: titulacion_c_duracion_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_duracion_en_fkey FOREIGN KEY (c_duracion_en) REFERENCES codigos.duracion_en_tipo(c_duracion_en) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3408 (class 2606 OID 71715)
-- Name: titulacion_c_inscripto_inet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_inscripto_inet_fkey FOREIGN KEY (c_inscripto_inet) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3409 (class 2606 OID 71720)
-- Name: titulacion_c_organizacion_cursada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_organizacion_cursada_fkey FOREIGN KEY (c_organizacion_cursada) REFERENCES codigos.organizacion_cursada_tipo(c_organizacion_cursada) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3410 (class 2606 OID 71725)
-- Name: titulacion_c_organizacion_plan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_organizacion_plan_fkey FOREIGN KEY (c_organizacion_plan) REFERENCES codigos.organizacion_plan_tipo(c_organizacion_plan) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3411 (class 2606 OID 71730)
-- Name: titulacion_c_orientacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_orientacion_fkey FOREIGN KEY (c_orientacion) REFERENCES codigos.orientacion_tipo(c_orientacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3412 (class 2606 OID 71735)
-- Name: titulacion_c_tiene_tit_int_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_tiene_tit_int_fkey FOREIGN KEY (c_tiene_tit_int) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3413 (class 2606 OID 71740)
-- Name: titulacion_c_tipo_formacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_tipo_formacion_fkey FOREIGN KEY (c_tipo_formacion) REFERENCES codigos.tipo_formacion_tipo(c_tipo_formacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3414 (class 2606 OID 71745)
-- Name: titulacion_c_tipo_titulo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_c_tipo_titulo_fkey FOREIGN KEY (c_tipo_titulo) REFERENCES codigos.tipo_titulo_tipo(c_tipo_titulo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3415 (class 2606 OID 71750)
-- Name: titulacion_id_nombre_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_id_nombre_titulacion_fkey FOREIGN KEY (id_nombre_titulacion) REFERENCES nombre_titulacion(id_nombre_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3416 (class 2606 OID 71755)
-- Name: titulacion_id_titulacion_ciclo_basico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_id_titulacion_ciclo_basico_fkey FOREIGN KEY (id_titulacion_ciclo_basico) REFERENCES titulacion(id_titulacion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3417 (class 2606 OID 71760)
-- Name: titulacion_id_titulacion_normativa_vigente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_id_titulacion_normativa_vigente_fkey FOREIGN KEY (id_titulacion_normativa_vigente) REFERENCES titulacion_normativa(id_titulacion_normativa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3418 (class 2606 OID 71765)
-- Name: titulacion_id_unidad_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion
    ADD CONSTRAINT titulacion_id_unidad_servicio_fkey FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3516 (class 2606 OID 71770)
-- Name: titulacion_normativa_c_normativa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT titulacion_normativa_c_normativa_fkey FOREIGN KEY (c_normativa) REFERENCES codigos.normativa_tipo(c_normativa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3517 (class 2606 OID 71775)
-- Name: titulacion_normativa_c_provincia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT titulacion_normativa_c_provincia_fkey FOREIGN KEY (c_provincia) REFERENCES codigos.provincia_tipo(c_provincia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3518 (class 2606 OID 71780)
-- Name: titulacion_normativa_c_tipo_norma_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT titulacion_normativa_c_tipo_norma_fkey FOREIGN KEY (c_tipo_norma) REFERENCES codigos.tipo_norma_tipo(c_tipo_norma) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3519 (class 2606 OID 71785)
-- Name: titulacion_normativa_id_titulacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY titulacion_normativa
    ADD CONSTRAINT titulacion_normativa_id_titulacion_fkey FOREIGN KEY (id_titulacion) REFERENCES titulacion(id_titulacion);


--
-- TOC entry 3419 (class 2606 OID 71790)
-- Name: unidad_servicio_c_alternancia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_alternancia_fkey FOREIGN KEY (c_alternancia) REFERENCES codigos.sino_tipo(c_sino) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3420 (class 2606 OID 71795)
-- Name: unidad_servicio_c_ciclo_lectivo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_ciclo_lectivo_fkey FOREIGN KEY (c_ciclo_lectivo) REFERENCES codigos.ciclo_lectivo_tipo(c_ciclo_lectivo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- TOC entry 3421 (class 2606 OID 71800)
-- Name: unidad_servicio_c_cooperadora_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_cooperadora_fkey FOREIGN KEY (c_cooperadora) REFERENCES codigos.cooperadora_tipo(c_cooperadora) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3422 (class 2606 OID 71805)
-- Name: unidad_servicio_c_estado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_estado_fkey FOREIGN KEY (c_estado) REFERENCES codigos.estado_tipo(c_estado) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3423 (class 2606 OID 71810)
-- Name: unidad_servicio_c_jornada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_jornada_fkey FOREIGN KEY (c_jornada) REFERENCES codigos.jornada_tipo(c_jornada) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3424 (class 2606 OID 71815)
-- Name: unidad_servicio_c_nivel_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_nivel_servicio_fkey FOREIGN KEY (c_nivel_servicio) REFERENCES codigos.nivel_servicio_tipo(c_nivel_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3425 (class 2606 OID 71820)
-- Name: unidad_servicio_c_subvencion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_c_subvencion_fkey FOREIGN KEY (c_subvencion) REFERENCES codigos.subvencion_tipo(c_subvencion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3426 (class 2606 OID 71825)
-- Name: unidad_servicio_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio
    ADD CONSTRAINT unidad_servicio_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES institucion(id_institucion) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3427 (class 2606 OID 71830)
-- Name: unidad_servicio_operativo_c_estado_operativo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio_operativo
    ADD CONSTRAINT unidad_servicio_operativo_c_estado_operativo_fkey FOREIGN KEY (c_estado_operativo) REFERENCES codigos.estado_operativo_tipo(c_estado_operativo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3428 (class 2606 OID 71835)
-- Name: unidad_servicio_operativo_c_operativo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio_operativo
    ADD CONSTRAINT unidad_servicio_operativo_c_operativo_fkey FOREIGN KEY (c_operativo) REFERENCES codigos.operativo_tipo(c_operativo) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3429 (class 2606 OID 71840)
-- Name: unidad_servicio_operativo_id_unidad_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY unidad_servicio_operativo
    ADD CONSTRAINT unidad_servicio_operativo_id_unidad_servicio_fkey FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3522 (class 2606 OID 71845)
-- Name: unidad_servicio_verificacion_carga; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY verificacion_carga
    ADD CONSTRAINT unidad_servicio_verificacion_carga FOREIGN KEY (id_unidad_servicio) REFERENCES unidad_servicio(id_unidad_servicio);


--
-- TOC entry 3693 (class 0 OID 0)
-- Dependencies: 9
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 3696 (class 0 OID 0)
-- Dependencies: 178
-- Name: alumno; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno FROM PUBLIC;
REVOKE ALL ON TABLE alumno FROM postgres;
GRANT ALL ON TABLE alumno TO postgres;


--
-- TOC entry 3697 (class 0 OID 0)
-- Dependencies: 482
-- Name: dblink_connect_u(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION dblink_connect_u(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION dblink_connect_u(text) FROM postgres;
GRANT ALL ON FUNCTION dblink_connect_u(text) TO postgres;


--
-- TOC entry 3698 (class 0 OID 0)
-- Dependencies: 483
-- Name: dblink_connect_u(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION dblink_connect_u(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION dblink_connect_u(text, text) FROM postgres;
GRANT ALL ON FUNCTION dblink_connect_u(text, text) TO postgres;


--
-- TOC entry 3699 (class 0 OID 0)
-- Dependencies: 179
-- Name: persona; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE persona FROM PUBLIC;
REVOKE ALL ON TABLE persona FROM postgres;
GRANT ALL ON TABLE persona TO postgres;


SET search_path = codigos, pg_catalog;

--
-- TOC entry 3700 (class 0 OID 0)
-- Dependencies: 180
-- Name: ambito_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE ambito_tipo FROM PUBLIC;
REVOKE ALL ON TABLE ambito_tipo FROM postgres;
GRANT ALL ON TABLE ambito_tipo TO postgres;


--
-- TOC entry 3701 (class 0 OID 0)
-- Dependencies: 181
-- Name: anio_corrido_edad_teorica_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE anio_corrido_edad_teorica_tipo FROM PUBLIC;
REVOKE ALL ON TABLE anio_corrido_edad_teorica_tipo FROM postgres;
GRANT ALL ON TABLE anio_corrido_edad_teorica_tipo TO postgres;


--
-- TOC entry 3702 (class 0 OID 0)
-- Dependencies: 182
-- Name: area_pedagogica_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE area_pedagogica_tipo FROM PUBLIC;
REVOKE ALL ON TABLE area_pedagogica_tipo FROM postgres;
GRANT ALL ON TABLE area_pedagogica_tipo TO postgres;


--
-- TOC entry 3703 (class 0 OID 0)
-- Dependencies: 183
-- Name: area_tematica_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE area_tematica_tipo FROM PUBLIC;
REVOKE ALL ON TABLE area_tematica_tipo FROM postgres;
GRANT ALL ON TABLE area_tematica_tipo TO postgres;


--
-- TOC entry 3704 (class 0 OID 0)
-- Dependencies: 184
-- Name: articulacion_tit_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE articulacion_tit_tipo FROM PUBLIC;
REVOKE ALL ON TABLE articulacion_tit_tipo FROM postgres;
GRANT ALL ON TABLE articulacion_tit_tipo TO postgres;


--
-- TOC entry 3705 (class 0 OID 0)
-- Dependencies: 185
-- Name: campo_formacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE campo_formacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE campo_formacion_tipo FROM postgres;
GRANT ALL ON TABLE campo_formacion_tipo TO postgres;


--
-- TOC entry 3706 (class 0 OID 0)
-- Dependencies: 186
-- Name: carga_horaria_en_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE carga_horaria_en_tipo FROM PUBLIC;
REVOKE ALL ON TABLE carga_horaria_en_tipo FROM postgres;
GRANT ALL ON TABLE carga_horaria_en_tipo TO postgres;


--
-- TOC entry 3707 (class 0 OID 0)
-- Dependencies: 187
-- Name: carrera_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE carrera_tipo FROM PUBLIC;
REVOKE ALL ON TABLE carrera_tipo FROM postgres;
GRANT ALL ON TABLE carrera_tipo TO postgres;


--
-- TOC entry 3708 (class 0 OID 0)
-- Dependencies: 188
-- Name: categoria_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE categoria_tipo FROM PUBLIC;
REVOKE ALL ON TABLE categoria_tipo FROM postgres;
GRANT ALL ON TABLE categoria_tipo TO postgres;


--
-- TOC entry 3709 (class 0 OID 0)
-- Dependencies: 189
-- Name: certificacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE certificacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE certificacion_tipo FROM postgres;
GRANT ALL ON TABLE certificacion_tipo TO postgres;


--
-- TOC entry 3710 (class 0 OID 0)
-- Dependencies: 190
-- Name: ciclo_lectivo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE ciclo_lectivo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE ciclo_lectivo_tipo FROM postgres;
GRANT ALL ON TABLE ciclo_lectivo_tipo TO postgres;


--
-- TOC entry 3711 (class 0 OID 0)
-- Dependencies: 191
-- Name: condicion_aprobacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE condicion_aprobacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE condicion_aprobacion_tipo FROM postgres;
GRANT ALL ON TABLE condicion_aprobacion_tipo TO postgres;


--
-- TOC entry 3712 (class 0 OID 0)
-- Dependencies: 192
-- Name: condicion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE condicion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE condicion_tipo FROM postgres;
GRANT ALL ON TABLE condicion_tipo TO postgres;


--
-- TOC entry 3713 (class 0 OID 0)
-- Dependencies: 193
-- Name: conexion_internet_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE conexion_internet_tipo FROM PUBLIC;
REVOKE ALL ON TABLE conexion_internet_tipo FROM postgres;
GRANT ALL ON TABLE conexion_internet_tipo TO postgres;


--
-- TOC entry 3714 (class 0 OID 0)
-- Dependencies: 194
-- Name: cooperadora_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE cooperadora_tipo FROM PUBLIC;
REVOKE ALL ON TABLE cooperadora_tipo FROM postgres;
GRANT ALL ON TABLE cooperadora_tipo TO postgres;


--
-- TOC entry 3715 (class 0 OID 0)
-- Dependencies: 195
-- Name: cursa_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE cursa_tipo FROM PUBLIC;
REVOKE ALL ON TABLE cursa_tipo FROM postgres;
GRANT ALL ON TABLE cursa_tipo TO postgres;


--
-- TOC entry 3717 (class 0 OID 0)
-- Dependencies: 197
-- Name: departamento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE departamento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE departamento_tipo FROM postgres;
GRANT ALL ON TABLE departamento_tipo TO postgres;


--
-- TOC entry 3718 (class 0 OID 0)
-- Dependencies: 198
-- Name: dependencia_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE dependencia_tipo FROM PUBLIC;
REVOKE ALL ON TABLE dependencia_tipo FROM postgres;
GRANT ALL ON TABLE dependencia_tipo TO postgres;


--
-- TOC entry 3719 (class 0 OID 0)
-- Dependencies: 199
-- Name: dicta_cuatrimestre_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE dicta_cuatrimestre_tipo FROM PUBLIC;
REVOKE ALL ON TABLE dicta_cuatrimestre_tipo FROM postgres;
GRANT ALL ON TABLE dicta_cuatrimestre_tipo TO postgres;


--
-- TOC entry 3720 (class 0 OID 0)
-- Dependencies: 200
-- Name: dictado_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE dictado_tipo FROM PUBLIC;
REVOKE ALL ON TABLE dictado_tipo FROM postgres;
GRANT ALL ON TABLE dictado_tipo TO postgres;


--
-- TOC entry 3721 (class 0 OID 0)
-- Dependencies: 201
-- Name: discapacidad_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE discapacidad_tipo FROM PUBLIC;
REVOKE ALL ON TABLE discapacidad_tipo FROM postgres;
GRANT ALL ON TABLE discapacidad_tipo TO postgres;


--
-- TOC entry 3722 (class 0 OID 0)
-- Dependencies: 202
-- Name: disciplina_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE disciplina_tipo FROM PUBLIC;
REVOKE ALL ON TABLE disciplina_tipo FROM postgres;
GRANT ALL ON TABLE disciplina_tipo TO postgres;


--
-- TOC entry 3723 (class 0 OID 0)
-- Dependencies: 203
-- Name: docente_integrador_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE docente_integrador_tipo FROM PUBLIC;
REVOKE ALL ON TABLE docente_integrador_tipo FROM postgres;
GRANT ALL ON TABLE docente_integrador_tipo TO postgres;


--
-- TOC entry 3724 (class 0 OID 0)
-- Dependencies: 204
-- Name: duracion_en_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE duracion_en_tipo FROM PUBLIC;
REVOKE ALL ON TABLE duracion_en_tipo FROM postgres;
GRANT ALL ON TABLE duracion_en_tipo TO postgres;


--
-- TOC entry 3725 (class 0 OID 0)
-- Dependencies: 205
-- Name: energia_electrica_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE energia_electrica_tipo FROM PUBLIC;
REVOKE ALL ON TABLE energia_electrica_tipo FROM postgres;
GRANT ALL ON TABLE energia_electrica_tipo TO postgres;


--
-- TOC entry 3726 (class 0 OID 0)
-- Dependencies: 206
-- Name: equipamiento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE equipamiento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE equipamiento_tipo FROM postgres;
GRANT ALL ON TABLE equipamiento_tipo TO postgres;


--
-- TOC entry 3727 (class 0 OID 0)
-- Dependencies: 207
-- Name: espacio_curricular_duracion_en_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE espacio_curricular_duracion_en_tipo FROM PUBLIC;
REVOKE ALL ON TABLE espacio_curricular_duracion_en_tipo FROM postgres;
GRANT ALL ON TABLE espacio_curricular_duracion_en_tipo TO postgres;


--
-- TOC entry 3728 (class 0 OID 0)
-- Dependencies: 208
-- Name: espacio_internet_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE espacio_internet_tipo FROM PUBLIC;
REVOKE ALL ON TABLE espacio_internet_tipo FROM postgres;
GRANT ALL ON TABLE espacio_internet_tipo TO postgres;


--
-- TOC entry 3729 (class 0 OID 0)
-- Dependencies: 209
-- Name: estado_civil_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_civil_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_civil_tipo FROM postgres;
GRANT ALL ON TABLE estado_civil_tipo TO postgres;


--
-- TOC entry 3730 (class 0 OID 0)
-- Dependencies: 210
-- Name: estado_hoja_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_hoja_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_hoja_tipo FROM postgres;
GRANT ALL ON TABLE estado_hoja_tipo TO postgres;


--
-- TOC entry 3731 (class 0 OID 0)
-- Dependencies: 211
-- Name: estado_inscripcion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_inscripcion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_inscripcion_tipo FROM postgres;
GRANT ALL ON TABLE estado_inscripcion_tipo TO postgres;


--
-- TOC entry 3732 (class 0 OID 0)
-- Dependencies: 212
-- Name: estado_operativo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_operativo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_operativo_tipo FROM postgres;
GRANT ALL ON TABLE estado_operativo_tipo TO postgres;


--
-- TOC entry 3733 (class 0 OID 0)
-- Dependencies: 213
-- Name: estado_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_tipo FROM postgres;
GRANT ALL ON TABLE estado_tipo TO postgres;


--
-- TOC entry 3734 (class 0 OID 0)
-- Dependencies: 214
-- Name: estado_verificacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE estado_verificacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE estado_verificacion_tipo FROM postgres;
GRANT ALL ON TABLE estado_verificacion_tipo TO postgres;


--
-- TOC entry 3735 (class 0 OID 0)
-- Dependencies: 215
-- Name: fines_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE fines_tipo FROM PUBLIC;
REVOKE ALL ON TABLE fines_tipo FROM postgres;
GRANT ALL ON TABLE fines_tipo TO postgres;


--
-- TOC entry 3736 (class 0 OID 0)
-- Dependencies: 216
-- Name: formato_espacio_curricular_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE formato_espacio_curricular_tipo FROM PUBLIC;
REVOKE ALL ON TABLE formato_espacio_curricular_tipo FROM postgres;
GRANT ALL ON TABLE formato_espacio_curricular_tipo TO postgres;


--
-- TOC entry 3737 (class 0 OID 0)
-- Dependencies: 217
-- Name: grado_nivel_servicio_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE grado_nivel_servicio_tipo FROM PUBLIC;
REVOKE ALL ON TABLE grado_nivel_servicio_tipo FROM postgres;
GRANT ALL ON TABLE grado_nivel_servicio_tipo TO postgres;


--
-- TOC entry 3738 (class 0 OID 0)
-- Dependencies: 218
-- Name: grado_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE grado_tipo FROM PUBLIC;
REVOKE ALL ON TABLE grado_tipo FROM postgres;
GRANT ALL ON TABLE grado_tipo TO postgres;


--
-- TOC entry 3739 (class 0 OID 0)
-- Dependencies: 219
-- Name: indigena_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE indigena_tipo FROM PUBLIC;
REVOKE ALL ON TABLE indigena_tipo FROM postgres;
GRANT ALL ON TABLE indigena_tipo TO postgres;


--
-- TOC entry 3740 (class 0 OID 0)
-- Dependencies: 220
-- Name: jornada_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE jornada_tipo FROM PUBLIC;
REVOKE ALL ON TABLE jornada_tipo FROM postgres;
GRANT ALL ON TABLE jornada_tipo TO postgres;


--
-- TOC entry 3742 (class 0 OID 0)
-- Dependencies: 221
-- Name: localidad_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE localidad_tipo FROM PUBLIC;
REVOKE ALL ON TABLE localidad_tipo FROM postgres;
GRANT ALL ON TABLE localidad_tipo TO postgres;


--
-- TOC entry 3743 (class 0 OID 0)
-- Dependencies: 222
-- Name: lugar_funcionamiento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE lugar_funcionamiento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE lugar_funcionamiento_tipo FROM postgres;
GRANT ALL ON TABLE lugar_funcionamiento_tipo TO postgres;


--
-- TOC entry 3744 (class 0 OID 0)
-- Dependencies: 223
-- Name: mantenimiento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE mantenimiento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE mantenimiento_tipo FROM postgres;
GRANT ALL ON TABLE mantenimiento_tipo TO postgres;


--
-- TOC entry 3745 (class 0 OID 0)
-- Dependencies: 224
-- Name: modalidad1_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE modalidad1_tipo FROM PUBLIC;
REVOKE ALL ON TABLE modalidad1_tipo FROM postgres;
GRANT ALL ON TABLE modalidad1_tipo TO postgres;


--
-- TOC entry 3746 (class 0 OID 0)
-- Dependencies: 225
-- Name: motivo_baja_inscripcion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE motivo_baja_inscripcion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE motivo_baja_inscripcion_tipo FROM postgres;
GRANT ALL ON TABLE motivo_baja_inscripcion_tipo TO postgres;


--
-- TOC entry 3747 (class 0 OID 0)
-- Dependencies: 226
-- Name: nacionalidad_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE nacionalidad_tipo FROM PUBLIC;
REVOKE ALL ON TABLE nacionalidad_tipo FROM postgres;
GRANT ALL ON TABLE nacionalidad_tipo TO postgres;


--
-- TOC entry 3748 (class 0 OID 0)
-- Dependencies: 227
-- Name: nivel_alcanzado_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE nivel_alcanzado_tipo FROM PUBLIC;
REVOKE ALL ON TABLE nivel_alcanzado_tipo FROM postgres;
GRANT ALL ON TABLE nivel_alcanzado_tipo TO postgres;


--
-- TOC entry 3749 (class 0 OID 0)
-- Dependencies: 228
-- Name: nivel_servicio_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE nivel_servicio_tipo FROM PUBLIC;
REVOKE ALL ON TABLE nivel_servicio_tipo FROM postgres;
GRANT ALL ON TABLE nivel_servicio_tipo TO postgres;


--
-- TOC entry 3750 (class 0 OID 0)
-- Dependencies: 229
-- Name: normativa_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE normativa_tipo FROM PUBLIC;
REVOKE ALL ON TABLE normativa_tipo FROM postgres;
GRANT ALL ON TABLE normativa_tipo TO postgres;


--
-- TOC entry 3751 (class 0 OID 0)
-- Dependencies: 230
-- Name: obligatoriedad_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE obligatoriedad_tipo FROM PUBLIC;
REVOKE ALL ON TABLE obligatoriedad_tipo FROM postgres;
GRANT ALL ON TABLE obligatoriedad_tipo TO postgres;


--
-- TOC entry 3752 (class 0 OID 0)
-- Dependencies: 231
-- Name: oferta_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE oferta_tipo FROM PUBLIC;
REVOKE ALL ON TABLE oferta_tipo FROM postgres;
GRANT ALL ON TABLE oferta_tipo TO postgres;


--
-- TOC entry 3754 (class 0 OID 0)
-- Dependencies: 233
-- Name: operativo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE operativo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE operativo_tipo FROM postgres;
GRANT ALL ON TABLE operativo_tipo TO postgres;


--
-- TOC entry 3755 (class 0 OID 0)
-- Dependencies: 234
-- Name: organizacion_cursada_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE organizacion_cursada_tipo FROM PUBLIC;
REVOKE ALL ON TABLE organizacion_cursada_tipo FROM postgres;
GRANT ALL ON TABLE organizacion_cursada_tipo TO postgres;


--
-- TOC entry 3756 (class 0 OID 0)
-- Dependencies: 235
-- Name: organizacion_plan_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE organizacion_plan_tipo FROM PUBLIC;
REVOKE ALL ON TABLE organizacion_plan_tipo FROM postgres;
GRANT ALL ON TABLE organizacion_plan_tipo TO postgres;


--
-- TOC entry 3757 (class 0 OID 0)
-- Dependencies: 236
-- Name: orientacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE orientacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE orientacion_tipo FROM postgres;
GRANT ALL ON TABLE orientacion_tipo TO postgres;


--
-- TOC entry 3758 (class 0 OID 0)
-- Dependencies: 237
-- Name: pais_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE pais_tipo FROM PUBLIC;
REVOKE ALL ON TABLE pais_tipo FROM postgres;
GRANT ALL ON TABLE pais_tipo TO postgres;


--
-- TOC entry 3759 (class 0 OID 0)
-- Dependencies: 238
-- Name: per_funcionamiento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE per_funcionamiento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE per_funcionamiento_tipo FROM postgres;
GRANT ALL ON TABLE per_funcionamiento_tipo TO postgres;


--
-- TOC entry 3760 (class 0 OID 0)
-- Dependencies: 239
-- Name: provincia_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE provincia_tipo FROM PUBLIC;
REVOKE ALL ON TABLE provincia_tipo FROM postgres;
GRANT ALL ON TABLE provincia_tipo TO postgres;


--
-- TOC entry 3761 (class 0 OID 0)
-- Dependencies: 240
-- Name: rama_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE rama_tipo FROM PUBLIC;
REVOKE ALL ON TABLE rama_tipo FROM postgres;
GRANT ALL ON TABLE rama_tipo TO postgres;


--
-- TOC entry 3762 (class 0 OID 0)
-- Dependencies: 241
-- Name: requisito_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE requisito_tipo FROM PUBLIC;
REVOKE ALL ON TABLE requisito_tipo FROM postgres;
GRANT ALL ON TABLE requisito_tipo TO postgres;


--
-- TOC entry 3763 (class 0 OID 0)
-- Dependencies: 242
-- Name: restriccion_internet_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE restriccion_internet_tipo FROM PUBLIC;
REVOKE ALL ON TABLE restriccion_internet_tipo FROM postgres;
GRANT ALL ON TABLE restriccion_internet_tipo TO postgres;


--
-- TOC entry 3764 (class 0 OID 0)
-- Dependencies: 243
-- Name: sector_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE sector_tipo FROM PUBLIC;
REVOKE ALL ON TABLE sector_tipo FROM postgres;
GRANT ALL ON TABLE sector_tipo TO postgres;


--
-- TOC entry 3765 (class 0 OID 0)
-- Dependencies: 244
-- Name: servicio_internet_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE servicio_internet_tipo FROM PUBLIC;
REVOKE ALL ON TABLE servicio_internet_tipo FROM postgres;
GRANT ALL ON TABLE servicio_internet_tipo TO postgres;


--
-- TOC entry 3766 (class 0 OID 0)
-- Dependencies: 245
-- Name: sexo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE sexo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE sexo_tipo FROM postgres;
GRANT ALL ON TABLE sexo_tipo TO postgres;


--
-- TOC entry 3767 (class 0 OID 0)
-- Dependencies: 246
-- Name: sino_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE sino_tipo FROM PUBLIC;
REVOKE ALL ON TABLE sino_tipo FROM postgres;
GRANT ALL ON TABLE sino_tipo TO postgres;


--
-- TOC entry 3768 (class 0 OID 0)
-- Dependencies: 247
-- Name: sistema_gestion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE sistema_gestion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE sistema_gestion_tipo FROM postgres;
GRANT ALL ON TABLE sistema_gestion_tipo TO postgres;


--
-- TOC entry 3769 (class 0 OID 0)
-- Dependencies: 248
-- Name: software_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE software_tipo FROM PUBLIC;
REVOKE ALL ON TABLE software_tipo FROM postgres;
GRANT ALL ON TABLE software_tipo TO postgres;


--
-- TOC entry 3770 (class 0 OID 0)
-- Dependencies: 249
-- Name: subvencion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE subvencion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE subvencion_tipo FROM postgres;
GRANT ALL ON TABLE subvencion_tipo TO postgres;


--
-- TOC entry 3771 (class 0 OID 0)
-- Dependencies: 250
-- Name: tipo_actividad_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_actividad_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_actividad_tipo FROM postgres;
GRANT ALL ON TABLE tipo_actividad_tipo TO postgres;


--
-- TOC entry 3772 (class 0 OID 0)
-- Dependencies: 251
-- Name: tipo_baja_inscripcion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_baja_inscripcion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_baja_inscripcion_tipo FROM postgres;
GRANT ALL ON TABLE tipo_baja_inscripcion_tipo TO postgres;


--
-- TOC entry 3773 (class 0 OID 0)
-- Dependencies: 252
-- Name: tipo_beneficio_alimentario_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_beneficio_alimentario_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_beneficio_alimentario_tipo FROM postgres;
GRANT ALL ON TABLE tipo_beneficio_alimentario_tipo TO postgres;


--
-- TOC entry 3774 (class 0 OID 0)
-- Dependencies: 253
-- Name: tipo_beneficio_plan_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_beneficio_plan_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_beneficio_plan_tipo FROM postgres;
GRANT ALL ON TABLE tipo_beneficio_plan_tipo TO postgres;


--
-- TOC entry 3775 (class 0 OID 0)
-- Dependencies: 254
-- Name: tipo_consistencia_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_consistencia_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_consistencia_tipo FROM postgres;
GRANT ALL ON TABLE tipo_consistencia_tipo TO postgres;


--
-- TOC entry 3776 (class 0 OID 0)
-- Dependencies: 255
-- Name: tipo_copia_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_copia_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_copia_tipo FROM postgres;
GRANT ALL ON TABLE tipo_copia_tipo TO postgres;


--
-- TOC entry 3777 (class 0 OID 0)
-- Dependencies: 256
-- Name: tipo_documento_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_documento_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_documento_tipo FROM postgres;
GRANT ALL ON TABLE tipo_documento_tipo TO postgres;


--
-- TOC entry 3778 (class 0 OID 0)
-- Dependencies: 257
-- Name: tipo_formacion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_formacion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_formacion_tipo FROM postgres;
GRANT ALL ON TABLE tipo_formacion_tipo TO postgres;


--
-- TOC entry 3779 (class 0 OID 0)
-- Dependencies: 258
-- Name: tipo_norma_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_norma_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_norma_tipo FROM postgres;
GRANT ALL ON TABLE tipo_norma_tipo TO postgres;


--
-- TOC entry 3780 (class 0 OID 0)
-- Dependencies: 259
-- Name: tipo_operativo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_operativo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_operativo_tipo FROM postgres;
GRANT ALL ON TABLE tipo_operativo_tipo TO postgres;


--
-- TOC entry 3781 (class 0 OID 0)
-- Dependencies: 260
-- Name: tipo_seccion_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_seccion_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_seccion_tipo FROM postgres;
GRANT ALL ON TABLE tipo_seccion_tipo TO postgres;


--
-- TOC entry 3782 (class 0 OID 0)
-- Dependencies: 261
-- Name: tipo_titulo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE tipo_titulo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE tipo_titulo_tipo FROM postgres;
GRANT ALL ON TABLE tipo_titulo_tipo TO postgres;


--
-- TOC entry 3783 (class 0 OID 0)
-- Dependencies: 262
-- Name: transporte_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE transporte_tipo FROM PUBLIC;
REVOKE ALL ON TABLE transporte_tipo FROM postgres;
GRANT ALL ON TABLE transporte_tipo TO postgres;


--
-- TOC entry 3784 (class 0 OID 0)
-- Dependencies: 263
-- Name: trayecto_formativo_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE trayecto_formativo_tipo FROM PUBLIC;
REVOKE ALL ON TABLE trayecto_formativo_tipo FROM postgres;
GRANT ALL ON TABLE trayecto_formativo_tipo TO postgres;


--
-- TOC entry 3785 (class 0 OID 0)
-- Dependencies: 264
-- Name: turno_tipo; Type: ACL; Schema: codigos; Owner: postgres
--

REVOKE ALL ON TABLE turno_tipo FROM PUBLIC;
REVOKE ALL ON TABLE turno_tipo FROM postgres;
GRANT ALL ON TABLE turno_tipo TO postgres;


SET search_path = public, pg_catalog;

--
-- TOC entry 3786 (class 0 OID 0)
-- Dependencies: 303
-- Name: actividad_extracurricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE actividad_extracurricular FROM PUBLIC;
REVOKE ALL ON TABLE actividad_extracurricular FROM postgres;
GRANT ALL ON TABLE actividad_extracurricular TO postgres;


--
-- TOC entry 3788 (class 0 OID 0)
-- Dependencies: 305
-- Name: alumno_beneficio_alimentario; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_beneficio_alimentario FROM PUBLIC;
REVOKE ALL ON TABLE alumno_beneficio_alimentario FROM postgres;
GRANT ALL ON TABLE alumno_beneficio_alimentario TO postgres;


--
-- TOC entry 3790 (class 0 OID 0)
-- Dependencies: 307
-- Name: alumno_beneficio_plan; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_beneficio_plan FROM PUBLIC;
REVOKE ALL ON TABLE alumno_beneficio_plan FROM postgres;
GRANT ALL ON TABLE alumno_beneficio_plan TO postgres;


--
-- TOC entry 3792 (class 0 OID 0)
-- Dependencies: 309
-- Name: alumno_discapacidad; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_discapacidad FROM PUBLIC;
REVOKE ALL ON TABLE alumno_discapacidad FROM postgres;
GRANT ALL ON TABLE alumno_discapacidad TO postgres;


--
-- TOC entry 3794 (class 0 OID 0)
-- Dependencies: 265
-- Name: alumno_espacio_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_espacio_curricular FROM PUBLIC;
REVOKE ALL ON TABLE alumno_espacio_curricular FROM postgres;
GRANT ALL ON TABLE alumno_espacio_curricular TO postgres;


--
-- TOC entry 3796 (class 0 OID 0)
-- Dependencies: 266
-- Name: alumno_inscripcion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion TO postgres;


--
-- TOC entry 3797 (class 0 OID 0)
-- Dependencies: 267
-- Name: alumno_inscripcion_espacio_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion_espacio_curricular FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion_espacio_curricular FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion_espacio_curricular TO postgres;


--
-- TOC entry 3798 (class 0 OID 0)
-- Dependencies: 269
-- Name: seccion_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE seccion_curricular FROM PUBLIC;
REVOKE ALL ON TABLE seccion_curricular FROM postgres;
GRANT ALL ON TABLE seccion_curricular TO postgres;


--
-- TOC entry 3800 (class 0 OID 0)
-- Dependencies: 270
-- Name: detalle_alumno_inscripcion_seccion_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular FROM PUBLIC;
REVOKE ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular FROM postgres;
GRANT ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular TO postgres;


--
-- TOC entry 3802 (class 0 OID 0)
-- Dependencies: 312
-- Name: detalle_alumno_estado_inscripcion_seccion_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_alumno_estado_inscripcion_seccion_curricular FROM PUBLIC;
REVOKE ALL ON TABLE detalle_alumno_estado_inscripcion_seccion_curricular FROM postgres;
GRANT ALL ON TABLE detalle_alumno_estado_inscripcion_seccion_curricular TO postgres;


--
-- TOC entry 3803 (class 0 OID 0)
-- Dependencies: 313
-- Name: nombre_titulacion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE nombre_titulacion FROM PUBLIC;
REVOKE ALL ON TABLE nombre_titulacion FROM postgres;
GRANT ALL ON TABLE nombre_titulacion TO postgres;


--
-- TOC entry 3804 (class 0 OID 0)
-- Dependencies: 298
-- Name: seccion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE seccion FROM PUBLIC;
REVOKE ALL ON TABLE seccion FROM postgres;
GRANT ALL ON TABLE seccion TO postgres;


--
-- TOC entry 3805 (class 0 OID 0)
-- Dependencies: 273
-- Name: titulacion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE titulacion FROM PUBLIC;
REVOKE ALL ON TABLE titulacion FROM postgres;
GRANT ALL ON TABLE titulacion TO postgres;


--
-- TOC entry 3806 (class 0 OID 0)
-- Dependencies: 314
-- Name: titulacion_nombre_titulacion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE titulacion_nombre_titulacion FROM PUBLIC;
REVOKE ALL ON TABLE titulacion_nombre_titulacion FROM postgres;
GRANT ALL ON TABLE titulacion_nombre_titulacion TO postgres;


--
-- TOC entry 3807 (class 0 OID 0)
-- Dependencies: 315
-- Name: alumno_estado_inscripcion_estudio_curricular_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_estado_inscripcion_estudio_curricular_vista FROM PUBLIC;
REVOKE ALL ON TABLE alumno_estado_inscripcion_estudio_curricular_vista FROM postgres;
GRANT ALL ON TABLE alumno_estado_inscripcion_estudio_curricular_vista TO postgres;


--
-- TOC entry 3808 (class 0 OID 0)
-- Dependencies: 316
-- Name: alumno_estado_inscripcion_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_estado_inscripcion_vista FROM PUBLIC;
REVOKE ALL ON TABLE alumno_estado_inscripcion_vista FROM postgres;
GRANT ALL ON TABLE alumno_estado_inscripcion_vista TO postgres;


--
-- TOC entry 3809 (class 0 OID 0)
-- Dependencies: 317
-- Name: alumno_inscripcion_historico; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion_historico FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion_historico FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion_historico TO postgres;


--
-- TOC entry 3810 (class 0 OID 0)
-- Dependencies: 318
-- Name: detalle_alumno_historico; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_alumno_historico FROM PUBLIC;
REVOKE ALL ON TABLE detalle_alumno_historico FROM postgres;
GRANT ALL ON TABLE detalle_alumno_historico TO postgres;


--
-- TOC entry 3811 (class 0 OID 0)
-- Dependencies: 319
-- Name: alumno_historico_incripcion_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_historico_incripcion_vista FROM PUBLIC;
REVOKE ALL ON TABLE alumno_historico_incripcion_vista FROM postgres;
GRANT ALL ON TABLE alumno_historico_incripcion_vista TO postgres;


--
-- TOC entry 3814 (class 0 OID 0)
-- Dependencies: 271
-- Name: espacio_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE espacio_curricular FROM PUBLIC;
REVOKE ALL ON TABLE espacio_curricular FROM postgres;
GRANT ALL ON TABLE espacio_curricular TO postgres;


--
-- TOC entry 3816 (class 0 OID 0)
-- Dependencies: 276
-- Name: detalle_seccion_curricular_alumnos_con_todas_notas_cargadas; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_con_todas_notas_cargadas FROM PUBLIC;
REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_con_todas_notas_cargadas FROM postgres;
GRANT ALL ON TABLE detalle_seccion_curricular_alumnos_con_todas_notas_cargadas TO postgres;


--
-- TOC entry 3817 (class 0 OID 0)
-- Dependencies: 322
-- Name: alumno_inscripcion_estudio_curricular_progreso_carga_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion_estudio_curricular_progreso_carga_vista FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion_estudio_curricular_progreso_carga_vista FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion_estudio_curricular_progreso_carga_vista TO postgres;


--
-- TOC entry 3818 (class 0 OID 0)
-- Dependencies: 268
-- Name: alumno_inscripcion_extracurricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion_extracurricular FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion_extracurricular FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion_extracurricular TO postgres;


--
-- TOC entry 3822 (class 0 OID 0)
-- Dependencies: 326
-- Name: alumno_inscripcion_nombre_apellido_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alumno_inscripcion_nombre_apellido_vista FROM PUBLIC;
REVOKE ALL ON TABLE alumno_inscripcion_nombre_apellido_vista FROM postgres;
GRANT ALL ON TABLE alumno_inscripcion_nombre_apellido_vista TO postgres;


--
-- TOC entry 3823 (class 0 OID 0)
-- Dependencies: 327
-- Name: autoridad; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE autoridad FROM PUBLIC;
REVOKE ALL ON TABLE autoridad FROM postgres;
GRANT ALL ON TABLE autoridad TO postgres;


--
-- TOC entry 3826 (class 0 OID 0)
-- Dependencies: 329
-- Name: ciclo_lectivo_tipo_y_sin_definir_text; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE ciclo_lectivo_tipo_y_sin_definir_text FROM PUBLIC;
REVOKE ALL ON TABLE ciclo_lectivo_tipo_y_sin_definir_text FROM postgres;
GRANT ALL ON TABLE ciclo_lectivo_tipo_y_sin_definir_text TO postgres;


--
-- TOC entry 3827 (class 0 OID 0)
-- Dependencies: 330
-- Name: consistencia; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE consistencia FROM PUBLIC;
REVOKE ALL ON TABLE consistencia FROM postgres;
GRANT ALL ON TABLE consistencia TO postgres;


--
-- TOC entry 3828 (class 0 OID 0)
-- Dependencies: 274
-- Name: unidad_servicio; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE unidad_servicio FROM PUBLIC;
REVOKE ALL ON TABLE unidad_servicio FROM postgres;
GRANT ALL ON TABLE unidad_servicio TO postgres;


--
-- TOC entry 3829 (class 0 OID 0)
-- Dependencies: 331
-- Name: detalle_espacio_curricular_alumnos_con_nota; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_espacio_curricular_alumnos_con_nota FROM PUBLIC;
REVOKE ALL ON TABLE detalle_espacio_curricular_alumnos_con_nota FROM postgres;
GRANT ALL ON TABLE detalle_espacio_curricular_alumnos_con_nota TO postgres;


--
-- TOC entry 3830 (class 0 OID 0)
-- Dependencies: 332
-- Name: count_espacio_curricular_alumnos_con_nota; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_espacio_curricular_alumnos_con_nota FROM PUBLIC;
REVOKE ALL ON TABLE count_espacio_curricular_alumnos_con_nota FROM postgres;
GRANT ALL ON TABLE count_espacio_curricular_alumnos_con_nota TO postgres;


--
-- TOC entry 3831 (class 0 OID 0)
-- Dependencies: 333
-- Name: detalle_espacio_curricular_alumnos_inscriptos; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_espacio_curricular_alumnos_inscriptos FROM PUBLIC;
REVOKE ALL ON TABLE detalle_espacio_curricular_alumnos_inscriptos FROM postgres;
GRANT ALL ON TABLE detalle_espacio_curricular_alumnos_inscriptos TO postgres;


--
-- TOC entry 3832 (class 0 OID 0)
-- Dependencies: 334
-- Name: count_espacio_curricular_alumnos_inscriptos; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_espacio_curricular_alumnos_inscriptos FROM PUBLIC;
REVOKE ALL ON TABLE count_espacio_curricular_alumnos_inscriptos FROM postgres;
GRANT ALL ON TABLE count_espacio_curricular_alumnos_inscriptos TO postgres;


--
-- TOC entry 3833 (class 0 OID 0)
-- Dependencies: 272
-- Name: detalle_seccion_curricular_alumnos_con_alguna_nota; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_con_alguna_nota FROM PUBLIC;
REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_con_alguna_nota FROM postgres;
GRANT ALL ON TABLE detalle_seccion_curricular_alumnos_con_alguna_nota TO postgres;


--
-- TOC entry 3834 (class 0 OID 0)
-- Dependencies: 335
-- Name: count_seccion_curricular_alumnos_con_alguna_nota; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_seccion_curricular_alumnos_con_alguna_nota FROM PUBLIC;
REVOKE ALL ON TABLE count_seccion_curricular_alumnos_con_alguna_nota FROM postgres;
GRANT ALL ON TABLE count_seccion_curricular_alumnos_con_alguna_nota TO postgres;


--
-- TOC entry 3835 (class 0 OID 0)
-- Dependencies: 336
-- Name: count_seccion_curricular_alumnos_con_todas_notas_cargadas; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_seccion_curricular_alumnos_con_todas_notas_cargadas FROM PUBLIC;
REVOKE ALL ON TABLE count_seccion_curricular_alumnos_con_todas_notas_cargadas FROM postgres;
GRANT ALL ON TABLE count_seccion_curricular_alumnos_con_todas_notas_cargadas TO postgres;


--
-- TOC entry 3836 (class 0 OID 0)
-- Dependencies: 296
-- Name: detalle_alumno_inscripcion_seccion_curricular_regulares; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular_regulares FROM PUBLIC;
REVOKE ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular_regulares FROM postgres;
GRANT ALL ON TABLE detalle_alumno_inscripcion_seccion_curricular_regulares TO postgres;


--
-- TOC entry 3837 (class 0 OID 0)
-- Dependencies: 297
-- Name: count_seccion_curricular_alumnos_inscriptos_regulares; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_seccion_curricular_alumnos_inscriptos_regulares FROM PUBLIC;
REVOKE ALL ON TABLE count_seccion_curricular_alumnos_inscriptos_regulares FROM postgres;
GRANT ALL ON TABLE count_seccion_curricular_alumnos_inscriptos_regulares TO postgres;


--
-- TOC entry 3838 (class 0 OID 0)
-- Dependencies: 337
-- Name: detalle_seccion_curricular_alumnos_regulares_repitientes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_regulares_repitientes FROM PUBLIC;
REVOKE ALL ON TABLE detalle_seccion_curricular_alumnos_regulares_repitientes FROM postgres;
GRANT ALL ON TABLE detalle_seccion_curricular_alumnos_regulares_repitientes TO postgres;


--
-- TOC entry 3839 (class 0 OID 0)
-- Dependencies: 338
-- Name: count_seccion_curricular_alumnos_regulares_repitientes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_seccion_curricular_alumnos_regulares_repitientes FROM PUBLIC;
REVOKE ALL ON TABLE count_seccion_curricular_alumnos_regulares_repitientes FROM postgres;
GRANT ALL ON TABLE count_seccion_curricular_alumnos_regulares_repitientes TO postgres;


--
-- TOC entry 3840 (class 0 OID 0)
-- Dependencies: 339
-- Name: detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo FROM PUBLIC;
REVOKE ALL ON TABLE detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo FROM postgres;
GRANT ALL ON TABLE detalle_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo TO postgres;


--
-- TOC entry 3841 (class 0 OID 0)
-- Dependencies: 340
-- Name: count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo FROM PUBLIC;
REVOKE ALL ON TABLE count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo FROM postgres;
GRANT ALL ON TABLE count_titulacion_alumnos_regulares_inscriptos_ciclo_lectivo TO postgres;


--
-- TOC entry 3842 (class 0 OID 0)
-- Dependencies: 341
-- Name: count_titulacion_espacios_curriculares; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_titulacion_espacios_curriculares FROM PUBLIC;
REVOKE ALL ON TABLE count_titulacion_espacios_curriculares FROM postgres;
GRANT ALL ON TABLE count_titulacion_espacios_curriculares TO postgres;


--
-- TOC entry 3843 (class 0 OID 0)
-- Dependencies: 342
-- Name: count_titulacion_secciones; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_titulacion_secciones FROM PUBLIC;
REVOKE ALL ON TABLE count_titulacion_secciones FROM postgres;
GRANT ALL ON TABLE count_titulacion_secciones TO postgres;


--
-- TOC entry 3844 (class 0 OID 0)
-- Dependencies: 343
-- Name: count_titulacion_secciones_curriculares; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_titulacion_secciones_curriculares FROM PUBLIC;
REVOKE ALL ON TABLE count_titulacion_secciones_curriculares FROM postgres;
GRANT ALL ON TABLE count_titulacion_secciones_curriculares TO postgres;


--
-- TOC entry 3845 (class 0 OID 0)
-- Dependencies: 275
-- Name: count_unidad_servicio_alumnos_con_alguna_nota; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_con_alguna_nota FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_con_alguna_nota FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_con_alguna_nota TO postgres;


--
-- TOC entry 3846 (class 0 OID 0)
-- Dependencies: 277
-- Name: count_unidad_servicio_alumnos_con_todas_notas_cargadas; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_con_todas_notas_cargadas FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_con_todas_notas_cargadas FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_con_todas_notas_cargadas TO postgres;


--
-- TOC entry 3847 (class 0 OID 0)
-- Dependencies: 278
-- Name: detalle_unidad_servicio_alumnos_examen; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_examen FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_examen FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_examen TO postgres;


--
-- TOC entry 3848 (class 0 OID 0)
-- Dependencies: 279
-- Name: count_unidad_servicio_alumnos_examen; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_examen FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_examen FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_examen TO postgres;


--
-- TOC entry 3849 (class 0 OID 0)
-- Dependencies: 280
-- Name: detalle_unidad_servicio_alumnos_extracurricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_extracurricular FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_extracurricular FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_extracurricular TO postgres;


--
-- TOC entry 3850 (class 0 OID 0)
-- Dependencies: 281
-- Name: count_unidad_servicio_alumnos_extracurricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_extracurricular FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_extracurricular FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_extracurricular TO postgres;


--
-- TOC entry 3851 (class 0 OID 0)
-- Dependencies: 282
-- Name: count_unidad_servicio_alumnos_ingresados_al_sistema; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_ingresados_al_sistema FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_ingresados_al_sistema FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_ingresados_al_sistema TO postgres;


--
-- TOC entry 3852 (class 0 OID 0)
-- Dependencies: 292
-- Name: detalle_unidad_servicio_alumnos_no_inscriptos; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_no_inscriptos FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_no_inscriptos FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_no_inscriptos TO postgres;


--
-- TOC entry 3853 (class 0 OID 0)
-- Dependencies: 293
-- Name: count_unidad_servicio_alumnos_no_inscriptos; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_no_inscriptos FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_no_inscriptos FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_no_inscriptos TO postgres;


--
-- TOC entry 3854 (class 0 OID 0)
-- Dependencies: 294
-- Name: count_unidad_servicio_alumnos_notas_faltantes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_notas_faltantes FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_notas_faltantes FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_notas_faltantes TO postgres;


--
-- TOC entry 3855 (class 0 OID 0)
-- Dependencies: 283
-- Name: detalle_unidad_servicio_alumnos_regular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_regular FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_regular FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_regular TO postgres;


--
-- TOC entry 3856 (class 0 OID 0)
-- Dependencies: 284
-- Name: count_unidad_servicio_alumnos_regular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_regular FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_regular FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_regular TO postgres;


--
-- TOC entry 3857 (class 0 OID 0)
-- Dependencies: 344
-- Name: detalle_unidad_servicio_alumnos_regular_y_examen; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_regular_y_examen FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_regular_y_examen FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_regular_y_examen TO postgres;


--
-- TOC entry 3858 (class 0 OID 0)
-- Dependencies: 345
-- Name: count_unidad_servicio_alumnos_regular_y_examen; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_regular_y_examen FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_regular_y_examen FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_regular_y_examen TO postgres;


--
-- TOC entry 3859 (class 0 OID 0)
-- Dependencies: 285
-- Name: unidad_servicio_operativo; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE unidad_servicio_operativo FROM PUBLIC;
REVOKE ALL ON TABLE unidad_servicio_operativo FROM postgres;
GRANT ALL ON TABLE unidad_servicio_operativo TO postgres;


--
-- TOC entry 3861 (class 0 OID 0)
-- Dependencies: 286
-- Name: unidad_servicio_ultimo_operativo_sin_confirmar; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE unidad_servicio_ultimo_operativo_sin_confirmar FROM PUBLIC;
REVOKE ALL ON TABLE unidad_servicio_ultimo_operativo_sin_confirmar FROM postgres;
GRANT ALL ON TABLE unidad_servicio_ultimo_operativo_sin_confirmar TO postgres;


--
-- TOC entry 3863 (class 0 OID 0)
-- Dependencies: 287
-- Name: detalle_unidad_servicio_alumnos_sin_condicion_promocion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_sin_condicion_promocion FROM PUBLIC;
REVOKE ALL ON TABLE detalle_unidad_servicio_alumnos_sin_condicion_promocion FROM postgres;
GRANT ALL ON TABLE detalle_unidad_servicio_alumnos_sin_condicion_promocion TO postgres;


--
-- TOC entry 3864 (class 0 OID 0)
-- Dependencies: 288
-- Name: count_unidad_servicio_alumnos_sin_condicion_promocion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_alumnos_sin_condicion_promocion FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_alumnos_sin_condicion_promocion FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_alumnos_sin_condicion_promocion TO postgres;


--
-- TOC entry 3865 (class 0 OID 0)
-- Dependencies: 299
-- Name: count_unidad_servicio_titulaciones; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_titulaciones FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_titulaciones FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_titulaciones TO postgres;


--
-- TOC entry 3866 (class 0 OID 0)
-- Dependencies: 300
-- Name: count_unidad_servicio_titulaciones_confirmadas; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_confirmadas FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_confirmadas FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_titulaciones_confirmadas TO postgres;


--
-- TOC entry 3867 (class 0 OID 0)
-- Dependencies: 301
-- Name: count_unidad_servicio_titulaciones_en_este_cl; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl TO postgres;


--
-- TOC entry 3868 (class 0 OID 0)
-- Dependencies: 302
-- Name: count_unidad_servicio_titulaciones_en_este_cl_confirmadas; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl_confirmadas FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl_confirmadas FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_titulaciones_en_este_cl_confirmadas TO postgres;


--
-- TOC entry 3869 (class 0 OID 0)
-- Dependencies: 295
-- Name: count_unidad_servicio_titulaciones_sin_confirmar; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_sin_confirmar FROM PUBLIC;
REVOKE ALL ON TABLE count_unidad_servicio_titulaciones_sin_confirmar FROM postgres;
GRANT ALL ON TABLE count_unidad_servicio_titulaciones_sin_confirmar TO postgres;


--
-- TOC entry 3870 (class 0 OID 0)
-- Dependencies: 346
-- Name: datos_institucion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE datos_institucion FROM PUBLIC;
REVOKE ALL ON TABLE datos_institucion FROM postgres;
GRANT ALL ON TABLE datos_institucion TO postgres;


--
-- TOC entry 3871 (class 0 OID 0)
-- Dependencies: 347
-- Name: datos_unidad_servicio; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE datos_unidad_servicio FROM PUBLIC;
REVOKE ALL ON TABLE datos_unidad_servicio FROM postgres;
GRANT ALL ON TABLE datos_unidad_servicio TO postgres;


--
-- TOC entry 3872 (class 0 OID 0)
-- Dependencies: 348
-- Name: nombre_espacio_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE nombre_espacio_curricular FROM PUBLIC;
REVOKE ALL ON TABLE nombre_espacio_curricular FROM postgres;
GRANT ALL ON TABLE nombre_espacio_curricular TO postgres;


--
-- TOC entry 3873 (class 0 OID 0)
-- Dependencies: 349
-- Name: espacio_curricular_detalle_y_alumnos_progreso_carga_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE espacio_curricular_detalle_y_alumnos_progreso_carga_vista FROM PUBLIC;
REVOKE ALL ON TABLE espacio_curricular_detalle_y_alumnos_progreso_carga_vista FROM postgres;
GRANT ALL ON TABLE espacio_curricular_detalle_y_alumnos_progreso_carga_vista TO postgres;


--
-- TOC entry 3875 (class 0 OID 0)
-- Dependencies: 351
-- Name: establecimiento; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE establecimiento FROM PUBLIC;
REVOKE ALL ON TABLE establecimiento FROM postgres;
GRANT ALL ON TABLE establecimiento TO postgres;


--
-- TOC entry 3877 (class 0 OID 0)
-- Dependencies: 353
-- Name: hoja_papel_moneda; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE hoja_papel_moneda FROM PUBLIC;
REVOKE ALL ON TABLE hoja_papel_moneda FROM postgres;
GRANT ALL ON TABLE hoja_papel_moneda TO postgres;


--
-- TOC entry 3878 (class 0 OID 0)
-- Dependencies: 354
-- Name: hoja_papel_moneda_analitico; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE hoja_papel_moneda_analitico FROM PUBLIC;
REVOKE ALL ON TABLE hoja_papel_moneda_analitico FROM postgres;
GRANT ALL ON TABLE hoja_papel_moneda_analitico TO postgres;


--
-- TOC entry 3881 (class 0 OID 0)
-- Dependencies: 289
-- Name: institucion; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE institucion FROM PUBLIC;
REVOKE ALL ON TABLE institucion FROM postgres;
GRANT ALL ON TABLE institucion TO postgres;


--
-- TOC entry 3882 (class 0 OID 0)
-- Dependencies: 357
-- Name: institucion_cantidad_alumnos_anio_turno_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE institucion_cantidad_alumnos_anio_turno_vista FROM PUBLIC;
REVOKE ALL ON TABLE institucion_cantidad_alumnos_anio_turno_vista FROM postgres;
GRANT ALL ON TABLE institucion_cantidad_alumnos_anio_turno_vista TO postgres;


--
-- TOC entry 3883 (class 0 OID 0)
-- Dependencies: 358
-- Name: institucion_equipamiento; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE institucion_equipamiento FROM PUBLIC;
REVOKE ALL ON TABLE institucion_equipamiento FROM postgres;
GRANT ALL ON TABLE institucion_equipamiento TO postgres;


--
-- TOC entry 3886 (class 0 OID 0)
-- Dependencies: 361
-- Name: institucion_software; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE institucion_software FROM PUBLIC;
REVOKE ALL ON TABLE institucion_software FROM postgres;
GRANT ALL ON TABLE institucion_software TO postgres;


--
-- TOC entry 3888 (class 0 OID 0)
-- Dependencies: 363
-- Name: lote_papel_moneda; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE lote_papel_moneda FROM PUBLIC;
REVOKE ALL ON TABLE lote_papel_moneda FROM postgres;
GRANT ALL ON TABLE lote_papel_moneda TO postgres;


--
-- TOC entry 3890 (class 0 OID 0)
-- Dependencies: 365
-- Name: nombre_cargo; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE nombre_cargo FROM PUBLIC;
REVOKE ALL ON TABLE nombre_cargo FROM postgres;
GRANT ALL ON TABLE nombre_cargo TO postgres;


--
-- TOC entry 3894 (class 0 OID 0)
-- Dependencies: 369
-- Name: nombre_titulacion_nivel_servicio_tipo_assn; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE nombre_titulacion_nivel_servicio_tipo_assn FROM PUBLIC;
REVOKE ALL ON TABLE nombre_titulacion_nivel_servicio_tipo_assn FROM postgres;
GRANT ALL ON TABLE nombre_titulacion_nivel_servicio_tipo_assn TO postgres;


--
-- TOC entry 3895 (class 0 OID 0)
-- Dependencies: 370
-- Name: oferta_local; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE oferta_local FROM PUBLIC;
REVOKE ALL ON TABLE oferta_local FROM postgres;
GRANT ALL ON TABLE oferta_local TO postgres;


--
-- TOC entry 3898 (class 0 OID 0)
-- Dependencies: 372
-- Name: operativo_tipo_y_sin_definir_text; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE operativo_tipo_y_sin_definir_text FROM PUBLIC;
REVOKE ALL ON TABLE operativo_tipo_y_sin_definir_text FROM postgres;
GRANT ALL ON TABLE operativo_tipo_y_sin_definir_text TO postgres;


--
-- TOC entry 3900 (class 0 OID 0)
-- Dependencies: 374
-- Name: seccion_curricular_espacio_curricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE seccion_curricular_espacio_curricular FROM PUBLIC;
REVOKE ALL ON TABLE seccion_curricular_espacio_curricular FROM postgres;
GRANT ALL ON TABLE seccion_curricular_espacio_curricular TO postgres;


--
-- TOC entry 3903 (class 0 OID 0)
-- Dependencies: 377
-- Name: seccion_curricular_progreso_carga_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE seccion_curricular_progreso_carga_vista FROM PUBLIC;
REVOKE ALL ON TABLE seccion_curricular_progreso_carga_vista FROM postgres;
GRANT ALL ON TABLE seccion_curricular_progreso_carga_vista TO postgres;


--
-- TOC entry 3904 (class 0 OID 0)
-- Dependencies: 378
-- Name: seccion_extracurricular; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE seccion_extracurricular FROM PUBLIC;
REVOKE ALL ON TABLE seccion_extracurricular FROM postgres;
GRANT ALL ON TABLE seccion_extracurricular TO postgres;


--
-- TOC entry 3907 (class 0 OID 0)
-- Dependencies: 381
-- Name: titulacion_cantidades_unidad_servicio_progreso_carga_vista; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE titulacion_cantidades_unidad_servicio_progreso_carga_vista FROM PUBLIC;
REVOKE ALL ON TABLE titulacion_cantidades_unidad_servicio_progreso_carga_vista FROM postgres;
GRANT ALL ON TABLE titulacion_cantidades_unidad_servicio_progreso_carga_vista TO postgres;


--
-- TOC entry 3909 (class 0 OID 0)
-- Dependencies: 383
-- Name: titulacion_normativa; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE titulacion_normativa FROM PUBLIC;
REVOKE ALL ON TABLE titulacion_normativa FROM postgres;
GRANT ALL ON TABLE titulacion_normativa TO postgres;


--
-- TOC entry 3911 (class 0 OID 0)
-- Dependencies: 290
-- Name: unidad_servicio_datos_identificatorios_calculados; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE unidad_servicio_datos_identificatorios_calculados FROM PUBLIC;
REVOKE ALL ON TABLE unidad_servicio_datos_identificatorios_calculados FROM postgres;
GRANT ALL ON TABLE unidad_servicio_datos_identificatorios_calculados TO postgres;


--
-- TOC entry 3913 (class 0 OID 0)
-- Dependencies: 291
-- Name: unidad_servicio_definidas_ultimo_operativo_sin_confirmar; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE unidad_servicio_definidas_ultimo_operativo_sin_confirmar FROM PUBLIC;
REVOKE ALL ON TABLE unidad_servicio_definidas_ultimo_operativo_sin_confirmar FROM postgres;
GRANT ALL ON TABLE unidad_servicio_definidas_ultimo_operativo_sin_confirmar TO postgres;


--
-- TOC entry 3916 (class 0 OID 0)
-- Dependencies: 388
-- Name: verificacion_carga; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE verificacion_carga FROM PUBLIC;
REVOKE ALL ON TABLE verificacion_carga FROM postgres;
GRANT ALL ON TABLE verificacion_carga TO postgres;


-- Completed on 2017-09-26 17:07:43

--
-- PostgreSQL database dump complete
--

