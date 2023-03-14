#!/usr/bin/env bash
# To load the variables in the .env file
source .env

# To deploy our contract on anvil
forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545  --private-key $TEST_PRIVATE_KEY --broadcast