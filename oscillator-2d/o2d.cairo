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
        xd : felt,
        y : felt,
        yd : felt
    ) -> (
        x_nxt : felt,
        xd_nxt : felt,
        y_nxt : felt,
        yd_nxt : felt
    ):
    alloc_locals

    # TODO: vectorize input
    # TODO: structify output (not until testing framework supports this!)
    # TODO: kindly ask Cairo team to enable vectorized function output

    # Algorithm
    #   use t, state (4-vector) to calculate next state at t+dt
    #   return next state

    let (
        x_nxt,
        xd_nxt,
        y_nxt,
        yd_nxt
    ) = rk4_2coord (t=t, dt=dt, q1=x, q1d=xd, q2=y, q2d=yd)

    return (x_nxt, xd_nxt, y_nxt, yd_nxt)
end

# Problem-specific evaluation function for first-order derivative of x and xd
func eval {range_check_ptr} (
        x : felt,
        xd : felt,
        y : felt,
        yd : felt
    ) -> (
        x_diff : felt,
        vx_diff : felt,
        y_diff : felt,
        vy_diff : felt
    ):
    alloc_locals

    # Scene setup
    # TODO externalize these into storage vars once block time is more mangeable
    const K1 = 6 * SCALE_FP
    const K2 = 10 * SCALE_FP
    const K3 = 13 * SCALE_FP
    const K4 = 15 * SCALE_FP
    const M = 2 * SCALE_FP
    const W = 600 * SCALE_FP
    const G = 98000 # 9.8 * 10000

    let x_diff = xd
    let y_diff = yd

    # ax = ( -k1*x + k2*(W-x) + k3*(W-x) -k4*x )/m
    let (local k1x) = mul_fp (K1, x)
    local Wmx = W-x
    let (local k2Wmx) = mul_fp (K2, Wmx)
    let (local k3Wmx) = mul_fp (K3, Wmx)
    let (local k4x) = mul_fp (K4, x)
    tempvar nominator_x = -k1x + k2Wmx + k3Wmx - k4x
    let (local vx_diff) = div_fp (nominator_x, M)

    # ay = ( -k1*y -k2*y + k3*(W-y) + k4*(W-y) )/m - G
    local Wmy = W-y
    let (local k1y) = mul_fp (K1, y)
    let (local k2y) = mul_fp (K2, y)
    let (local k3Wmy) = mul_fp (K3, Wmy)
    let (local k4Wmy) = mul_fp (K4, Wmy)
    tempvar nominator_y = -k1y - k2y + k3Wmy + k4Wmy
    let (local vy_diff) = div_fp (nominator_y, M)

    return (x_diff, vx_diff, y_diff, vy_diff)
end

# Runge-Kutta 4th-order method for four-vector
# (set to @view for testing purposes)
@view
func rk4_2coord {range_check_ptr} (
        t : felt,
        dt : felt,
        q1 : felt,
        q1d : felt,
        q2 : felt,
        q2d : felt
    ) -> (
        q1_nxt : felt,
        q1d_nxt : felt,
        q2_nxt : felt,
        q2d_nxt : felt
    ):
    alloc_locals

    ## accept generaized 2-q system (whether two-body 1D or 1-body 2D)
    ## preparing for a shift to hamiltonian/lagrangian method

    # k1 stage
    let (local k1_q1_, local k1_q1d_, local k1_q2_, local k1_q2d_) = eval (q1, q1d, q2, q2d)
    let (local k1_q1)  = mul_fp (k1_q1_, dt)
    let (local k1_q1d) = mul_fp (k1_q1d_, dt)
    let (local k1_q2)  = mul_fp (k1_q2_, dt)
    let (local k1_q2d) = mul_fp (k1_q2d_, dt)

    # k2 stage
    let (local k1_q1_half)  = div_fp_ul (k1_q1,  2)
    let (local k1_q1d_half) = div_fp_ul (k1_q1d,  2)
    let (local k1_q2_half)  = div_fp_ul (k1_q2,  2)
    let (local k1_q2d_half) = div_fp_ul (k1_q2d,  2)
    local k2_q1_est  = q1  + k1_q1_half
    local k2_q1d_est = q1d + k1_q1d_half
    local k2_q2_est  = q2  + k1_q2_half
    local k2_q2d_est = q2d + k1_q2d_half
    let (local k2_q1_, local k2_q1d_, local k2_q2_, local k2_q2d_) = eval (k2_q1_est, k2_q1d_est, k2_q2_est, k2_q2d_est)
    let (local k2_q1)  = mul_fp (k2_q1_, dt)
    let (local k2_q1d) = mul_fp (k2_q1d_, dt)
    let (local k2_q2)  = mul_fp (k2_q2_, dt)
    let (local k2_q2d) = mul_fp (k2_q2d_, dt)

    # k3 stage
    let (local k2_q1_half)  = div_fp_ul (k2_q1,  2)
    let (local k2_q1d_half) = div_fp_ul (k2_q1d,  2)
    let (local k2_q2_half)  = div_fp_ul (k2_q2,  2)
    let (local k2_q2d_half) = div_fp_ul (k2_q2d,  2)
    local k3_q1_est  = q1  + k2_q1_half
    local k3_q1d_est = q1d + k2_q1d_half
    local k3_q2_est  = q2  + k2_q2_half
    local k3_q2d_est = q2d + k2_q2d_half
    let (local k3_q1_, local k3_q1d_, local k3_q2_, local k3_q2d_) = eval (k3_q1_est, k3_q1d_est, k3_q2_est, k3_q2d_est)
    let (local k3_q1)  = mul_fp (k3_q1_, dt)
    let (local k3_q1d) = mul_fp (k3_q1d_, dt)
    let (local k3_q2)  = mul_fp (k3_q2_, dt)
    let (local k3_q2d) = mul_fp (k3_q2d_, dt)

    # k4 stage
    local k4_q1_est  = q1  + k3_q1
    local k4_q1d_est = q1d + k3_q1d
    local k4_q2_est  = q2  + k3_q2
    local k4_q2d_est = q2d + k3_q2d
    let (local k4_q1_, local k4_q1d_, local k4_q2_, local k4_q2d_) = eval (k4_q1_est, k4_q1d_est, k4_q2_est, k4_q2d_est)
    let (local k4_q1)  = mul_fp (k4_q1_, dt)
    let (local k4_q1d) = mul_fp (k4_q1d_, dt)
    let (local k4_q2)  = mul_fp (k4_q2_, dt)
    let (local k4_q2d) = mul_fp (k4_q2d_, dt)

    # sum k, mul dt, div 6
    let (local k2_q1_mul2) = mul_fp_ul  (k2_q1, 2)
    let (local k3_q1_mul2) = mul_fp_ul  (k3_q1, 2)
    let (local k2_q1d_mul2) = mul_fp_ul (k2_q1d, 2)
    let (local k3_q1d_mul2) = mul_fp_ul (k3_q1d, 2)
    let (local k2_q2_mul2) = mul_fp_ul  (k2_q2, 2)
    let (local k3_q2_mul2) = mul_fp_ul  (k3_q2, 2)
    let (local k2_q2d_mul2) = mul_fp_ul (k2_q2d, 2)
    let (local k3_q2d_mul2) = mul_fp_ul (k3_q2d, 2)
    local k_q1_sum  = k1_q1  + k2_q1_mul2  + k3_q1_mul2  + k4_q1
    local k_q1d_sum = k1_q1d + k2_q1d_mul2 + k3_q1d_mul2 + k4_q1d
    local k_q2_sum  = k1_q2  + k2_q2_mul2  + k3_q2_mul2  + k4_q2
    local k_q2d_sum = k1_q2d + k2_q2d_mul2 + k3_q2d_mul2 + k4_q2d
    let (local q1_delta)  = div_fp_ul (k_q1_sum, 6)
    let (local q1d_delta) = div_fp_ul (k_q1d_sum, 6)
    let (local q2_delta)  = div_fp_ul (k_q2_sum, 6)
    let (local q2d_delta) = div_fp_ul (k_q2d_sum, 6)

    # produce final estimation
    tempvar q1_nxt  = q1  + q1_delta
    tempvar q1d_nxt = q1d + q1d_delta
    tempvar q2_nxt  = q2  + q2_delta
    tempvar q2d_nxt = q2d + q2d_delta

    return (q1_nxt, q1d_nxt, q2_nxt, q2d_nxt)
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