DROP TABLE IF EXISTS sadc.frame_labels;

--create the grid line table
CREATE TABLE sadc.frame_labels(
	gid serial primary key,
	the_geom geometry(POINT,4326),
	dot_position varchar(10),
	dot_unit varchar(6),
	dot_name varchar(16),
	dot_orient varchar(4));


--create or replace the function that loops to create line dashes that run 
CREATE OR REPLACE FUNCTION sadc.draw_frame_labels(
	x_min integer,									--southern-most box line in whole degrees
	x_max integer,									--northern-most box line in whole degrees
	x_int integer,									--length of vertical dashes in whole minutes (60 = 1 degree)
	y_min integer,									--western-most box line in whole degrees
	y_max integer,									--eastern-most box line in whole degrees
	y_int integer)									--length of horizontal dashes in whole minutes (60 = 1 degree)
RETURNS void AS
$BODY$

DECLARE
	x_coord numeric(21,18);								--the coordinates of the vertices on the lines
	y_coord numeric(21,18);								-- "  ditto  "
	i integer;
	dot_int numeric(24,21);							--space between lines in decimal fractions of a degree
--	dash_start numeric(21,18);							--the position of the start of the dash
	orient varchar(4);
	mant numeric(21,18);								--fractional part of the line's definition
	deg integer;									--whole part (unsigned) of the line's defintion
	min integer;									--fractional part, (unsigned minutes) of the line's defintion
	hemis varchar(2);								--hemisphere (N, S, E, W) of the line's definition
	coord varchar(10);								--description in degrees, minutes and hemisphere, of the line
	unit varchar(6);								--whether line represents a whole degree or a fraction (minute)
	line varchar(6);								--whether the line of points is on the top, bottom, left or right
	wkt_str varchar;								--the WKT vesrion of each string

BEGIN
	--Check the limits of the input parameters
	IF x_min < -179.99 THEN
		x_min := -179.99;
	END IF;--
	IF x_max > 180 THEN
		x_max := 180;
	END IF;
	IF y_min < -85 THEN
		y_min := -85;
	END IF;
	IF y_max > 85 THEN
		y_max := 85;
	END IF;

	-- check the horizontal (longitude interval) doesn't exceed 90 deg
	IF x_int > 5400 THEN
		x_int := 5400;
	END IF;
	--get the dot interval in dec deg
	dot_int := abs(x_int) / 60.0;
	--loop to do the bottom and the top
	FOR i IN 1..2 LOOP
		--choose whether the bottom or top line
		CASE i
			--bottom
			WHEN 1 THEN
				y_coord := y_min;
				line := 'Bottom';
			--top
			WHEN 2 THEN
				y_coord := y_max;
				line := 'Top';
		END CASE;
		--set the start of the lines to the left
		x_coord := x_min;
		--set up the beginning of the WKT string
		wkt_str := 'SRID=4326;POINT(' || x_coord || ' ' || y_coord || ')';
		--loop to add line
		<<hor>>
		LOOP
			--make a label for the line in degrees and minutes
			deg := trunc(x_coord);
			mant := abs(x_coord - deg);
			hemis := to_char(sign(round(x_coord,6)),'SG9');
			deg := abs(deg);
			min := round(round(mant,5) * 60);
			IF min >= 60 THEN
				deg := deg + 1;
				min := min - 60;
			END IF;
			CASE hemis
				WHEN '-1' THEN
					hemis := 'W';
				WHEN '+1' THEN
					hemis := 'E';
				ELSE
					hemis := ' ';
			END CASE;
			coord := to_char(deg, '99') || chr(186) || to_char(min, '00') || chr(180) || ' ' || hemis;
			--catagorise the line as a degree line or a minute line
			CASE min
				WHEN 0 THEN
					unit := 'degree';
				ELSE
					unit := 'minute';
			END CASE;
			--add in the point as a  WKT string
			wkt_str := 'SRID=4326;POINT(' || x_coord || ' ' || y_coord || ')';
			--load the data,including the WKT as a geometry, into the table as a row
			INSERT INTO sadc.frame_labels(
				the_geom,
				dot_position,
				dot_unit,
				dot_name,
				dot_orient)
				VALUES (
					ST_GeomFromEWKT(wkt_str),
					coord,
					unit,
					line,
					'long');
			--add points along the line, increment by the dot interval
			x_coord := x_coord + dot_int;
			--leave the loop once the line has reached its right-most limit
			EXIT hor WHEN x_coord >= x_max;
		END LOOP hor;
	END LOOP;

	-- check the vertical (latitude interval) doesn't exceed 45 deg
	IF y_int > 2700 THEN
		y_int := 2700;
	END IF;
	--get the dot interval in dec deg
	dot_int := abs(y_int) / 60.0;
	--loop to do the left and the right
	FOR i IN 1..2 LOOP
		--choose whether the left or right line
		CASE i
			--left
			WHEN 1 THEN
				x_coord := x_min;
				line := 'Left';
			--right
			WHEN 2 THEN
				x_coord := x_max;
				line := 'Right';
		END CASE;
		--set the start of the lines to the bottom
		y_coord := y_min;
		--loop to add line
		<<vert>>
		LOOP
			--make a label for the line in degrees and minutes
			deg := trunc(y_coord);
			mant := abs(y_coord - deg);
			hemis := to_char(sign(round(y_coord,6)),'SG9');
			deg := abs(deg);
			min := round(round(mant,5) * 60);
			IF min >= 60 THEN
				deg := deg + 1;
				min := min - 60;
			END IF;
			CASE hemis
				WHEN '-1' THEN
					hemis := 'S';
				WHEN '+1' THEN
					hemis := 'N';
				ELSE
					hemis := ' ';
			END CASE;
			coord := to_char(deg, '99') || chr(186) || to_char(min, '00') || chr(180) || ' ' || hemis;
			--catagorise the line as a degree line or a minute line
			CASE min
				WHEN 0 THEN
					unit := 'degree';
				ELSE
					unit := 'minute';
			END CASE;
			--add in the point as a  WKT string
			wkt_str := 'SRID=4326;POINT(' || x_coord || ' ' || y_coord || ')';
			--load the data,including the WKT as a geometry, into the table as a row
			INSERT INTO sadc.frame_labels(
				the_geom,
				dot_position,
				dot_unit,
				dot_name,
				dot_orient)
				VALUES (
					ST_GeomFromEWKT(wkt_str),
					coord,
					unit,
					line,
					'lat');
			--increment by the dot interval
			y_coord := y_coord + dot_int;
			--leave the loop once the line has reached its top-most limit
			EXIT vert WHEN y_coord >= y_max;
		END LOOP vert;
	END LOOP;
--	RETURN wkt_str;
	RETURN;
END;

$BODY$
LANGUAGE plpgsql;

--run the function, with the given parameters
SELECT * FROM sadc.draw_frame_labels(8, 68, 5, -40, 8, 5);

--view thw result
SELECT 
	ST_AsEWKT(the_geom),
	dot_position,
	dot_unit,
	dot_name,
	dot_orient
FROM sadc.frame_labels;
