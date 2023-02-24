// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.17 <0.9.0;

interface IProtocolDataProvider {
    /**
     * @notice getReserveData() allows users to get the available liquidity of a given asset.
     * @dev getReserveData() takes an address of an asset as an argument and returns the available liquidity of that asset.
     */
    function getReserveData(
        address asset
    ) external view returns (uint256 availableLiquidity);
}
