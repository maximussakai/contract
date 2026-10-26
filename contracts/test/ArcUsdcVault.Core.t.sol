// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

contract ArcUsdcVaultCoreTest is ArcUsdcVaultTestBase {
    // ---------------------------------------------------------------- deposit

    function test_Deposit_MintsSharesAndPullsUsdc() public {
        _deposit(alice, 1_000e6);
        assertEq(vault.balanceOf(alice), 1_000e6);
        assertEq(vault.totalSupply(), 1_000e6);
        assertEq(usdc.balanceOf(address(vault)), 1_000e6);
        assertEq(usdc.balanceOf(alice), START - 1_000e6);
    }

    function test_Deposit_EmitsDepositAndTransfer() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 500e6);
        vm.expectEmit(true, true, false, true, address(vault));
        emit IERC20.Transfer(address(0), bob, 500e6);
        vm.expectEmit(true, true, false, true, address(vault));
        emit ArcUsdcVault.Deposit(alice, bob, 500e6);
        vault.deposit(500e6, bob);
        vm.stopPrank();
    }

    function test_Deposit_RoutesSharesToReceiver() public {
        _deposit(alice, 700e6, bob);
        assertEq(vault.balanceOf(bob), 700e6);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), START - 700e6); // payer is the caller
        assertEq(usdc.balanceOf(bob), START);
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(ArcUsdcVault.ZeroAmount.selector);
        vault.deposit(0, alice);
    }

    function test_Deposit_RevertsOnZeroReceiver() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 1e6);
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        vault.deposit(1e6, address(0));
        vm.stopPrank();
    }

    function test_Deposit_RevertsWithoutAllowance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(vault), 0, 1e6
            )
        );
        vault.deposit(1e6, alice);
        assertEq(vault.totalSupply(), 0);
    }

    function test_Deposit_RevertsOnInsufficientUsdcBalance() public {
        address poor = makeAddr("poor");
        vm.startPrank(poor);
        usdc.approve(address(vault), 1e6);
        vm.expectRevert();
        vault.deposit(1e6, poor);
        vm.stopPrank();
        assertEq(vault.balanceOf(poor), 0);
    }

    function test_Deposit_RevertsAboveCap() public {
        vm.prank(capMgr);
        vault.setDepositCap(1_000e6);
        _deposit(alice, 600e6);
        vm.startPrank(bob);
        usdc.approve(address(vault), 500e6);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, 500e6, 400e6));
        vault.deposit(500e6, bob);
        vm.stopPrank();
    }

    function test_Deposit_FillsCapExactly() public {
        vm.prank(capMgr);
        vault.setDepositCap(1_000e6);
        _deposit(alice, 1_000e6);
        assertEq(vault.maxDeposit(), 0);
        vm.startPrank(bob);
        usdc.approve(address(vault), 1);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, 1, 0));
        vault.deposit(1, bob);
        vm.stopPrank();
    }

    function test_Deposit_ZeroCapBlocksDeposits() public {
        vm.prank(capMgr);
        vault.setDepositCap(0);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, 1, 0));
        vault.deposit(1, alice);
        vm.stopPrank();
    }

    // --------------------------------------------------------------- withdraw

    function test_Withdraw_BurnsSharesAndPaysUsdc() public {
        _deposit(alice, 1_000e6);
        vm.prank(alice);
        vault.withdraw(400e6, alice);
        assertEq(vault.balanceOf(alice), 600e6);
        assertEq(vault.totalSupply(), 600e6);
        assertEq(usdc.balanceOf(address(vault)), 600e6);
        assertEq(usdc.balanceOf(alice), START - 600e6);
    }

    function test_Withdraw_EmitsWithdrawAndTransfer() public {
        _deposit(alice, 1_000e6);
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true, address(vault));
        emit IERC20.Transfer(alice, address(0), 250e6);
        vm.expectEmit(true, true, false, true, address(vault));
        emit ArcUsdcVault.Withdraw(alice, bob, 250e6);
        vault.withdraw(250e6, bob);
        vm.stopPrank();
    }

    function test_Withdraw_RoutesUsdcToReceiver() public {
        _deposit(alice, 1_000e6);
        address sink = makeAddr("sink");
        vm.prank(alice);
        vault.withdraw(1_000e6, sink);
        assertEq(usdc.balanceOf(sink), 1_000e6);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), START - 1_000e6);
    }

    function test_Withdraw_RevertsOnZeroAmount() public {
        _deposit(alice, 1e6);
        vm.prank(alice);
        vm.expectRevert(ArcUsdcVault.ZeroAmount.selector);
        vault.withdraw(0, alice);
    }

    function test_Withdraw_RevertsOnZeroReceiver() public {
        _deposit(alice, 1e6);
        vm.prank(alice);
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        vault.withdraw(1e6, address(0));
    }

    function test_Withdraw_RevertsOnInsufficientShares() public {
        _deposit(alice, 100e6);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 100e6, 100e6 + 1)
        );
        vault.withdraw(100e6 + 1, alice);
    }

    function test_Withdraw_CannotSpendOthersShares() public {
        _deposit(alice, 100e6);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker, 0, 1)
        );
        vault.withdraw(1, attacker);
    }

    function test_Withdraw_TransferredSharesRedeemable() public {
        _deposit(alice, 100e6);
        vm.prank(alice);
        vault.transfer(bob, 100e6);
        vm.prank(bob);
        vault.withdraw(100e6, bob);
        assertEq(usdc.balanceOf(bob), START + 100e6);
    }

    // ------------------------------------------------------------------ pause

    function test_Pause_BlocksDepositButNotWithdrawOrShareTransfer() public {
        _deposit(alice, 1_000e6);
        vm.prank(pauser);
        vault.pause();

        assertEq(vault.maxDeposit(), 0);

        vm.startPrank(bob);
        usdc.approve(address(vault), 10e6);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.deposit(10e6, bob);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.transfer(bob, 300e6);
        vault.approve(carol, 100e6);
        vault.withdraw(200e6, alice);
        vm.stopPrank();

        vm.prank(carol);
        vault.transferFrom(alice, carol, 100e6);

        vm.prank(bob);
        vault.withdraw(300e6, bob);

        assertEq(vault.balanceOf(alice), 400e6);
        assertEq(vault.balanceOf(carol), 100e6);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.totalSupply(), 500e6);
    }

    function test_Pause_UnpauseRestoresDeposits() public {
        vm.prank(pauser);
        vault.pause();
        vm.prank(pauser);
        vault.unpause();
        assertEq(vault.maxDeposit(), CAP);
        _deposit(alice, 5e6);
        assertEq(vault.balanceOf(alice), 5e6);
    }

    function test_Pause_EmitsEvents() public {
        vm.startPrank(pauser);
        vm.expectEmit(false, false, false, true, address(vault));
        emit Pausable.Paused(pauser);
        vault.pause();
        vm.expectEmit(false, false, false, true, address(vault));
        emit Pausable.Unpaused(pauser);
        vault.unpause();
        vm.stopPrank();
    }

    function test_Pause_RevertsWhenAlreadyPaused() public {
        vm.startPrank(pauser);
        vault.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.pause();
        vm.stopPrank();
    }

    function test_Unpause_RevertsWhenNotPaused() public {
        vm.prank(pauser);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        vault.unpause();
    }

    // -------------------------------------------------------------------- cap

    function test_SetDepositCap_UpdatesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(vault));
        emit ArcUsdcVault.DepositCapUpdated(CAP, 42e6);
        vm.prank(capMgr);
        vault.setDepositCap(42e6);
        assertEq(vault.depositCap(), 42e6);
        assertEq(vault.maxDeposit(), 42e6);
    }

    function test_SetDepositCap_BelowSupplyBlocksDepositsKeepsWithdrawals() public {
        _deposit(alice, 800e6);
        vm.prank(capMgr);
        vault.setDepositCap(100e6); // below the 800e6 supply: allowed
        assertEq(vault.depositCap(), 100e6);
        assertEq(vault.maxDeposit(), 0);

        vm.startPrank(bob);
        usdc.approve(address(vault), 1e6);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, 1e6, 0));
        vault.deposit(1e6, bob);
        vm.stopPrank();

        vm.prank(alice);
        vault.withdraw(800e6, alice);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.maxDeposit(), 100e6); // capacity reopens as supply falls
    }

    function test_SetDepositCap_RaisingReopensDeposits() public {
        vm.prank(capMgr);
        vault.setDepositCap(0);
        vm.prank(capMgr);
        vault.setDepositCap(50e6);
        _deposit(alice, 50e6);
        assertEq(vault.totalSupply(), 50e6);
    }

    // ------------------------------------------------------------------- misc

    function test_Decimals_IsSix() public view {
        assertEq(vault.decimals(), 6);
    }

    function test_Surplus_DirectTransferCreatesSurplusNotShares() public {
        _deposit(alice, 100e6);
        vm.prank(bob);
        usdc.transfer(address(vault), 25e6);
        assertEq(vault.surplus(), 25e6);
        assertEq(vault.totalSupply(), 100e6);
        assertEq(vault.maxDeposit(), CAP - 100e6);
    }

    function test_VaultRejectsNativeValue() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(vault).call{value: 1 ether}("");
        assertFalse(ok);
    }
}
