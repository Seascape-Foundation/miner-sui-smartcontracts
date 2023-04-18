// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// A basic ECDSA utility contract to do the following: 
// 1) Hash a piece of data using keccak256, output an object with hashed data.
// 2) Recover a Secp256k1 signature to its public key, output an object with the public key. 
// 3) Verify a Secp256k1 signature, produce an event for whether it is verified. 
module mini_miners::verifier {
    use sui::ecdsa_k1;
    use sui::hash;
    use std::vector;

    public fun ecrecover(signature: vector<u8>, msg: vector<u8>): vector<u8> {
        // Normalize the last byte of the signature to be 0 or 1.
        let v = vector::borrow_mut(&mut signature, 64);
        if (*v == 27) {
            *v = 0;
        } else if (*v == 28) {
            *v = 1;
        } else if (*v > 35) {
            *v = (*v - 1) % 2;
        };

        // keccak256 constant = 0 
        // ecdsa_r1::KECCAK256
        // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/docs/ecdsa_r1.md
        let pubkey = ecdsa_k1::secp256k1_ecrecover(&signature, &msg, 0);
        // let uncompressed = ecdsa_k1::decompress_pubkey(&pubkey);

        // // address::from_bytes(uncompressed)
        // // Take the last 64 bytes of the uncompressed pubkey.
        // let uncompressed_64 = vector::empty<u8>();
        // let i = 1;
        // while (i < 65) {
        //     let value = vector::borrow(&uncompressed, i);
        //     vector::push_back(&mut uncompressed_64, *value);
        //     i = i + 1;
        // };

        // // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.
        // let hashed = hash::keccak256(&uncompressed_64);
        // let addr = vector::empty<u8>();
        // let i = 12;
        // while (i < 32) {
        //     let value = vector::borrow(&hashed, i);
        //     vector::push_back(&mut addr, *value);
        //     i = i + 1;
        // };

        // address::from_bytes(addr)
        pubkey
    }

    public fun ecrecover_to_eth_address(signature: vector<u8>, msg: vector<u8>): vector<u8> {
        // Normalize the last byte of the signature to be 0 or 1.
        let v = vector::borrow_mut(&mut signature, 64);
        if (*v == 27) {
            *v = 0;
        } else if (*v == 28) {
            *v = 1;
        } else if (*v > 35) {
            *v = (*v - 1) % 2;
        };

        // keccak256 constant = 0 
        // ecdsa_r1::KECCAK256
        // https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/docs/ecdsa_r1.md
        let pubkey = ecdsa_k1::secp256k1_ecrecover(&signature, &msg, 0);
        let uncompressed = ecdsa_k1::decompress_pubkey(&pubkey);

        // Take the last 64 bytes of the uncompressed pubkey.
        let uncompressed_64 = vector::empty<u8>();
        let i = 1;
        while (i < 65) {
            let value = vector::borrow(&uncompressed, i);
            vector::push_back(&mut uncompressed_64, *value);
            i = i + 1;
        };

        // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.
        let hashed = hash::keccak256(&uncompressed_64);
        let addr = vector::empty<u8>();
        let i = 12;
        while (i < 32) {
            let value = vector::borrow(&hashed, i);
            vector::push_back(&mut addr, *value);
            i = i + 1;
        };

        addr
    }
}