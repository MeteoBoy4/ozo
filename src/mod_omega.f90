module mod_omega
  use mod_wrf_file
  use mod_common_subrs
  use mod_omega_subrs
  implicit none

contains

  subroutine calculate_omegas( file, t, u, v, omegaan, z, q, xfrict, yfrict, &
       ttend, zetaraw, zetatend, uKhi, vKhi, sigmaraw, mulfact, alfa, toler, &
       ny1, ny2, mode, calc_b, debug, omegas, omegas_QG )

    real,dimension(:,:,:,:),intent(inout) :: omegas, omegas_QG
    real,dimension(:,:,:),  intent(inout) :: z,q,u,v,ttend,zetatend
    real,dimension(:,:,:),  intent(in) :: t,omegaan,xfrict,yfrict,sigmaraw
    real,dimension(:,:,:),  intent(in) :: mulfact,zetaraw,uKhi,vKhi
    real,                   intent(in) :: alfa,toler
    integer,                intent(in) :: ny1,ny2
    character,              intent(in) :: mode
    logical,                intent(in) :: calc_b,debug
    type ( wrf_file ),      intent(in) :: file

    real,dimension(:,:,:,:,:),allocatable :: rhs
    real,dimension(:,:,:,:),allocatable :: boundaries,zero,sigma,feta,corfield
    real,dimension(:,:,:,:),allocatable :: dudp,dvdp,ftest,d2zetadp,omega
    real,dimension(:,:,:),  allocatable :: zeta
    real,dimension(:,:),    allocatable :: sigma0
    integer :: i,j,k

!   Threshold values to keep the generalized omega equation elliptic.
    real,parameter :: sigmamin=2e-7,etamin=2e-6

!   For iubound, ilbound and iybound are 0, horizontal boundary
!   conditions are used at the upper, lower and north/south boundaries  
!   A value of 1 for any of these parameters means that the boundary
!   condition is taken directly from the "real" WRF omega. In practice,
!   only the lower boundary condition (ilbound) is important.
    integer :: iubound,ilbound,iybound

    iubound=1 ! 1 for "real" omega as upper-boundary condition
    ilbound=1 ! 1 for "real" omega as upper-boundary condition
    iybound=1 ! 1 for "real" omega as north/south boundary condtion

    associate ( &
         nlon => file % nlon(1), &
         nlat => file % nlat(1), &
         nlev => file % nlev(1), &
         dx => file % dx(1), &
         dy => file % dy(1), &
         dlev => file % dlev(1), &
         lev => file % pressure_levels, &
         ! Grid sizes for the different resolutions
         nres => size(file % nlat), &
         nlonx => file % nlon, &
         nlatx => file % nlat, &
         nlevx => file % nlev, &
         dx2 => file % dx, &
         dy2 => file % dy, &
         dlev2 => file % dlev )

    allocate(zeta(nlon,nlat,nlev))
    allocate(omega(nlon,nlat,nlev,nres),ftest(nlon,nlat,nlev,nres))
    allocate(boundaries(nlon,nlat,nlev,nres),corfield(nlon,nlat,nlev,nres))
    allocate(zero(nlon,nlat,nlev,nres),sigma(nlon,nlat,nlev,nres))
    allocate(d2zetadp(nlon,nlat,nlev,nres),feta(nlon,nlat,nlev,nres))
    allocate(dudp(nlon,nlat,nlev,nres),dvdp(nlon,nlat,nlev,nres))
    allocate(sigma0(nlev,nres))
    allocate(rhs(nlon,nlat,nlev,nres,n_terms))

!   Calculation of coriolisparameter field
    do j=1,nlat
       corfield(:,j,:,1) = file % corpar(j)
    enddo

!   For quasi-geostrophic equation: calculation of geostrophic winds
!
    if(mode.eq.'Q')then
       call gwinds(z,dx,dy,corfield(:,:,:,1),u,v)
    endif

!   Calculation of forcing terms 
!
    if(mode.eq.'G'.or.mode.eq.'Q')then
       rhs(:,:,:,1,termV) = fvort(u,v,zetaraw,corfield(:,:,:,1),dx,dy,dlev,mulfact)
       
       rhs(:,:,:,1,termT) = ftemp(u,v,t,lev,dx,dy,mulfact)
    endif

    if(mode.eq.'G')then
       rhs(:,:,:,1,termF) = ffrict(xfrict,yfrict,corfield(:,:,:,1),dx,dy,dlev,mulfact)
       rhs(:,:,:,1,termQ) = fdiab(q,lev,dx,dy,mulfact)
       rhs(:,:,:,1,termA) = fimbal(zetatend,ttend,corfield(:,:,:,1),lev,dx,dy,dlev,mulfact)
       rhs(:,:,:,1,termVKhi) = fvort(ukhi,vkhi,zetaraw,corfield(:,:,:,1),dx,dy,dlev,mulfact)
       rhs(:,:,:,1,termTKhi) = ftemp(ukhi,vkhi,t,lev,dx,dy,mulfact)
    endif

!   Deriving quantities needed for the LHS of the 
!   QG and/or generalised omega equation.

!   1. Pressure derivatives of wind components

    dudp(:,:,:,1) = pder(u,dlev)
    dvdp(:,:,:,1) = pder(v,dlev)
!!
!   2. Modifying stability and vorticity on the LHS to keep
!   the solution elliptic
!
    call modify(sigmaraw,sigmamin,etamin,zetaraw, file % corpar,&
         dudp(:,:,:,1),dvdp(:,:,:,1),sigma(:,:,:,1),feta(:,:,:,1),zeta)      
!
!   3. Second pressure derivative of vorticity 
!
    d2zetadp(:,:,:,1) = p2der(zeta,dlev)
!
!   4. Area mean of static stability over the whole grid
!
    do k=1,nlev
       sigma0(k,1) = aave(sigmaraw(:,:,k))
    enddo
!
!   Left-hand side coefficients for the QG equation
!
    if(mode.eq.'Q'.or.mode.eq.'t')then
       do k=1,nlev
          sigma(:,:,k,1)=sigma0(k,1)
       enddo
       feta=corfield**2.
    endif
!
!   Forcing for quasigeostrophic test case ('t')
!   In essence: calculating the LHS from the WRF omega (omegaan) 
!   and substituting it to the RHS
!
    if(mode.eq.'t')then
       call QG_test(omegaan,sigma,feta,dx,dy,dlev,ftest)
    endif ! mode.eq.'t'   
!
!   Forcing for the general test case
!   In essence: calculating the LHS from the WRF omega (omegaan) 
!   and substituting it to the RHS
       
    if(mode.eq.'T')then
       call gen_test(sigmaraw,omegaan,zetaraw,dudp(:,:,:,1),dvdp(:,:,:,1),corfield(:,:,:,1),dx,dy,dlev,ftest)
    endif ! (forcing for the general test case if mode.eq.'T')

!   Boundary conditions from WRF omega?  
!
    boundaries=0.
    if ( calc_b ) then
       boundaries(:,:,1,1)=iubound*omegaan(:,:,1)
       boundaries(:,:,nlev,1)=ilbound*omegaan(:,:,nlev)
       boundaries(:,1,2:nlev-1,1)=iybound*omegaan(:,1,2:nlev-1)
       boundaries(:,nlat,2:nlev-1,1)=iybound*omegaan(:,nlat,2:nlev-1)
    end if
!   Regrid left-hand-side parameters and boundary conditions to 
!   coarser grids. Note that non-zero boundary conditions are only 
!   possibly given at the highest resolutions (As only the 
!   'residual omega' is solved at lower resolutions)

    do i=1,nres
       if(i.eq.1)then
          call coarsen3d(boundaries(:,:,:,1),boundaries(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       else
          call coarsen3d(zero(:,:,:,1),boundaries(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       endif
       call coarsen3d(zero(:,:,:,1),zero(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(sigma(:,:,:,1),sigma(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(feta(:,:,:,1),feta(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(d2zetadp(:,:,:,1),d2zetadp(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(dudp(:,:,:,1),dudp(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(dvdp(:,:,:,1),dvdp(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(corfield(:,:,:,1),corfield(:,:,:,i),nlon,nlat,nlev,nlonx(i),nlatx(i),nlevx(i))
       call coarsen3d(sigma0(:,1),sigma0(:,i),1,1,nlev,1,1,nlevx(i))
    enddo

! *************************************************************************
! ***** Solving for omega, using the forcing and the LHS coefficients *****    
! ***** and possibly boundary conditions **********************************
! *************************************************************************

!      1) Test cases ('T','t'): only one forcing ('ftest') is used, but
!         the results are written out for every resolution.
!      2) Other cases: the vertical motion associated with each individual
!         forcing term + boundary conditions is written out separately
!         (-> 2 + 1 = 3 terms for QG omega, 5 + 1 terms for generalized 
!         omega) 
!
!       iunit=1

    if(mode.eq.'T')then
       call callsolvegen(ftest,boundaries,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,sigma,feta,corfield,d2zetadp,dudp,dvdp,nres,alfa,toler,ny1,ny2)
    endif

    if(mode.eq.'t')then
       call callsolveQG(ftest,boundaries,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,feta,nres,alfa,toler)
    endif

    if(mode.eq.'G')then            

       do i=1,5
          call callsolvegen(rhs(:,:,:,:,i),zero,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
               sigma0,sigma,feta,corfield,d2zetadp,dudp,dvdp,nres,alfa,toler,ny1,ny2)
          omegas(:,:,:,i)=omega(:,:,:,1)
       enddo
       
       if (calc_b) then
          !       Write(*,*)'Boundary conditions'        
          call callsolvegen(zero,boundaries,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
               sigma0,sigma,feta,corfield,d2zetadp,dudp,dvdp,nres,alfa,toler,ny1,ny2)
          omegas(:,:,:,8)=omega(:,:,:,1)
       end if

       call callsolvegen(rhs(:,:,:,:,termvkhi),zero,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,sigma,feta,corfield,d2zetadp,dudp,dvdp,nres,alfa,toler,ny1,ny2)
       omegas(:,:,:,termvkhi)=omega(:,:,:,1)
       call callsolvegen(rhs(:,:,:,:,termtkhi),zero,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,sigma,feta,corfield,d2zetadp,dudp,dvdp,nres,alfa,toler,ny1,ny2)
       omegas(:,:,:,termtkhi)=omega(:,:,:,1)
    endif

    if(mode.eq.'Q')then
       do i=1,2
          call callsolveQG(rhs(:,:,:,:,i),zero,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,feta,nres,alfa,toler)
          omegas_QG(:,:,:,i)=omega(:,:,:,1)
       enddo

!       Write(*,*)'Boundary conditions'        
       call callsolveQG(zero,boundaries,omega,nlonx,nlatx,nlevx,dx2,dy2,dlev2,&
            sigma0,feta,nres,alfa,toler)
       omegas_QG(:,:,:,3)=omega(:,:,:,1)

    endif

  end associate

  end subroutine calculate_omegas

end module mod_omega
