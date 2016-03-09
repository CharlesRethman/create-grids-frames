--Purpose: to generate a grid of longitude and latitude lines that
--spand the SADC region and bend according to the projection in use. 

--Output: Table containing rows, each row with geometry and data
--for a line of longitude or latitiude and each line separated at
--five-minute intervals.

--delete the old table if it's there
DROP TABLE IF EXISTS sadc.grid;


--create the grid line table
CREATE TABLE sadc.grid(
	gid serial primary key,
	the_geom geometry(LINESTRING,4326),
	line_pos numeric(10,6),
	line_name varchar(11),
	line_res varchar(6),
	line_type varchar(4),
	line_num integer,
	line_int_dd numeric (10,6),
	line_int_min integer);


--create or replace the function that does the looping to ceate the lines
CREATE OR REPLACE FUNCTION sadc.draw_grid_lines(
	x_min integer,									--southern-most line of latitude in whole degrees
	x_max integer,									--northern-most line of latitude in whole degrees
	y_int integer,									--interval of latitude lines in whole minutes (60 = 1 degree)
	y_min integer,									--western-most line of longitude in whole degrees
	y_max integer,									--eastern-most line of longitude in whole degrees
	x_int integer)									--interval of longitude lines in whole minutes (60 = 1 degree)
RETURNS VOID AS
$BODY$

DECLARE
	x_coord numeric(21,18);								--the coordinates of the vertices on the lines
	y_coord numeric(21,18);								--          "             "           "
	i integer;									--counter
	line_int numeric(24,21);							--space between lines in decimal fractions of a degree
	mant numeric(21,18);								--fractional part of the line's definition
	deg integer;									--whole part (unsigned) of the line's defintion
	min integer;									--fractional part, (unsigned minutes) of the line's defintion
	hemis varchar(2);								--hemisphere (N, S, E, W) of the line's definition
	line varchar(11);								--description in degrees, minutes and hemisphere, of the line
	unit varchar(6);								--whether line represents a whole degree or a fraction (minute)
	wkt_str varchar;								--the WKT vesrion of each string

BEGIN
	--Check the limits of the input parameters
	--too far east
	IF x_min < -179.99 THEN
		--fix the limit to -179.99 long
		x_min := -179.99;
	END IF;
	--too far west
	IF x_max > 180 THEN
		--fix the limit to 180.0 long
		x_max := 180.0;
	END IF;
	--too far south
	IF y_min < -85 THEN
		--fix the limit to -85.0 lat 
		y_min := -85.0;
	END IF;
	--too far north
	IF y_max > 85 THEN
		--fix the limit to 85.0 lat
		y_max := 85.0;
	END IF;
	--horizontal limits inverted
	IF x_min > x_max THEN
		--swap them
		x_coord := x_max;
		x_max := x_min;
		x_min := x_coord;
	END IF;
	--vertical limits inverted
	IF y_min > y_max THEN
		--swap them
		y_coord := y_max;
		y_max := y_min;
		y_min := y_coord;
	END IF;

	--start with the lines of latitude (horizontals)
	y_coord := y_min;
	--reset the counter
	i := 1;
	--Check the line interval isn't more that the bounds (y_min to y_max)
	IF y_int > (y_max - y_min) * 60 THEN
		y_int := (y_max - y_min) * 60;
	END IF;
	--get the interval between lines in decimal degrees
	line_int := abs(y_int) / 60.0;
	--loop to add new lines of latitude
	<<hlines>>
	LOOP
		EXIT hlines WHEN (y_coord > y_max) OR (i > abs(60.0 * (y_max - y_min)));
		--Reset the start of the lines to the left
		x_coord := x_min;
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
		line := to_char(deg, '99') || chr(186) || to_char(min, '00') || chr(180) || ' ' || hemis;
		--catagorise the line as a degree line or a minute line
		CASE min
			WHEN 0 THEN
				unit := 'degree';
			ELSE
				unit := 'minute';
		END CASE;
		--set up the first point on the WKT string
		wkt_str := 'SRID=4326;LINESTRING(' || x_coord || ' ' || y_coord;
		--loop to add points to the line
		<<hpoints>>
		LOOP
			--leave the loop after reaching the maximum width
			EXIT hpoints WHEN x_coord > x_max;
			--increment by 1 hundredth of a degree (line curvature)
			x_coord := x_coord + 0.01;
			--concatenate next coordinates
			wkt_str := wkt_str || ', ' || x_coord || ' ' || y_coord;
		END LOOP hpoints;
		--close the WKT string with a ')'
		wkt_str := wkt_str || ')';
		--load the data,including the WKT as a geometry, into the table as a row
		INSERT INTO sadc.grid(
			the_geom,
			line_pos,
			line_name,
			line_res,
			line_type,
			line_num,
			line_int_dd,
			line_int_min)
			VALUES (
				ST_GeomFromEWKT(wkt_str),
				y_coord,
				line,
				unit,
				'lat',
				i,
				line_int,
				y_int);
		--increment the longitude by the line interval to position the next line
		y_coord := y_coord + line_int;
		--increment the counter
		i := i + 1;
	END LOOP hlines;

	--next, the lines of longitude (verticals)
	x_coord := x_min;
	--reset the counter
	i := 1;
	--Check the line interval isn't more that the bounds (x_min to x_max)
	IF x_int > (x_max - x_min) * 60 THEN
		x_int := (x_max - x_min) * 60;
	END IF;
	line_int := abs(x_int) / 60.0;
	--loop to add new lines of longitude
	<<vlines>>
	LOOP
		EXIT vlines WHEN (x_coord > x_max) OR (i > abs(60.0 * (x_max - x_min)));
		y_coord := y_min;
		--make a label for the line in degrees and minutes
		deg := trunc(x_coord);
		mant := abs(x_coord - deg);
		hemis := to_char(sign(x_coord),'SG9'); 
		deg := abs(deg);
		min := round(round(mant,5) * 60.0);
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
		line := to_char(deg, '999') || chr(186) || to_char(min, '00') || chr(180) || ' ' || hemis;
		--catagorise the line as a degree line or a 10', 20', 30', 40' or 50' line
		CASE min
			WHEN 0 THEN
				unit := 'degree';
			ELSE
				unit := 'minute';
		END CASE;
		--set up the first point on the WKT string
		wkt_str := 'SRID=4326;LINESTRING(' || x_coord || ' ' || y_coord;
		--loop to add points to the line
		<<vpoints>>
		LOOP
			--leave the loop after reaching the maximum height
			EXIT vpoints WHEN y_coord > y_max;
			--increment by 1 hundredth of a degree (line curvature)
			y_coord := y_coord + 0.01;
			--concatenate next coordinates
			wkt_str := wkt_str || ', ' || x_coord || ' ' || y_coord;
		END LOOP vpoints;
		--close the WKT string with a ')'
		wkt_str := wkt_str || ')';
		--load the data,including the WKT as a geometry, into the table as a row
		INSERT INTO sadc.grid(
			the_geom,
			line_pos,
			line_name,
			line_res,
			line_type,
			line_num,
			line_int_dd,
			line_int_min)
			VALUES (
				ST_GeomFromEWKT(wkt_str),
				x_coord,
				line,
				unit,
				'long',
				i,
				line_int,
				x_int);
		--increment the longitude by the line interval to position the next line
		x_coord := x_coord + line_int;
		--increment the counter
		i := i + 1;
	END LOOP vlines;
--	RETURN wkt_str;
	RETURN;
END;
$BODY$
LANGUAGE plpgsql;


--run the function, with the given parameters
SELECT * FROM sadc.draw_grid_lines(0, 75, 5, -50, 15, 5);


--view thw result
SELECT 
	ST_AsEWKT(the_geom),
	line_pos,
	line_name,
	line_res,
	line_type,
	line_num,
	line_int_dd,
	line_int_min
FROM sadc.grid;
