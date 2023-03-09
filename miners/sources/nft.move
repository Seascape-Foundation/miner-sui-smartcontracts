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

    const ENotMinter: u64 = 1;
    const NFT_NAME: vector<u8> = b"MINES";

    struct Mine has key, store {
        id: UID,
        name: string::String,
        url: Url,
        // custom attributes of Nft
        generation: u64,
        quality: u64,
    }

    // The permissioned to mint
    struct Management has key {
        id: UID,
        base_uri: vector<u8>,
        minter: address,
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

    struct ManagementTransferred has copy, drop {
        owner: address,
    }

    struct SetMinter has copy, drop {
        minter: address,
    }

    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);

        let minter = Management {
            id: object::new(ctx),
            base_uri: b"https://sui-api.miniminersgame.com/meta/",
            minter: owner,
        };

        event::emit(ManagementTransferred {owner: owner});
        event::emit(SetMinter {minter: owner});

        // smartcontracts could be minted by the owner
        transfer::transfer(minter, owner)
    }

    // mint a new nft
    public entry fun mint(factory: &Management, receiver: address, generation: u64, quality: u64, ctx: &mut TxContext) {
        let minter = factory.minter;
        let sender = tx_context::sender(ctx);
        assert!(sender == minter, ENotMinter);
        
        let id = object::new(ctx);

        let id_bytes = object::uid_to_bytes(&id);
        let id_string = string::utf8(id_bytes);

        let token_url = string::utf8(factory.base_uri);

        string::append(&mut token_url, id_string);

        let mine = Mine {
            id: id,
            generation: generation,
            quality: quality,
            name: string::utf8(NFT_NAME),
            url: url::new_unsafe(string::to_ascii(token_url)),
        };

        event::emit(NftMinted {
            nft_id: object::id(&mine),
            receiver: receiver,
            quality: quality,
            generation: generation,
        });

        transfer::transfer(mine, receiver);
    }

    // transfer ownership over the nft management
    public entry fun transfer_ownership(management: Management, recipient: address, _ctx: &mut TxContext) {
        transfer::transfer(management, recipient);

        event::emit(ManagementTransferred {owner: recipient});
    }

    // Change the address who can mint nfts
    public entry fun set_minter(management: &mut Management, recipient: address, _ctx: &mut TxContext) {
        management.minter = recipient;

        event::emit(SetMinter {minter: recipient});
    }

    // transfer nft
    public entry fun transfer(mine: Mine, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        event::emit(NftTransferred {
            nft_id: object::id(&mine),
            receiver: recipient,
            sender: sender,
        });

        // transfer the MINES nft
        transfer::transfer(mine, recipient);
    }

    public fun generation(mine: &Mine): u64 {
        mine.generation
    }
    
    public fun quality(mine: &Mine): u64 {
        mine.quality
    }

    public fun name(_mine: &Mine): vector<u8> {
        NFT_NAME
    }

    #[test]
    public fun test_mint() {
        use sui::tx_context;
        use sui::url::{Self};
        use std::string;

        let ctx = tx_context::dummy();

        // generation and quality
        let g: u64 = 0;
        let q: u64 = 1;
        let id = object::new(&mut ctx);

        let mine = Mine {
            id: id,
            generation: g,
            quality: q,
            name: string::utf8(b""),
            url: url::new_unsafe_from_bytes(b""),
        };

        assert!(generation(&mine) == g && quality(&mine) == q, 1);

        transfer::transfer(mine, tx_context::sender(&mut ctx));
    }
}

