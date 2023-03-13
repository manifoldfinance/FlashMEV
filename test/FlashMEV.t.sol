// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/FlashMEV.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";

contract FlashMEVTest is Test {
    using SafeTransferLib for ERC20;
    FlashMEV public flashMev;
    uint256 internal mainnetFork;
    string internal MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant SUSHI_ROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address internal constant UNI_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant mevETH =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL, 14476842);
        vm.selectFork(mainnetFork);
        flashMev = new FlashMEV(2, mevETH, UNI_ROUTER);
    }
 

    /// @dev run arb for known opportunity
    function testFlashArb() public {
        vm.selectFork(mainnetFork);
        uint256 amountIn = 73000000000000000000;
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;
        uint256 deadline = block.timestamp;
        address to = address(flashMev);
        uint256[] memory amounts = IUniswapV2Router02(SUSHI_ROUTER)
            .getAmountsOut(amountIn, path);
        uint256 amountOutMin = amounts[1];

        // execute tx to backrun
        IUniswapV2Router02(SUSHI_ROUTER).swapExactETHForTokens{value: amountIn}(
            amountOutMin,
            path,
            address(this),
            deadline
        );

        amountIn = 61201080349749865111782;
        deadline = block.timestamp;
        path[0] = DAI;
        path[1] = WETH;
        bytes memory data0 = abi.encodeWithSignature(
            "approve(address,uint256)",
            SUSHI_ROUTER,
            amountIn
        );
        amounts = IUniswapV2Router02(SUSHI_ROUTER).getAmountsOut(
            amountIn,
            path
        );
        amountOutMin = amounts[1];
        bytes memory data = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
        path[0] = WETH;
        path[1] = DAI;
        bytes memory data1 = abi.encodeWithSignature(
            "approve(address,uint256)",
            UNI_ROUTER,
            amountOutMin
        );
        bytes memory data2 = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
            amountOutMin,
            0,
            path,
            to,
            deadline
        );

        bytes memory transactions = abi.encodePacked(
            uint256(0),
            DAI,
            uint16(data0.length),
            data0,
            uint256(0),
            SUSHI_ROUTER,
            uint16(data.length),
            data,
            uint256(0),
            WETH,
            uint16(data1.length),
            data1,
            uint256(0),
            UNI_ROUTER,
            uint16(data2.length),
            data2
        );
        emit log_bytes(transactions);
        uint256 balBefore = ERC20(DAI).balanceOf(address(this));
        flashMev.flash(true, DAI, amountIn, transactions);
        assertGt(ERC20(DAI).balanceOf(address(this)), balBefore);
        assertGt(ERC20(DAI).balanceOf(address(flashMev)), 0);
    }

    function testDestroy() external {
        flashMev.destroy(payable(address(this)));
    }

    function testUnauthorized() external {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        flashMev.destroy(payable(address(this)));
    }

    function testUpdateGov() external {
        flashMev.updateGov(0xfc90FAc785B6cd79A83351Ef80922Bb484431E8d);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        flashMev.destroy(payable(address(this)));
    }

    function testUpdateFee() external {
        flashMev.updateFee(1);
        
    }

    function testUpdateOracle() external {
        flashMev.updateOracle(SUSHI_ROUTER);
        
    }

    function testUpdateFriend() external {
        flashMev.updateFriend(true, address(0));
    }

    function testSweep() external {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;
        IWETH(WETH).deposit{value: 1000000000000000000}();
        ERC20(WETH).safeTransfer(address(flashMev), 1000000000000000000);
        SafeTransferLib.safeTransferETH(address(flashMev), 1000000000000000000);
        assertEq(ERC20(WETH).balanceOf(address(flashMev)), 1000000000000000000);
        flashMev.sweep(tokens, address(this));
        assertEq(ERC20(WETH).balanceOf(address(flashMev)), 0);
    }

    /// @notice Function to receive Ether. msg.data must be empty
    receive() external payable {}

    /// @notice Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
