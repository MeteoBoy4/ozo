
# Instructions to produce input data for OZO by WRF model

## Download

Here you can find different versions of the WRF model:

[http://www2.mmm.ucar.edu/wrf/users/download/get_sources.html] [WRF]

## Tutorial

And here is information about downloading and compiling WRF on your local computer

[http://www2.mmm.ucar.edu/wrf/OnLineTutorial/index.htm] [tutorial]


### 1. Downloading and compiling WRF on your local computer

Get the source code of the WRF version 3.8.1 and extract it:

```sh
wget http://www2.mmm.ucar.edu/wrf/src/WRFV3.8.1.TAR.gz
tar xvf WRFV3.8.1.TAR.gz
```

Go to the appeared directory and run following commands. Those will compile the model for a single processor job with no nesting and using gfortran compiler. 

```sh
cd WRFV3/
export NETCDF=/usr WRFIO_NCD_LARGE_FILE_SUPPORT=1
# GCC, serial, no nesting
./configure <<<'32

'
export WRF_EM_CORE=1
./compile em_b_wave >& compile.log
```
Check the compile.log file for any errors. If the compilation was succesful, you should have the executables appeared in main-directory.

### 2. Editing the namelist 

Go to the baroclinic wave directory:  
```sh
cd test/em_b_wave/
```
Open _namelist.input_ with some text editor and change at least following values:  

Section _&time\_control_:  


`run_days = 10` Sets simulation time to 10 days. 

`end_day = 10` Ending day of the simulation.  

`history_interval = 60` Output interval in seconds. 

`iofields_filename = = "iofield_list.txt"` This is optional. By default, WRF outputs huge number of unnecessary variables.  
With that file you can change the number of output variables. You can find an example file from wrf-directory.


Section &physics:  
These values can be changed according your taste, but provided numbers are more or less the simplest schemes.  

`mp_physics = 2`  

`sf_sfclay_physics = 1`  

`sf_surface_physics = 1`  

`bl_pbl_physics = 1`  

`cu_physics = 1`  


### 3. Running the model
Once you have set correct values in the namelist, you have to link some files to running directory.  
This can be done by executing _run\_me\_first.csh_ script and linking one other file in the same directory:

```sh
./run_me_first.csh
ln -s ../../run/LANDUSE.TBL
```

Now you are ready to create initial state of the simulation by running _ideal.exe_:

```sh
./ideal.exe
```

If the file _wrfinput\_d01_ appears to the directory, your initial state is created.  
After that, start running the model:

```sh
./wrf.exe
```

If the run was succesful, you should have _wrfout\_d01\_0001-01-01\_00:00:00_ appeared to your directory.  
That file is the output netcdf-file of the simulation and contains the data on model levels. Before running OZO, that data needs to be interpolated to pressure levels.

### 4. Interpolating to pressure levels


To interpolate WRF output to pressure levels, you need to download utility called wrf\_interp:

[http://www2.mmm.ucar.edu/wrf/users/download/get_sources.html#utilities][wrfinterp]

Create a directory for the program:

```sh
mkdir -p ~/wrf/wrf_interp
cd $_
```

Get the source code and extract it:

```sh
wget http://www2.mmm.ucar.edu/wrf/src/WRF_INTERP.TAR.gz
tar -xvf WRF_INTERP.TAR.gz
```

If you are using gfortran, you may need to do small change to the source code. After that, compile it:

```sh
sed -i 's/\.eq\. \.T/.eqv. .T/' wrf_interp.F90
gfortran -o wrf_interp.exe wrf_interp.F90 -I/usr/include -free -L/usr/lib -lnetcdff
```

Next, you need change some namelist values in the _namelist.vinterp_. Here are example values:  

```sh
&io
 path_to_input = '/home/mikarant/WRFV3/test/em_b_wave'
 path_to_output = '/home/mikarant/WRFV3/test/em_b_wave/interp'
 root_name = 'wrfout'
 grid_id = 1
 start_date =  '0001-01-01_00'
 leap_year  = .FALSE.
 debug = .TRUE.
/

&interp_in
  interp_levels = 1000,-100,50 
  extrapolate = 1 
  unstagger_grid = .TRUE. 
  vert_coordinate = 'pres'
/
```

After that, run the program:

```sh
./wrf_interp.exe
```


[//]: # (Reference links)

[WRF]: <http://www2.mmm.ucar.edu/wrf/users/download/get_source.html>
[tutorial]: <http://www2.mmm.ucar.edu/wrf/OnLineTutorial/index.htm>
[wrfinterp]: <http://www2.mmm.ucar.edu/wrf/users/download/get_sources.html#utilities>
