!***************************************************************************
!                                                                           
!     Flyvbjerg og Petersen                                                 
!                                                                           
!     this programme calculates the standard deviation of a set of          
!     correlated data using the method of H. Flyvbjerg and                  
!     H.G. Petersen (1989) J. Chem. Phys., 91, 461--466.                    
!                                                                           
!     KM Tu 2011                                                            
!                                                                           
!***************************************************************************

PROGRAM flypet
  IMPLICIT NONE
  CHARACTER(LEN=128) :: input_filename, output_filename
  INTEGER, PARAMETER :: input_fileid = 11, output_fileid = 12
  INTEGER :: num_block_transform, stat, num_data, column
  INTEGER :: num_data_per_block, i, j, idx
  LOGICAL :: is_num_block_transform_assigned, is_input_filename_assigned
  LOGICAL :: is_output_filename_assigned, is_eof
  REAL(KIND=8) :: average, sdev, block1, block2, error
  REAL(KIND=8), DIMENSION(:), ALLOCATABLE :: data
  CHARACTER, PARAMETER :: COMMENT_CHAR = '#'
  INTEGER, EXTERNAL :: count_num_data

  is_input_filename_assigned = .FALSE.
  is_output_filename_assigned = .FALSE.
  
  call get_argument()

  open(UNIT=input_fileid, FILE=input_filename, STATUS='OLD', IOSTAT=stat, ACTION='READ')
  if (stat /= 0) then
     write(*,*) "Unable to open input file: ", TRIM(ADJUSTL(input_filename))
     call EXIT(1)
  end if

  if (is_output_filename_assigned) then
     open(UNIT=output_fileid, FILE=output_filename, IOSTAT=stat, ACTION='WRITE')
     if (stat /= 0) then
        write(*,*) "Unable to open output file: ", TRIM(ADJUSTL(output_filename))
        call EXIT(1)
     end if
  end if

  num_data = count_num_data(input_fileid, COMMENT_CHAR)

  ALLOCATE(data(num_data), STAT=stat)
  if (stat /=0) then
     write(*,*) "Allocation error: data"
     call EXIT(1)
  end if

  write(*,*) "Input file: ", TRIM(ADJUSTL(input_filename))
  write(*,*) "Number of data: ", num_data

  !read all data
  do i = 1, num_data
     call read_real_datum(data(i), column, EOF=is_eof)
  end do
  
  average = SUM(data)/SIZE(data)
  write(*,*) "Average = ", average
  
  if (is_output_filename_assigned) then
     write(output_fileid,*) "# Input file: ", TRIM(ADJUSTL(input_filename))
     write(output_fileid,*) "# Number of data: ", num_data
     write(output_fileid,*) "# Average = ", average
  end if

  !start block transformation
  num_block_transform = -1
  do while(num_data > 1)
     num_block_transform = num_block_transform + 1
     sdev = 0.0d0
     do i = 1, num_data
        sdev = sdev + (data(i) - average)*(data(i) - average)
        !blocking data for next loop
        idx = i/2 + MOD(i,2)
        if (MOD(i,2)==1) then
           data(idx) = data(i)/2.0d0
        else
           data(idx) = data(idx) + data(i)/2.0d0
        end if
     end do
     sdev = (sdev / num_data) / (num_data - 1)
     sdev = sqrt(sdev)
     error = sdev / sqrt(2.0d0 * (num_data - 1))
     
     call output(num_block_transform, sdev, error)
     num_data = num_data / 2  !For next loop, ignore the last datum if total number is odd
  end do

  
CONTAINS
  SUBROUTINE get_argument()
    IMPLICIT NONE
    INTEGER :: stat, i, n
    INTEGER, PARAMETER :: LEAST_REQUIRED_NUM_ARG = 2
    CHARACTER(LEN=128) :: usage, arg

    n = COMMAND_ARGUMENT_COUNT()
    call GET_COMMAND_ARGUMENT(NUMBER=0, VALUE=arg)
    !<column>: the column to be used as data.
    usage = "Usage: " // TRIM(ADJUSTL(arg)) // " -f <in file> [-o <out file>&
         & -c <column>]"

    !Default values:
    column = 1
    
    if (n < LEAST_REQUIRED_NUM_ARG) then
       write(*,*) "Insufficient arguments!"
       write(*,*) usage
       call EXIT(1)
    end if

    i = 1
    do while (i <= n)
       call GET_COMMAND_ARGUMENT(NUMBER=i, VALUE=arg, STATUS=stat)
       i = i + 1
       select case (arg)
       case ('-f')
          call GET_COMMAND_ARGUMENT(NUMBER=i, VALUE=input_filename, STATUS=stat)
          i = i + 1
          if (stat /= 0) then
             write(*,*) "Unable to read the value of argument -f"
             write(*,*) usage
             call EXIT(1)
          end if
          is_input_filename_assigned = .TRUE.

       case ('-o')
          call GET_COMMAND_ARGUMENT(NUMBER=i, VALUE=output_filename, STATUS=stat)
          i = i + 1
          if (stat /= 0) then
             write(*,*) "Unable to read the value of argument -o"
             write(*,*) usage
             call EXIT(1)
          end if
          is_output_filename_assigned = .TRUE.
          
       case ('-c')
          call GET_COMMAND_ARGUMENT(NUMBER=i, VALUE=arg, STATUS=stat)
          i = i + 1
          if (stat /= 0) then
             write(*,*) "Unable to read the value of argument -c"
             write(*,*) usage
             call EXIT(1)
          end if
          read(arg, *, IOSTAT=stat) column
          if (stat /= 0) then
             write(*,*) "Unable to parse the value of argument -c, an&
                  & integer is needed!"
             write(*,*) usage
             call EXIT(1)
          else if (column < 1) then
             write(*,*) "Illegal value of argument -c, a positive integer&
                  & is needed!"
             call EXIT(1)
          end if
          
       case default
          write(*,*) "Unknown argument: ", arg
          call EXIT(1)
       end select
    end do

    if (.NOT. is_input_filename_assigned) then
       write(*,*) "<in file> (input filename) should be provided."
       write(*,*) usage
       call EXIT(1)
    end if
  END SUBROUTINE get_argument

  !First see num_data = 2**X + r , then num_block_transform = X-1
!   SUBROUTINE cal_num_block_transform(num_bt)
!     IMPLICIT NONE
!     INTEGER :: temp, num_bt
    
!     num_bt = INT( LOG(DBLE(num_data)) / LOG(DBLE(2)) )
!     temp = num_data / 2**num_bt
!     if (temp == 1) then !X = num_block_transform
!        num_bt = num_bt - 1
!     else if (temp == 2) then !X is underestimated due to rounding error
!        !num_block_transform = num_block_transform
!        return
!     else
!        write(*,*) "Something is wrong when calulating <num_block_transform>!"
!        write(*,*) "num_block_transform = INT( LOG(DBLE(num_data)) / LOG(2) ) = ", num_bt
!        write(*,*) "num_data / 2**num_block_transform = ", temp
!        call EXIT(1)
!     end if
!   END SUBROUTINE cal_num_block_transform

  SUBROUTINE read_real_datum(datum, col, eof)
    IMPLICIT NONE
    REAL(KIND=8), INTENT(OUT) :: datum
    INTEGER, INTENT(IN) :: col
    LOGICAL, INTENT(OUT) :: eof
    INTEGER :: stat, i, space_idx
    CHARACTER(LEN=128) :: line

    eof = .FALSE.
    
    do while(.TRUE.)
       read(input_fileid, "(A)", IOSTAT=stat) line
       if (stat > 0) then
          write(*,*) "Error occurred while reading data line!"
          call EXIT(1)
       else if (stat < 0) then !End of file
          eof = .TRUE.
          write(*,*) "End of file occurred while reading data line!"
          call EXIT(1)
       end if

       if (TRIM(ADJUSTL(line)) /= '' .AND. &
            &INDEX(ADJUSTL(line), comment_char) /= 1) then
          if (col > 1) then
             do i = 1, col-1
                line = ADJUSTL(line)
                space_idx = INDEX(line, ' ')
                if (space_idx == 0) then !no space is found
                   write(*,*) "Insufficient columns in data file!"
                   call EXIT(1)
                end if
                line = line(space_idx + 1:)
             end do
          end if
          read(line, *, IOSTAT=stat) datum
          if (stat < 0) then
             write(*,*) "Insufficient columns in data file!"
             call EXIT(1)
          else if (stat > 0) then
             write(*,*) "Error occurred while parsing data line!"
             call EXIT(1)
          end if
          RETURN
       end if
    end do
  END SUBROUTINE read_real_datum

  SUBROUTINE output(num_bt, sd, err)
    IMPLICIT NONE
    INTEGER :: num_bt
    REAL(KIND=8) :: sd, err
    write(*,*) num_bt, sd, err
    if (is_output_filename_assigned) then
       write(output_fileid, *) num_bt, sd, err
    end if
  END SUBROUTINE output
END PROGRAM flypet

FUNCTION count_num_data(input_fileid, comment_char)
  IMPLICIT NONE
  INTEGER, INTENT(IN) :: input_fileid
  CHARACTER, INTENT(IN) :: comment_char
  INTEGER :: count_num_data
  INTEGER :: line_num, stat
  CHARACTER(LEN=128) :: line

  line_num = 1
  count_num_data = 0
  
  do while (.TRUE.)
     read(input_fileid, "(A)", IOSTAT=stat) line
     if (stat > 0) then
        write(*,*) "Error occurred while reading line #", line_num
        call EXIT(1)
     else if (stat < 0) then !End of file
        exit
     else
        line_num = line_num + 1
        if (TRIM(ADJUSTL(line)) /= '' .AND. &
             &INDEX(ADJUSTL(line), comment_char) /= 1) then
           count_num_data = count_num_data + 1
        end if
     end if
  end do
  REWIND(input_fileid)
END FUNCTION count_num_data
