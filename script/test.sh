#!/bin/bash

source .env

forge test -f "$MAINNET_RPC_URL" -vvvvv --etherscan-api-key $ETHERSCAN_API