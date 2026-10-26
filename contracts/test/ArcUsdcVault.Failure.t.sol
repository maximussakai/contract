// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

/// @dev Uses the configurable MockERC20 (fee / revert / blocklist / return-false) as the underlying.
contract ArcUsdcVaultFailureTest is ArcUsdcVaultTestBase {
    // -------------------------------------------------- fee-on-transfer token

    function test_Deposit_FeeOnTransferTokenRejected() public {
        usdc.setFeeBps(100); // 1% burned on transfer
        vm.startPrank(alice);
        usdc.approve(address(vault), 100e6);
        vm.expectRevert(
            abi.encodeWithSelector(ArcUsdcVault.UnexpectedBalanceDelta.selector, 0, 99e6, 100e6)
        );
        vault.deposit(100e6, alice);
        vm.stopPrank();

        // whole tx rolled back
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), START);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_Deposit_FeeRejectedEvenWhenVaultAlreadyFunded() public {
        _deposit(alice, 100e6);
        usdc.setFeeBps(1);
        vm.startPrank(bob);
        usdc.approve(address(vault), 1_000e6);
        // 0.01% of 1000e6 = 100_000 burned
        vm.expectRevert(
            abi.encodeWithSelector(
                ArcUsdcVault.UnexpectedBalanceDelta.selector, 100e6, 100e6 + 1_000e6 - 100_000, 1_000e6
            )
        );
        vault.deposit(1_000e6, bob);
        vm.stopPrank();
        assertEq(vault.totalSupply(), 100e6);
    }

    function test_Deposit_TinyAmountBelowFeeRoundingStillAccepted() public {
        // fee rounds to zero for 1 base unit at 1%, so balance delta == amount: accepted.
        usdc.setFeeBps(100);
        _deposit(alice, 1);
        assertEq(vault.balanceOf(alice), 1);
    }

    // ------------------------------------------------ failed transfer rollback

    function test_Deposit_TransferFromRevertRollsBackMint() public {
        usdc.setRevertTransfers(true);
        vm.startPrank(alice);
        usdc.approve(address(vault), 10e6);
        vm.expectRevert();
        vault.deposit(10e6, alice);
        vm.stopPrank();
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), START);
    }

    function test_Deposit_BlocklistedCallerRollsBack() public {
        usdc.setBlocked(alice, true);
        vm.startPrank(alice);
        usdc.approve(address(vault), 10e6);
        vm.expectRevert();
        vault.deposit(10e6, bob);
        vm.stopPrank();
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_Deposit_ReturnFalseTokenReverts() public {
        usdc.setReturnFalse(true);
        vm.startPrank(alice);
        usdc.approve(address(vault), 10e6);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(usdc)));
        vault.deposit(10e6, alice);
        vm.stopPrank();
        assertEq(vault.totalSupply(), 0);
    }

    function test_Withdraw_BlocklistedReceiverRollsBackBurn() public {
        _deposit(alice, 100e6);
        address bad = makeAddr("blocked");
        usdc.setBlocked(bad, true);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(100e6, bad);

        assertEq(vault.balanceOf(alice), 100e6);
        assertEq(vault.totalSupply(), 100e6);
        assertEq(usdc.balanceOf(address(vault)), 100e6);

        // retry with another receiver (blocked caller can still route elsewhere)
        usdc.setBlocked(alice, true);
        vm.prank(alice);
        vault.withdraw(100e6, bob);
        assertEq(usdc.balanceOf(bob), START + 100e6);
        assertEq(vault.totalSupply(), 0);
    }

    function test_Withdraw_TransferRevertRollsBackBurn() public {
        _deposit(alice, 100e6);
        usdc.setRevertTransfers(true);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(50e6, alice);
        assertEq(vault.balanceOf(alice), 100e6);
        assertEq(vault.totalSupply(), 100e6);
    }

    function test_Withdraw_ReturnFalseTokenRollsBackBurn() public {
        _deposit(alice, 100e6);
        usdc.setReturnFalse(true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(usdc)));
        vault.withdraw(50e6, alice);
        assertEq(vault.balanceOf(alice), 100e6);
    }

    function test_Withdraw_BlocklistedVaultFreezesWithdrawalsDocumentedRisk() public {
        _deposit(alice, 100e6);
        usdc.setBlocked(address(vault), true);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(1e6, alice);
        assertEq(vault.balanceOf(alice), 100e6);
        // share transfers are unaffected
        vm.prank(alice);
        vault.transfer(bob, 1e6);
        assertEq(vault.balanceOf(bob), 1e6);
    }

    // -------------------------------------------- insolvent underlying (info)

    function test_Surplus_RevertsIfUnderlyingBecomesInsolvent() public {
        _deposit(alice, 100e6);
        // force insolvency: USDC leaves the vault outside the vault's own logic
        vm.prank(address(vault));
        usdc.transfer(bob, 10e6);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        vault.surplus();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        vault.rescueToken(IERC20(address(usdc)), admin, 1);
    }
}
