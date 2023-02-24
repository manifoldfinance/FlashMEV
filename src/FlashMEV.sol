// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.17 <0.9.0;

/// ============ Imports ============

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IFlashBorrower} from "./interfaces/IFlashBorrower.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {IFlashLoanRecipient} from "./interfaces/IFlashLoanRecipient.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IBentoBoxV1} from "./interfaces/IBentoBoxV1.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IProtocolDataProvider} from "./interfaces/IProtocolDataProvider.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

/// @title FlashMEV
/// @author Sandy Bradley <@sandybradley>
/// @notice Generic flash loan for MEV execution (loans from Balancer (0% fee), BentoBox (0.05%), Aave (0.09%))
contract FlashMEV is IFlashLoanRecipient, IFlashBorrower, IFlashLoanReceiver {
    using SafeTransferLib for ERC20;

    error ZeroAddress();
    error Unauthorized();
    error UnsupportedToken();
    error InsufficientOutputAmount();

    event MEV(address indexed token, uint256 value);

    uint8 internal GOV_FEE;
    address internal GOV;
    address internal mevETH;
    address internal ORACLE_ROUTER;
    address internal constant WETH09 =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant BENTO =
        0xF5BCE5077908a1b7370B9ae04AdC565EBd643966; // bentobox vault
    address internal constant LENDING_POOL_ADDRESS =
        0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9; // aave lending pool address
    address internal constant AAVE_DATA_PROVIDER =
        0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d; // aave data provider
    address internal constant VAULT =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8; // balancer vault

    // address internal constant SPLIT_SWAP =
    //     0x77337dEEA78720542f0A1325394Def165918D562;  // Manifold split swap router

    /// @dev setup contract with governece fee and mevETH address
    /// @param _govFee governence fee on mev profit as 1/100 th of a decimal i.e. 1 == 0.01%
    /// @param _mevETH mevETH address
    /// @param _oracleRouter uni V2 style router for eth value lookup
    constructor(uint8 _govFee, address _mevETH, address _oracleRouter) {
        GOV = msg.sender;
        mevETH = _mevETH;
        GOV_FEE = _govFee;
        ORACLE_ROUTER = _oracleRouter;
    }

    /// @notice Admin can change ownership
    /// @param newGov Address of new owner
    function changeGov(address newGov) external {
        if (msg.sender != GOV) revert Unauthorized();
        if (newGov == address(0)) revert ZeroAddress();
        GOV = newGov;
    }

    /// @notice Admin can change fee
    /// @param _newFee New fee (1 == 0.01%)
    function changeFee(uint8 _newFee) external {
        if (msg.sender != GOV) revert Unauthorized();
        GOV_FEE = _newFee;
    }

    /// @notice Admin can change oracle router
    /// @param _oracleRouter uni V2 style router
    function changeOracle(address _oracleRouter) external {
        if (msg.sender != GOV) revert Unauthorized();
        ORACLE_ROUTER = _oracleRouter;
    }

    /// @notice Main Flash loan call to execute MEV
    /// @param token token to loan
    /// @param amount Amount to loan of token
    /// @param transactions packed list of transaction data (value(256),contract(160),data_len(16),data(data_len*8))
    function flash(
        address token,
        uint256 amount,
        bytes calldata transactions
    ) external {
        address me = address(this);
        address sender = msg.sender;
        uint256 startGas = gasleft();
        uint256 balBefore = ERC20(token).balanceOf(me);

        // loan preference
        // 1) balancer
        // 2) bentobox
        // 3) aave
        if (ERC20(token).balanceOf(VAULT) >= amount) {
            // addresses of the reserves to flashloan
            address[] memory assets = new address[](1);
            assets[0] = token;
            // amounts of assets to flashloan.
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            IVault(VAULT).flashLoan(
                IFlashLoanRecipient(me),
                assets,
                amounts,
                transactions
            );
        } else if (ERC20(token).balanceOf(BENTO) >= amount) {
            IBentoBoxV1(BENTO).flashLoan(
                IFlashBorrower(me),
                me,
                token,
                amount,
                transactions
            );
        } else if (
            IProtocolDataProvider(AAVE_DATA_PROVIDER).getReserveData(token) >=
            amount
        ) {
            {
                // addresses of the reserves to flashloan
                address[] memory assets = new address[](1);
                assets[0] = token;
                // amounts of assets to flashloan.
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = amount;
                // 0 = no debt (just revert), 1 = stable, 2 = variable
                uint256[] memory modes = new uint256[](1);
                modes[0] = 0;
                ILendingPool(LENDING_POOL_ADDRESS).flashLoan(
                    me,
                    assets,
                    amounts,
                    modes,
                    me,
                    transactions,
                    uint16(0)
                );
            }
        } else {
            revert UnsupportedToken();
        }
        // check profit exceeds gas cost
        uint256 profit = ((ERC20(token).balanceOf(me) - balBefore) *
            (10000 - uint256(GOV_FEE))) / 10000;
        if ((startGas - gasleft()) * block.basefee > _ethValue(token, profit))
            revert InsufficientOutputAmount();
        ERC20(token).safeTransfer(sender, profit);
        emit MEV(token, profit); // emit MEV event
    }

    /// @notice Sweep tokens and eth to recipient
    /// @param tokens Array of token addresses
    /// @param recipient Address of recipient
    function sweep(address[] calldata tokens, address recipient) external {
        if (msg.sender != GOV) revert Unauthorized();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            ERC20(token).safeTransfer(
                recipient,
                ERC20(token).balanceOf(address(this))
            );
        }
        SafeTransferLib.safeTransferETH(recipient, address(this).balance);
    }

    /// @notice Admin function to remove code from blockchain and receive rebate
    /// @param recipient Address of rebate recipient
    function destroy(address payable recipient) external {
        if (msg.sender != GOV) revert Unauthorized();
        selfdestruct(recipient);
    }

    /// @notice Called from BentoBox Lending pool after contract has received the flash loaned amount
    /// @dev Reverts if not profitable.
    /// @param sender Address of flashloan initiator
    /// @param token Token to loan
    /// @param amount Amount to loan
    /// @param fee Fee to repay on loan amount
    /// @param data Encoded factories and tokens
    function onFlashLoan(
        address sender,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external {
        if (msg.sender != BENTO) revert Unauthorized();
        _executeTransactions(data);
        ERC20(token).safeTransfer(BENTO, amount + fee);
    }

    /// @notice Called from Aave Lending pool after contract has received the flash loaned amount (https://docs.aave.com/developers/v/2.0/guides/flash-loans)
    /// @dev Reverts if not profitable.
    /// @param assets Array of tokens to loan
    /// @param amounts Array of amounts to loan
    /// @param premiums Array of premiums to repay on loan amounts
    /// @param initiator Address of flashloan initiator
    /// @param params Encoded factories and tokens
    /// @return success indicating success
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != LENDING_POOL_ADDRESS) revert Unauthorized();
        _executeTransactions(params);
        ERC20(assets[0]).safeApprove(
            LENDING_POOL_ADDRESS,
            amounts[0] + premiums[0]
        );
        return true;
    }

    /// @notice Called from Balancer vault after contract has received flashloan
    /// @param tokens Array of tokens to loan
    /// @param amounts Array of amounts to loan
    /// @param feeAmounts Array of fees to repay on loan amounts
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        if (msg.sender != VAULT) revert Unauthorized();
        _executeTransactions(userData);
        ERC20(tokens[0]).safeTransfer(VAULT, amounts[0] + feeAmounts[0]);
    }

    /// @notice Calculate eth value of a token amount
    /// @param token Address of token
    /// @param amount Amount of token
    /// @return eth value
    function _ethValue(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        if (token == WETH09) return amount;
        if (token == mevETH) return amount;
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH09;
        uint256[] memory amounts = IUniswapV2Router02(ORACLE_ROUTER)
            .getAmountsOut(amount, path);
        if (amounts.length < 2) return 0;
        return amounts[1];
    }

    /// @dev Sends multiple transactions
    /// @param transactions Encoded transactions. Each transaction is encoded as a packed bytes of
    ///                     value as a uint256 (=> 32 bytes),
    ///                     contract address (20 bytes)
    ///                     data length as a uint16 (=> 2 bytes),
    ///                     data as bytes.
    ///                     see abi.encodePacked for more information on packed encoding
    function _executeTransactions(bytes memory transactions) internal {
        assembly ("memory-safe") {
            let length := mload(transactions)
            let i := 0x20
            for {
                // Pre block is not used in "while mode"
            } lt(i, length) {
                // Post block is not used in "while mode"
            } {
                // let value = mload(add(transactions, i))
                let to := and(
                    shr(96, mload(add(transactions, add(i, 0x20)))),
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                let dataLength := and(
                    shr(240, mload(add(transactions, add(i, 0x34)))),
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                let success := call(
                    gas(), // gas left
                    to, // router
                    mload(add(transactions, i)), // value
                    add(transactions, add(i, 0x36)), // input data (0x(4 byte func sig hash)(abi encoded args))
                    dataLength, // input data byte length
                    0, // output
                    0 // output byte length
                )
                if iszero(success) {
                    revert(0, 0)
                }
                // Next entry starts at 0x35 byte + data length
                i := add(i, add(0x36, dataLength))
            }
        }
    }

    /// @notice Function to receive Ether. msg.data must be empty
    receive() external payable {}

    /// @notice Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
