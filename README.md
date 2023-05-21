# Agchain Contract

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">

## Please make sure you have already installed [Foundry](https://github.com/foundry-rs/foundry) globally

</div>

## Useful commands

1. Install dependencies
```bash
$ forge install # Without any argument
```

2. Compile 
```bash
$ forge build
```

3. Run test scripts
```bash
$ forge test
$ forge test -vvvv
$ (forge build; clear; forge test)
```

4. Clean the build artifacts and cache
```bash
forge clean
```

5. Deploy contracts
```bash
source .env
forge script script/deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
```

6. Other commands
```bash
$ cast run <TXN_HASH> --rpc-url $SEPOLIA_RPC_URL -vvv
$ cast tx <TXN_HASH> --rpc-url $SEPOLIA_RPC_URL
$ cast receipt <TXN_HASH> --rpc-url $SEPOLIA_RPC_URL
```
