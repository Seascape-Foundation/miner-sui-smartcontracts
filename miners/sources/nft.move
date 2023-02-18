// SPDX-License-Identifier: Mozilla Public License 2.0

// IMPORTANT! Sui module names are always in CamelCase format.
// Ref: https://github.com/MystenLabs/sui/blob/main/doc/src/build/move/index.md
module mini_miners::mine_nft {
    use sui::object::{Self, UID};
    // use sui::object_bag::{Self, ObjectBag};
    // use sui::object_table::{Self, ObjectTable};
    // use sui::dynamic_object_field;
    // use sui::typed_id::{Self, TypedID};
    use sui::tx_context::{Self, TxContext};
    // use std::option::{Self, Option};
    use sui::transfer;
    // use std::ascii::{Self, String};
    // use std::vector;

    const ENotFactory: u64 = 1;

    struct Mine has key, store {
        id: UID,
        generation: u64,
        quality: u64
    }

    // The permissioned to mint
    struct Factory has key {
        id: UID,
        permissioned: bool,
    }

    fun init(ctx: &mut TxContext) {
        let minter = Factory {
            id: object::new(ctx),
            permissioned: true,
        };
        transfer::transfer(minter, tx_context::sender(ctx))
    }

    public fun mint(factory: &Factory, to: address, generation: u64, quality: u64, ctx: &mut TxContext) {
        assert!(factory.permissioned == true, ENotFactory);

        let mine = Mine {
            id: object::new(ctx),
            generation: generation,
            quality: quality
        };

        transfer::transfer(mine, to);
    }
}