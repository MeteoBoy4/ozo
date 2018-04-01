module mod_common_subrs
  use mod_wrf_file
  implicit none
contains

!-------------------------------------------------------------------------------
! This module contains some general subroutines which can be used both
! generalized omega equation and Zwack-okossi equation.
!-------------------------------------------------------------------------------

  function calmul(psfc,lev,nlev) result (mulfact)
!   Calculation of multiplication factors for the attenuation of
!   below-ground forcings
    real,dimension(:,:),  intent(in) :: psfc
    real,dimension(:),    intent(in) :: lev
    integer,              intent(in) :: nlev
    real,dimension(:,:,:),allocatable :: mulfact
    real :: pm1
    integer :: i,j,k,nlon,nlat,factor
    nlon=size(psfc,1); nlat=size(psfc,2)
    allocate(mulfact(nlon,nlat,nlev))
    factor=1

    select case (factor)

    case (1) ! old version
       mulfact=1.
       do i=1,nlon
          do j=1,nlat
             do k=1,nlev-1
                if(psfc(i,j) .le. lev(k+1) )then
                   mulfact(i,j,k)=0.
                else
                   if(psfc(i,j).le.lev(k))then
                      mulfact(i,j,k)=(psfc(i,j)-lev(k+1))/(lev(k)-lev(k+1))
                      !mulfact(i,j,k)=0.
                   endif
                endif
             enddo
          enddo
       enddo

    case (2) ! new version with mass-centered cells
       mulfact=1.
       do i=1,nlon
          do j=1,nlat
             do k=1,nlev-1
                if(k==1)then
                   pm1=2*lev(1)-lev(2)
                else
                   pm1=lev(k-1)
                end if
                if (psfc(i,j) <= lev(k)-((lev(k)-lev(k+1))/2) )then
                   mulfact(i,j,k)=0.
                else if (psfc(i,j) > lev(k)-((lev(k)-lev(k+1))/2) .and. &
                     psfc(i,j) <= lev(k)+((pm1-lev(k))/2)) then
                   mulfact(i,j,k)=(psfc(i,j)-(lev(k+1)+(lev(k)-lev(k+1))/2))&
                        /((pm1-lev(k))/2+(lev(k)-lev(k+1))/2)
                else if (psfc(i,j) >= (2*lev(1)-lev(2))) then
                   mulfact(i,j,k) = 1 + (psfc(i,j)-((lev(1)+pm1)/2))/&
                        (pm1-lev(1))
                endif
             enddo
          enddo
       enddo

    end select
  end function calmul

  subroutine irrotationalWind(u,v,dx,dy,mf,uKhi,vKhi,khi)
!   This subroutine calculates irrotational wind components (uKhi,vKhi) from
!   velocity potential.
    use mod_poisson_DFT
    implicit none

    real,dimension(:,:,:),intent(in) :: u,v,mf
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),intent(out) :: uKhi,vKhi,khi

    integer :: nlon,nlat,nlev,k
    double precision, dimension ( : ), allocatable ::  bd_0y,bd_0x
    real,dimension(:,:,:),allocatable :: dudx,dvdy,dkhidx,dkhidy,div,mf2

    nlon=size(u,1); nlat=size(u,2); nlev=size(u,3)
    allocate(dudx(nlon,nlat,nlev))
    allocate(dvdy(nlon,nlat,nlev))
    allocate(dkhidx(nlon,nlat,nlev))
    allocate(dkhidy(nlon,nlat,nlev))
    allocate(div(nlon,nlat,nlev))
    allocate(mf2(nlon,nlat,nlev))
    allocate(bd_0y(nlon), bd_0x(nlat))

    mf2 = mf * mf

!   Calculate the divergence of wind
    dudx = xder_cart(u/mf,dx,mf)
    dvdy = yder_cart(v/mf,dy,mf)
    div  = mf * ( dudx + dvdy )

!   Velocity potential is equal to inverse laplacian of divergence

    bd_0y=0.0e0
    bd_0x=0.0e0
    do k=1,nlev
       call poisson_solver_2D(div(:,:,k)/mf2(:,:,k),dx,dy,khi(:,:,k),&
            bd_0y,bd_0y,bd_0x,bd_0x)
    enddo

!   Derivatives of velocity potential
    dkhidx = xder_cart(khi,dx,mf)
    dkhidy = yder_cart(khi,dy,mf)

!   Wind components are equal to derivatives
    uKhi=dkhidx
    vKhi=dkhidy

  end subroutine irrotationalWind

  function curl_cart ( u, v, dx, dy, mf ) result ( zeta )
    real, dimension ( :, :, : ), intent ( in ) :: u, v, mf
    real,                        intent ( in ) :: dx,dy
    real, dimension ( :, :, : ), allocatable :: zeta, du_dy, dv_dx

    allocate ( zeta ( size (u, 1 ), size ( u, 2 ), &
         size ( u, 3 ) ) )
    allocate ( du_dy ( size (u, 1 ), size ( u, 2 ), &
         size ( u, 3 ) ))
    allocate ( dv_dx ( size (u, 1 ), size ( u, 2 ), &
         size ( u, 3 ) ))

    du_dy = yder_cart(u/mf,dy,mf)
    dv_dx = xder_cart(v/mf,dx,mf)
    zeta = mf * ( dv_dx - du_dy )

  end function curl_cart

  function pder(f,dp) result (dfdp)
!   Estimation of pressure derivatives.
!   One-sided derivatives are used at top and bottom levels
!   Accuracy=1 means second-order accuracy
!   Accuracy=2 fourth-order accuracy
    implicit none

    real,dimension(:,:,:),intent(in) :: f
    real,                 intent(in) :: dp
    real,dimension(:,:,:),allocatable :: dfdp
    real :: inv_dp
    integer :: nlon,nlat,nlev,accuracy,k

    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)
    allocate(dfdp(nlon,nlat,nlev))
    inv_dp = 1.0 / (2.*dp)
    accuracy=1
    select case (accuracy)

       case(1)
          dfdp(:,:,2:nlev-1)=f(:,:,3:nlev)-f(:,:,1:nlev-2)
          dfdp(:,:,2:nlev-1)=dfdp(:,:,2:nlev-1)*inv_dp

          dfdp(:,:,1)=(f(:,:,2)-f(:,:,1))/dp
          dfdp(:,:,nlev)=(f(:,:,nlev)-f(:,:,nlev-1))/dp
       case(2)
          do k=3,nlev-2
             dfdp(:,:,k)=f(:,:,k-2)-8.*f(:,:,k-1)+8.*f(:,:,k+1) &
                  -f(:,:,k+2)
             dfdp(:,:,k)=dfdp(:,:,k)/(12.*dp)
          enddo
          dfdp(:,:,2)=(dfdp(:,:,3)-dfdp(:,:,1))/(2.*dp)
          dfdp(:,:,nlev-1)=(dfdp(:,:,nlev)-dfdp(:,:,nlev-2))/(2.*dp)
          dfdp(:,:,1)=(f(:,:,2)-f(:,:,1))/dp
          dfdp(:,:,nlev)=(f(:,:,nlev)-f(:,:,nlev-1))/dp

       end select

  end function pder

  function xder_cart(f,dx,mf) result(dfdx)
!   Calculation of x derivatives.
    implicit none

    real,dimension(:,:,:),intent(in) :: f, mf
    real,                 intent(in) :: dx
    real,dimension(:,:,:),allocatable  :: dfdx
    real :: inv_dx
    logical :: period = .false.
    integer :: i,j,k,nlon,nlat,nlev,i1,i2,acc,i_1,i_2
    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)
    allocate(dfdx(nlon,nlat,nlev))
    acc=1
    inv_dx = 1.0 / (2.*dx)

    select case (acc)
    case (1)
       do k=1,nlev
          do j=1,nlat
             do i=1,nlon
                i1=max(i-1,1)
                i2=min(i+1,nlon)
                if ( period ) then
                    if(i1.eq.i)i1=nlon
                    if(i2.eq.i)i2=1
                end if
                dfdx(i,j,k)=(f(i2,j,k)-f(i1,j,k))*inv_dx
             enddo
          enddo
       enddo
    case (2)
       do k=1,nlev
          do j=1,nlat
             do i=1,nlon
                i_2=i-2
                i_1=i-1
                i1=i+1
                i2=i+2
                if ( period ) then
                    if(i==2)i_2=nlon
                    if(i==1)then
                        i_2=nlon-1
                        i_1=nlon
                    end if
                    if(i==nlon-1)i2=1
                    if(i==nlon)then
                        i1=1
                        i2=2
                    end if
                end if
                dfdx(i,j,k)=(f(i_2,j,k)-8*f(i_1,j,k)+8*f(i1,j,k)-f(i2,j,k))&
                            /(12*dx)
             enddo
          enddo
       enddo
    end select

    dfdx = mf * dfdx

  end function xder_cart

  function yder_cart(f,dy,mf) result(dfdy)
!   Calculation of y derivatives
!   One-sided estimates are used at the southern and northern boundaries
    implicit none

    real,dimension(:,:,:),intent(in) :: f, mf
    real,                 intent(in) :: dy
    real,dimension(:,:,:),allocatable  :: dfdy
    real :: inv_dy
    integer :: i,j,k,nlon,nlat,nlev,acc
    nlon=size(f,1); nlat=size(f,2); nlev=size(f,3)
    allocate(dfdy(nlon,nlat,nlev))
    inv_dy = 1.0 / (2.*dy)
    acc=1
    select case(acc)

    case(1)
       do k=1,nlev
          do j=2,nlat-1
             do i=1,nlon
                dfdy(i,j,k)=(f(i,j+1,k)-f(i,j-1,k))*inv_dy
             enddo
          enddo
       enddo
       dfdy(:,1,:)=(f(:,2,:)-f(:,1,:))/dy
       dfdy(:,nlat,:)=(f(:,nlat,:)-f(:,nlat-1,:))/dy

    case (2)
       do k=1,nlev
          do j=1,nlat
             do i=1,nlon
                if(j==2)then
                   dfdy(i,2,k)=(f(i,3,k)-f(i,1,k))/(2*dy)
                else if(j==1)then
                   dfdy(i,1,k)=(-f(i,3,k)+4*f(i,2,k)-3*f(i,1,k))/(2*dy)
                else if(j==nlat-1)then
                   dfdy(i,nlat-1,k)=(f(i,nlat,k)-f(i,nlat-2,k))/(2*dy)
                else if(j==nlat)then
                   dfdy(i,nlat,k)=(f(i,nlat-2,k)-4*f(i,nlat-1,k) &
                                 +3*f(i,nlat,k))/(2*dy)
                else
                   dfdy(i,j,k)=(f(i,j-2,k)-8*f(i,j-1,k)+8*f(i,j+1,k)&
                               -f(i,j+2,k))/(12*dy)
                end if
             enddo
          enddo
       enddo
    end select

    dfdy = mf * dfdy

  end function yder_cart

  function advect_cart(u,v,f,dx,dy,mf) result(adv)
!   Computing u*dfdx + v*dfdy in cartesian coordinates
    implicit none

    real,dimension(:,:,:),intent(in) :: u,v,f,mf
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),allocatable :: dfdx,dfdy,adv
    allocate(adv(size(u,1),size(u,2),size(u,3)))
    allocate(dfdx(size(u,1),size(u,2),size(u,3)))
    allocate(dfdy(size(u,1),size(u,2),size(u,3)))

    dfdx = xder_cart(f,dx,mf)
    dfdy = yder_cart(f,dy,mf)

    adv=u*dfdx+v*dfdy

  end function advect_cart

  function define_sigma(t,lev) result(sigma)
!   Calculatig sigma stability parameter in isobaric coordinates
    use mod_const
    implicit none

    real,dimension(:,:,:),intent(in) :: t
    real,dimension(:),    intent(in) :: lev
    real                             :: dlev
    real,dimension(:,:,:),allocatable :: sigma
    integer :: k,nlon,nlat,nlev
    real,dimension(:,:,:),allocatable :: theta,dThetaDp

    nlon=size(t,1); nlat=size(t,2); nlev=size(t,3)
    dlev=lev(2)-lev(1)
    allocate(theta(nlon,nlat,nlev),sigma(nlon,nlat,nlev))
    allocate(dThetaDp(nlon,nlat,nlev))

    do k=1,nlev
       theta(:,:,k)=log(t(:,:,k))-(r/cp)*log(lev(k)/1e5)
    enddo
    dThetaDp=pder(theta,dlev)

    do k=1,nlev
       sigma(:,:,k)=-R*t(:,:,k)/lev(k)*dThetaDp(:,:,k)
    enddo

  end function define_sigma

  function define_sp(sigma,lev) result(sp)
!   Calculating Sp stability parameter
    use mod_const
    implicit none

    real,dimension(:,:,:),intent(in) :: sigma
    real,dimension(:),intent(in) :: lev
    real,dimension(:,:,:),allocatable :: sp
    integer :: k

    allocate(sp(size(sigma,1),size(sigma,2),size(sigma,3)))

    do k=1,size(sigma,3)
       sp(:,:,k)=sigma(:,:,k)*lev(k)/r
    enddo

  end function define_sp

  function laplace_cart(f,dx,dy,mf) result(lapl)
!     Laplace operator in cartesian coordinates.
!     The domain is assumed to be periodic in east-west-direction
!     ** At the northern and southern boundaries, second y derivative
!     is assumed to be zero because they are not used when solving Dirichlet boundary problems
      !lcq: adjusting but useless

    implicit none

    real,dimension(:,:,:),intent(in) :: f, mf
    real,                 intent(in) :: dx,dy
    real,dimension(:,:,:),  allocatable :: mf2
    real,dimension(:,:,:),allocatable :: lapl
    integer :: nlon,nlat,nlev,acc,i,j,k
    real :: inv_dx,inv_dy
    logical :: period = .false.
    nlon=size(f,1)
    nlat=size(f,2)
    nlev=size(f,3)
    allocate(mf2(nlon,nlat,nlev))
    allocate(lapl(nlon,nlat,nlev))
    inv_dx = 1.0 / (dx * dx)
    inv_dy = 1.0 / (dy * dy)
    mf2 = mf * mf
    acc=1

    select case(acc)
    case(1)
       ! x-direction
       lapl ( 2 : nlon - 1, :, : ) = f( 1: nlon - 2, :, : ) + f ( 3: nlon, :, : ) &
            - 2 * f( 2 : nlon - 1, :, : )
       if ( period ) then
            lapl ( 1, :, : )    = f( nlon, :, : ) + f ( 2, :, : ) &
                - 2 * f( 1, :, : )
            lapl ( nlon, :, : ) = f( nlon - 1, :, : ) + f ( 1, :, : ) &
                - 2 * f( nlon, :, : )
       else
            lapl ( 1, :, : )    = f( 1, :, : ) + f ( 3, :, : ) &
                - 2 * f( 2, :, : )
            lapl ( nlon, :, : ) = f( nlon, :, : ) + f ( nlon - 2, :, : ) &
                - 2 * f( nlon - 1, :, : )
       end if
       lapl = lapl * inv_dx

       ! y-directon
       lapl ( :, 2 : nlat -1, : ) = lapl ( :, 2 : nlat -1, : ) &
            + ( f ( :, 1 : nlat -2, : ) + f ( :, 3 : nlat, :) &
            - 2 * f( :, 2 : nlat -1, : ) ) * inv_dy
       lapl ( :, 1, : ) = lapl ( :, 1, : ) &
            + ( f ( :, 1, : ) + f ( :, 3, :) &
            - 2 * f( :, 2, : ) ) * inv_dy
       lapl ( :, nlat, : ) = lapl ( :, nlat, : ) &
            + ( f ( :, nlat, : ) + f ( :, nlat-2, :) &
            - 2 * f( :, nlat-1, : ) ) * inv_dy

    case(2) ! lcq: Have not adjusted the 2nd accuracy derivative to non-periodic version

       do j=1,nlat
          do k=1,nlev
             do i=1,nlon
                ! x-direction
                if(i==1)then
                   lapl(i,j,k)=(-(1/12)*f(nlon-1,j,k)+(4/3)*f(nlon,j,k)-(5/2)*f(i,j,k) &
                     +(4/3)*f(i+1,j,k)-(1/12)*f(i+2,j,k))/(dx*dx)
                else if(i==2)then
                   lapl(i,j,k)=(-(1/12)*f(nlon,j,k)+(4/3)*f(i-1,j,k)-(5/2)*f(i,j,k) &
                        +(4/3)*f(i+1,j,k)-(1/12)*f(i+2,j,k))/(dx*dx)
                else if(i==nlon-1)then
                   lapl(i,j,k)=(-(1/12)*f(i-2,j,k)+(4/3)*f(i-1,j,k)-(5/2)*f(i,j,k) &
                     +(4/3)*f(i+1,j,k)-(1/12)*f(1,j,k))/(dx*dx)
                else if(i==nlon)then
                   lapl(i,j,k)=(-(1/12)*f(i-2,j,k)+(4/3)*f(i-1,j,k)-(5/2)*f(i,j,k) &
                     +(4/3)*f(1,j,k)-(1/12)*f(2,j,k))/(dx*dx)
                else
                   lapl(i,j,k)=-(1/12)*f(i-2,j,k)+(4/3)*f(i-1,j,k)-(5/2)*f(i,j,k) &
                        +(4/3)*f(i+1,j,k)-(1/12)*f(i+2,j,k)
                   lapl(i,j,k)=lapl(i,j,k)/(dx*dx)
                end if
             enddo
          enddo
       enddo

       do i=1,nlon
          do k=1,nlev
             do j=2,nlat-1
                ! y-direction
                if(j==2)then
                   lapl(i,j,k)=lapl(i,j,k)+(f(i,j-1,k)+f(i,j+1,k)-2*f(i,j,k))&
                        /(dy*dy)
                else if(j==nlat-1)then
                   lapl(i,j,k)=lapl(i,j,k)+(f(i,j-1,k)+f(i,j+1,k)-2*f(i,j,k))&
                        /(dy*dy)
                else
                   lapl(i,j,k)=lapl(i,j,k)+(-(1/12)*f(i,j-2,k)+(4/3)*f(i,j-1,k) &
                        -(5/2)*f(i,j,k)+(4/3)*f(i,j+1,k)-(1/12)*f(i,j+2,k))/(dy*dy)
                end if
             enddo
          enddo
       enddo

    end select

    lapl = mf2 * lapl

  end function laplace_cart

end module mod_common_subrs
