!-------------------------------------------------------------------------------------------------------------------------------------------
! This module contains functions that operate with system paths
!-------------------------------------------------------------------------------------------------------------------------------------------
module path_utils
  use general_utils
  use input_params_mod
  use parallel_utils
  use system_mod

contains

!-------------------------------------------------------------------------------------------------------------------------------------------
! Creates specified folder
!-------------------------------------------------------------------------------------------------------------------------------------------
  subroutine create_path(path)
    character(*), intent(in) :: path
    call execute_command_line('mkdir -p ' // path)
  end subroutine

!-----------------------------------------------------------------------
! extracts last token from path
!-----------------------------------------------------------------------
  function get_path_tail(path)
    character(*), intent(in) :: path
    character(:), allocatable :: get_path_tail
    integer :: ind_slash

    ind_slash = index(path, '/', .true.)
    get_path_tail = path(ind_slash+1:)
  end function

!-----------------------------------------------------------------------
! extracts everything before the last token in path
!-----------------------------------------------------------------------
  function get_path_head(path)
    character(*), intent(in) :: path
    character(:), allocatable :: get_path_head
    integer :: ind_slash

    ind_slash = index(path, '/', .true.)
    get_path_head = path(:ind_slash-1)
  end function
  
!-----------------------------------------------------------------------
! removes specified number of tokens from the end of path
!-----------------------------------------------------------------------
  function strip_path_tokens(path, n_tokens)
    character(*), intent(in) :: path
    integer, intent(in) :: n_tokens
    character(:), allocatable :: strip_path_tokens
    integer :: i
    
    strip_path_tokens = path
    do i = 1,n_tokens
      strip_path_tokens = get_path_head(strip_path_tokens)
    end do
  end function
  
!-----------------------------------------------------------------------
! resolves a path relative to location of executable file
!-----------------------------------------------------------------------
  function resolve_relative_exe_path(relative_exe_path) result(res)
    character(*), intent(in) :: relative_exe_path
    character(:), allocatable :: res
    character(512) :: path_arg
    character(:), allocatable :: path

    call get_command_argument(0, path_arg)
    path = execute_shell_command('readlink -f $(which ' // path_arg // ')', '.temp' // num2str(get_proc_id()))
    path = get_path_head(path)
    ! only if path is non-empty
    if (len(path) /= 0) then
      path = trim(path) // '/'
    end if
    path = trim(path) // relative_exe_path
    res = trim(path)
  end function
  
!-------------------------------------------------------------------------------------------------------------------------------------------
! Appends a new token to a path
!-------------------------------------------------------------------------------------------------------------------------------------------
  function append_path_token(path, token) result(new_path)
    character(*), intent(in) :: path, token
    character(:), allocatable :: new_path, separator
    
    separator = '/'
    new_path = path
    if (new_path(len(new_path) - len(separator) + 1 : len(new_path)) /= separator) then
      new_path = new_path // separator
    end if
    new_path = new_path // token
  end function
  
!-------------------------------------------------------------------------------------------------------------------------------------------
! Appends a new token to a path
!-------------------------------------------------------------------------------------------------------------------------------------------
  function append_path_tokens(path, token1, token2, token3, token4) result(new_path)
    character(*), intent(in) :: path, token1
    character(*), optional, intent(in) :: token2, token3, token4
    character(:), allocatable :: new_path
    
    new_path = append_path_token(path, token1)
    if (present(token2)) then
      new_path = append_path_token(new_path, token2)
    end if
    if (present(token3)) then
      new_path = append_path_token(new_path, token3)
    end if
    if (present(token4)) then
      new_path = append_path_token(new_path, token4)
    end if
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for given Ks
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_k_folder_path(root_path, K) result(res)
    character(*), intent(in) :: root_path
    integer, intent(in) :: K
    character(:), allocatable :: res
    character(:), allocatable :: k_folder_name
    
    k_folder_name = iff(K == -1, 'K_all', 'K_' // num2str(K))
    res = append_path_tokens(root_path, k_folder_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for given Ks
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_k_folder_path_params(params) result(res)
    class(input_params), intent(in) :: params
    character(:), allocatable :: res
    integer :: K

    K = merge(-1, params % K(1), params % rovib_coupling == 1 .and. params % mode /= 'overlaps')
    res = get_k_folder_path(params % root_path, K)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for a given symmetry and Ks
! Parity is relevant for coupled diagonalization only
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_sym_path_int(k_path, sym_code, parity) result(res)
    character(*), intent(in) :: k_path
    integer, intent(in) :: sym_code
    integer, intent(in), optional :: parity
    character(:), allocatable :: res
    character(:), allocatable :: sym_name

    sym_name = iff(sym_code == 0, 'even', 'odd')
    res = get_sym_path_str(k_path, sym_name, parity)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for a given symmetry and Ks
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_sym_path_str(k_path, sym_name, parity) result(res)
    character(*), intent(in) :: k_path, sym_name
    integer, intent(in), optional :: parity
    character(:), allocatable :: res

    res = k_path
    if (present(parity)) then
      if (parity /= -1) then
        res = append_path_tokens(res, 'parity_' // num2str(parity)) 
      end if
    end if
    res = append_path_tokens(res, sym_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for a given symmetry and Ks
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_sym_path_root(root_path, K, sym_code, parity) result(res)
    character(*), intent(in) :: root_path
    integer, intent(in) :: K, sym_code
    integer, intent(in), optional :: parity
    character(:), allocatable :: res
    character(:), allocatable :: k_path

    k_path = get_k_folder_path(root_path, K)
    res = get_sym_path_int(k_path, sym_code, parity)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with calculation results for a given symmetry and Ks
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_sym_path_params(params) result(res)
    class(input_params), intent(in) :: params
    character(:), allocatable :: res
    integer :: parity
    character(:), allocatable :: k_path

    k_path = get_k_folder_path_params(params)
    parity = merge(params % parity, -1, params % rovib_coupling == 1 .and. params % mode /= 'overlaps')
    res = get_sym_path_int(k_path, params % symmetry, parity)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with basis calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_basis_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    res = append_path_tokens(sym_path, 'basis')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with basis results calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_basis_results_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: basis_path

    basis_path = get_basis_path(sym_path)
    res = append_path_tokens(basis_path, 'basis')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to k-block info (overlap structure)
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_block_info_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: basis_results_path
    
    basis_results_path = get_basis_results_path(sym_path)
    res = append_path_tokens(basis_results_path, 'nvec2.dat')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with 1D eigenvalues and eigenvectors from all theta slices in a specific rho slice
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_solutions_1d_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: basis_results_path, file_name

    basis_results_path = get_basis_results_path(sym_path)
    file_name = 'bas1.' // num2str(slice_ind, '(I0)') // '.bin.out'
    res = append_path_tokens(basis_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with 2D eigenvalues and eigenvectors in a specific rho slice
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_solutions_2d_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: basis_results_path, file_name

    basis_results_path = get_basis_results_path(sym_path)
    file_name = 'bas2.' // num2str(slice_ind, '(I0)') // '.bin.out'
    res = append_path_tokens(basis_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with overlaps calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_overlaps_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    res = append_path_tokens(sym_path, 'overlaps')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with overlaps results calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_overlaps_results_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_path

    overlaps_path = get_overlaps_path(sym_path)
    res = append_path_tokens(overlaps_path, 'overlap')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with a regular overlap block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_regular_overlap_file_path(sym_path, slice_ind_1, slice_ind_2) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind_1, slice_ind_2
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'overlap.' // num2str(slice_ind_1, '(I0)') // '.' // num2str(slice_ind_2, '(I0)') // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with a symmetric overlap block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_symmetric_overlap_J_file_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'sym_J.' // num2str(slice_ind) // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with a symmetric overlap block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_symmetric_overlap_K_file_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'sym_K.' // num2str(slice_ind) // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with a coriolis overlap block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_coriolis_overlap_file_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'coriolis.' // num2str(slice_ind) // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with an asymmetric overlap block. Negative values of slice_ind indicate K=1 block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_asymmetric_overlap_file_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'asym.' // num2str(slice_ind) // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with an asymmetric overlap block. Negative values of slice_ind indicate K=1 block
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_asymmetric_overlap_file_1_path(sym_path, slice_ind) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: slice_ind
    character(:), allocatable :: res
    character(:), allocatable :: overlaps_results_path, file_name

    overlaps_results_path = get_overlaps_results_path(sym_path)
    file_name = 'asym_1.' // num2str(slice_ind) // '.bin.out'
    res = append_path_tokens(overlaps_results_path, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with diagonalization calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_diagonalization_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    res = append_path_tokens(sym_path, 'diagonalization')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with diagonalization results calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_diagonalization_results_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: diagonalization_path

    diagonalization_path = get_diagonalization_path(sym_path)
    res = append_path_tokens(diagonalization_path, '3dsdt')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with 3D expansion coefficients
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_expansion_coefficients_3d_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: diagonalization_results_path

    diagonalization_results_path = get_diagonalization_results_path(sym_path)
    res = append_path_tokens(diagonalization_results_path, 'exps')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with 3D expansion coefficients for a given state number k
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_solution_3d_path(sym_path, k) result(res)
    character(*), intent(in) :: sym_path
    integer, intent(in) :: k ! solution index
    character(:), allocatable :: res
    character(:), allocatable :: exp_coeffs_folder, file_name

    exp_coeffs_folder = get_expansion_coefficients_3d_path(sym_path)
    file_name = 'exp.' // num2str(k, '(I0)') // '.bin.out'
    res = append_path_tokens(exp_coeffs_folder, file_name)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to computed spectrum
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_spectrum_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: diagonalization_results_path

    diagonalization_results_path = get_diagonalization_results_path(sym_path)
    res = append_path_tokens(diagonalization_results_path, 'spec.out')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with properties calculations
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_properties_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    res = append_path_tokens(sym_path, 'properties')
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to file with properties results calculation
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_properties_result_path(sym_path) result(res)
    character(*), intent(in) :: sym_path
    character(:), allocatable :: res
    character(:), allocatable :: properties_path

    properties_path = get_properties_path(sym_path)
    res = append_path_tokens(properties_path, 'states.fwc') ! Fixed width columns
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to folder with 'chrecog' folder
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_channels_folder_parent_path(channels_root, J, K, sym) result(res)
    character(*), intent(in) :: channels_root
    integer, intent(in) :: J, K, sym
    character(:), allocatable :: res
    character :: sym_letter

    sym_letter = merge('S', 'A', sym == 0)
    res = append_path_tokens(channels_root, 'J' // num2str(J, '(I2.2)'), 'K' // num2str(K, '(I2.2)') // sym_letter)
  end function

!-------------------------------------------------------------------------------------------------------------------------------------------
! Generates path to channels file corresponding to given parameters
!-------------------------------------------------------------------------------------------------------------------------------------------
  function get_channels_file_path(channels_root, J, K, sym) result(res)
    character(*), intent(in) :: channels_root
    integer, intent(in) :: J, K, sym
    character(:), allocatable :: res
    character(:), allocatable :: parent

    parent = get_channels_folder_parent_path(channels_root, J, K, sym)
    res = append_path_tokens(parent, 'chrecog', 'channels.dat')
  end function

end module
