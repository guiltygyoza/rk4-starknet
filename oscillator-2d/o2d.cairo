%lang starknet
%builtins pedersen range_check

from starkware.starknet.common.storage import Storage
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (signed_div_rem, sign)

const RANGE_CHECK_BOUND = 2 ** 64
const SCALE_FP = 10000

# Generated problem-specific struct for holding the coordinates for dynamics (all in fixed-point representation)
struct Dynamics:
    member q1  : felt
    member q1d : felt
    member q2  : felt
    member q2d : felt
end

# Generated function to compute the sum of two Dynamics structs
func dynamics_add {range_check_ptr} (
        state_a : Dynamics,
        state_b : Dynamics
    ) -> (
        state_z : Dynamics
    ):
    alloc_locals
    local q1_  = state_a.q1  + state_b.q1
    local q1d_ = state_a.q1d + state_b.q1d
    local q2_  = state_a.q2  + state_b.q2
    local q2d_ = state_a.q2d + state_b.q2d
    local state_z : Dynamics = Dynamics(q1=q1_, q1d=q1d_, q2=q2_, q2d=q2d_)
    return (state_z)
end

# Generated function to compute a Dynamics struct multiplied by a fixed-point value
func dynamics_mul_fp {range_check_ptr} (
        state_a : Dynamics,
        multiplier_fp  : felt
    ) -> (
        state_z : Dynamics
    ):
    alloc_locals
    local q1  = state_a.q1
    local q1d = state_a.q1d
    local q2  = state_a.q2
    local q2d = state_a.q2d
    let (local q1_)  = mul_fp (q1,  multiplier_fp)
    let (local q1d_) = mul_fp (q1d, multiplier_fp)
    let (local q2_)  = mul_fp (q2,  multiplier_fp)
    let (local q2d_) = mul_fp (q2d, multiplier_fp)
    local state_z : Dynamics = Dynamics(q1=q1_, q1d=q1d_, q2=q2_, q2d=q2d_)
    return (state_z)
end

# Generated function to compute a Dynamics struct multiplied by a unit-less value
func dynamics_mul_fp_ul {range_check_ptr} (
        state_a : Dynamics,
        multiplier_ul  : felt
    ) -> (
        state_z : Dynamics
    ):
    alloc_locals
    local q1  = state_a.q1
    local q1d = state_a.q1d
    local q2  = state_a.q2
    local q2d = state_a.q2d
    let (local q1_)  = mul_fp_ul (q1,  multiplier_ul)
    let (local q1d_) = mul_fp_ul (q1d, multiplier_ul)
    let (local q2_)  = mul_fp_ul (q2,  multiplier_ul)
    let (local q2d_) = mul_fp_ul (q2d, multiplier_ul)
    local state_z : Dynamics = Dynamics(q1=q1_, q1d=q1d_, q2=q2_, q2d=q2d_)
    return (state_z)
end

# Generated function to compute a Dynamics struct divided by a unit-less value
func dynamics_div_fp_ul {range_check_ptr} (
        state_a : Dynamics,
        divisor_ul  : felt
    ) -> (
        state_z : Dynamics
    ):
    alloc_locals
    local q1  = state_a.q1
    local q1d = state_a.q1d
    local q2  = state_a.q2
    local q2d = state_a.q2d
    let (local q1_)  = div_fp_ul (q1,  divisor_ul)
    let (local q1d_) = div_fp_ul (q1d, divisor_ul)
    let (local q2_)  = div_fp_ul (q2,  divisor_ul)
    let (local q2d_) = div_fp_ul (q2d, divisor_ul)
    local state_z : Dynamics = Dynamics(q1=q1_, q1d=q1d_, q2=q2_, q2d=q2d_)
    return (state_z)
end

### Utility functions for fixed-point arithmetic

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

func mul_fp_ul {range_check_ptr} (
        a : felt,
        b_ul : felt
    ) -> (
        c : felt
    ):
    let c = a * b_ul
    return (c)
end

func div_fp_ul {range_check_ptr} (
        a : felt,
        b_ul : felt
    ) -> (
        c : felt
    ):
    let (c, _) = signed_div_rem(a, b_ul, RANGE_CHECK_BOUND)
    return (c)
end

# Generated Runge-Kutta 4th-order method for Dynamics state
func rk4 {range_check_ptr} (
        t : felt,
        dt : felt,
        state : Dynamics
    ) -> (
        state_nxt : Dynamics
    ):
    alloc_locals
    # k1 stage
    local k1_state : Dynamics            = state
    let (local k1_state_diff : Dynamics) = eval (k1_state)
    let (local k1 : Dynamics)            = dynamics_mul_fp (k1_state_diff, dt)

    # k2 stage
    let (local k1_half : Dynamics)       = dynamics_div_fp_ul (k1, 2)
    let (local k2_state : Dynamics)      = dynamics_add(state, k1_half)
    let (local k2_state_diff : Dynamics) = eval (k2_state)
    let (local k2 : Dynamics)            = dynamics_mul_fp (k2_state_diff, dt)

    # k3 stage
    let (local k2_half : Dynamics)       = dynamics_div_fp_ul (k2, 2)
    let (local k3_state : Dynamics)      = dynamics_add(state, k2_half)
    let (local k3_state_diff : Dynamics) = eval (k3_state)
    let (local k3 : Dynamics)            = dynamics_mul_fp (k3_state_diff, dt)

    # k4 stage
    let (local k4_state : Dynamics)      = dynamics_add(state, k3)
    let (local k4_state_diff : Dynamics) = eval (k4_state)
    let (local k4 : Dynamics)            = dynamics_mul_fp (k4_state_diff, dt)

    # sum k, mul dt, div 6, obtain state_nxt
    let (local k2_2)        = dynamics_mul_fp_ul (k2, 2)
    let (local k3_2)        = dynamics_mul_fp_ul (k3, 2)
    let (local sum_k1_2k2)  = dynamics_add (k1, k2_2) # wish we could overload operators..
    let (local sum_2k3_k4)  = dynamics_add (k3_2, k4)
    let (local k_sum)       = dynamics_add (sum_k1_2k2, sum_2k3_k4)
    let (local state_delta) = dynamics_div_fp_ul (k_sum, 6)
    let (local state_nxt)   = dynamics_add (state, state_delta)

    return (state_nxt)
end

# Problem-specific evaluation function for first-order derivative of x and xd
func eval {range_check_ptr} (
        state : Dynamics
    ) -> (
        state_diff : Dynamics
    ):
    alloc_locals

    # unpack struct
    local x  = state.q1
    local xd = state.q1d
    local y  = state.q2
    local yd = state.q2d

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

    local state_diff : Dynamics = Dynamics(
        q1  = x_diff,
        q1d = vx_diff,
        q2  = y_diff,
        q2d = vy_diff
    )

    return (state_diff)
end

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
    #   use t, state to calculate next state at t+dt
    #   return next state

    local state : Dynamics = Dynamics(q1=x, q1d=xd, q2=y, q2d=yd) # packing

    let (state_nxt) = rk4 (t=t, dt=dt, state=state)

    local x_nxt  = state_nxt.q1 # unpacking
    local xd_nxt = state_nxt.q1d
    local y_nxt  = state_nxt.q2
    local yd_nxt = state_nxt.q2d

    return (x_nxt, xd_nxt, y_nxt, yd_nxt)
end

