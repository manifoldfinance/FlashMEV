// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import "./IFlashBorrower.sol";

/// @notice Minimal interface for BentoBox token vault (V1) interactions
interface IBentoBoxV1 {
    function flashLoan(
        IFlashBorrower borrower,
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
