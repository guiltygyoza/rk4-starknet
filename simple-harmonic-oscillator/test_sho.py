import pytest
from starkware.starknet.testing.starknet import Starknet
from timeit import default_timer as timer

@pytest.mark.asyncio
async def test_dict():
    starknet = await Starknet.empty()
    print()

    contract = await starknet.deploy("sho.cairo")

    ## note: if passing negative numbers to cairo function => must mod P in python first;
    ##       also, the return value from cairo has been mod P, so must detect neg value specifically
    PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481
    PRIME_HALF = PRIME//2
    SCALE_FP = 10000 # consistent with SCALE_FP in the contract

    # set constants for the experiment
    x_0 = 100.
    xd_0 = 0.
    t_0 = 0.
    dt = 0.01
    T = 2

    t_0_fp  = int(t_0 * SCALE_FP)
    dt_fp   = int(dt * SCALE_FP)
    x_0_fp  = int(x_0 * SCALE_FP)
    xd_0_fp = int(xd_0 * SCALE_FP)
    #await contract.set_coordinate(x=x_0_fp, xd=xd_0_fp).invoke()

    # run rk4 integration continuously
    t_fp = t_0_fp
    x_fp = x_0_fp
    xd_fp = xd_0_fp
    print(f'starting x: {x_fp}')
    print(f'starting xd: {xd_fp}')

    x_fp_history = [x_fp]
    xd_fp_history = [xd_fp]

    N = int(T//dt)
    for i in range(N):
        ret = await contract.query_next_given_coordinates(
            t  = t_fp,
            dt = dt_fp,
            x  = x_fp,
            xd = xd_fp
        ).call()
        x_fp = ret.x_nxt
        xd_fp = ret.xd_nxt
        x_fp_history.append(x_fp)
        xd_fp_history.append(xd_fp)
        print(f'{i+1}th/{N} retrieved.')

    ## handling negative numbers returned by Cairo function (current testing framework does not handle this)
    x_fp_history = [x if x < PRIME_HALF else x-PRIME for x in x_fp_history]
    xd_fp_history = [xd if xd < PRIME_HALF else xd-PRIME for xd in xd_fp_history]

    print('x_fp_history:')
    print(x_fp_history)

    print('xd_fp_history:')
    print(xd_fp_history)

    # test utility functions for fixed-point arithmetic (they must be @view for testing purposes)
    '''
    a = int( 1.5 * SCALE_FP )
    b = int( 1.7 * SCALE_FP )
    ret = await contract.mul_fp(a,b).call()
    print(f'mul_fp({a},{b}) returns {ret.c}')

    a = int( 5.0 * SCALE_FP )
    b = int( 2.0 * SCALE_FP )
    ret = await contract.div_fp(a,b).call()
    print(f'div_fp({a},{b}) returns {ret.c}')
    '''

    # run rk4 integration
    #for i in range(1):
    #    ret = await contract.query_next(dt=1).invoke()
    #    print(f'x={ret.x_nxt}, xd={ret.xd_nxt}')
