// SPDX-License-Identifier: Mozilla Public License 2.0

// IMPORTANT! Sui module names are always in CamelCase format.
// Ref: https://github.com/MystenLabs/sui/blob/main/doc/src/build/move/index.md
module mini_miners::mine_nft {
    use sui::url::{Self, Url};
    use std::string;
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const ENotFactory: u64 = 1;

    struct Mine has key, store {
        id: UID,
        name: string::String,
        quality: u64,
        url: Url,
        // custom attributes of Nft
        description: string::String,
        generation: u64,
    }

    // The permissioned to mint
    struct Factory has key {
        id: UID,
        permissioned: bool,
    }

    ////////////////////////////////////////////////
    //
    // ============ Events ============
    //
    ////////////////////////////////////////////////

    struct NftMinted has copy, drop {
        nft_id: ID,
        receiver: address,
        quality: u64,
        generation: u64,
    }

    struct NftTransferred has copy, drop {
        nft_id: ID,
        receiver: address,
        sender: address,
    }

    fun init(ctx: &mut TxContext) {
        let minter = Factory {
            id: object::new(ctx),
            permissioned: true,
        };
        // smartcontracts could be minted by the owner
        transfer::transfer(minter, tx_context::sender(ctx))
    }

    // mint a new nft
    // todo: create an event that emits generation, quality
    public entry fun mint(factory: &Factory, to: address, generation: u64, quality: u64, ctx: &mut TxContext) {
        assert!(factory.permissioned == true, ENotFactory);

        let mine = Mine {
            id: object::new(ctx),
            generation: generation,
            quality: quality,
            name: string::utf8(b"MINES"),
            url: url::new_unsafe_from_bytes(b"https://sui-api.miniminersgame.com/metadata/any"),
            description: string::utf8(b"The MiniMiners nft")
        };

        event::emit(NftMinted {
            nft_id: object::id(&mine),
            receiver: to,
            quality: quality,
            generation: generation,
        });

        transfer::transfer(mine, to);
    }

    // transfer minted nft
    public entry fun transfer(mine: Mine, recipient: address, ctx: &mut TxContext) {
        use sui::transfer;

        let sender = tx_context::sender(ctx);

        event::emit(NftTransferred {
            nft_id: object::id(&mine),
            receiver: recipient,
            sender: sender,
        });

        // transfer the MineNFT
        transfer::transfer(mine, recipient);
    }

    public fun generation(mine: &Mine): u64 {
        mine.generation
    }
    
    public fun quality(mine: &Mine): u64 {
        mine.quality
    }

    #[test]
    public fun test_mint() {
        use sui::tx_context;

        let ctx = tx_context::dummy();

        // generation and quality
        let g: u64 = 0;
        let q: u64 = 1;
        let id = object::new(&mut ctx);

        let mine = Mine {
            id: id,
            generation: g,
            quality: q,
        };

        assert!(generation(&mine) == g && quality(&mine) == q, 1);

        transfer::transfer(mine, tx_context::sender(&mut ctx));
    }
}

