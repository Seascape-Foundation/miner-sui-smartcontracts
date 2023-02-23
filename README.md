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

Transaction Hash: *MiniMiners package deployment* [H6yGv6iiGfcFQZ9FoLcu4pyyWbnskWADs4MgsQzN865J](https://explorer.sui.io/transaction/H6yGv6iiGfcFQZ9FoLcu4pyyWbnskWADs4MgsQzN865J)

MiniMiners package: *Keeps MineNFT, Game smartcontracts as its modules* [0x62b81b8a62d111fc3d4c058d0a4980179f5dfca9](https://explorer.sui.io/object/0x62b81b8a62d111fc3d4c058d0a4980179f5dfca9)

MineNFT Factory: *used to mint MineNFT*[	0x5406e3921609dc2db5a0fb6b42c81cd03adfb391](https://explorer.sui.io/object/	0x5406e3921609dc2db5a0fb6b42c81cd03adfb391)

MineNFT type:
	0x62b81b8a62d111fc3d4c058d0a4980179f5dfca9::mine_nft::Mine

Game object: *used to manage Game module*
[0x194311ac0db4a30f0c6138d99d719e4a6141e8be](https://explorer.sui.io/object/0x194311ac0db4a30f0c6138d99d719e4a6141e8be)

### Scripts

If you didn't install sui, install it using:

```powershell
cargo install --git https://github.com/MystenLabs/sui.git `
 --branch testnet sui --force
```

*If the `sui publish` command gives a client-server version mismatch, then you should install the exact version*

```powershell
cargo install --git https://github.com/MystenLabs/sui.git \
 --tag devnet-0.27.0 sui --force
```

Go to the root directory with the smartcontracts.

---
#####Compile the smartcontracts

```powershell
sui move build
```

---

####Publish the smartcontracts**

```powershell
sui client publish --gas-budget 3000 --dev --doc --abi
```

*If it shows an error `Multiple source verification errors found:`*

Then add to the command another argument after `--abi`:

```powershell
--skip-dependency-verification
```

Upon successful publishing, the console output will show
Transaction Hash. Then we need to update the game backend to work with the newly published data.

#####Steps to do to update the game
Go to the explorer, to the page of the transaction.
The explorer will show the list of the created objects.
Go to each object to identify the Object Type.

**1. Update the config.json on CDN.**
For now for demo we keep the cdn on the backend as hardcoded config.
Its hardcoded in the `src/app.js`. Find the `sui_dev_config` variable in the source file. And set the write parameters.

**2. Update the sync bot**
In the repository of the sync bot, update the `config/config.json`

> Done! Now you can call the following commands to test it.

---

####Mint new MineNFTs
*Can be called by the owner of `NftFactory` object.*
*By default its the publisher of the package.*

```powerpowershell
sui client call `
 --function mint `
 --module mine_nft `
 --package 0x62b81b8a62d111fc3d4c058d0a4980179f5dfca9 ` --gas-budget 1000 `
 --args `
  	0x5406e3921609dc2db5a0fb6b42c81cd03adfb391 `
  0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2 `
  2 `
  3
```

The first argument is the resource(aka object) id of the Factory. The second argument is the owner of the nft.
The last two arguments are generation and quality.

Mint an `MineNFT` with `generation = 2` and `quality = 3`. The minted nft is transferred to `0x8714a9b7819e42cedbde695f9a0242b7d79ff9c2`.

---

##### Transfer Nft

```powershell
sui client transfer --to 0x8ec7ccb4e3925fef987d8a2ff11f78051e0ffc46 `
--object-id 0xbd1479055f0f091123d245b7ad4ebb95ef80b9cb `
--gas-budget 3000
```
