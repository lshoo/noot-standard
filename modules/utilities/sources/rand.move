// This is a psuedo-random number generator; outputs will always be the same number
// given the same ctx (transaction context). Note that the ctx is mutated every time a
// number is generated, so it can be used consecutively in the same transaction, however
// the sequence of random numbers is deterministic.
//
// I don't know of any way for a user to externally "game" this; I believe the UID's
// generated by Sui are very dependent upon the chain itself.
//
// Eventually this should be replaced by a VRF from Switchboard (work in progress)

module utils::rand {
    use std::vector;
    use sui::object;
    use sui::math;
    use sui::tx_context::TxContext;

    const EBAD_RANGE: u64 = 0;
    const ETOO_FEW_BYTES: u64 = 1;
    const EDIVISOR_MUST_BE_NON_ZERO: u64 = 2;

    // Generates an integer from the range [min, max), not inclusive of max
    // bytes = vector<u8> with length of 20. However we only use the first 8 bytes
    public fun rng(min: u64, max: u64, ctx: &mut TxContext): u64 {
        assert!(max > min, EBAD_RANGE);

        let uid = object::new(ctx);
        let bytes = object::uid_to_bytes(&uid);
        object::delete(uid);

        let num = from_bytes(bytes);
        mod(num, max - min) + min
    }

    public fun from_bytes(bytes: vector<u8>): u64 {
        assert!(vector::length(&bytes) >= 8, ETOO_FEW_BYTES);

        let i: u8 = 0;
        let sum: u64 = 0;
        while (i < 8) {
            sum = sum + (*vector::borrow(&bytes, (i as u64)) as u64) * math::pow(2, (7 - i) * 8);
            i = i + 1;
        };

        sum
    }

    public fun mod(x: u64, divisor: u64): u64 {
        assert!(divisor > 0, EDIVISOR_MUST_BE_NON_ZERO);

        let quotient = x / divisor;
        x - (quotient * divisor)
    }

    public fun mod_u8(x: u8, divisor: u8): u8 {
        assert!(divisor > 0, EDIVISOR_MUST_BE_NON_ZERO);

        let quotient = x / divisor;
        x - (quotient * divisor)
    }
}

#[test_only]
module utils::rand_tests {
    use std::debug;
    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use utils::rand;

    const EOUTSIDE_RANGE: u64 = 0;
    const EBAD_SINGLE_RANGE: u64 = 1;
    const EONE_IN_A_MILLION_ERROR: u64 = 2;

    public fun print_rand(min: u64, max: u64, ctx: &mut TxContext): u64 {
        let num = rand::rng(min, max, ctx);
        debug::print(&num);
        assert!(num >= min && num < max, EOUTSIDE_RANGE);
        num
    }

    #[test]
    public fun test1() {
        // 1st tx: must always be == 1
        let scenario = test_scenario::begin(@0x5);
        print_rand(1, 2, test_scenario::ctx(&mut scenario));

        // 2nd tx
        test_scenario::next_tx(&mut scenario, @0x5);
        print_rand(15, 99, test_scenario::ctx(&mut scenario));

        // 3rd tx
        test_scenario::next_tx(&mut scenario, @0x5);
        let r1 = print_rand(99, 1000000, test_scenario::ctx(&mut scenario));

        // 4th tx: identical range as above tx, but different outcome
        test_scenario::next_tx(&mut scenario, @0x5);
        let r2 = print_rand(99, 1000000, test_scenario::ctx(&mut scenario));
        assert!(r1 != r2, EONE_IN_A_MILLION_ERROR);

        // 5th tx: 100 rands in the same tx
        test_scenario::next_tx(&mut scenario, @0x5);
        let i = 0;
        while (i < 100) {
            print_rand(0, 100, test_scenario::ctx(&mut scenario));
            i = i + 1;
        };

        test_scenario::end(scenario);
    }
}