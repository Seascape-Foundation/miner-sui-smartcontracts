// SPDX-License-Identifier: Mozilla Public License 2.0

// IMPORTANT! Sui module names are always in CamelCase format.
// Ref: https://github.com/MystenLabs/sui/blob/main/doc/src/build/move/index.md
module mini_miners::mine_nft {
    use sui::url::{Self, Url};
    use std::string;
    use sui::address;
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field;
    use sui::bcs;
    use mini_miners::verifier;

    const ENotMinter: u64 = 1;
    const ENotOwner: u64 = 1;
    const EMinterExists: u64 = 2;
    const ESigFail: u64 = 4;

    const NFT_NAME: vector<u8> = b"MINES";

    struct Mine has key, store {
        id: UID,
        name: string::String,
        url: Url,
        // custom attributes of Nft
        generation: u64,
        quality: u64,
    }

    struct Info has key {
        id: UID,
        base_uri: vector<u8>,
        owner: address,
        verifier: vector<u8>,
    }

    struct Minter has key, store {
        id: UID,
    }

    #[derive(Serialize)]
    struct MintNftMessage has drop {
        minter: vector<u8>, // the minter game name
        owner: address,
        timestamp: u64,
        generation: u64,
        quality: u64,
    }


    ////////////////////////////////////////////////
    //
    // ============ Events ============
    //
    ////////////////////////////////////////////////

    struct NftMinted has copy, drop {
        nft_id: ID,
        recipient: address,
        quality: u64,
        generation: u64,
    }

    struct NftTransferred has copy, drop {
        nft_id: ID,
        recipient: address,
        sender: address,
    }

    struct TransferOwnership has copy, drop {
        owner: address,
    }

    struct AddMinter has copy, drop {
        minter: address,
    }

    struct DeleteMinter has copy, drop {
        minter: address,
    }

    struct SetBaseUri has copy, drop {
        value: vector<u8>,
    }

    struct SetVerifier has copy, drop {
        recepient: vector<u8>,
    }

    struct NftMintedBy has copy, drop {
        minter: vector<u8>,
        player: address,
        generation: u64,
        quality: u64,
    }

    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);

        let info = Info {
            id: object::new(ctx),
            base_uri: b"https://sui-api.miniminersgame.com/meta/",
            owner: owner,
            verifier: x"eb3b05ca37ae926fc8d0a2115ca0903800a502f8",
        };

        add_minter(&mut info, owner, ctx);

        // smartcontracts could be minted by the owner
        transfer::share_object(info);

        event::emit(SetBaseUri {value: b"https://sui-api.miniminersgame.com/meta/"});
        event::emit(TransferOwnership {owner: owner});
    }

    // Grants the permission to recepient to mint new NFTs.
    // info Object contains the owner information. Only Owner can call this function.
    public entry fun add_minter(info: &mut Info, recepient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == info.owner, ENotOwner);

        assert!(!dynamic_object_field::exists_with_type<address, Minter>(&info.id, recepient), EMinterExists);

        let minter = Minter {
            id: object::new(ctx),
        };

        dynamic_object_field::add<address, Minter>(&mut info.id, recepient, minter);

        event::emit(AddMinter {minter: recepient});
    }

    public entry fun remove_minter(info: &mut Info, recepient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == info.owner, ENotOwner);

        assert!(dynamic_object_field::exists_with_type<address, Minter>(&info.id, recepient), ENotMinter);

        let Minter { id } = dynamic_object_field::remove<address, Minter>(&mut info.id, recepient);
        object::delete(id);

        event::emit(DeleteMinter {minter: recepient});
    }

    fun mint_internal(info: &Info, recipient: address, generation: u64, quality: u64, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let id_address = object::uid_to_address(&id);
        let id_string = address::to_string(id_address);
        let token_url = string::utf8(info.base_uri);
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
            recipient: recipient,
            quality: quality,
            generation: generation,
        });

        transfer::transfer(mine, recipient);
    }

    // mint a new nft
    public entry fun mint(info: &Info, recipient: address, generation: u64, quality: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(dynamic_object_field::exists_with_type<address, Minter>(&info.id, sender), ENotMinter);

        mint_internal(info, recipient, generation, quality, ctx);
    }

    // mint a new nft
    public entry fun mint_by(info: &Info, recipient: address, generation: u64, quality: u64, timestamp: u64, signature: vector<u8>, minter: vector<u8>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let message = MintNftMessage {
            minter: minter,
            owner: sender,
            timestamp: timestamp,
            generation: generation,
            quality: quality,
        };

        let message_bytes = bcs::to_bytes(&message);
        let recovered_address = verifier::ecrecover_to_eth_address(signature, message_bytes);
        assert!(info.verifier == recovered_address, ESigFail);

        mint_internal(info, recipient, generation, quality, ctx);

        event::emit(NftMintedBy{minter: minter, player: sender, generation: generation, quality: quality})
    }

    // Update the backend private key
    public entry fun set_verifier(info: &mut Info, recepient: vector<u8>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == info.owner, ENotOwner);
        info.verifier = recepient;

        event::emit(SetVerifier {recepient: recepient});
    }

    #[test_only]
    public fun mint_test(ctx: &mut TxContext): Mine {
        let id = object::new(ctx);
        let g: u64 = 0;
        let q: u64 = 1;

        let mine = Mine {
            id: id,
            generation: g,
            quality: q,
            name: string::utf8(b""),
            url: url::new_unsafe_from_bytes(b""),
        };

        mine
    }

    #[test_only]
    public fun burn_test(mine: Mine, _ctx: &mut TxContext) {
        let Mine { id, generation: _, quality: _, name: _, url: _ } = mine;
        object::delete(id);
    }

    // transfer ownership over the nft management
    public entry fun transfer_ownership(info: &mut Info, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == info.owner, ENotOwner);

        info.owner = recipient;

        event::emit(TransferOwnership {owner: recipient});
    }

    // transfer nft
    public entry fun transfer(mine: Mine, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        event::emit(NftTransferred {
            nft_id: object::id(&mine),
            recipient: recipient,
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

