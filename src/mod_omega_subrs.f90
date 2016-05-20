module mod_omega_subrs
  use mod_const
  use mod_common_subrs
  implicit none

contains

!
!****************** SUBROUTINES **************************************************
!

  subroutine coarsen3D(f,g,nlon1,nlat1,nlev1,nlon2,nlat2,nlev2)
!
!      Averages the values of field f (grid size nlon1 x nlat1 x nlev1) over larger
!      grid boxes (grid size nlon2 x nlat2 x nlev2), to field g

!      To keep the algorithm
!      simple, only 0/1 weights are used -> works only well if
!      div(nlon1/nlon2)=div(nlat1/nlat2)=div(nlev1/nlev2)
!
    implicit none
    integer nlon1,nlat1,nlon2,nlat2,nlev1,nlev2
    real f(nlon1,nlat1,nlev1),g(nlon2,nlat2,nlev2)
    integer i,i2,j,j2,k,k2,imin,imax,jmin,jmax,kmin,kmax
    real fsum
    
    do i2=1,nlon2
       imin=nint((i2-1)*real(nlon1)/real(nlon2)+1)
         imax=nint(i2*real(nlon1)/real(nlon2))
         do j2=1,nlat2
           jmin=nint((j2-1)*real(nlat1)/real(nlat2)+1)
           jmax=nint(j2*real(nlat1)/real(nlat2))
           do k2=1,nlev2
              kmin=nint((k2-1)*real(nlev1)/real(nlev2)+1)
              kmax=nint(k2*real(nlev1)/real(nlev2))
              fsum=0.
              do i=imin,imax
              do j=jmin,jmax
              do k=kmin,kmax
                 fsum=fsum+f(i,j,k)
              enddo
              enddo 
              enddo
              g(i2,j2,k2)=fsum/((imax-imin+1)*(jmax-jmin+1)*(kmax-kmin+1))
           enddo
         enddo 
       enddo

       return
       end subroutine coarsen3D

  subroutine finen3D(f,g,nlon1,nlat1,nlev1,nlon2,nlat2,nlev2)
!
!      Distributes the values of field f (grid size nlon2 x nlat2 x nlev2) to a
!      finer grid g (grid size nlon1 x nlat1 x nlev1), assuming that f is
!      constant in each grid box of the original grid 
!
!      ** PERHAPS THIS SHOULD BE REPLACED BY BILINEAR INTERPOLATION 
!      ** TO AVOID ARTIFICIAL JUMPS

       implicit none
       integer nlon1,nlat1,nlev1,nlon2,nlat2,nlev2
       real f(nlon2,nlat2,nlev2),g(nlon1,nlat1,nlev1)
       integer i,i2,j,j2,k,k2,imin,imax,jmin,jmax,kmin,kmax

       do i2=1,nlon2
         imin=nint((i2-1)*real(nlon1)/real(nlon2)+1)
         imax=nint(i2*real(nlon1)/real(nlon2))
         do j2=1,nlat2
           jmin=nint((j2-1)*real(nlat1)/real(nlat2)+1)
           jmax=nint(j2*real(nlat1)/real(nlat2))
           do k2=1,nlev2
             kmin=nint((k2-1)*real(nlev1)/real(nlev2)+1)
             kmax=nint(k2*real(nlev1)/real(nlev2))
              do i=imin,imax
              do j=jmin,jmax
              do k=kmin,kmax
                 g(i,j,k)=f(i2,j2,k2)
              enddo 
              enddo
              enddo
           enddo
         enddo 
       enddo

       return
       end subroutine finen3D

  subroutine gwinds(z,dx,dy,corpar,u,v)
!
!      Calculation of geostrophic winds (u,v) from z. At the equator, mean of
!      the two neighbouring latitudes is used (should not be a relevant case).
!
    implicit none

    real,dimension(:,:,:),intent(in) :: z
    real,dimension(:,:,:),intent(out) :: u,v
    real,dimension(:),intent(in) :: corpar
    real,intent(in) :: dx,dy
    integer :: nlon,nlat,nlev,i,j,k
    real,dimension(:,:,:),allocatable :: dzdx,dzdy

    nlon=size(u,1)
    nlat=size(u,2)
    nlev=size(u,3)
    allocate(dzdx(nlon,nlat,nlev),dzdy(nlon,nlat,nlev))

    call xder_cart(z,dx,dzdx) 
    call yder_cart(z,dy,dzdy) 

    do k=1,nlev
       do j=1,nlat
          if(abs(corpar(j)).gt.1e-7)then
             do i=1,nlon
                u(i,j,k)=-g*dzdy(i,j,k)/corpar(j) 
                v(i,j,k)=g*dzdx(i,j,k)/corpar(j) 
             enddo
          endif
       enddo
       do j=1,nlat
          if(abs(corpar(j)).lt.1e-7)then
             do i=1,nlon
                u(i,j,k)=(u(i,j+1,k)+u(i,j-1,k))/2.
                v(i,j,k)=(v(i,j+1,k)+v(i,j-1,k))/2.
             enddo
          endif
       enddo
    enddo

  end subroutine gwinds

  subroutine modify(sigmaraw,sigmamin,etamin,zetaraw,&
                        corpar,dudp,dvdp,sigma,feta,zeta)      
!
!      Modifying stability and vorticity to keep the LHS of the genearlized
!      omega equation elliptic
!
    implicit none

    real,dimension(:,:,:),intent(in) :: sigmaraw,zetaraw,dudp,dvdp
    real,dimension(:),intent(in) :: corpar
    real,dimension(:,:,:),intent(inout) :: zeta,feta,sigma
    real,intent(in) :: sigmamin,etamin
    integer :: nlon,nlat,nlev,i,j,k
    
    nlon=size(sigmaraw,1)
    nlat=size(sigmaraw,2)
    nlev=size(sigmaraw,3)
     
    do k=1,nlev
       do j=1,nlat
          do i=1,nlon
             sigma(i,j,k)=max(sigmaraw(i,j,k),sigmamin)
             zeta(i,j,k)=0.
             ! Northern Hemisphere
             if(corpar(j).gt.1e-7)then
                zeta(i,j,k)=max(zetaraw(i,j,k),etamin+corpar(j)/ &
                            (4*sigma(i,j,k))*(dudp(i,j,k)**2.+dvdp(i,j,k)**2.) &
                            -corpar(j))
             endif
             ! Southern Hemisphere
             if(corpar(j).lt.-1e-7)then
                zeta(i,j,k)=min(zetaraw(i,j,k),-etamin+corpar(j)/ &
                            (4*sigma(i,j,k))*(dudp(i,j,k)**2.+dvdp(i,j,k)**2.) &
                            -corpar(j))
             endif
             feta(i,j,k)=(zeta(i,j,k)+corpar(j))*corpar(j)
          enddo
       enddo
    enddo

  end subroutine modify

      subroutine aave(f,nlon,nlat,res)                      
!
!     Calculation of area mean (res) of field f in cartesian coordinates.
!     Simplest possible way.
!
      implicit none
      integer i,j,nlon,nlat
      real f(nlon,nlat),res,sum,wsum
!      do k=1,nlev
      sum=0
      wsum=0
      do j=1,nlat
      do i=1,nlon
        sum=sum+f(i,j)
        wsum=wsum+1.
      enddo 
      enddo
      res=sum/wsum
!      enddo

      return
      end subroutine aave

  subroutine fvort(u,v,zeta,corpar,dx,dy,dp,mulfact,fv)
!
!     Calculation of vorticity advection forcing
!     Input: u,v,zeta
!     Output: stored in "fv"
!
    implicit none
    real,dimension(:,:,:),intent(in) :: u,v,zeta,mulfact
    real,dimension(:,:,:),intent(out) :: fv
    real,dimension(:),intent(in) :: corpar
    real,dimension(:,:,:),allocatable :: eta,adv,dadvdp
    real,intent(in) :: dx,dy,dp
    integer :: i,j,k,nlon,nlat,nlev

    nlon=size(u,1)
    nlat=size(u,2)
    nlev=size(u,3)
    allocate(eta(nlon,nlat,nlev),adv(nlon,nlat,nlev))
    allocate(dadvdp(nlon,nlat,nlev))

    do k=1,nlev
       do j=1,nlat
          do i=1,nlon
             eta(i,j,k)=zeta(i,j,k)+corpar(j)
          enddo
       enddo
    enddo

    call advect_cart(u,v,eta,dx,dy,adv)
    adv=adv*mulfact
    call pder(adv,dp,dadvdp) 

    do k=1,nlev
       do j=1,nlat      
          do i=1,nlon
             fv(i,j,k)=corpar(j)*dadvdp(i,j,k)
          enddo
       enddo
    enddo

  end subroutine fvort

  subroutine ftemp(u,v,t,lev,dx,dy,mulfact,ft)
!
!     Calculation of temperature advection forcing
!     Input: u,v,t
!     Output: stored in "adv" (bad style ...)
!
    implicit none
    real,dimension(:,:,:),intent(in) :: u,v,t,mulfact
    real,dimension(:,:,:),intent(out) :: ft
    real,dimension(:),intent(in) :: lev
    real,intent(in) :: dx,dy
    real,dimension(:,:,:),allocatable :: adv,lapladv

    integer :: i,j,k,nlon,nlat,nlev

    nlon=size(u,1)
    nlat=size(u,2)
    nlev=size(u,3)
    allocate(adv(nlon,nlat,nlev),lapladv(nlon,nlat,nlev))

    call advect_cart(u,v,t,dx,dy,adv)
    adv=adv*mulfact
    call laplace_cart(adv,lapladv,dx,dy)         

    do k=1,nlev
       do j=1,nlat      
          do i=1,nlon
             ft(i,j,k)=lapladv(i,j,k)*r/lev(k)
          enddo
       enddo
    enddo

  end subroutine ftemp

      subroutine ffrict(fx,fy,corpar,dx,dy,dp,mulfact,ff)
!
!     Calculation of friction forcing
!     Input: fx,fy = x and y components of "friction force"
!     Output: res 
!
      implicit none
      real,dimension(:,:,:),intent(in) :: fx,fy,mulfact
      real,dimension(:),intent(in) :: corpar
      real,dimension(:,:,:),intent(out) :: ff
      real,dimension(:,:,:),allocatable :: fcurl,dcurldp
      real,intent(in) :: dx,dy,dp
      integer :: i,j,k,nlon,nlat,nlev

!       real fcurl(nlon,nlat,nlev),dcurldp(nlon,nlat,nlev),res(nlon,nlat,nlev)
!      real mulfact(nlon,nlat,nlev)

      nlon=size(fx,1)
    nlat=size(fx,2)
    nlev=size(fx,3)
    allocate(fcurl(nlon,nlat,nlev),dcurldp(nlon,nlat,nlev))

      call curl_cart(fx,fy,dx,dy,fcurl)
      fcurl=fcurl*mulfact
      call pder(fcurl,dp,dcurldp) 

      do k=1,nlev
      do j=1,nlat      
      do i=1,nlon
          ff(i,j,k)=-corpar(j)*dcurldp(i,j,k)
      enddo
      enddo
      enddo

      return
      end subroutine ffrict

      subroutine fdiab(q,nlon,nlat,nlev,lev,r,dx,dy,res,mulfact)
!
!     Calculation of diabatic heaging forcing
!     Input: q = diabatic temperature tendency (already normalized by cp)
!     Output: slightly illogically stored in "adv"
!
      implicit none
      integer i,j,k,nlon,nlat,nlev
      real dx,dy,r,lev(nlev)
      real q(nlon,nlat,nlev),res(nlon,nlat,nlev)
      real mulfact(nlon,nlat,nlev)

      q=q*mulfact
      call laplace_cart(q,res,dx,dy)         

      do k=1,nlev
      do j=1,nlat      
      do i=1,nlon
          res(i,j,k)=-r*res(i,j,k)/lev(k)
      enddo
      enddo
      enddo

      return
      end subroutine fdiab

      subroutine fimbal(dzetadt,dtdt,nlon,nlat,nlev,f,& 
                       r,lev,dx,dy,dp,ddpdzetadt,lapldtdt,res,mulfact)
!
!     Calculation of the FA ("imbalance") forcing term
!     Input: dzetadt, dtdt = vorticity & temperature tendencies
!     Output: res 
!
      implicit none
      integer i,j,k,nlon,nlat,nlev
      real dx,dy,dp,r,lev(nlev)
      real dzetadt(nlon,nlat,nlev),dtdt(nlon,nlat,nlev),f(nlat)
      real ddpdzetadt(nlon,nlat,nlev),lapldtdt(nlon,nlat,nlev),res(nlon,nlat,nlev)
      real mulfact(nlon,nlat,nlev)

      dzetadt=dzetadt*mulfact
      dtdt=dtdt*mulfact

      call pder(dzetadt,dp,ddpdzetadt) 
      call laplace_cart(dtdt,lapldtdt,dx,dy)         

      do k=1,nlev
      do j=1,nlat      
      do i=1,nlon
        ddpdzetadt(i,j,k)=f(j)*ddpdzetadt(i,j,k)
        res(i,j,k)=ddpdzetadt(i,j,k)+lapldtdt(i,j,k)*r/lev(k)
      enddo
      enddo
      enddo

      return
      end subroutine fimbal

       subroutine callsolveQG(rhs,boundaries,omega,omegaold,nlon,nlat,nlev,&
              dx,dy,dlev,sigma0,feta,laplome,domedp2,dum1,&
              coeff1,coeff2,coeff,resid,omega1,ny1,ny2,alfa, &
              nres,lzeromean)
!
!      Calling solveQG + writing out omega. Multigrid algorithm.
!
       implicit none
       integer i,j,k,nres,nlon(nres),nlat(nres),nlev(nres)
       real,intent(in) :: rhs(nlon(1),nlat(1),nlev(1),nres)
       real dx(nres),dy(nres),dlev(nres)       
       real boundaries(nlon(1),nlat(1),nlev(1),nres)
       real omega(nlon(1),nlat(1),nlev(1),nres),omegaold(nlon(1),nlat(1),nlev(1),nres) 
       real sigma0(nlev(1),nres)
       real feta(nlon(1),nlat(1),nlev(1),nres),coeff(nlon(1),nlat(1),nlev(1))
       real laplome(nlon(1),nlat(1),nlev(1))
       real domedp2(nlon(1),nlat(1),nlev(1)),dum1(nlon(1),nlat(1),nlev(1))              
       real coeff1(nlon(1),nlat(1),nlev(1)),coeff2(nlon(1),nlat(1),nlev(1))
       real resid(nlon(1),nlat(1),nlev(1)),omega1(nlon(1),nlat(1),nlev(1))      
       real alfa,maxdiff,toler
       integer itermax,ny1,ny2,ires
       logical lzeromean
       real aomega
       integer iter

       toler=5e-5 ! threshold for stopping iterations
       itermax=1000
       omega=0.
       omegaold=boundaries
!
!      The whole multigrid cycle is written explicitly here. Better as a separate subroutine?  
!
!----------------------------------------------------------------------------------------
       do iter=1,itermax  ! Each iteration = one (fine->coarse->fine) multigrid cycle
!
!      Loop from finer to coarser resolutions
!
       do ires=1,nres
!         write(*,*)'fine-coarse:iter,ires',iter,ires
         call solveQG(rhs(1,1,1,ires),boundaries(1,1,1,ires),& 
             omega(1,1,1,ires),omegaold(1,1,1,ires),nlon(ires),nlat(ires),nlev(ires),&
             dx(ires),dy(ires),dlev(ires),sigma0(1,ires),feta(1,1,1,ires),&
             laplome,domedp2,coeff1,coeff2,coeff,&
             ny1,alfa,.true.,resid)
         if(ires.eq.1)omega1(:,:,:)=omega(:,:,:,1)
         if(ires.lt.nres)then
            call coarsen3d(resid,rhs(1,1,1,ires+1),nlon(ires),nlat(ires),nlev(ires),&
                 nlon(ires+1),nlat(ires+1),nlev(ires+1))          
         endif  
       enddo         
!
!      Loop from coarser to finer resolutions
!
       do ires=nres-1,1,-1
!        write(*,*)'coarse-fine:iter,ires',iter,ires
         call finen3D(omega(1,1,1,ires+1),dum1,nlon(ires),nlat(ires),nlev(ires),& 
              nlon(ires+1),nlat(ires+1),nlev(ires+1))          
!        Without the underrelaxation (coefficient alfa), the solution diverges
         omegaold(:,:,:,ires)=omega(:,:,:,ires)+alfa*dum1(:,:,:)
!         if(ires.eq.1)then
!         write(*,*)'omega',ires,omega(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2,ires)
!         write(*,*)'dum1',ires,dum1(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2)
!         write(*,*)'omegaold',ires,omegaold(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2,ires)
!         endif

         call solveQG(rhs(1,1,1,ires),boundaries(1,1,1,ires),& 
             omega(1,1,1,ires),omegaold(1,1,1,ires),nlon(ires),nlat(ires),nlev(ires),&
             dx(ires),dy(ires),dlev(ires),sigma0(1,ires),feta(1,1,1,ires),&
             laplome,domedp2,coeff1,coeff2,coeff,&
             ny2,alfa,.false.,resid)
       enddo  

        maxdiff=0.
        do k=1,nlev(1)  
        do j=1,nlat(1)  
        do i=1,nlon(1)  
           maxdiff=max(maxdiff,abs(omega(i,j,k,1)-omega1(i,j,k)))
        enddo
        enddo
        enddo
        print*,iter,maxdiff
        if(maxdiff.lt.toler.or.iter.eq.itermax)then
          write(*,*)'iter,maxdiff',iter,maxdiff
          goto 10
        endif

        omegaold=omega
          
        enddo ! iter=1,itermax
 10     continue         
!----------------------------------------------------------------------------------------
!
!       Subtract the area mean of omega
!
         if(lzeromean)then
           do k=1,nlev(1) 
           call aave(omega(1,1,k,1),nlon(1),nlat(1),aomega)
           do j=1,nlat(1)
           do i=1,nlon(1)
             omega(i,j,k,1)=omega(i,j,k,1)-aomega
           enddo 
           enddo 
           enddo 
         endif

!        irec=irec+1
!        call WRIGRA2(omega,nlon(1)*nlat(1)*nlev(1),irec,iunit)

       return
       end subroutine callsolveQG

       subroutine solveQG(rhs,boundaries,omega,omegaold,nlon,nlat,nlev,&
              dx,dy,dlev,sigma0,feta,&
              laplome,domedp2,coeff1,coeff2,coeff,&
              niter,alfa,lres,resid)
!
!      Solving the QG omega equation using 'niter' iterations.
!
       implicit none

       real :: rhs(nlon,nlat,nlev)
       integer i,j,k,nlon,nlat,nlev
       real omegaold(nlon,nlat,nlev),omega(nlon,nlat,nlev)
       real boundaries(nlon,nlat,nlev) 
       real sigma0(nlev),feta(nlon,nlat,nlev)!,rhs(nlon,nlat,nlev) 
       real laplome(nlon,nlat,nlev),domedp2(nlon,nlat,nlev)        
       real coeff1(nlon,nlat,nlev),coeff2(nlon,nlat,nlev),coeff(nlon,nlat,nlev)
       real dx,dy,dlev,maxdiff,alfa
       integer niter
       logical lres
       real resid(nlon,nlat,nlev)       

       do j=1,nlat       
       do i=1,nlon         
         omegaold(i,j,1)=boundaries(i,j,1)
         omegaold(i,j,nlev)=boundaries(i,j,nlev)
       enddo
       enddo      
       do k=2,nlev-1
       do i=1,nlon
         omegaold(i,1,k)=boundaries(i,1,k)
         omegaold(i,nlat,k)=boundaries(i,nlat,k)
       enddo
       enddo     

       omega=omegaold

       do i=1,niter
       call updateQG(omegaold,omega,sigma0,feta,&
            rhs,nlon,nlat,nlev, &
            dx,dy,dlev,maxdiff,laplome,domedp2,&
            coeff1,coeff2,coeff,alfa)
       enddo

       if(lres)then
             call residQG(rhs,omega,resid,sigma0,feta,&
             nlon,nlat,nlev,dx,dy,dlev,laplome,domedp2)
       endif

       return
       end subroutine solveQG

       subroutine updateQG(omegaold,omega,sigma,etasq,rhs,nlon,nlat,nlev, &
            dx,dy,dlev,maxdiff,lapl2,domedp2,coeff1,coeff2,coeff,alfa)
!
!      New estimate for the local value of omega, using omega in the 
!      surrounding points and the right-hand-side forcing (rhs)
!
!      QG version: for 'sigma' and 'etasq', constant values from the QG theory
!      are used.
! 
       implicit none

       real :: rhs(nlon,nlat,nlev)
       integer i,j,k,nlon,nlat,nlev
       real omegaold(nlon,nlat,nlev),omega(nlon,nlat,nlev) 
       real sigma(nlev),etasq(nlon,nlat,nlev)!,rhs(nlon,nlat,nlev) 
       real lapl2(nlon,nlat,nlev),domedp2(nlon,nlat,nlev)        
       real coeff1(nlon,nlat,nlev),coeff2(nlon,nlat,nlev),coeff(nlon,nlat,nlev)
       real dx,dy,dlev,maxdiff,alfa
!
!      Top and bottom levels: omega directly from the boundary conditions,
!      does not need to be solved.
!
       call laplace2_cart(omegaold,lapl2,coeff1,nlon,nlat,nlev,dx,dy)
       call p2der2(omegaold,domedp2,coeff2,nlon,nlat,nlev,dlev) 

!       write(*,*)'Calculate the coefficients'
!       write(*,*)nlon,nlat,nlev
!       write(*,*)'coeff(nlon,nlat,nlev-1)',coeff(nlon,nlat,nlev-1)
!       write(*,*)'coeff1(nlon,nlat,nlev-1)',coeff1(nlon,nlat,nlev-1)
!       write(*,*)'coeff2(nlon,nlat,nlev-1)',coeff2(nlon,nlat,nlev-1)
!       write(*,*)'sigma(nlon,nlat,nlev-1)',sigma(nlon,nlat,nlev-1)
!       write(*,*)'domedp2(nlon,nlat,nlev-1)',domedp2(nlon,nlat,nlev-1)
!       write(*,*)'lapl2(nlon,nlat,nlev-1)',lapl2(nlon,nlat,nlev-1)
!       write(*,*)'etasq(nlon,nlat,nlev-1)',etasq(nlon,nlat,nlev-1)

       do k=2,nlev-1
       do j=2,nlat-1
       do i=1,nlon
         coeff(i,j,k)=sigma(k)*coeff1(i,j,k)+etasq(i,j,k)*coeff2(i,j,k)
         omega(i,j,k)=(rhs(i,j,k)-sigma(k)*lapl2(i,j,k)-etasq(i,j,k)*domedp2(i,j,k)) &
         /coeff(i,j,k) 
       enddo
       enddo
       enddo

!       write(*,*)'Updating omega'
       maxdiff=0.
       do k=2,nlev-1
       do j=2,nlat-1
       do i=1,nlon
         maxdiff=max(maxdiff,abs(omega(i,j,k)-omegaold(i,j,k)))
         omegaold(i,j,k)=alfa*omega(i,j,k)+(1-alfa)*omegaold(i,j,k)
       enddo
       enddo
       enddo

       return
       end subroutine updateQG


       subroutine residQG(rhs,omega,resid,sigma,etasq,nlon,nlat,nlev,&
            dx,dy,dlev,laplome,domedp2)
!
!      Calculating the residual RHS - LQG(omega)
!      
!      Variables:
!
!      omega = approximation for omega
!      sigma = local values of sigma (*after modifying for ellipticity*)
!      feta = f*eta (*after modifying for ellipticity*)
!      f = coriolis parameter
!      d2zetadp = second pressure derivative of relative vorticity 
!      dudp,dvdp = pressure derivatives of wind components
!      rhs = right-hand-side forcing
!
       implicit none

       real:: rhs(nlon,nlat,nlev)
       integer i,j,k,nlon,nlat,nlev
       real omega(nlon,nlat,nlev),resid(nlon,nlat,nlev) 
       real sigma(nlev),etasq(nlon,nlat,nlev)
       real laplome(nlon,nlat,nlev),domedp2(nlon,nlat,nlev)        
       real dx,dy,dlev

       call laplace_cart(omega,laplome,dx,dy)         
       call p2der(omega,dlev,domedp2) 
 
       do k=1,nlev
       do j=1,nlat
       do i=1,nlon
         resid(i,j,k)=rhs(i,j,k)-(sigma(k)*laplome(i,j,k)+etasq(i,j,k)*domedp2(i,j,k))
!         if(i.eq.nlon/2.and.j.eq.nlat/2.and.k.eq.nlev/2)write(*,*)'rhs,resid',rhs(i,j,k),resid(i,j,k)
       enddo
       enddo
       enddo

       return
       end subroutine residQG


       subroutine callsolvegen(rhs,boundaries,omega,omegaold,nlon,nlat,nlev,&
              dx,dy,dlev,sigma0,sigma,feta,corpar,d2zetadp,dudp,dvdp,&
              laplome,domedp2,coeff1,coeff2,coeff,dum0,dum1,dum2,dum3,&
              dum4,dum5,dum6,resid,omega1,ny1,ny2,alfa,&
              nres,lzeromean)
!
!      Calling solvegen + writing out omega. Multigrid algorithm
!            
       implicit none
       integer i,j,k,nres,nlon(nres),nlat(nres),nlev(nres)
       real dx(nres),dy(nres),dlev(nres)       
       real rhs(nlon(1),nlat(1),nlev(1),nres),boundaries(nlon(1),nlat(1),nlev(1),nres)
       real omega(nlon(1),nlat(1),nlev(1),nres),omegaold(nlon(1),nlat(1),nlev(1),nres) 
       real sigma0(nlev(1),nres),sigma(nlon(1),nlat(1),nlev(1),nres)
       real feta(nlon(1),nlat(1),nlev(1),nres),corpar(nlat(1),nres)
       real d2zetadp(nlon(1),nlat(1),nlev(1),nres),dudp(nlon(1),nlat(1),nlev(1),nres),dvdp(nlon(1),nlat(1),nlev(1),nres)
       real laplome(nlon(1),nlat(1),nlev(1)),domedp2(nlon(1),nlat(1),nlev(1))        
       real coeff1(nlon(1),nlat(1),nlev(1)),coeff2(nlon(1),nlat(1),nlev(1)),coeff(nlon(1),nlat(1),nlev(1))
       real dum0(nlon(1),nlat(1),nlev(1)),dum1(nlon(1),nlat(1),nlev(1)),dum2(nlon(1),nlat(1),nlev(1))
       real dum3(nlon(1),nlat(1),nlev(1)),dum4(nlon(1),nlat(1),nlev(1)),dum5(nlon(1),nlat(1),nlev(1))
       real dum6(nlon(1),nlat(1),nlev(1))      
       real resid(nlon(1),nlat(1),nlev(1)),omega1(nlon(1),nlat(1),nlev(1))      
       real alfa,maxdiff,toler
       integer itermax,ny1,ny2,ires,iter
       logical lzeromean
       real aomega
 
       toler=5e-5 ! threshold for stopping iterations
       itermax=1000
       omega=0.
       omegaold=boundaries
!
!      This far: the whole multigrid cycle is written explicitly here  
!
!------------------------------------------------------------------------------------------
!
       do iter=1,itermax  ! Each iteration = one (fine->coarse->fine) multigrid cycle
!
!      Loop from finer to coarser resolutions
!
       do ires=1,nres
!         write(*,*)'fine-coarse:iter,ires',iter,ires
         call solvegen(rhs(1,1,1,ires),boundaries(1,1,1,ires),& 
             omega(1,1,1,ires),omegaold(1,1,1,ires),nlon(ires),nlat(ires),nlev(ires),&
             dx(ires),dy(ires),dlev(ires),sigma0(1,ires),sigma(1,1,1,ires),&
             feta(1,1,1,ires),corpar(1,ires),&
             d2zetadp(1,1,1,ires),dudp(1,1,1,ires),dvdp(1,1,1,ires),&
             laplome,domedp2,coeff1,coeff2,coeff,dum0,dum1,dum2,dum3,&
             dum4,dum5,dum6,ny1,alfa,.true.,resid)
!             write(*,*)'ires,omega',ires,omega(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2,1)
!             write(*,*)'ires,resid',ires,resid(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2)
         if(ires.eq.1)omega1(:,:,:)=omega(:,:,:,1)
         if(ires.lt.nres)then
            call coarsen3d(resid,rhs(1,1,1,ires+1),nlon(ires),nlat(ires),nlev(ires),&
                 nlon(ires+1),nlat(ires+1),nlev(ires+1))          
!             write(*,*)'ires,rhs',ires,rhs(nlon(ires+1)/2,nlat(ires+1)/2,nlev(ires+1)/2,ires)
         endif  
       enddo         
!
!      Loop from coarser to finer resolutions
!
       do ires=nres-1,1,-1
 !        write(*,*)'coarse-fine:iter,ires',iter,ires
         call finen3D(omega(1,1,1,ires+1),dum1,nlon(ires),nlat(ires),nlev(ires),& 
              nlon(ires+1),nlat(ires+1),nlev(ires+1))          
!      Without the underrelaxation (coeffient alfa) the soultion diverges
          omegaold(:,:,:,ires)=omega(:,:,:,ires)+alfa*dum1(:,:,:)
!         if(ires.eq.1)then
!         write(*,*)'omega',ires,omega(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2,ires)
!         write(*,*)'dum1',ires,dum1(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2)
!         write(*,*)'omegaold',ires,omegaold(nlon(ires)/2,nlat(ires)/2,nlev(ires)/2,ires)
!         endif

         call solvegen(rhs(1,1,1,ires),boundaries(1,1,1,ires),& 
             omega(1,1,1,ires),omegaold(1,1,1,ires),nlon(ires),nlat(ires),nlev(ires),&
             dx(ires),dy(ires),dlev(ires),sigma0(1,ires),sigma(1,1,1,ires),&
             feta(1,1,1,ires),corpar(1,ires),&
             d2zetadp(1,1,1,ires),dudp(1,1,1,ires),dvdp(1,1,1,ires),&
             laplome,domedp2,coeff1,coeff2,coeff,dum0,dum1,dum2,dum3,&
             dum4,dum5,dum6,ny2,alfa,.false.,resid)
       enddo  

        maxdiff=0.
        do k=1,nlev(1)  
        do j=1,nlat(1)  
        do i=1,nlon(1)  
          maxdiff=max(maxdiff,abs(omega(i,j,k,1)-omega1(i,j,k)))
        enddo
        enddo
        enddo
        write(*,*)iter,maxdiff
        if(maxdiff.lt.toler.or.iter.eq.itermax)then
          write(*,*)'iter,maxdiff',iter,maxdiff
          goto 10
        endif

        omegaold=omega
          
        enddo ! iter=1,itermax
 10     continue
!----------------------------------------------------------------------------------

!       Subtracting area mean of omega
         if(lzeromean)then
           do k=1,nlev(1) 
           call aave(omega(1,1,k,1),nlon(1),nlat(1),aomega)
           do j=1,nlat(1)
           do i=1,nlon(1)
             omega(i,j,k,1)=omega(i,j,k,1)-aomega
           enddo 
           enddo 
           enddo 
         endif

!        irec=irec+1
!         call WRIGRA2(omega,nlon(1)*nlat(1)*nlev(1),irec,iunit)

       return
       end subroutine callsolvegen
 

       subroutine solvegen(rhs,boundaries,omega,omegaold,nlon,nlat,nlev,&
              dx,dy,dlev,sigma0,sigma,feta,corpar,d2zetadp,dudp,dvdp,&
              laplome,domedp2,coeff1,coeff2,coeff,dum0,dum1,dum2,dum3,&
              dum4,dum5,dum6,niter,alfa,lres,resid)
!
!      Solving omega iteratively using the generalized LHS operator.
!      'niter' iterations with relaxation coefficient alfa
!               
!      Input:
!
!      rhs = right-hand-side forcing
!      boundaries = boundary conditions 
!      omegaold,omega = old and new omega
!      sigma0 = area means of sigma at each pressure level
!      sigma = local values of sigma (*after modifying for ellipticity*)
!      feta = f*eta (*after modifying for ellipticity*)
!      f = coriolis parameter
!      d2zetadp = second pressure derivative of relative vorticity 
!      dudp,dvdp = pressure derivatives of wind components
!      rhs = right-hand-side forcing
!
!      output:
!
!      omega 
!      resid (if (lres))
!
       implicit none

       integer i,j,k,nlon,nlat,nlev
       real omegaold(nlon,nlat,nlev),omega(nlon,nlat,nlev) 
       real sigma(nlon,nlat,nlev),feta(nlon,nlat,nlev),rhs(nlon,nlat,nlev) 
       real boundaries(nlon,nlat,nlev) 
       real sigma0(nlev),corpar(nlat)
       real d2zetadp(nlon,nlat,nlev),dudp(nlon,nlat,nlev),dvdp(nlon,nlat,nlev)
       real laplome(nlon,nlat,nlev),domedp2(nlon,nlat,nlev)        
       real coeff1(nlon,nlat,nlev),coeff2(nlon,nlat,nlev),coeff(nlon,nlat,nlev)
       real dx,dy,dlev,maxdiff
       real dum0(nlon,nlat,nlev),dum1(nlon,nlat,nlev),dum2(nlon,nlat,nlev)
       real dum3(nlon,nlat,nlev),dum4(nlon,nlat,nlev),dum5(nlon,nlat,nlev)
       real dum6(nlon,nlat,nlev)    
       real resid(nlon,nlat,nlev)  
       real alfa
       integer niter
       logical lres

!       omegaold=boundaries

       do j=1,nlat       
       do i=1,nlon
         omegaold(i,j,1)=boundaries(i,j,1)
         omegaold(i,j,nlev)=boundaries(i,j,nlev)
       enddo
       enddo      
       do k=2,nlev-1
       do i=1,nlon
         omegaold(i,1,k)=boundaries(i,1,k)
         omegaold(i,nlat,k)=boundaries(i,nlat,k)
       enddo
       enddo     

       omega=omegaold

!       write(*,*)'Boundary conditions given'

       do i=1,niter
       call updategen(omegaold,omega,sigma0,sigma,feta,corpar,&
            d2zetadp,dudp,dvdp,rhs,nlon,nlat,nlev, &
            dx,dy,dlev,maxdiff,laplome,domedp2,&
            coeff1,coeff2,coeff,dum0,dum1,dum3,dum4,dum5,dum6,alfa)
       enddo
!
!      Calculate the residual = RHS - L(omega)

       if(lres)then
         call residgen(rhs,omega,resid,&
            sigma,feta,corpar,d2zetadp,dudp,dvdp,nlon,nlat,nlev, &
            dx,dy,dlev,dum0,dum1,dum2,dum3,dum4,dum5,dum6)
       endif

       return
       end subroutine solvegen

       subroutine updategen(omegaold,omega, &
            sigma0,sigma,feta,f,d2zetadp,dudp,dvdp,rhs,nlon,nlat,nlev, &
            dx,dy,dlev,maxdiff,lapl2,domedp2,coeff1,coeff2,coeff, &
            dum0,dum1,dum3,dum4,dum5,dum6,alfa)
!
!      Calculating new local values of omega, based on omega in the
!      surrounding points and the right-hand-side forcing (rhs).
!      
!      The left-hand-side of the omega equation as in (Räisänen 1995),
!      but terms reorganised following Pauley & Nieman (1992)
!         
!      Variables:
!
!      omegaold,omega = old and new omega
!      sigma0 = area means of sigma at each pressure level
!      sigma = local values of sigma (*after modifying for ellipticity*)
!      feta = f*eta (*after modifying for ellipticity*)
!      f = coriolis parameter
!      d2zetadp = second pressure derivative of relative vorticity 
!      dudp,dvdp = pressure derivatives of wind components
!      rhs = right-hand-side forcing
!
       implicit none

       integer i,j,k,nlon,nlat,nlev
       real omegaold(nlon,nlat,nlev),omega(nlon,nlat,nlev) 
       real sigma(nlon,nlat,nlev),feta(nlon,nlat,nlev),rhs(nlon,nlat,nlev) 
       real sigma0(nlev),f(nlat)
       real d2zetadp(nlon,nlat,nlev),dudp(nlon,nlat,nlev),dvdp(nlon,nlat,nlev)
       real lapl2(nlon,nlat,nlev),domedp2(nlon,nlat,nlev)        
       real coeff1(nlon,nlat,nlev),coeff2(nlon,nlat,nlev),coeff(nlon,nlat,nlev)
       real dx,dy,dlev,maxdiff
       real dum0(nlon,nlat,nlev),dum1(nlon,nlat,nlev)
       real dum3(nlon,nlat,nlev),dum4(nlon,nlat,nlev),dum5(nlon,nlat,nlev)
       real dum6(nlon,nlat,nlev)      
       real alfa
!
!      Top and bottom levels: omega directly from the boundary conditions,
!      does not need to be solved.
!
       call laplace2_cart(omegaold,lapl2,coeff1,nlon,nlat,nlev,dx,dy)
       call p2der2(omegaold,domedp2,coeff2,nlon,nlat,nlev,dlev) 
!
!      Calculate non-constant terms on the left-hand-side, based on 'omegaold'
!
!       a) Deviation of sigma from its normal value

       do k=2,nlev-1
       do j=1,nlat
       do i=1,nlon
        dum0(i,j,k)=omegaold(i,j,k)*(sigma(i,j,k)-sigma0(k))
       enddo
       enddo
       enddo        
       call laplace_cart(dum0,dum1,dx,dy)         
!
!      b) f*omega*(d2zetadp): explicitly, later
!          
!      c) tilting
!
       call xder_cart(omegaold,dx,dum4) 
       call yder_cart(omegaold,dy,dum5) 
 
       do k=1,nlev
       do j=1,nlat
       do i=1,nlon
         dum6(i,j,k)=f(j)*(dudp(i,j,k)*dum5(i,j,k)-dvdp(i,j,k)*dum4(i,j,k))
       enddo
       enddo
       enddo        
       call pder(dum6,dlev,dum3) 
!
!      Solving for omega 
!      Old values are retained at y and z boundaries.
!       
       do k=2,nlev-1
       do j=2,nlat-1
       do i=1,nlon
         coeff(i,j,k)=sigma0(k)*coeff1(i,j,k)+feta(i,j,k)*coeff2(i,j,k)-f(j)*d2zetadp(i,j,k)
         omega(i,j,k)=(rhs(i,j,k)-dum1(i,j,k)-dum3(i,j,k)-sigma0(k)*lapl2(i,j,k)-feta(i,j,k)*domedp2(i,j,k)) &
         /coeff(i,j,k)
       enddo
       enddo
       enddo

!       write(*,*)'updating omega'
       maxdiff=0.
       do k=2,nlev-1
       do j=2,nlat-1
       do i=1,nlon
         maxdiff=max(maxdiff,abs(omega(i,j,k)-omegaold(i,j,k)))
         omegaold(i,j,k)=alfa*omega(i,j,k)+(1-alfa)*omegaold(i,j,k)
       enddo
       enddo
       enddo

       return
       end subroutine updategen

       subroutine residgen(rhs,omega,resid, &
            sigma,feta,f,d2zetadp,dudp,dvdp,nlon,nlat,nlev, &
            dx,dy,dlev,dum0,dum1,dum2,dum3,dum4,dum5,dum6)
!
!      Calculating the residual RHS - L(omega)
!      
!      Variables:
!
!      omega = approximation for omega
!      sigma = local values of sigma (*after modifying for ellipticity*)
!      feta = f*eta (*after modifying for ellipticity*)
!      f = coriolis parameter
!      d2zetadp = second pressure derivative of relative vorticity 
!      dudp,dvdp = pressure derivatives of wind components
!      rhs = right-hand-side forcing
!
       implicit none

       integer i,j,k,nlon,nlat,nlev
       real rhs(nlon,nlat,nlev),omega(nlon,nlat,nlev),resid(nlon,nlat,nlev) 
       real f(nlat)
       real sigma(nlon,nlat,nlev),feta(nlon,nlat,nlev)
       real d2zetadp(nlon,nlat,nlev),dudp(nlon,nlat,nlev),dvdp(nlon,nlat,nlev)
       real dx,dy,dlev
       real dum0(nlon,nlat,nlev),dum1(nlon,nlat,nlev),dum2(nlon,nlat,nlev)
       real dum3(nlon,nlat,nlev),dum4(nlon,nlat,nlev),dum5(nlon,nlat,nlev)
       real dum6(nlon,nlat,nlev)      
!
!      Calculate L(omega)

!       a) nabla^2(sigma*omega)

       dum0=omega*sigma

       call laplace_cart(dum0,dum1,dx,dy)         
!
!      f*eta*d2omegadp
!       
       call p2der(omega,dlev,dum2) 
!
       dum3=feta*dum2
!
!      c) -f*omega*(d2zetadp): explicitly, later
!                  
!      d) tilting
!
       call xder_cart(omega,dx,dum4) 
       call yder_cart(omega,dy,dum5) 
 
       do k=1,nlev
       do j=1,nlat
       do i=1,nlon
         dum6(i,j,k)=f(j)*(dudp(i,j,k)*dum5(i,j,k)-dvdp(i,j,k)*dum4(i,j,k))
       enddo
       enddo
       enddo        
       call pder(dum6,dlev,dum2) 

       do k=1,nlev
       do j=1,nlat
       do i=1,nlon
         resid(i,j,k)=rhs(i,j,k)-(dum1(i,j,k)+dum2(i,j,k)+dum3(i,j,k)-f(j)*d2zetadp(i,j,k)*omega(i,j,k))
       enddo
       enddo
       enddo

       return
       end subroutine residgen

       subroutine laplace2_cart(f,lapl2,coeff,nlon,nlat,nlev,dx,dy)
!
!      As laplace_cart but
!        - the contribution of the local value to the Laplacian is left out
!        - coeff is the coefficient for the local value
!
       integer i,i1,i2,j,k,nlon,nlat,nlev
       real f(nlon,nlat,nlev),lapl2(nlon,nlat,nlev),coeff(nlon,nlat,nlev)
       double precision d2fdy,d2fdx
       real dx,dy

       do k=1,nlev
       do i=1,nlon 
         i1=i-1
         i2=i+1
         if(i1.lt.1)i1=i1+nlon
         if(i2.gt.nlon)i2=i2-nlon
         do j=2,nlat-1
            d2fdx=(f(i2,j,k)+f(i1,j,k))/(dx**2.)
            if(j.gt.1.and.j.lt.nlat)then
               d2fdy=(f(i,j+1,k)+f(i,j-1,k))/(dy**2.)
               lapl2(i,j,k)=d2fdx+d2fdy
               coeff(i,j,k)=-2/(dy**2.)-2/(dx**2.)
            else
               lapl2(i,j,k)=d2fdx
               coeff(i,j,k)=-2/(dx**2.)
            endif
         enddo
       enddo 
       enddo
 
       return
       end subroutine laplace2_cart

  subroutine p2der(f,dp,df2dp2) 
!
!      Estimation of second pressure derivatives.
!      At top and bottom levels, these are set to zero
!
    implicit none
    real,dimension(:,:,:),intent(in) :: f
    real,dimension(:,:,:),intent(out) :: df2dp2
    real,intent(in) :: dp
    integer :: i,j,k,nlon,nlat,nlev

    nlon=size(f,1)
    nlat=size(f,2)
    nlev=size(f,3)
    
   do i=1,nlon
      do j=1,nlat
         do k=2,nlev-1
            df2dp2(i,j,k)=(f(i,j,k+1)+f(i,j,k-1)-2*f(i,j,k))/(dp*dp)
         enddo
         df2dp2(i,j,1)=0.
         df2dp2(i,j,nlev)=0.
      enddo
   enddo

 end subroutine p2der

       subroutine p2der2(f,df2dp22,coeff,nlon,nlat,nlev,dp) 
!
!      As p2der, but
!        - the contribution of the local value is left out
!        - the coefficient 'coeff' of the local value is also calculated        
!
       implicit none
       integer i,j,k,nlon,nlat,nlev
       real f(nlon,nlat,nlev),df2dp22(nlon,nlat,nlev),coeff(nlon,nlat,nlev),dp 
       do i=1,nlon
       do j=1,nlat
       do k=2,nlev-1
         df2dp22(i,j,k)=(f(i,j,k+1)+f(i,j,k-1))/(dp*dp)
         coeff(i,j,k)=-2/(dp*dp)
       enddo
       df2dp22(i,j,1)=0.
       df2dp22(i,j,nlev)=0.
       coeff(i,j,1)=0.
       coeff(i,j,nlev)=0.
 
       enddo
       enddo
       return
       end subroutine p2der2      


!************ SUBROUTINES NOT CURRENTLY USED ****************************************

       subroutine coarsen3dbil(f,g,nlon1,nlat1,nlev1,nlon2,nlat2,nlev2)
!
!      DOES NOT WORK, DON'T KNOW WHY (JR 230316)
!
!      Bilinear interpolation from grid 1 (nlon1,nlat1,nlev1)
!      to grid 2 (nlon2,nlat2,nlev2). Assumptions:
!       - all grids have even spacing in all directions
!       - the boundaries are located at x/y/z=0.5 and x/y/z=nlon1-2/nlat1-2/nlev1-2+0.5
!       - the domain is periodic is in the x direction but not in y and z
!      With these assumptions, only the grid sizes are needed as input,
!      not the actual coordinates 
!
       implicit none
       integer nlon1,nlat1,nlon2,nlat2,nlev1,nlev2
       real f(nlon1,nlat1,nlev1),g(nlon2,nlat2,nlev2)
       integer i,j,k
       real rx,ry,rz,rlon,rlat,rlev
       integer maxsiz
       parameter (maxsiz=1000)
       integer ii1(maxsiz),jj1(maxsiz),kk1(maxsiz),ii2(maxsiz),jj2(maxsiz),kk2(maxsiz)       
       real ai(maxsiz),aj(maxsiz),ak(maxsiz),bi(maxsiz),bj(maxsiz),bk(maxsiz)       

       rlon=real(nlon1)/real(nlon2) 
       rlat=real(nlat1)/real(nlat2) 
       rlev=real(nlev1)/real(nlev2) 
!
!      Tabulate coordinates and coefficients to speed up
!
       do i=1,nlon2          
         rx=0.5+rlon*(i-0.5)
         ii1(i)=int(rx)
         bi(i)=rx-ii1(i)
         if(ii1(i).lt.1)ii1(i)=nlon1
         ii2(i)=ii1(i)+1
         if(ii2(i).gt.nlon1)ii2(i)=1
         ai(i)=1-bi(i)

!         write(*,*)'Coarsen3dbil: i,ii1,ii2,ai,bi',i,ii1(i),ii2(i),ai(i),bi(i)
       enddo 

       do j=1,nlat2          
         ry=0.5+rlat*(j-0.5)
         jj1(j)=int(ry)
         jj2(j)=jj1(j)+1
         bj(j)=ry-jj1(j)
         if(jj1(j).lt.1)then
           jj1(j)=1
           bj(j)=0.
         endif
         if(jj2(j).gt.nlat1)then
           jj2(j)=nlat1
           bj(j)=1.
         endif
         aj(j)=1-bj(j)
!         write(*,*)'Coarsen3dbil: j,jj1,jj2,aj,bj',j,jj1(j),jj2(j),aj(j),bj(j)
       enddo 

       do k=1,nlev2          
         rz=0.5+rlev*(k-0.5)
         kk1(k)=int(rz)
         kk2(k)=kk1(k)+1
         bk(k)=rz-kk1(k)
         if(kk1(k).lt.1)then
           kk1(k)=1
           bk(k)=0.
         endif
         if(kk2(k).gt.nlev1)then
           kk2(k)=nlev1
         endif
         ak(k)=1-bk(k)

!         write(*,*)'Coarsen3dbil: k,kk1,kk2,ak,bk',k,kk1(k),kk2(k),ak(k),bk(k)
       enddo 

       do k=1,nlev2
       do j=1,nlat2
       do i=1,nlon2
            g(i,j,k)=ai(i)*aj(j)*ak(k)*f(ii1(i),jj1(j),kk1(k))+&
                     bi(i)*aj(j)*ak(k)*f(ii2(i),jj1(j),kk1(k))+&
                     ai(i)*bj(j)*ak(k)*f(ii1(i),jj2(j),kk1(k))+&
                     bi(i)*bj(j)*ak(k)*f(ii2(i),jj2(j),kk1(k))+&
                     ai(i)*aj(j)*bk(k)*f(ii1(i),jj1(j),kk2(k))+&
                     bi(i)*aj(j)*bk(k)*f(ii2(i),jj1(j),kk2(k))+&
                     ai(i)*bj(j)*bk(k)*f(ii1(i),jj2(j),kk2(k))+&
                     bi(i)*bj(j)*bk(k)*f(ii2(i),jj2(j),kk2(k))
       enddo
       enddo
       enddo

       return
       end subroutine coarsen3dbil

       subroutine finen3Dbil(f,g,nlon2,nlat2,nlev2,nlon1,nlat1,nlev1)
!
!      Bilinear interpolation from grid 1 (nlon1,nlat1,nlev1)
!      to grid 2 (nlon2,nlat2,nlev2). Assumptions:
!       - all grids have even spacing in all directions
!       - the boundaries are located at x/y/z=0.5 and x/y/z=nlon1-2/nlat1-2/nlev1-2+0.5
!       - the domain is periodic is in the x direction but not in y and z
!      With these assumptions, only the grid sizes are needed as input,
!      not the actual coordinates 
!
!      SAME AS COARSEN3DBIL, except for the order of the arguments
!
       implicit none
       integer nlon1,nlat1,nlon2,nlat2,nlev1,nlev2
       real f(nlon1,nlat1,nlev1),g(nlon2,nlat2,nlev2)
       integer i,j,k
       real rx,ry,rz,rlon,rlat,rlev
       integer maxsiz
       parameter (maxsiz=1000)
       integer ii1(maxsiz),jj1(maxsiz),kk1(maxsiz),ii2(maxsiz),jj2(maxsiz),kk2(maxsiz)       
       real ai(maxsiz),aj(maxsiz),ak(maxsiz),bi(maxsiz),bj(maxsiz),bk(maxsiz)       

       rlon=real(nlon1)/real(nlon2) 
       rlat=real(nlat1)/real(nlat2) 
       rlev=real(nlev1)/real(nlev2) 
!
!      Tabulate coordinates and coefficients to speed up
!
       do i=1,nlon2          
         rx=0.5+rlon*(i-0.5)
         ii1(i)=int(rx)
         bi(i)=rx-ii1(i)
         ai(i)=1-bi(i)
         if(ii1(i).lt.1)ii1(i)=nlon1
         ii2(i)=ii1(i)+1
         if(ii2(i).gt.nlon1)ii2(i)=1
!         write(*,*)'Finen3D: i,ii1,ii2,ai,bi',i,ii1(i),ii2(i),ai(i),bi(i)
       enddo 

       do j=1,nlat2          
         ry=0.5+rlat*(j-0.5)
         jj1(j)=int(ry)
         jj2(j)=jj1(j)+1
         bj(j)=ry-jj1(j)
         if(jj1(j).lt.1)then
           jj1(j)=1
           bj(j)=0.
         endif
         if(jj2(j).gt.nlat1)then
           jj2(j)=nlat1
           bj(j)=1.
         endif
         aj(j)=1-bj(j)
!         write(*,*)'Finen3Dbil: j,jj1,jj2,aj,bj',j,jj1(j),jj2(j),aj(j),bj(j)
       enddo 

       do k=1,nlev2          
         rz=0.5+rlev*(k-0.5)
         kk1(k)=int(rz)
         kk2(k)=kk1(k)+1
         bk(k)=rz-kk1(k)
         if(kk1(k).lt.1)then
           kk1(k)=1
           bk(k)=0.
         endif
         if(kk2(k).gt.nlev1)then
           kk2(k)=nlev1
           bk(k)=1.
         endif
         ak(k)=1-bk(k)

!         write(*,*)'Finen3Dbil: k,kk1,kk2,ak,bk',k,kk1(k),kk2(k),ak(k),bk(k)
       enddo 
      
       do k=1,nlev2
       do j=1,nlat2
       do i=1,nlon2
            g(i,j,k)=ai(i)*aj(j)*ak(k)*f(ii1(i),jj1(j),kk1(k))+&
                     bi(i)*aj(j)*ak(k)*f(ii2(i),jj1(j),kk1(k))+&
                     ai(i)*bj(j)*ak(k)*f(ii1(i),jj2(j),kk1(k))+&
                     bi(i)*bj(j)*ak(k)*f(ii2(i),jj2(j),kk1(k))+&
                     ai(i)*aj(j)*bk(k)*f(ii1(i),jj1(j),kk2(k))+&
                     bi(i)*aj(j)*bk(k)*f(ii2(i),jj1(j),kk2(k))+&
                     ai(i)*bj(j)*bk(k)*f(ii1(i),jj2(j),kk2(k))+&
                     bi(i)*bj(j)*bk(k)*f(ii2(i),jj2(j),kk2(k))
       enddo
       enddo
       enddo

       return
       end subroutine finen3Dbil

     end module mod_omega_subrs
