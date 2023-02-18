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

    struct BuyGold has copy, drop {
        player: address,
        token_amount: u64,
    } 

    struct SellGold has copy, drop {
        player: address,
        token_amount: u64,
        gold_amount: u64,
    }

    // Upon deployment, we create a shared nonce
    fun init(ctx: &mut TxContext) {
        let game = Game {
            id: object::new(ctx),
            nonce: 0,
            ratio: 15000,
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
    }

    /////////////////////////////////////////////////////////////////////
    //
    // In-game currency to Token
    //
    /////////////////////////////////////////////////////////////////////
    
    // todo make sure that Coin is whitelisted
    // in the Game struct we store it using std::vector<Coin>
    public entry fun buy_gold<COIN>(game: &mut Game, paid: Coin<COIN>, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let token_amount = coin::value(&paid);
        let collector = game.collector;

        // Check if there's already a Coin hanging and merge `paid` with it.
        // Otherwise attach `paid` to the `Marketplace` under owner's `address`.
        if (dynamic_object_field::exists_<address>(&game.id, collector)) {
            coin::join(
                dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, collector),
                paid
            )
        } else {
            dynamic_object_field::add(&mut game.id, collector, paid)
        };

        event::emit(BuyGold{player, token_amount})
    }

    // todo add signature verification
    // with the signature we avoid duplicate data transfer
    public entry fun sell_gold<COIN>(game: &mut Game, gold_amount: u64, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let collector = game.collector;

        assert!(dynamic_object_field::exists_<address>(&game.id, collector), ENotEnoughFunds);

        game.nonce = game.nonce + 1;
        let token_amount = gold_amount / game.ratio;

        let borrowed_coin = coin::split(
            dynamic_object_field::borrow_mut<address, Coin<COIN>>(&mut game.id, collector),
            token_amount,
            ctx
        );

        transfer::transfer(borrowed_coin, player);

        event::emit(SellGold{player, token_amount, gold_amount})
    }

    
    /////////////////////////////////////////////////////////////////////
    //
    // The Game owner functions
    //
    /////////////////////////////////////////////////////////////////////


    /// Call [`take_profits`] and transfer Coin to the sender.
    public entry fun withdraw_and_keep<COIN>(
        game: &mut Game,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == game.collector, ENotOwner);
        let coin = dynamic_object_field::remove<address, Coin<COIN>>(&mut game.id, tx_context::sender(ctx));

        transfer::transfer(coin, sender)
    }
}