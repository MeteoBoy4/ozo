mod_common_subrs.o : src/mod_common_subrs.f90 mod_const.o 
mod_const.o : src/mod_const.f90 
mod_poisson.o : src/mod_poisson.f90 mkl_poisson.o 
mod_subrs.o : src/mod_subrs.f90 mod_poisson.o mod_common_subrs.o mod_const.o mod_type_vars.o 
mod_time_step_loop.o : src/mod_time_step_loop.f90 mod_subrs.o mod_wrf_file.o 
mod_type_vars.o : src/mod_type_vars.f90 
mod_wrf_file.o : src/mod_wrf_file.f90 
ozo.o : src/ozo.f90 mod_time_step_loop.o mod_wrf_file.o 
mkl_poisson.o : /home/mikarant/intel/compilers_and_libraries_2016.2.181/linux/mkl/include/mkl_poisson.f90 mkl_dfti.o 
mkl_dfti.o : /home/mikarant/intel/compilers_and_libraries_2016.2.181/linux/mkl/include/mkl_dfti.f90 
