// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

contract ArcUsdcVaultRescueTest is ArcUsdcVaultTestBase {
    MockERC20 internal other;

    function setUp() public override {
        super.setUp();
        other = new MockERC20("Other", "OTH", 18);
        other.mint(address(vault), 500e18);
    }

    function test_Rescue_NonUsdcTokenFreely() public {
        _deposit(alice, 100e6); // outstanding shares must not restrict other tokens
        vm.expectEmit(true, true, false, true, address(vault));
        emit ArcUsdcVault.TokenRescued(IERC20(address(other)), bob, 500e18);
        vm.prank(admin);
        vault.rescueToken(IERC20(address(other)), bob, 500e18);
        assertEq(other.balanceOf(bob), 500e18);
        assertEq(other.balanceOf(address(vault)), 0);
    }

    function test_Rescue_UsdcRevertsWhenNoSurplus() public {
        _deposit(alice, 100e6);
        assertEq(vault.surplus(), 0);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.InsufficientSurplus.selector, 1, 0));
        vault.rescueToken(IERC20(address(usdc)), admin, 1);
        assertEq(usdc.balanceOf(address(vault)), 100e6);
    }

    function test_Rescue_UsdcOnlySurplus() public {
        _deposit(alice, 100e6);
        vm.prank(bob);
        usdc.transfer(address(vault), 25e6);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.InsufficientSurplus.selector, 25e6 + 1, 25e6));
        vault.rescueToken(IERC20(address(usdc)), admin, 25e6 + 1);

        vm.expectEmit(true, true, false, true, address(vault));
        emit ArcUsdcVault.TokenRescued(IERC20(address(usdc)), carol, 25e6);
        vm.prank(admin);
        vault.rescueToken(IERC20(address(usdc)), carol, 25e6);

        assertEq(usdc.balanceOf(carol), START + 25e6);
        assertEq(vault.surplus(), 0);
        assertEq(vault.totalSupply(), 100e6);

        // backing is intact: holder can still redeem everything
        vm.prank(alice);
        vault.withdraw(100e6, alice);
        assertEq(usdc.balanceOf(alice), START);
    }

    function test_Rescue_UsdcPartialSurplusThenRemainder() public {
        usdc.mint(address(vault), 10e6); // pure donation, no shares
        vm.startPrank(admin);
        vault.rescueToken(IERC20(address(usdc)), admin, 4e6);
        assertEq(vault.surplus(), 6e6);
        vault.rescueToken(IERC20(address(usdc)), admin, 6e6);
        vm.expectRevert(abi.encodeWithSelector(ArcUsdcVault.InsufficientSurplus.selector, 1, 0));
        vault.rescueToken(IERC20(address(usdc)), admin, 1);
        vm.stopPrank();
    }

    function test_Rescue_WorksWhilePaused() public {
        usdc.mint(address(vault), 1e6);
        vm.prank(pauser);
        vault.pause();
        vm.prank(admin);
        vault.rescueToken(IERC20(address(usdc)), admin, 1e6);
        assertEq(usdc.balanceOf(admin), 1e6);
    }

    function test_Rescue_RevertsOnZeroToken() public {
        vm.prank(admin);
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        vault.rescueToken(IERC20(address(0)), admin, 1);
    }

    function test_Rescue_RevertsOnZeroRecipient() public {
        vm.prank(admin);
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        vault.rescueToken(IERC20(address(other)), address(0), 1);
    }

    function test_Rescue_RevertsOnZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(ArcUsdcVault.ZeroAmount.selector);
        vault.rescueToken(IERC20(address(other)), admin, 0);
    }

    function test_Rescue_RevertsOnZeroAmountForUsdc() public {
        vm.prank(admin);
        vm.expectRevert(ArcUsdcVault.ZeroAmount.selector);
        vault.rescueToken(IERC20(address(usdc)), admin, 0);
    }

    function test_Rescue_NonUsdcBeyondBalanceReverts() public {
        vm.prank(admin);
        vm.expectRevert();
        vault.rescueToken(IERC20(address(other)), admin, 500e18 + 1);
    }

    function test_Rescue_SharesOfVaultItselfNotUsdcBacking() public {
        // Rescuing the vault's own share token (if stuck there) is treated as non-USDC.
        _deposit(alice, 100e6);
        vm.prank(alice);
        vault.transfer(address(vault), 10e6);
        vm.prank(admin);
        vault.rescueToken(IERC20(address(vault)), admin, 10e6);
        assertEq(vault.balanceOf(admin), 10e6);
        assertEq(vault.totalSupply(), 100e6);
    }
}
