# MiniMiners smartcontracts for Sui blockchain.

## Sui tutorials
The list of references used in the writing of these smartcontracts:

* https://github.com/MystenLabs/sui &ndash; source code with all links to start to work with Sui blockchain.
* https://docs.sui.io/devnet/explore &ndash; primary hub of the documentations.
* https://github.com/MystenLabs/sui/blob/main/doc/src/explore/examples.md &ndash; primary hub of the examples.
* https://github.com/MystenLabs/sui/blob/main/sui_programmability/examples/nfts/sources/marketplace.move &ndash; NFT marketplace, used to see how to import/export NFT into MiniMiners game smartcontract.
* https://github.com/MystenLabs/sui-axelar/blob/2a0f17ab8efdb8ebc6bca753328180a02f6fcf6e/presets/index.js#L108 &ndash; example on how to generate the signatures offchain, then verifying them on-chain using `ecrecover` function.
* https://github.com/MystenLabs/sui/tree/main/sdk/typescript/ &ndash; the SDK to interact with Sui blockchain from Node.js and browser backends.
* https://move-language.github.io/move/vector.html &ndash; Move programming language book. The link is the page describing array like data structures: vectors.
* https://github.com/MystenLabs/sui/blob/main/doc/src/build/install.md#sui-tokens &ndash; How to obtain devnet SUI token.
* https://explorer.sui.io/ &ndash; explore the blocks and transactions.
* https://github.com/move-language/move/tree/main/language/documentation/tutorial &ndash; official tutorial on move programming language.
* https://github.com/MystenLabs/awesome-move#move-powered-blockchains &ndash; list of useful recource collection related to Move programming language.

## v0.0.1
DevNet deployed smartcontract:

Deployer:
[0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2]
(https://explorer.sui.io/address/0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2)

Transaction Hash: *MiniMiners package deployment* [0x3kzV4PsoicUcR3jtwM2NwJoJ7fKpBvDVmmSXAtHKZBgn](https://explorer.sui.io/transaction/3kzV4PsoicUcR3jtwM2NwJoJ7fKpBvDVmmSXAtHKZBgn)

MiniMiners package: *Keeps MineNFT, Game smartcontracts as its modules* [0x3e661eddbfa2da4bef5c2a41800392a8485dcf55](https://explorer.sui.io/object/0x3e661eddbfa2da4bef5c2a41800392a8485dcf55)

MineNFT Factory: *used to mint MineNFT*[0x5e7cbd38ec1c41bd697a629e087eff8bfd9cd750](https://explorer.sui.io/object/0x5e7cbd38ec1c41bd697a629e087eff8bfd9cd750)

MineNFT type:
0x3e661eddbfa2da4bef5c2a41800392a8485dcf55::mine_nft::Mine

Game object: *used to manage Game module*[0x976630cf7929f8d2b1dbdb0ac8c8219ad037092b](https://explorer.sui.io/object/0x976630cf7929f8d2b1dbdb0ac8c8219ad037092b)

### Scripts

Go to the root directory with the smartcontracts.

---

**Mint new MineNFTs**
*Can be called by the owner of `NftFactory` object.*
*By default its the publisher of the package.*

```sh
sui client call 
 --function mint \
 --module mine_nft 
 --package 0x3e661eddbfa2da4bef5c2a41800392a8485dcf55 \ --gas-budget 1000 \
 --args \ 
  0x5e7cbd38ec1c41bd697a629e087eff8bfd9cd750 \
  0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2 \
  2 \
  3
```

Mint an `MineNFT` with `generation = 2` and `quality = 3`. The minted nft is transferred to `0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2`.

---
