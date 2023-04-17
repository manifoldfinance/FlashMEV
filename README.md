# FlashMEV

### Generic flash-loan smart contract for executing any MEV opportunity

Herein contains source code and example usage for `FlashMEV` contract.

Loans are made in a preferential order, based on lowest fees first then token availability. The following protocols are used:
- Balancer (0% fee)
- BentoBox (0.05% fee)
- Aave (0.09% fee)

## Deployed at

- Mainnet [0x60CFf949c22b7136dc750Af1F1a8e0a2D2A7556F](https://etherscan.io/address/0x60CFf949c22b7136dc750Af1F1a8e0a2D2A7556F)

## Usage

Example usage:

```solidity
flashMev.flash(DAI, amountIn, transactions);
```

## Development and testing

Tests were built on Foundry.

### Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
```
```bash
foundryup
```

### Setup .env
Copy `.env.example` to `.env` and fill out env vars e.g.
```bash
export MAINNET_RPC_URL=...
```

### Build and run tests
```bash
./script/test.sh
```
[Output](docs/backrun-test-results.md)

### Deploy
```bash
./script/deploy.sh
```

### Engineering log

[Log of goals, development, challenges etc](doc/engineer-log.md)