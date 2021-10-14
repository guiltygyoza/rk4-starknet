import pytest
from starkware.starknet.testing.starknet import Starknet
from timeit import default_timer as timer


@pytest.mark.asyncio
async def test_dict():
    starknet = await Starknet.empty()
    print()

    contract = await starknet.deploy("o2d.cairo")

    ## note: if passing negative numbers to cairo function => must mod P in python first;
    ##       also, the return value from cairo has been mod P, so must detect neg value specifically
    PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
    PRIME_HALF = PRIME//2
    SCALE_FP = 10000 # consistent with SCALE_FP in the contract

    ## handling negative numbers returned by Cairo function (current testing framework does not handle this)
    def adjust_for_negative (history):
        return [e if e < PRIME_HALF else e-PRIME for e in history]

    def adjust_for_negative_single (e):
        return e if e < PRIME_HALF else e-PRIME

    # set constants for the experiment
    W = 600 # consistent with const W set in contract

    # initial condition
    x_0 = 150.
    xd_0 = 100.
    y_0 = 250.
    yd_0 = 50.
    t_0 = 0.

    # simulation setup
    dt = 0.02
    T = 5

    x_0_fp  = int(x_0 * SCALE_FP)
    xd_0_fp = int(xd_0 * SCALE_FP)
    y_0_fp  = int(y_0 * SCALE_FP)
    yd_0_fp = int(yd_0 * SCALE_FP)
    t_0_fp  = int(t_0 * SCALE_FP)
    dt_fp   = int(dt * SCALE_FP)

    # run rk4 integration continuously
    t_fp  = t_0_fp
    x_fp  = x_0_fp
    xd_fp = xd_0_fp
    y_fp  = y_0_fp
    yd_fp = yd_0_fp
    print(f'the lonely m starting at (x,y)=({x_fp},{y_fp}) with (v2,vy)=({xd_fp},{yd_fp})')

    x_fp_history  = [x_fp]
    xd_fp_history = [xd_fp]
    y_fp_history  = [y_fp]
    yd_fp_history = [yd_fp]

    N = int(T//dt)
    for i in range(N):
        # TODO deal with negative input args
        ret = await contract.query_next_given_coordinates(
            t   = t_fp,
            dt  = dt_fp,
            x   = x_fp,
            xd  = xd_fp,
            y   = y_fp,
            yd  = yd_fp
        ).call()

        x_fp  = ret.x_nxt
        xd_fp = ret.xd_nxt
        y_fp  = ret.y_nxt
        yd_fp = ret.yd_nxt

        x_fp_history.append (x_fp)
        xd_fp_history.append(xd_fp)
        y_fp_history.append (y_fp)
        yd_fp_history.append(yd_fp)
        print(f'{i+1}th/{N} retrieved.')

    x_fp_history  = adjust_for_negative (x_fp_history)
    xd_fp_history = adjust_for_negative (xd_fp_history)
    y_fp_history  = adjust_for_negative (y_fp_history)
    yd_fp_history = adjust_for_negative (yd_fp_history)

    print('x_fp_history:')
    print(f'  {x_fp_history}')
    print()

    print('y_fp_history:')
    print(f'  {y_fp_history}')

