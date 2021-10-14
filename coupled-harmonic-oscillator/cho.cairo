%lang starknet
%builtins pedersen range_check

from starkware.starknet.common.storage import Storage
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (signed_div_rem, sign)

const RANGE_CHECK_BOUND = 2 ** 64
const SCALE_FP = 10000

@view
func query_next_given_coordinates {
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        t : felt,
        dt : felt,
        x1 : felt,
        x1d : felt,
        x2 : felt,
        x2d : felt
    ) -> (
        x1_nxt : felt,
        x1d_nxt : felt,
        x2_nxt : felt,
        x2d_nxt : felt
    ):
    alloc_locals

    # TODO: vectorize input
    # TODO: kindly ask Cairo team to enable vectorized function output

    # Algorithm
    #   use t, state (4-vector) to calculate next state at t+dt
    #   return next state

    let (
        x1_nxt,
        x1d_nxt,
        x2_nxt,
        x2d_nxt,
        _, _, _, _
    ) = rk4_1d_2body_fp(t=t, dt=dt, x1=x1, x1d=x1d, x2=x2, x2d=x2d)

    return (x1_nxt, x1d_nxt, x2_nxt, x2d_nxt)
end

# Problem-specific evaluation function for first-order derivative of x and xd
func eval_2d_fp {range_check_ptr} (
        x1 : felt,
        x1d : felt,
        x2 : felt,
        x2d : felt
    ) -> (
        x1_diff : felt,
        v1_diff : felt,
        x2_diff : felt,
        v2_diff : felt
    ):
    alloc_locals

    # Spring constant. TODO: tune to produce interesting result
    # (let the middle spring k2 to be looser so that the two masses won't collide,
    #  because collision is not handled yet by this bambino of physics engine!)
    const K1 = 17 * SCALE_FP
    const K2 = 10 * SCALE_FP
    const K3 = 15 * SCALE_FP
    const M1 = 1 * SCALE_FP
    const M2 = 2 * SCALE_FP
    const W = 1000 * SCALE_FP

    let x1_diff = x1d
    let x2_diff = x2d

    # a1 = ( -k1x1 + k2(x2-x1) ) /m1
    let (local k1x1) = mul_fp (K1, x1)
    tempvar x2mx1 = x2-x1
    let (local k2x2mx1) = mul_fp (K2, x2mx1)
    tempvar nominator1 = k2x2mx1 - k1x1
    let (local v1_diff) = div_fp (nominator1, M1)

    # a2 = ( -k2(x2-x1) + k3(W-x2) ) /m2
    tempvar Wmx2 = W-x2
    let (local k3Wmx2) = mul_fp (K3, Wmx2)
    tempvar nominator2 = k3Wmx2 - k2x2mx1
    let (local v2_diff) = div_fp (nominator2, M2)

    return (x1_diff, v1_diff, x2_diff, v2_diff)
end

# Runge-Kutta 4th-order method for two-vector
# (set to @view for testing purposes)
@view
func rk4_1d_2body_fp {range_check_ptr} (
        t : felt,
        dt : felt,
        x1 : felt,
        x1d : felt,
        x2 : felt,
        x2d : felt
    ) -> (
        x1_nxt : felt,
        x1d_nxt : felt,
        x2_nxt : felt,
        x2d_nxt : felt,
        k1_x1 : felt,
        k2_x1_mul2 : felt,
        k3_x1_mul2 : felt,
        k4_x1 : felt
    ):
    alloc_locals

    # k1 stage
    let (local k1_x1_, local k1_x1d_, local k1_x2_, local k1_x2d_) = eval_2d_fp (x1, x1d, x2, x2d)
    let (local k1_x1)  = mul_fp (k1_x1_, dt)
    let (local k1_x1d) = mul_fp (k1_x1d_, dt)
    let (local k1_x2)  = mul_fp (k1_x2_, dt)
    let (local k1_x2d) = mul_fp (k1_x2d_, dt)

    # k2 stage
    let (local k1_x1_half)  = div_fp_ul (k1_x1,  2)
    let (local k1_x1d_half) = div_fp_ul (k1_x1d,  2)
    let (local k1_x2_half)  = div_fp_ul (k1_x2,  2)
    let (local k1_x2d_half) = div_fp_ul (k1_x2d,  2)
    local k2_x1_est  = x1  + k1_x1_half
    local k2_x1d_est = x1d + k1_x1d_half
    local k2_x2_est  = x2  + k1_x2_half
    local k2_x2d_est = x2d + k1_x2d_half
    let (local k2_x1_, local k2_x1d_, local k2_x2_, local k2_x2d_) = eval_2d_fp (k2_x1_est, k2_x1d_est, k2_x2_est, k2_x2d_est)
    let (local k2_x1)  = mul_fp (k2_x1_, dt)
    let (local k2_x1d) = mul_fp (k2_x1d_, dt)
    let (local k2_x2)  = mul_fp (k2_x2_, dt)
    let (local k2_x2d) = mul_fp (k2_x2d_, dt)

    # k3 stage
    let (local k2_x1_half)  = div_fp_ul (k2_x1,  2)
    let (local k2_x1d_half) = div_fp_ul (k2_x1d,  2)
    let (local k2_x2_half)  = div_fp_ul (k2_x2,  2)
    let (local k2_x2d_half) = div_fp_ul (k2_x2d,  2)
    local k3_x1_est  = x1  + k2_x1_half
    local k3_x1d_est = x1d + k2_x1d_half
    local k3_x2_est  = x2  + k2_x2_half
    local k3_x2d_est = x2d + k2_x2d_half
    let (local k3_x1_, local k3_x1d_, local k3_x2_, local k3_x2d_) = eval_2d_fp (k3_x1_est, k3_x1d_est, k3_x2_est, k3_x2d_est)
    let (local k3_x1)  = mul_fp (k3_x1_, dt)
    let (local k3_x1d) = mul_fp (k3_x1d_, dt)
    let (local k3_x2)  = mul_fp (k3_x2_, dt)
    let (local k3_x2d) = mul_fp (k3_x2d_, dt)

    # k4 stage
    local k4_x1_est  = x1  + k3_x1
    local k4_x1d_est = x1d + k3_x1d
    local k4_x2_est  = x2  + k3_x2
    local k4_x2d_est = x2d + k3_x2d
    let (local k4_x1_, local k4_x1d_, local k4_x2_, local k4_x2d_) = eval_2d_fp (k4_x1_est, k4_x1d_est, k4_x2_est, k4_x2d_est)
    let (local k4_x1)  = mul_fp (k4_x1_, dt)
    let (local k4_x1d) = mul_fp (k4_x1d_, dt)
    let (local k4_x2)  = mul_fp (k4_x2_, dt)
    let (local k4_x2d) = mul_fp (k4_x2d_, dt)

    # sum k, mul dt, div 6
    let (local k2_x1_mul2) = mul_fp_ul  (k2_x1, 2)
    let (local k3_x1_mul2) = mul_fp_ul  (k3_x1, 2)
    let (local k2_x1d_mul2) = mul_fp_ul (k2_x1d, 2)
    let (local k3_x1d_mul2) = mul_fp_ul (k3_x1d, 2)
    let (local k2_x2_mul2) = mul_fp_ul  (k2_x2, 2)
    let (local k3_x2_mul2) = mul_fp_ul  (k3_x2, 2)
    let (local k2_x2d_mul2) = mul_fp_ul (k2_x2d, 2)
    let (local k3_x2d_mul2) = mul_fp_ul (k3_x2d, 2)
    local k_x1_sum  = k1_x1  + k2_x1_mul2  + k3_x1_mul2  + k4_x1
    local k_x1d_sum = k1_x1d + k2_x1d_mul2 + k3_x1d_mul2 + k4_x1d
    local k_x2_sum  = k1_x2  + k2_x2_mul2  + k3_x2_mul2  + k4_x2
    local k_x2d_sum = k1_x2d + k2_x2d_mul2 + k3_x2d_mul2 + k4_x2d
    let (local x1_delta)  = div_fp_ul (k_x1_sum, 6)
    let (local x1d_delta) = div_fp_ul (k_x1d_sum, 6)
    let (local x2_delta)  = div_fp_ul (k_x2_sum, 6)
    let (local x2d_delta) = div_fp_ul (k_x2d_sum, 6)

    # produce final estimation
    tempvar x1_nxt  = x1 + x1_delta
    tempvar x1d_nxt = x1d + x1d_delta
    tempvar x2_nxt  = x2 + x2_delta
    tempvar x2d_nxt = x2d + x2d_delta

    return (x1_nxt, x1d_nxt, x2_nxt, x2d_nxt, k1_x1, k2_x1_mul2, k3_x1_mul2, k4_x1)
end

### utility functions for fixed-point arithmetic

@view
func mul_fp {range_check_ptr} (
        a : felt,
        b : felt
    ) -> (
        c : felt
    ):
    # signed_div_rem by SCALE_FP after multiplication

    tempvar product = a * b
    let (c, _) = signed_div_rem(product, SCALE_FP, RANGE_CHECK_BOUND)

    return (c)
end

@view
func div_fp {range_check_ptr} (
        a : felt,
        b : felt
    ) -> (
        c : felt
    ):
    # multiply by SCALE_FP before signed_div_rem

    tempvar a_scaled = a * SCALE_FP
    let (c, _) = signed_div_rem(a_scaled, b, RANGE_CHECK_BOUND)

    return (c)
end

@view
func mul_fp_ul {range_check_ptr} (
        a : felt,
        b_ul : felt
    ) -> (
        c : felt
    ):

    let c = a * b_ul

    return (c)
end

@view
func div_fp_ul {range_check_ptr} (
        a : felt,
        b_ul : felt
    ) -> (
        c : felt
    ):

    let (c, _) = signed_div_rem(a, b_ul, RANGE_CHECK_BOUND)

    return (c)
end