# Engineer log

## Goal: Generic flash-loan contract for executing any MEV

Primary driver for generic flashloan contract is the arb design for `mevETH`, which has contract interactions with mevETH, Balancer, Uniswap V3, Sushiswap. Potentially others will be involved. This ties in with background drivers for an upgraded `mev-seeker` flash loan contract which has an evolving arb and liquidation search.

## Key trade-offs

Initial design is to encapsulate pre-constructed transactions in a flash-loan. This has the advantage of being able to construct any opportunity, with the disadvantage that the transaction details cannot be dynamic with changes in state (e.g. from other transactions in the block). 

## 2023/02/24

- Core contract created
- Flash-loan test created
- Deploy script created
- Pushed initial repo to github.

## 2023/02/25

- Added access list to contract flash function for safety (contract exploit potential)

## 2023/03/09

- Added bool to flash function to indicate whether it can use Balancer flashloan. Reason for this addition is that through testing it was discovered, Balancer cannot make swaps with its own flashloan. This is due to reentrancy protection similar to Uni V2 flashloans.

## 2023/03/10

- Testing engine on rETH, wstEth and stEth yields some interesting results.
- stEth is rebased, so ratio Eth -> stEth is not 1:1
- rEth deposit limit seems full i.e. no more deposits can be made