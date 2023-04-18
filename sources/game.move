// SPDX-License-Identifier: Mozilla Public License 2.0

// This package imports and exports the nfts
// It also contains the functions to exchange the in-game currency to the token
module mini_miners::game {
    use sui::object::{Self, ID, UID};
    use sui::dynamic_object_field;
    use mini_miners::verifier;
    use sui::transfer;
    use sui::bcs;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;
    use std::type_name;

    const ENotOwner: u64 = 1;
    const EAmountIncorrect: u64 = 2;
    const ENotEnoughFunds: u64 = 3;
    const ESigFail: u64 = 4;

    const IMPORT_NFT_PREFIX: vector<u8> = b"import_miner_nft";
    const SELL_PACK_PREFIX: vector<u8> = b"sell_miner_pack";
    const BUY_PACK_PREFIX: vector<u8> = b"buy_miner_pack";

    struct PlayerParams has key, store {
        id: UID,
        owner: address,
        stake_time: u64
    }

    struct Game has key {
        id: UID,
        owner: address,
        collector: address,
        verifier: vector<u8>,
    }

    #[derive(Serialize)]
    struct ImportNftMessage has drop {
        prefix: vector<u8>,
        nft_id: ID,
        owner: address,
        timestamp: u64,
    }

    #[derive(Serialize)]
    struct PackMessage has drop {
        prefix: vector<u8>,
        token_amount: u64,
        coin_type: type_name::TypeName,
        pack_id: u8,
        game: address,
        owner: address,
        timestamp: u64,
    }

    //////////////////////////////////////////////////////////////
    //
    // Events
    //
    //////////////////////////////////////////////////////////////

    struct SellPack has copy, drop {
        player: address,
        token_amount: u64,
        pack_id: u8,
    }

    struct BuyPack has copy, drop {
        player: address,
        token_amount: u64,
        pack_id: u8,
    }

    struct NftImported has copy, drop {
        nft_id: ID,
        owner: address,
    }

    struct NftExported has copy, drop {
        nft_id: ID,
        owner: address,
    }

    struct TransferOwnership has copy, drop {
        recepient: address,
    }

    struct SetCollector has copy, drop {
        recepient: address,
    }

    struct SetVerifier has copy, drop {
        recepient: vector<u8>,
    }

    struct Checkin has copy, drop {
        player: address,
    }

    // Upon deployment, we create a shared nonce
    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);

        let game = Game {
            id: object::new(ctx),
            owner: owner,
            collector: owner,
            verifier: x"eb3b05ca37ae926fc8d0a2115ca0903800a502f8",
        };
        transfer::share_object(game);

        event::emit(TransferOwnership {recepient: owner});
        event::emit(SetCollector {recepient: owner});
        event::emit(SetVerifier {recepient: x"eb3b05ca37ae926fc8d0a2115ca0903800a502f8"});
    }

    //////////////////////////////////////////////////////////////////
    //
    // Nft import/export
    //
    //////////////////////////////////////////////////////////////////

    // import nft into the game.
    public entry fun import_nft<T: key + store>(game: &mut Game, item: T, timestamp: u64, signature: vector<u8>, ctx: &mut TxContext) {
        let nft_id = object::id(&item);
        let sender = tx_context::sender(ctx);
        
        let import_nft_message = ImportNftMessage {
            prefix: IMPORT_NFT_PREFIX,
            nft_id: nft_id,
            owner: sender,
            timestamp: timestamp,
        };
        let import_nft_bytes = bcs::to_bytes(&import_nft_message);
        let recovered_address = verifier::ecrecover_to_eth_address(signature, import_nft_bytes);
        assert!(game.verifier == recovered_address, ESigFail);

        let params = PlayerParams {
            id: object::new(ctx),
            owner: sender,
            stake_time: timestamp,
        };

        dynamic_object_field::add(&mut params.id, true, item);
        dynamic_object_field::add(&mut game.id, nft_id, params);

        event::emit(NftImported{nft_id: nft_id, owner: sender});
    }

    // Export the nft back to the user.
    public fun export_nft<T: key + store>(
        game: &mut Game,
        item_id: ID,
        ctx: &mut TxContext
    ): T {
        assert!(dynamic_object_field::exists_with_type<ID, PlayerParams>(&game.id, item_id), 0);

        let PlayerParams {
            id,
            owner,
            stake_time: _,
        } = dynamic_object_field::remove(&mut game.id, item_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let item = dynamic_object_field::remove(&mut id, true);
        object::delete(id);
        item
    }

    /// Call [`delist`] and transfer item to the sender.
    public entry fun export_nft_and_return<T: key + store>(
        game: &mut Game,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let item = export_nft<T>(game, item_id, ctx);
        transfer::public_transfer(item, tx_context::sender(ctx));

        event::emit(NftExported{nft_id: item_id, owner: tx_context::sender(ctx)});
    }

    /////////////////////////////////////////////////////////////////////
    //
    // In-game currency to Token
    //
    /////////////////////////////////////////////////////////////////////

    // We add some tokens into the balance of the Game
    // That will be send to the users later.    
    public entry fun transfer_token<COIN>(game: &mut Game, paid: Coin<COIN>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.collector, ENotOwner);

        if (dynamic_object_field::exists_with_type<address, Coin<COIN>>(&game.id, sender)) {
            coin::join(
                dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, sender),
                paid
            )
        } else {
            dynamic_object_field::add<address, Coin<COIN>>(&mut game.id, sender, paid);
        }
    }

    // User sells the in-game currency in exchange for COIN.
    // Or any other pack that we define
    public entry fun sell_pack<COIN>(game: &mut Game, token_amount: u64, pack_id: u8, timestamp: u64, signature: vector<u8>, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let collector = game.collector;

        let message = PackMessage {
            prefix: SELL_PACK_PREFIX,
            token_amount: token_amount,
            coin_type: type_name::get<COIN>(),
            pack_id: pack_id,
            game: object::id_address(game),
            owner: player,
            timestamp: timestamp,
        };
        let message_bytes = bcs::to_bytes(&message);
        let recovered_address = verifier::ecrecover_to_eth_address(signature, message_bytes);
        assert!(game.verifier == recovered_address, ESigFail);

        assert!(dynamic_object_field::exists_<address>(&game.id, collector), ENotEnoughFunds);

        let borrowed_coin = coin::split(
            dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, collector),
            token_amount,
            ctx
        );

        transfer::public_transfer(borrowed_coin, player);

        event::emit(SellPack{player, token_amount, pack_id: pack_id})
    }

    // Buy a resource pack or diamond pack
    // todo change the pack_id to the to resource type.
    public entry fun buy_pack<COIN>(game: &mut Game, paid: Coin<COIN>, pack_id: u8, timestamp: u64, signature: vector<u8>, ctx: &mut TxContext) {
        let token_amount = coin::value(&paid);
        let player = tx_context::sender(ctx);

        let message = PackMessage {
            prefix: BUY_PACK_PREFIX,
            token_amount: token_amount,
            coin_type: type_name::get<COIN>(),
            pack_id: pack_id,
            game: object::id_address(game),
            owner: player,
            timestamp: timestamp,
        };
        let message_bytes = bcs::to_bytes(&message);
        let recovered_address = verifier::ecrecover_to_eth_address(signature, message_bytes);
        assert!(game.verifier == recovered_address, ESigFail);

        transfer::public_transfer(paid, game.collector);

        let player = tx_context::sender(ctx);

        event::emit(BuyPack{player, token_amount, pack_id})
    }

    /////////////////////////////////////////////////////////////////////
    //
    // Sui specific
    //
    /////////////////////////////////////////////////////////////////////

    public entry fun checkin(
        ctx: &mut TxContext
    ) {
        event::emit(Checkin{player: tx_context::sender(ctx)})
    }

    
    /////////////////////////////////////////////////////////////////////
    //
    // The Game owner functions
    //
    /////////////////////////////////////////////////////////////////////


    public entry fun transfer_ownership(game: &mut Game, recepient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.owner, ENotOwner);
        game.owner = recepient;

        event::emit(TransferOwnership {recepient: recepient});
    }

    // Update the fee collector
    public entry fun set_collector(game: &mut Game, recepient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.owner, ENotOwner);
        game.collector = recepient;

        event::emit(SetCollector {recepient: recepient});
    }

    // Update the backend private key
    public entry fun set_verifier(game: &mut Game, recepient: vector<u8>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.owner, ENotOwner);
        game.verifier = recepient;

        event::emit(SetVerifier {recepient: recepient});
    }

    /////////////////////////////////////////////////////////////////////
    //
    // Testing buy and sell
    //
    /////////////////////////////////////////////////////////////////////

    #[test_only]
    public entry fun sell_pack_without_signature<COIN>(game: &mut Game, token_amount: u64, pack_id: u8, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let collector = game.collector;

        assert!(dynamic_object_field::exists_<address>(&game.id, collector), ENotEnoughFunds);

        let borrowed_coin = coin::split(
            dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, collector),
            token_amount,
            ctx
        );

        transfer::public_transfer(borrowed_coin, player);

        event::emit(SellPack{player, token_amount, pack_id: pack_id})
    }

    #[test_only]
    public entry fun buy_pack_without_signature<COIN>(game: &mut Game, paid: Coin<COIN>, pack_id: u8, ctx: &mut TxContext) {
        let token_amount = coin::value(&paid);
        let player = tx_context::sender(ctx);

        transfer::public_transfer(paid, game.collector);

        event::emit(BuyPack{player, token_amount, pack_id})
    }

    #[test]
    public fun test_import_nft() {
        use sui::test_scenario;
        use sui::sui::SUI;
        use std::debug;
        use std::string;

        let collector: address = @0x84818b44cb33fae71f25ca9aa3d8aed0aadbc87f784f0f6eccbce02bb2217742;

        // first we create the game object
        let scenario_val = test_scenario::begin(collector);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        // let's mint some SUI coins for the deployer
        test_scenario::next_tx(scenario, collector);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            transfer::public_transfer(coin, collector);
        };

        // mint some nft for the user
        test_scenario::next_tx(scenario, collector);
        {
            debug::print(&string::utf8(b"starting to check parameters"));

            let sender: address = @0x84818b44cb33fae71f25ca9aa3d8aed0aadbc87f784f0f6eccbce02bb2217742;
            let timestamp: u64 = 1681830785;

            let import_nft_message = ImportNftMessage {
                prefix: IMPORT_NFT_PREFIX,
                nft_id: object::id_from_address(@0x59078ead25bee396ed7c971abe359d0c91a386bd61dab760af2ba0b353208941),
                owner: sender,
                timestamp: timestamp,
            };
            let import_nft_bytes = bcs::to_bytes(&import_nft_message);

            let signature: vector<u8> = x"47d7a769dbe9dec47c8fa954f24e849685be8304939d55d7f5b5dc3ab47a88c96a6fadb677cad34b2bd241a0a0ac768ce38306d432d34f69d29664fdba9eded200";
            let verifier: vector<u8> = x"EB3B05cA37aE926fC8D0a2115Ca0903800a502f8";
            let recovered_address = verifier::ecrecover_to_eth_address(signature, import_nft_bytes);

            let equal = verifier == recovered_address;
            debug::print(&import_nft_bytes);
            debug::print(&import_nft_message);
            debug::print(&equal);
            debug::print(&recovered_address);
            debug::print(&verifier);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_sell_gold() {
        use sui::test_scenario;
        use sui::sui::SUI;
        use std::debug;
        use std::string;

        let collector: address = @0xBABE;
        let player: address = @0xCAFE;

        // first we create the game object
        let scenario_val = test_scenario::begin(collector);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        // let's mint some SUI coins for the deployer
        test_scenario::next_tx(scenario, collector);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            transfer::public_transfer(coin, collector);
        };

        // let's mint some SUI coins for the player
        test_scenario::next_tx(scenario, player);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            transfer::public_transfer(coin, player);
        };

        // we send some coins to the smartcontract
        // that user can withdraw
        test_scenario::next_tx(scenario, collector);
        {
            let coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let payment = coin::take(coin::balance_mut(&mut coin), 10, test_scenario::ctx(scenario));

            let game_wrapper = test_scenario::take_shared<Game>(scenario); 

            transfer_token<SUI>(&mut game_wrapper, payment, test_scenario::ctx(scenario));
            test_scenario::return_shared(game_wrapper);
            test_scenario::return_to_sender(scenario, coin);
        }; 
  
        // player sells the gold
        test_scenario::next_tx(scenario, player);
        {
            let game_wrapper = test_scenario::take_shared<Game>(scenario); 
            let token_amount: u64 = 1; // 0.1 SUI
            let gold_id = 1;
            
            let player_pre_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let pre_balance = coin::value(&player_pre_coin);
            debug::print(&pre_balance);

            sell_pack_without_signature<SUI>(&mut game_wrapper, token_amount, gold_id, test_scenario::ctx(scenario));
            
            test_scenario::return_shared(game_wrapper);
            test_scenario::return_to_sender(scenario, player_pre_coin);
        };

        // player buys a pack
        test_scenario::next_tx(scenario, player);
        {
            let game_wrapper = test_scenario::take_shared<Game>(scenario); 
            let pack_id: u8 = 1;

            let player_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let pre_balance = coin::value(&player_coin);
            debug::print(&collector);
            debug::print(&pre_balance);
            let payment = coin::take(coin::balance_mut(&mut player_coin), 20, test_scenario::ctx(scenario));

            let collector_pre_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, collector);
            let collector_pre_balance = coin::value(&collector_pre_coin);
            debug::print(&collector_pre_balance);

            buy_pack_without_signature<SUI>(&mut game_wrapper, payment, pack_id, test_scenario::ctx(scenario));

            test_scenario::return_shared(game_wrapper);

            // printing the sui amount after the transaction
            test_scenario::return_to_sender(scenario, player_coin);
            test_scenario::return_to_address(collector, collector_pre_coin);
        };

        // verify the signature of buying pack
        test_scenario::next_tx(scenario, collector);
        {
            debug::print(&string::utf8(b"starting to check signature parameters"));

            let timestamp: u64 = 1678367370;

            debug::print(&type_name::get<SUI>());
            debug::print(&type_name::into_string(type_name::get<SUI>()));

            let pack_id: u8 = 1;
            let token_amount: u64 = 1000000000; // 0.1 SUI

            let message = PackMessage {
                prefix: SELL_PACK_PREFIX,
                token_amount: token_amount,
                coin_type: type_name::get<SUI>(),
                pack_id: pack_id,
                game: @0x84818b44cb33fae71f25ca9aa3d8aed0aadbc87f784f0f6eccbce02bb2217742,
                owner: @0x84818b44cb33fae71f25ca9aa3d8aed0aadbc87f784f0f6eccbce02bb2217742,
                timestamp: timestamp,
            };
            let message_bytes = bcs::to_bytes(&message);
            debug::print(&message);
            debug::print(&message_bytes);

            let signature: vector<u8> = x"24ca1b2b9a73ee9e4a6b2688b48d49008703ea4c1efe3328f8aa981e090221fe7f78ad43c029532a09e1a0d099a2ba2785a175f752202398e2a169645d4df3df01";
            let verifier: vector<u8> = x"EB3B05cA37aE926fC8D0a2115Ca0903800a502f8";
            let recovered_address = verifier::ecrecover_to_eth_address(signature, message_bytes);
            let equal = verifier == recovered_address;
            debug::print(&equal);
            debug::print(&recovered_address);
            debug::print(&verifier);
        };

        test_scenario::end(scenario_val);
    }
}