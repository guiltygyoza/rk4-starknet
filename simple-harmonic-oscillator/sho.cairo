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
        x : felt,
        xd : felt
    ) -> (
        x_nxt : felt,
        xd_nxt : felt,
        x_delta : felt,
        xd_delta : felt
    ):
    alloc_locals

    # Algorithm
    #   use t, x, xd to calculate x_nxt and xd_nxt (coordinate at t+dt)
    #   return (x_nxt, xd_nxt)

    let (x_nxt, xd_nxt, x_delta, xd_delta) = rk4_fp(t=t, dt=dt, x=x, xd=xd)

    return (x_nxt, xd_nxt, x_delta, xd_delta)
end

# Problem-specific evaluation function for first-order derivative of x and xd
func eval_2d_fp {range_check_ptr} (
        x : felt,
        xd : felt
    ) -> (
        x_diff : felt,
        xd_diff : felt
    ):
    alloc_locals

    const K = 150 * SCALE_FP
    const M = 10 * SCALE_FP

    let x_diff = xd
    let (local k_div_m) = div_fp (K, M)
    let (local xd_diff) = mul_fp (-k_div_m, x)

    return (x_diff, xd_diff)
end

# Runge-Kutta 4th-order method for two-vector
# (set to @external for testing purposes)
@view
func rk4_fp {range_check_ptr} (
        t : felt,
        dt : felt,
        x : felt,
        xd : felt
    ) -> (
        x_nxt : felt,
        xd_nxt : felt,
        x_delta : felt,
        xd_delta : felt
    ):
    alloc_locals

    # k1
    let (local k1_x_, local k1_xd_) = eval_2d_fp (x, xd)
    let (local k1_x)  = mul_fp (k1_x_, dt)
    let (local k1_xd) = mul_fp (k1_xd_, dt)

    # k2
    let (local k1_x_half)  = div_fp_ul (k1_x,  2)
    let (local k1_xd_half) = div_fp_ul (k1_xd, 2)
    local k2_x_est  = x  + k1_x_half
    local k2_xd_est = xd + k1_xd_half
    let (local k2_x_, local k2_xd_) = eval_2d_fp (k2_x_est, k2_xd_est)
    let (local k2_x)  = mul_fp (k2_x_, dt)
    let (local k2_xd) = mul_fp (k2_xd_, dt)

    # k3
    let (local k2_x_half)  = div_fp_ul (k2_x,  2)
    let (local k2_xd_half) = div_fp_ul (k2_xd, 2)
    local k3_x_est  = x  + k2_x_half
    local k3_xd_est = xd + k2_xd_half
    let (local k3_x_, local k3_xd_) = eval_2d_fp (k3_x_est, k3_xd_est)
    let (local k3_x)  = mul_fp (k3_x_, dt)
    let (local k3_xd) = mul_fp (k3_xd_, dt)

    # k4
    local k4_x_est  = x  + k3_x
    local k4_xd_est = xd + k3_xd
    let (local k4_x_, local k4_xd_) = eval_2d_fp (k4_x_est, k4_xd_est)
    let (local k4_x)  = mul_fp (k4_x_, dt)
    let (local k4_xd) = mul_fp (k4_xd_, dt)

    # adding up
    let (local k2_x_mul2) = mul_fp_ul (k2_x, 2)
    let (local k3_x_mul2) = mul_fp_ul (k3_x, 2)
    local k_x_sum = k1_x + k2_x_mul2 + k3_x_mul2 + k4_x

    let (local k2_xd_mul2) = mul_fp_ul (k2_xd, 2)
    let (local k3_xd_mul2) = mul_fp_ul (k3_xd, 2)
    local k_xd_sum = k1_xd + k2_xd_mul2 + k3_xd_mul2 + k4_xd

    let (local x_delta) = div_fp_ul (k_x_sum, 6)
    let (local xd_delta) = div_fp_ul (k_xd_sum, 6)
    tempvar x_nxt = x + x_delta
    tempvar xd_nxt = xd + xd_delta

    return (x_nxt, xd_nxt, x_delta, xd_delta)
end

### utility functions for fixed-point arithmetic ###
### (set to @view for testing purposes)
### TODO: refactor mul/div_fp to a separate contract if beneficial

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
