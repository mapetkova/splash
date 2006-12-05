!--------------------------------------------------------------------
! module containing subroutines to do with setting of physical units
!--------------------------------------------------------------------
module settings_units
 use params
 implicit none
 real, dimension(0:maxplot), public :: units
 character(len=20), dimension(0:maxplot), public :: unitslabel
 public :: set_units,read_unitsfile,write_unitsfile
 
 private

contains
!
!--set units
!
subroutine set_units(ncolumns,numplot,UnitsHaveChanged)
  use prompting, only:prompt
  use labels, only:label,ix,ih,iamvec,labelvec
  use settings_data, only:ndim,ndimV
  implicit none
  integer, intent(in) :: ncolumns,numplot
  logical, intent(out) :: UnitsHaveChanged
  integer :: icol
  real :: unitsprev,dunits
  logical :: applytoall

  icol = 1
  do while(icol.ge.0)
     icol = -1
     call prompt('enter column to change units (-2=reset all,-1=quit,0=time)',icol,-2,numplot)
     if (icol.ge.0) then
        unitsprev = units(icol)
        if (icol.gt.ncolumns) then
           print "(a)",' WARNING: calculated quantities are automatically calculated in physical units '
           print "(a)",' this means that units set here will be re-scalings of these physical values'
        endif
        if (icol.eq.0) then
           call prompt('enter time units (new=old*units)',units(icol))
        else
           call prompt('enter '//trim(label(icol))//' units (new=old*units)',units(icol))
        endif
        if (abs(units(icol)).gt.tiny(units)) then
           if (abs(units(icol) - unitsprev).gt.tiny(units)) UnitsHaveChanged = .true.
           if (len_trim(unitslabel(icol)).eq.0) then
           !--suggest a label amendment if none already set
              dunits = 1./units(icol)
              if (dunits.gt.100 .or. dunits.lt.1.e-1) then
                 write(unitslabel(icol),"(1pe8.1)") dunits
              else
                 write(unitslabel(icol),"(f5.1)") dunits                  
              endif
              unitslabel(icol) = ' [ x '//trim(adjustl(unitslabel(icol)))//' ]'
           endif
           !--label amendment can be overwritten
           call prompt('enter label amendment ',unitslabel(icol))
        else
           UnitsHaveChanged = .true.
           units(icol) = 1.0
           unitslabel(icol) = ' '
        endif
        if (UnitsHaveChanged) then
           !
           !--prompt to apply same units to coordinates and h for consistency
           !
           if (any(ix(1:ndim).eq.icol) .or. icol.eq.ih) then
              applytoall = .true.
              !--try to make prompts apply to whichever situation we have
              if (ndim.eq.1) then
                 if (icol.eq.ix(1) .and. ih.gt.0) then
                    call prompt(' Apply these units to h?',applytoall)                                  
                 else
                    call prompt(' Apply these units to '//trim(label(ix(1)))//'?',applytoall)              
                 endif
              elseif (any(ix(1:ndim).eq.icol) .and. ih.gt.0) then
                 call prompt(' Apply these units to all coordinates and h?',applytoall)              
              else
                 call prompt(' Apply these units to all coordinates?',applytoall)
              endif
              if (applytoall) then
                 units(ix(1:ndim)) = units(icol)
                 unitslabel(ix(1:ndim)) = unitslabel(icol)
                 if (ih.gt.0) then
                    units(ih) = units(icol)
                    unitslabel(ih) = unitslabel(icol)
                 endif
              endif
           endif
           !
           !--also sensible to apply same units to all components of a vector
           !
           if (ndimV.gt.1 .and. iamvec(icol).gt.0) then
              applytoall = .true.
              call prompt(' Apply these units to all components of '//trim(labelvec(icol))//'?',applytoall)
              if (applytoall) then
                 where (iamvec(1:ncolumns).eq.iamvec(icol))
                    units(1:ncolumns) = units(icol)
                    unitslabel(1:ncolumns) = unitslabel(icol)
                 end where
              endif
           endif
        endif

     elseif (icol.eq.-2) then
        UnitsHaveChanged = .true.
        print "(/a)",' resetting all units to unity...'
        units = 1.0
        unitslabel = ' '
     endif
     print*
  enddo

end subroutine set_units
!
!--save units for all columns to a file
!
subroutine write_unitsfile(unitsfile,ncolumns)
  implicit none
  character(len=*), intent(in) :: unitsfile
  integer, intent(in) :: ncolumns
  integer :: i,ierr

  print*,'saving plot limits to file ',trim(unitsfile)

  open(unit=77,file=unitsfile,status='replace',form='formatted',iostat=ierr)
  if (ierr /=0) then
     print*,'ERROR: cannot write units file'
  else
     do i=0,ncolumns
        write(77,*,iostat=ierr) units(i),';',unitslabel(i)
        if (ierr /= 0) then
           print*,'ERROR whilst writing units file'
           close(unit=77)
           return
        endif
     enddo
  endif
  close(unit=77)

  return

end subroutine write_unitsfile
!
!--read units for all columns from a file
!
subroutine read_unitsfile(unitsfile,ncolumns,ierr)
  implicit none
  character(len=*), intent(in) :: unitsfile
  integer, intent(in) :: ncolumns
  integer, intent(out) :: ierr
  character(len=len(unitslabel)+20) :: line
  integer :: i,itemp,isemicolon

  ierr = 0

  open(unit=78,file=unitsfile,status='old',form='formatted',err=997)
  print "(/,a)",' reading units from file '//trim(unitsfile)
  do i=0,ncolumns
!
!    read a line from the file
!
     read(78,"(a)",err=998,end=999) line
!
!    now get units from the first part of the line
!
     read(line,*,iostat=itemp) units(i)
     if (itemp /= 0) print*,'error reading units for column ',i
!
!    units label is what comes after the semicolon
!
     isemicolon = index(line,';')
     if (isemicolon.gt.0) then
        unitslabel(i) = trim(line(isemicolon+1:))
     else
        print*,'error reading units label for column ',i
     endif
!     print*,i,'units = ',units(i),'label = ',unitslabel(i)
  enddo
  close(unit=78)

  return

997 continue
  print*,trim(unitsfile),' not found'
  ierr = 1
  return
998 continue
  print*,'*** error reading units from file '
  ierr = 2
  close(unit=78)
  return
999 continue
  !--only give error if we really do not have enough columns
  !  (on first call nextra is not set)
  if (i.le.ncolumns) then
     print*,'end of file in ',trim(unitsfile),': units read to column ',i
     ierr = -1
  endif
  close(unit=78)
  return

end subroutine read_unitsfile

end module settings_units
