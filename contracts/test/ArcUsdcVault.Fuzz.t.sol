// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

contract ArcUsdcVaultFuzzTest is ArcUsdcVaultTestBase {
    function testFuzz_DepositThenFullWithdrawRoundTrips(uint256 amount) public {
        amount = bound(amount, 1, START);
        _deposit(alice, amount);
        assertEq(vault.balanceOf(alice), amount);
        assertEq(usdc.balanceOf(address(vault)), amount);

        vm.prank(alice);
        vault.withdraw(amount, alice);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(usdc.balanceOf(alice), START);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function testFuzz_PartialWithdrawConservesValue(uint256 dep, uint256 wd) public {
        dep = bound(dep, 1, START);
        wd = bound(wd, 1, dep);
        _deposit(alice, dep);
        vm.prank(alice);
        vault.withdraw(wd, bob);

        assertEq(vault.balanceOf(alice), dep - wd);
        assertEq(vault.totalSupply(), dep - wd);
        assertEq(usdc.balanceOf(bob), START + wd);
        assertEq(usdc.balanceOf(address(vault)), dep - wd);
        assertEq(vault.surplus(), 0);
    }

    function testFuzz_WithdrawMoreThanBalanceReverts(uint256 dep, uint256 extra) public {
        dep = bound(dep, 1, START);
        extra = bound(extra, 1, type(uint128).max);
        _deposit(alice, dep);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(dep + extra, alice);
        assertEq(vault.balanceOf(alice), dep);
    }

    function testFuzz_ReceiverRouting(address payer, address receiver, uint256 amount) public {
        vm.assume(payer != address(0) && receiver != address(0));
        vm.assume(payer != address(vault) && receiver != address(vault));
        amount = bound(amount, 1, CAP);
        usdc.mint(payer, amount);
        uint256 payerBefore = usdc.balanceOf(payer);
        uint256 receiverUsdcBefore = usdc.balanceOf(receiver);
        uint256 payerSharesBefore = vault.balanceOf(payer);

        _deposit(payer, amount, receiver);

        assertEq(usdc.balanceOf(payer), payerBefore - amount);
        if (receiver != payer) {
            assertEq(usdc.balanceOf(receiver), receiverUsdcBefore);
            assertEq(vault.balanceOf(payer), payerSharesBefore);
        }
        assertEq(vault.balanceOf(receiver), (receiver == payer ? payerSharesBefore : 0) + amount);
    }

    function testFuzz_DepositRespectsCap(uint256 cap, uint256 first, uint256 second) public {
        cap = bound(cap, 0, START * 2);
        first = bound(first, 1, START);
        second = bound(second, 1, START);
        vm.prank(capMgr);
        vault.setDepositCap(cap);

        // first deposit
        vm.startPrank(alice);
        usdc.approve(address(vault), first);
        if (first > cap) {
            vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, first, cap));
            vault.deposit(first, alice);
            vm.stopPrank();
            return;
        }
        vault.deposit(first, alice);
        vm.stopPrank();

        uint256 remaining = cap - first;
        assertEq(vault.maxDeposit(), remaining);

        vm.startPrank(bob);
        usdc.approve(address(vault), second);
        if (second > remaining) {
            vm.expectRevert(
                abi.encodeWithSelector(ArcUsdcVault.DepositCapExceeded.selector, second, remaining)
            );
            vault.deposit(second, bob);
        } else {
            vault.deposit(second, bob);
            assertLe(vault.totalSupply(), cap);
        }
        vm.stopPrank();
    }

    function testFuzz_LoweredCapNeverTrapsHolders(uint256 dep, uint256 newCap) public {
        dep = bound(dep, 1, START);
        newCap = bound(newCap, 0, type(uint128).max);
        _deposit(alice, dep);
        vm.prank(capMgr);
        vault.setDepositCap(newCap);
        vm.prank(alice);
        vault.withdraw(dep, alice);
        assertEq(usdc.balanceOf(alice), START);
    }

    function testFuzz_PausedAlwaysAllowsWithdrawAndTransfer(uint256 dep, uint256 moved) public {
        dep = bound(dep, 1, START);
        moved = bound(moved, 0, dep - 1);
        _deposit(alice, dep);
        vm.prank(pauser);
        vault.pause();
        vm.startPrank(alice);
        vault.transfer(bob, moved);
        vault.withdraw(dep - moved, alice);
        vm.stopPrank();
        assertEq(vault.balanceOf(bob), moved);
    }

    function testFuzz_SurplusEqualsDonations(uint256 dep, uint256 donation) public {
        dep = bound(dep, 1, START);
        donation = bound(donation, 0, START);
        _deposit(alice, dep);
        vm.prank(bob);
        usdc.transfer(address(vault), donation);
        assertEq(vault.surplus(), donation);
        assertEq(vault.totalSupply(), dep);
    }
}
