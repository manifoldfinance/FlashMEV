#!/usr/bin/env bash
# To load the variables in the .env file
source .env

anvil -f $MAINNET_RPC_URL
