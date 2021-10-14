import pytest
from starkware.starknet.testing.starknet import Starknet
from timeit import default_timer as timer


@pytest.mark.asyncio
async def test_dict():
    starknet = await Starknet.empty()
    print()

    contract = await starknet.deploy("cho.cairo")

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
    W = 1000 # consistent with const W set in contract
    x1_0 = 100.
    x1d_0 = 0.
    x2_0 = 900.
    x2d_0 = 0.
    t_0 = 0.
    dt = 0.01
    T = 2

    x1_0_fp  = int(x1_0 * SCALE_FP)
    x1d_0_fp = int(x1d_0 * SCALE_FP)
    x2_0_fp  = int(x2_0 * SCALE_FP)
    x2d_0_fp = int(x2d_0 * SCALE_FP)
    t_0_fp  = int(t_0 * SCALE_FP)
    dt_fp   = int(dt * SCALE_FP)

    # run rk4 integration continuously
    t_fp = t_0_fp
    x1_fp = x1_0_fp
    x1d_fp = x1d_0_fp
    x2_fp = x2_0_fp
    x2d_fp = x2d_0_fp
    print(f'm1 starting at x1: {x1_fp} with v1: {x1d_fp}')
    print(f'm2 starting at x2: {x2_fp} with v2: {x2d_fp}')

    x1_fp_history  = [x1_fp]
    x1d_fp_history = [x1d_fp]
    x2_fp_history  = [x2_fp]
    x2d_fp_history = [x2d_fp]
    x1_delta_history = []

    N = int(T//dt)
    for i in range(N):
        ret = await contract.query_next_given_coordinates(
            t   = t_fp,
            dt  = dt_fp,
            x1  = x1_fp,
            x1d = x1d_fp,
            x2  = x2_fp,
            x2d = x2d_fp
        ).call()

        x1_fp  = ret.x1_nxt
        x1d_fp = ret.x1d_nxt
        x2_fp  = ret.x2_nxt
        x2d_fp = ret.x2d_nxt

        x1_fp_history.append (x1_fp)
        x1d_fp_history.append(x1d_fp)
        x2_fp_history.append (x2_fp)
        x2d_fp_history.append(x2d_fp)
        print(f'{i+1}th/{N} retrieved.')

    x1_fp_history  = adjust_for_negative (x1_fp_history)
    x1d_fp_history = adjust_for_negative (x1d_fp_history)
    x2_fp_history  = adjust_for_negative (x2_fp_history)
    x2d_fp_history = adjust_for_negative (x2d_fp_history)

    print('x1_fp_history:')
    print(f'  {x1_fp_history}')
    print()

    print('x2_fp_history:')
    print(f'  {x2_fp_history}')

