// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {FlashMEV} from "../src/FlashMEV.sol";

contract DeployScript is Script {
    function run() public {
        uint8 fee = 2; // 0.02%
        address mevETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        address oracle = 0x77337dEEA78720542f0A1325394Def165918D562; // split swap router
        vm.startBroadcast();
        new FlashMEV{salt: "Manifold"}(fee, mevETH, oracle);
        vm.stopBroadcast();
    }
}
