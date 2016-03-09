DROP TABLE IF EXISTS sadc.frame_ticks;

--create the grid line table
CREATE TABLE sadc.frame_ticks(
	gid serial primary key,
	the_geom geometry(LINESTRING,4326),
	line_style varchar(10),
	line_name varchar(16),
	line_orient varchar(4));


--create or replace the function that loops to create line dashes that run 
CREATE OR REPLACE FUNCTION sadc.draw_frame_ticks(
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
	tick_int numeric(24,21);								--space between lines in decimal fractions of a degree
--	orient varchar(4);
--	mant numeric(21,18);								--fractional part of the line's definition
--	deg integer;									--whole part (unsigned) of the line's defintion
--	min integer;									--fractional part, (unsigned minutes) of the line's defintion
--	hemis varchar(2);								--hemisphere (N, S, E, W) of the line's definition
	line varchar(10);								--placement of the line
--	rep varchar(6);									--whether line represents a whole degree or a fraction (minute)
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
	tick_int := abs(x_int) / 60.0;
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
		wkt_str := 'SRID=4326;LINESTRING(' || x_coord || ' ' || y_coord;
		--loop to add line
		<<hor>>
		LOOP
			--add points to the line, increment bythe dot interval
			x_coord := x_coord + tick_int;
			--concatenate next coordinates
			wkt_str := wkt_str || ', ' || x_coord || ' ' || y_coord;
			--leave the loop once the line has reached its right-most limit
			EXIT hor WHEN x_coord >= x_max;
		END LOOP hor;
		--close the last bracket
		wkt_str := wkt_str || ')';
		--load the data,including the WKT as a geometry, into the table as a row
		INSERT INTO sadc.frame_ticks(
			the_geom,
			line_style,
			line_name,
			line_orient)
			VALUES (
				ST_GeomFromEWKT(wkt_str),
				'ticks',
				line,
				'lat');
	END LOOP;

	-- check the vertical (latitude interval) doesn't exceed 45 deg
	IF y_int > 2700 THEN
		y_int := 2700;
	END IF;
	--get the dot interval in dec deg
	tick_int := abs(y_int) / 60.0;
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
		--set up the beginning of the WKT string
		wkt_str := 'SRID=4326;LINESTRING(' || x_coord || ' ' || y_coord;
		--loop to add line
		<<vert>>
		LOOP
			--increment by the dot interval
			y_coord := y_coord + tick_int;
			--concatenate next coordinates
			wkt_str := wkt_str || ', ' || x_coord || ' ' || y_coord;
			--leave the loop once the line has reached its top-most limit
			EXIT vert WHEN y_coord >= y_max;
		END LOOP vert;
		--close the last bracket
		wkt_str := wkt_str || ')';
		--load the data,including the WKT as a geometry, into the table as a row
		INSERT INTO sadc.frame_ticks(
			the_geom,
			line_style,
			line_name,
			line_orient)
			VALUES (
				ST_GeomFromEWKT(wkt_str),
				'ticks',
				line,
				'long');
	END LOOP;
--	RETURN wkt_str;
	RETURN;
END;

$BODY$
LANGUAGE plpgsql;

--run the function, with the given parameters
SELECT * FROM sadc.draw_frame_ticks(8, 68, 60, -40, 8, 60);

--view thw result
SELECT 
	ST_AsEWKT(the_geom),
	line_style,
	line_name,
	line_orient
FROM sadc.frame_ticks;
