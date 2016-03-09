# create-grids-frames

## Intro

Ever wondered how you could create a really cool map layout in your QGIS Composer, where the map's edges follow longitude/latitude grid lines, regardless of the projection used, instead of the plain old rectangular look? For example, this is a conically-projected map of South Africa:

![map of SA in Albers Equal Area](images/livelihood_zones_v2_a4_1.png "Livelihood Zones in South Africa")

Looks cool, doesn't it? See how the map's left edge follows the 16 degree E meridian, which is slanted appropriately to the left, while the top border curves nicely along the 22 degree S parallel.

These routines will do it for you by making a set of components that contain the necessary lines and dots. All you have to do do is format the output in QGIS using the supplied .qml files. More about that later.

I need to add here that the lines _appear_ to curve nicely but they **do** have a finite resolution. Vertices are positioned every one-hundredth of a degree; this is great for small scale maps but might get jerky when you zoom in to large scales.

The resultant files are in the GCS long-lat CRS, with WGS Datum and ellipsoid (EPSG 4326). This can be reprojected on the fly very easily by QGIS.

##
