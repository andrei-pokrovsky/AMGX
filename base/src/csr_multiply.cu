/* Copyright (c) 2013-2017, NVIDIA CORPORATION. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of NVIDIA CORPORATION nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <csr_multiply.h>
#include <csr_multiply_sm20.h>
#include <csr_multiply_sm35.h>
#include <util.h>
#include <device_properties.h>
#include <amgx_cusparse.h>

namespace amgx
{

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void *CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_workspace_create()
{
    cudaDeviceProp props = getDeviceProperties();
    int arch = 10 * props.major + props.minor;

    if ( arch >= 35 )
    {
        return new CSR_Multiply_Sm35<TConfig_d>();
    }
    else if ( arch >= 20 )
    {
        return new CSR_Multiply_Sm20<TConfig_d>();
    }

    FatalError( "CSR_Multiply: Unsupported architecture. It requires a Fermi GPU or newer!!!", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void *CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_workspace_create( AMG_Config &cfg, const std::string &cfg_scope )
{
    int max_attempts = cfg.getParameter<int>("spmm_max_attempts", cfg_scope);
    cudaDeviceProp props = getDeviceProperties();
    int arch = 10 * props.major + props.minor;

    if ( arch >= 35 )
    {
        CSR_Multiply_Sm35<TConfig_d> *wk = new CSR_Multiply_Sm35<TConfig_d>();
        wk->set_max_attempts(max_attempts);
        return wk;
    }
    else if ( arch >= 20 )
    {
        CSR_Multiply_Sm20<TConfig_d> *wk = new CSR_Multiply_Sm20<TConfig_d>();
        wk->set_max_attempts(max_attempts);
        return wk;
    }

    FatalError( "CSR_Multiply: Unsupported architecture. It requires a Fermi GPU or newer!!!", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
}

// ====================================================================================================================

template <AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I>
void CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_workspace_delete( void *workspace )
{
    CSR_Multiply_Impl<TConfig_d> *impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>(workspace);
    delete impl;
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_multiply( const Matrix_d &A, const Matrix_d &B, Matrix_d &C, void *wk )
{
    if ( A.get_block_size() != 1 || B.get_block_size() != 1 )
    {
        FatalError( "csr_multiply: Unsupported block size", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if (A.hasProps(DIAG) || ( A.hasProps(DIAG) != B.hasProps(DIAG) ) )
    {
        FatalError( "csr_multiply does not support external diagonal and the two matrices have to use the same storage for the diagonal", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        printf("csr_multiply: wk is NULL\n");
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->multiply( A, B, C, NULL, NULL, NULL, NULL );

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_sparsity( const Matrix_d &A, Matrix_d &B, void *wk )
{
    if ( A.get_block_size() != 1 || B.get_block_size() != 1 )
    {
        FatalError( "csr_sparsity: Unsupported block size", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if (A.hasProps(DIAG) || ( A.hasProps(DIAG) != B.hasProps(DIAG) ) )
    {
        FatalError( "csr_sparsity does not support external diagonal and the two matrices have to use the same storage for the diagonal", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        printf("csr_sparsity: wk is NULL\n");
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->sparsity( A, B );

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_sparsity( const Matrix_d &A, const Matrix_d &B, Matrix_d &C, void *wk )
{
    if ( A.get_block_size() != 1 || B.get_block_size() != 1 )
    {
        FatalError( "csr_sparsity: Unsupported block size", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if (A.hasProps(DIAG) || ( A.hasProps(DIAG) != B.hasProps(DIAG) ) )
    {
        FatalError( "csr_sparsity does not support external diagonal and the two matrices have to use the same storage for the diagonal", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        printf("csr_sparsity 2: wk is NULL\n");
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->sparsity( A, B, C );

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_sparsity_ilu1( const Matrix_d &A, Matrix_d &B, void *wk )
{
    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        printf("csr_sparsity_ilu1: wk is NULL\n");
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->sparsity_ilu1( A, B );

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void
CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_galerkin_product( const Matrix_d &R, const Matrix_d &A, const Matrix_d &P, Matrix_d &RAP, IVector *Rq1, IVector *Aq1, IVector *Pq1, IVector *Rq2, IVector *Aq2, IVector *Pq2, void *wk)
{
    if ( R.get_block_size( ) != 1 || A.get_block_size( ) != 1 || P.get_block_size( ) != 1 )
    {
        FatalError( "csr_galerkin_product: Unsupported block size", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if ( A.hasProps(DIAG) || R.hasProps( DIAG ) != A.hasProps( DIAG ) || P.hasProps( DIAG ) != A.hasProps( DIAG ) )
    {
        FatalError( "csr_galerkin_product: The three matrices have to use the same storage for the diagonal, and cannot support external diagonal", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if ( R.get_num_rows( ) == 0 || A.get_num_rows( ) == 0 || P.get_num_rows( ) == 0 )
    {
        return;
    }

    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        printf("csr_galerkin_product: wk is NULL\n");
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->galerkin_product( R, A, P, RAP, Rq1, Aq1, Pq1, Rq2, Aq2, Pq2 );

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void
CSR_Multiply<TemplateConfig<AMGX_device, V, M, I> >::csr_RAP_sparse_add( Matrix_d &RAP, const Matrix_d &RAP_int, std::vector<IVector> &RAP_ext_row_offsets, std::vector<IVector> &RAP_ext_col_indices, std::vector<MVector> &RAP_ext_values, std::vector<IVector> &RAP_ext_row_ids, void *wk )
{
    if ( RAP_int.get_block_size( ) != 1 )
    {
        FatalError( "csr_RAP_sparse_add: Unsupported block size", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    if ( RAP_int.hasProps(DIAG) )
    {
        FatalError( "csr_RAP_sparse_add: Does not support external diagonal", AMGX_ERR_NOT_SUPPORTED_BLOCKSIZE );
    }

    CSR_Multiply_Impl<TConfig_d> *impl = NULL;

    if ( wk == NULL )
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( csr_workspace_create() );
    }
    else
    {
        impl = static_cast<CSR_Multiply_Impl<TConfig_d> *>( wk );
    }

    assert( impl != NULL );
    impl->RAP_sparse_add( RAP, RAP_int, RAP_ext_row_offsets, RAP_ext_col_indices, RAP_ext_values, RAP_ext_row_ids);

    if ( wk != NULL )
    {
        return;
    }

    delete impl;
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::CSR_Multiply_Impl( bool allocate_vals, int grid_size, int max_warp_count, int gmem_size )
    : Base( allocate_vals, grid_size, max_warp_count, gmem_size )
    , m_max_attempts(10)
{}

// ====================================================================================================================

#define CUSPARSE_CSRGEMM(type, func) \
cusparseStatus_t cusparseCsrgemm(cusparseHandle_t handle,             \
                                 cusparseOperation_t transA,          \
                                 cusparseOperation_t transB,          \
                                 int m,                               \
                                 int n,                               \
                                 int k,                               \
                                 const cusparseMatDescr_t descrA,     \
                                 int nnzA,                            \
                                 const type *csrValA,                 \
                                 const int *csrRowPtrA,               \
                                 const int *csrColIndA,               \
                                 const cusparseMatDescr_t descrB,     \
                                 int nnzB,                            \
                                 const type *csrValB,                 \
                                 const int *csrRowPtrB,               \
                                 const int *csrColIndB,               \
                                 const cusparseMatDescr_t descrC,     \
                                 type *csrValC,                       \
                                 const int *csrRowPtrC,               \
                                 int *csrColIndC)                     \
{                                                                     \
  return func(handle, transA, transB, m, n, k,                        \
              descrA, nnzA, csrValA, csrRowPtrA, csrColIndA,          \
              descrB, nnzB, csrValB, csrRowPtrB, csrColIndB,          \
              descrC, csrValC, csrRowPtrC, csrColIndC);               \
}

CUSPARSE_CSRGEMM(float,           cusparseScsrgemm)
CUSPARSE_CSRGEMM(double,          cusparseDcsrgemm)
CUSPARSE_CSRGEMM(cuComplex,       cusparseCcsrgemm)
CUSPARSE_CSRGEMM(cuDoubleComplex, cusparseZcsrgemm)

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::multiply( const Matrix_d &A, const Matrix_d &B, Matrix_d &C, IVector *Aq1, IVector *Bq1, IVector *Aq2, IVector *Bq2 )
{
    // Make C "mutable".
    C.set_initialized(0);
    // Compute row offsets C.
    C.set_num_rows( A.get_num_rows() );
    C.set_num_cols( B.get_num_cols() );
    C.row_offsets.resize( A.get_num_rows() + 1 );
    C.m_seq_offsets.resize( A.get_num_rows() + 1 );
    thrust::sequence(C.m_seq_offsets.begin(), C.m_seq_offsets.end());
    cudaCheckError();
    bool done = false;

    try
    {
        for ( int attempt = 0 ; !done && attempt < get_max_attempts() ; ++attempt )
        {
            // Double the amount of GMEM (if needed).
            if ( attempt > 0 )
            {
                this->m_gmem_size *= 2;
                this->allocate_workspace();
            }

            // Reset the status.
            int status = 0;
            cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice );
            // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
            // properly set but it is responsible for setting the work queue.
            this->count_non_zeroes( A, B, C, Aq1, Bq1, Aq2, Bq2 );
            // Read the result from count_non_zeroes.
            cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost );
            done = status == 0;
        }
    }
    catch (std::bad_alloc &e) // We are running out of memory. Try the fallback instead.
    {
        if ( done ) // Just in case but it should never happen.
        {
            throw e;
        }
    }

    // We have to fallback to the CUSPARSE path.
    if ( !done )
    {
        // CUSPARSE does not work if the matrix is not sorted!!! So we sort the matrices in doubt.
        const_cast<Matrix_d &>(A).sortByRowAndColumn();
        const_cast<Matrix_d &>(B).sortByRowAndColumn();
        // Run the algorithm.
        cusparseHandle_t handle = Cusparse::get_instance().get_handle();
        cusparsePointerMode_t old_pointer_mode;
        cusparseCheckError(cusparseGetPointerMode(handle, &old_pointer_mode));
        cusparseCheckError(cusparseSetPointerMode(handle, CUSPARSE_POINTER_MODE_HOST));
        int num_vals = 0;
        cusparseCheckError(cusparseXcsrgemmNnz(
                               handle,
                               CUSPARSE_OPERATION_NON_TRANSPOSE,
                               CUSPARSE_OPERATION_NON_TRANSPOSE,
                               A.get_num_rows(),
                               B.get_num_cols(),
                               A.get_num_cols(),
                               A.cuMatDescr,
                               A.get_num_nz(),
                               A.row_offsets.raw(),
                               A.col_indices.raw(),
                               B.cuMatDescr,
                               B.get_num_nz(),
                               B.row_offsets.raw(),
                               B.col_indices.raw(),
                               C.cuMatDescr,
                               C.row_offsets.raw(),
                               &num_vals
                           ));
        C.col_indices.resize(num_vals);
        C.values.resize(num_vals);
        C.set_num_nz(num_vals);
        C.diag.resize(C.get_num_rows());
        C.set_block_dimx(A.get_block_dimx());
        C.set_block_dimy(B.get_block_dimy());
        C.setColsReorderedByColor(false);
        cusparseCheckError(cusparseCsrgemm(
                               Cusparse::get_instance().get_handle(),
                               CUSPARSE_OPERATION_NON_TRANSPOSE,
                               CUSPARSE_OPERATION_NON_TRANSPOSE,
                               A.get_num_rows(),
                               B.get_num_cols(),
                               A.get_num_cols(),
                               A.cuMatDescr,
                               A.get_num_nz(),
                               A.values.raw(),
                               A.row_offsets.raw(),
                               A.col_indices.raw(),
                               B.cuMatDescr,
                               B.get_num_nz(),
                               B.values.raw(),
                               B.row_offsets.raw(),
                               B.col_indices.raw(),
                               C.cuMatDescr,
                               C.values.raw(),
                               C.row_offsets.raw(),
                               C.col_indices.raw()
                           ));
        cusparseCheckError(cusparseSetPointerMode(handle, old_pointer_mode));
        C.set_initialized(1);
        return;
    }

    // Compute row offsets.
    this->compute_offsets( C );
    // Allocate memory to store columns/values.
    int num_vals = C.row_offsets[C.get_num_rows()];
    C.col_indices.resize(num_vals);
    C.values.resize(num_vals);
    C.set_num_nz(num_vals);
    C.diag.resize( C.get_num_rows() );
    C.set_block_dimx(A.get_block_dimx());
    C.set_block_dimy(B.get_block_dimy());
    C.setColsReorderedByColor(false);
    // Like count_non_zeroes, compute_values is responsible for setting its work queue (if it dares :)).
    done = false;

    if ( this->m_num_threads_per_row_count != this->m_num_threads_per_row_compute )
    {
        // Reset the status.
        int status = 0;
        cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice );
        // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
        // properly set but it is responsible for setting the work queue.
        this->compute_values( A, B, C, this->m_num_threads_per_row_compute, Aq1, Bq1, Aq2, Bq2 );
        // Read the result from count_non_zeroes.
        cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost );
        done = status == 0;
    }

    // Re-run if needed.
    if ( !done )
    {
        this->compute_values( A, B, C, this->m_num_threads_per_row_count, Aq1, Bq1, Aq2, Bq2 );
    }

    // Finalize the initialization of the matrix.
    C.set_initialized(1);
}

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::sparse_add( Matrix_d &RAP, const Matrix_d &RAP_int, std::vector<IVector> &RAP_ext_row_offsets, std::vector<IVector> &RAP_ext_col_indices, std::vector<MVector> &RAP_ext_values, std::vector<IVector> &RAP_ext_row_ids)
{
    // Make C "mutable".
    RAP.set_initialized(0);
    RAP.m_seq_offsets.resize( RAP.get_num_rows() + 1 );
    thrust::sequence(RAP.m_seq_offsets.begin(), RAP.m_seq_offsets.end());
    cudaCheckError();
    int attempt = 0;

    for ( bool done = false ; !done && attempt < 10 ; ++attempt )
    {
        // Double the amount of GMEM (if needed).
        if ( attempt > 0 )
        {
            this->m_gmem_size *= 2;
            this->allocate_workspace();
        }

        // Reset the status.
        int status = 0;
        cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice );
        // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
        // properly set but it is responsible for setting the work queue.
        this->count_non_zeroes_RAP_sparse_add( RAP, RAP_int, RAP_ext_row_offsets, RAP_ext_col_indices, RAP_ext_values, RAP_ext_row_ids );
        // Read the result from count_non_zeroes.
        cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost );
        done = status == 0;
    }

    // Compute row offsets.
    this->compute_offsets( RAP );
    // Allocate memory to store columns/values.
    int num_vals = RAP.row_offsets[RAP.get_num_rows()];
    RAP.col_indices.resize(num_vals);
    RAP.values.resize(num_vals);
    RAP.set_num_nz(num_vals);
    RAP.diag.resize( RAP.get_num_rows() );
    RAP.set_block_dimx(RAP_int.get_block_dimx());
    RAP.set_block_dimy(RAP_int.get_block_dimy());
    RAP.setColsReorderedByColor(false);
    // Like count_non_zeroes, compute_values is responsible for setting its work queue (if it dares :)).
    bool done = false;

    if ( this->m_num_threads_per_row_count != this->m_num_threads_per_row_compute )
    {
        // Reset the status.
        int status = 0;
        cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice );
        // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
        // properly set but it is responsible for setting the work queue.
        this->compute_values_RAP_sparse_add( RAP, RAP_int, RAP_ext_row_offsets, RAP_ext_col_indices, RAP_ext_values, RAP_ext_row_ids,  this->m_num_threads_per_row_compute );
        // Read the result from count_non_zeroes.
        cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost );
        done = status == 0;
    }

    // Re-run if needed.
    if ( !done )
    {
        this->compute_values_RAP_sparse_add( RAP, RAP_int, RAP_ext_row_offsets, RAP_ext_col_indices, RAP_ext_values, RAP_ext_row_ids, this->m_num_threads_per_row_count );
    }
}



// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::galerkin_product( const Matrix_d &R, const Matrix_d &A, const Matrix_d &P, Matrix_d &RAP, IVector *Rq1, IVector *Aq1, IVector *Pq1, IVector *Rq2, IVector *Aq2, IVector *Pq2)
{
    Matrix_d AP;
    AP.set_initialized(0);
    int avg_nz_per_row = P.get_num_nz() / P.get_num_rows();

    if ( avg_nz_per_row < 2 )
    {
        this->set_num_threads_per_row_count(2);
        this->set_num_threads_per_row_compute(2);
    }
    else
    {
        this->set_num_threads_per_row_count(4);
        this->set_num_threads_per_row_compute(4);
    }

    this->multiply( A, P, AP, Aq1, Pq1, Aq2, Pq2 );
    AP.set_initialized(1);
    avg_nz_per_row = AP.get_num_nz() / AP.get_num_rows();
    this->set_num_threads_per_row_count(avg_nz_per_row <= 16.0 ? 8 : 32);
    this->set_num_threads_per_row_compute(32);
    RAP.set_initialized(0);
    this->multiply( R, AP, RAP, Rq1, NULL, Rq2, NULL );
    RAP.computeDiagonal();
    RAP.set_initialized(1);
}

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::RAP_sparse_add( Matrix_d &RAP, const Matrix_d &RAP_int, std::vector<IVector> &RAP_ext_row_offsets, std::vector<IVector> &RAP_ext_col_indices, std::vector<MVector> &RAP_ext_values, std::vector<IVector> &RAP_ext_row_ids)
{
    if (RAP_int.get_num_rows() <= 0)
    {
        return;
    }

    int avg_nz_per_row = RAP_int.get_num_nz() / RAP_int.get_num_rows();
    this->set_num_threads_per_row_count(avg_nz_per_row <= 16.0 ? 8 : 32);
    this->set_num_threads_per_row_compute(32);
    RAP.set_initialized(0);
    this->sparse_add( RAP, RAP_int, RAP_ext_row_offsets, RAP_ext_col_indices, RAP_ext_values, RAP_ext_row_ids );
    RAP.computeDiagonal();
    RAP.set_initialized(1);
}


// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::sparsity( const Matrix_d &A, const Matrix_d &B, Matrix_d &C )
{
    // Make C "mutable".
    C.set_initialized(0);
    // Compute row offsets C.
    C.set_num_rows( A.get_num_rows() );
    C.set_num_cols( B.get_num_cols() );
    C.row_offsets.resize( A.get_num_rows() + 1 );
    int attempt = 0;

    for ( bool done = false ; !done && attempt < 10 ; ++attempt )
    {
        // Double the amount of GMEM (if needed).
        if ( attempt > 0 )
        {
            this->m_gmem_size *= 2;
            this->allocate_workspace();
        }

        // Reset the status.
        int status = 0;
        cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice );
        // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
        // properly set but it is responsible for setting the work queue.
        this->count_non_zeroes( A, B, C, NULL, NULL, NULL, NULL );
        // Read the result from count_non_zeroes.
        cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost );
        done = status == 0;
    }

    // Compute row offsets.
    this->compute_offsets( C );
    // Allocate memory to store columns/values.
    int num_vals = C.row_offsets[C.get_num_rows()];
    C.col_indices.resize(num_vals);
    C.values.resize(num_vals);
    C.set_num_nz(num_vals);
    C.diag.resize( C.get_num_rows( ) );
    C.setColsReorderedByColor(false);
    // Like count_non_zeroes, compute_values is responsible for setting its work queue (if it dares :)).
    this->compute_sparsity( A, B, C );
    // Finalize the initialization of the matrix.
    C.set_initialized(1);
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::sparsity( const Matrix_d &A, Matrix_d &B )
{
    this->sparsity( A, A, B );
}

// ====================================================================================================================

template< AMGX_VecPrecision V, AMGX_MatPrecision M, AMGX_IndPrecision I >
void CSR_Multiply_Impl<TemplateConfig<AMGX_device, V, M, I> >::sparsity_ilu1( const Matrix_d &A, Matrix_d &B )
{
    // Make C "mutable".
    B.set_initialized(0);
    // Compute row offsets C.
    B.set_num_rows( A.get_num_rows() );
    B.set_num_cols( A.get_num_cols() );
    B.row_offsets.resize( A.get_num_rows() + 1 );
    int attempt = 0;

    for ( bool done = false ; !done && attempt < 10 ; ++attempt )
    {
        // Double the amount of GMEM (if needed).
        if ( attempt > 0 )
        {
            this->m_gmem_size *= 2;
            this->allocate_workspace();
        }

        // Reset the status.
        int status = 0;
        CUDA_SAFE_CALL( cudaMemcpy( this->m_status, &status, sizeof(int), cudaMemcpyHostToDevice ) );
        // Count the number of non-zeroes. The function count_non_zeroes assumes status has been
        // properly set but it is responsible for setting the work queue.
        this->count_non_zeroes_ilu1( A, B );
        // Read the result from count_non_zeroes.
        CUDA_SAFE_CALL( cudaMemcpy( &status, this->m_status, sizeof(int), cudaMemcpyDeviceToHost ) );
        done = status == 0;
    }

    // Compute row offsets.
    this->compute_offsets(B);
    // Allocate memory to store columns/values.
    int num_vals = B.row_offsets[B.get_num_rows()];
    B.col_indices.resize(num_vals);
    B.values.resize((num_vals + 1)*A.get_block_size());
    B.set_num_nz(num_vals);
    B.diag.resize( B.get_num_rows() );
    B.set_block_dimx(A.get_block_dimx());
    B.set_block_dimy(A.get_block_dimy());
    // Like count_non_zeroes, compute_values is responsible for setting its work queue (if it dares :)).
    this->compute_sparsity_ilu1( A, B );
    // Finalize the initialization of the matrix.
    B.setColsReorderedByColor(false);
    B.set_initialized(1);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define AMGX_CASE_LINE(CASE) template class CSR_Multiply<TemplateMode<CASE>::Type>;
AMGX_FORALL_BUILDS(AMGX_CASE_LINE)
AMGX_FORCOMPLEX_BUILDS(AMGX_CASE_LINE)
#undef AMGX_CASE_LINE

#define AMGX_CASE_LINE(CASE) template class CSR_Multiply_Impl<TemplateMode<CASE>::Type>;
AMGX_FORALL_BUILDS(AMGX_CASE_LINE)
AMGX_FORCOMPLEX_BUILDS(AMGX_CASE_LINE)
#undef AMGX_CASE_LINE

} // namespace amgx
