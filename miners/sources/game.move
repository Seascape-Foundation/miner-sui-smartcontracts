// SPDX-License-Identifier: Mozilla Public License 2.0

// This package imports and exports the nfts
// It also contains the functions to exchange the in-game currency to the token
module mini_miners::game {
    use sui::object::{Self, ID, UID};
    use sui::dynamic_object_field;
    // use mini_miners::verifier;
    // use std::vector;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;

    const ENotOwner: u64 = 1;
    const EAmountIncorrect: u64 = 2;
    const ENotEnoughFunds: u64 = 3;

    struct PlayerParams has key, store {
        id: UID,
        owner: address,
        stake_time: u64
    }

    // todo change the collector
    // change the ratio
    struct Game has key {
        id: UID,
        collector: address,
        ratio: u64,
        nonce: u64,
    }

    //////////////////////////////////////////////////////////////
    //
    // Events
    //
    //////////////////////////////////////////////////////////////

    struct SellGold has copy, drop {
        player: address,
        token_amount: u64,
        gold_id: u8,
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


    // Upon deployment, we create a shared nonce
    fun init(ctx: &mut TxContext) {
        let game = Game {
            id: object::new(ctx),
            nonce: 0,
            ratio: 10_000_000, // 10 million golds to 1 Crypto coin
            collector: tx_context::sender(ctx),
        };
        transfer::share_object(game);
    }

    public fun nonce(game: &Game): u64 {
        game.nonce
    }

    //////////////////////////////////////////////////////////////////
    //
    // Nft import/export
    //
    //////////////////////////////////////////////////////////////////

    // todo add the ecrecover
    // generating the message hash using sui::bcs and sui::hash::keccak256
    // on top of the
    // https://github.com/MystenLabs/sui-axelar/blob/2a0f17ab8efdb8ebc6bca753328180a02f6fcf6e/presets/index.js#L108
    // check the miners/sources/ecdsa.move for ecrecover example
    //
    // todo emit event using sui::event
    //
    // todo make sure that nft is whitelisted
    public entry fun import_nft<T: key + store>(game: &mut Game, item: T, timestamp: u64, ctx: &mut TxContext) {
        let item_id = object::id(&item);
        let params = PlayerParams {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            stake_time: timestamp,
        };

        game.nonce = game.nonce + 1;

        dynamic_object_field::add(&mut params.id, true, item);
        dynamic_object_field::add(&mut game.id, item_id, params);

        event::emit(NftImported{nft_id: item_id, owner: tx_context::sender(ctx)});
    }

    // Export the nft back to the user.
    public fun export_nft<T: key + store>(
        game: &mut Game,
        item_id: ID,
        ctx: &mut TxContext
    ): T {
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
        transfer::transfer(item, tx_context::sender(ctx));

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

        if (dynamic_object_field::exists_<address>(&game.id, sender)) {
            coin::join(
                dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, sender),
                paid
            )
        } else {
            dynamic_object_field::add<address, Coin<COIN>>(&mut game.id, sender, paid);
        }
    }

    // todo add signature verification
    // with the signature we avoid duplicate data transfer
    public entry fun sell_gold<COIN>(game: &mut Game, token_amount: u64, pack_id: u8, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let collector = game.collector;

        assert!(dynamic_object_field::exists_<address>(&game.id, collector), ENotEnoughFunds);

        game.nonce = game.nonce + 1;

        let borrowed_coin = coin::split(
            dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, collector),
            token_amount,
            ctx
        );

        transfer::transfer(borrowed_coin, player);

        event::emit(SellGold{player, token_amount, gold_id: pack_id})
    }

    // Buy a resource pack or diamond pack
    // todo change the pack_id to the to resource type.
    public entry fun buy_pack<COIN>(game: &mut Game, paid: Coin<COIN>, pack_id: u8, ctx: &mut TxContext) {
        let token_amount = coin::value(&paid);

        transfer::transfer(paid, game.collector);

        let player = tx_context::sender(ctx);

        event::emit(BuyPack{player, token_amount, pack_id})
    }

    
    /////////////////////////////////////////////////////////////////////
    //
    // The Game owner functions
    //
    /////////////////////////////////////////////////////////////////////


    /// Call [`take_profits`] and transfer Coin to the sender.
    public entry fun withdraw_and_keep<COIN>(
        game: &mut Game,
        collector_balance: &mut Coin<COIN>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.collector, ENotOwner);
        let claimable_amount = dynamic_object_field::remove<u8, Coin<COIN>>(&mut game.id, 0x01);

        coin::join(collector_balance, claimable_amount);
    }

    /////////////////////////////////////////////////////////////////////
    //
    // Testing buy and sell
    //
    /////////////////////////////////////////////////////////////////////


    #[test]
    public fun test_sell_gold() {
        use sui::test_scenario;
        use sui::sui::SUI;
        use std::debug;

        let collector: address = @0xBABE;
        let player: address = @0xCAFE;

        // first we create the game object
        let scenario_val = test_scenario::begin(collector);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        // we send some coins to the smartcontract
        test_scenario::next_tx(scenario, collector);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            transfer::transfer(coin, collector);
        };

        test_scenario::next_tx(scenario, player);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
            transfer::transfer(coin, player);
        };

        test_scenario::next_tx(scenario, collector);
        {
            let coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let payment = coin::take(coin::balance_mut(&mut coin), 10, test_scenario::ctx(scenario));

            let game_wrapper = test_scenario::take_shared<Game>(scenario); 

            transfer_token<SUI>(&mut game_wrapper, payment, test_scenario::ctx(scenario));

            test_scenario::return_shared(game_wrapper);
            test_scenario::return_to_sender(scenario, coin);
        }; 
  
        test_scenario::next_tx(scenario, player);
        {
            let game_wrapper = test_scenario::take_shared<Game>(scenario); 
            let token_amount = 2; // 0.1 SUI
            let gold_id = 1;
            
            let player_pre_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let pre_balance = coin::value(&player_pre_coin);
            debug::print(&pre_balance);

            let collector_pre_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, collector);
            let collector_pre_balance = coin::value(&collector_pre_coin);
            debug::print(&collector_pre_balance);

            sell_gold(&mut game_wrapper, &mut player_pre_coin, token_amount, gold_id, test_scenario::ctx(scenario));
            
            test_scenario::return_shared(game_wrapper);

            // printing the sui amount after the transaction
            let post_balance = coin::value(&player_pre_coin);
            debug::print(&post_balance);
            let collector_post_balance = coin::value(&collector_pre_coin);
            debug::print(&collector_post_balance);

            assert!(post_balance == 1002, 2);

            test_scenario::return_to_sender(scenario, player_pre_coin);
            test_scenario::return_to_address(collector, collector_pre_coin);
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

            buy_pack(&mut game_wrapper, payment, pack_id, test_scenario::ctx(scenario));

            test_scenario::return_shared(game_wrapper);

            // printing the sui amount after the transaction
            let post_balance = coin::value(&player_coin);
            debug::print(&post_balance);
            let collector_post_balance = coin::value(&collector_pre_coin);
            debug::print(&collector_post_balance);

            test_scenario::return_to_sender(scenario, player_coin);
            test_scenario::return_to_address(collector, collector_pre_coin);
        };

        // check the collector balance
        test_scenario::next_tx(scenario, collector);
        {
            debug::print(&collector);

            let game_wrapper = test_scenario::take_shared<Game>(scenario); 

            let player_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let pre_balance = coin::value(&player_coin);
            debug::print(&pre_balance);

            withdraw_and_keep<SUI>(&mut game_wrapper, &mut player_coin, test_scenario::ctx(scenario));

            let pre_balance = coin::value(&player_coin);
            debug::print(&pre_balance);

            test_scenario::return_to_sender(scenario, player_coin);
            test_scenario::return_shared(game_wrapper);
        };

        test_scenario::end(scenario_val);
    }
}