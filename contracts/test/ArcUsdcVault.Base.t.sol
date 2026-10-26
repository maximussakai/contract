// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

abstract contract ArcUsdcVaultTestBase is Test {
    ArcUsdcVault internal vault;
    MockERC20 internal usdc;

    address internal admin = makeAddr("admin");
    address internal pauser = makeAddr("pauser");
    address internal capMgr = makeAddr("capMgr");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal attacker = makeAddr("attacker");

    uint48 internal constant ADMIN_DELAY = 1 days;
    uint256 internal constant CAP = 1_000_000e6;
    uint256 internal constant START = 10_000e6;

    function setUp() public virtual {
        usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        vault = new ArcUsdcVault(IERC20(address(usdc)), admin, ADMIN_DELAY, pauser, capMgr, CAP);
        usdc.mint(alice, START);
        usdc.mint(bob, START);
        usdc.mint(carol, START);
        usdc.mint(attacker, START);
    }

    /// @dev Approve exactly `amount` and deposit as `who` to `receiver`.
    function _deposit(address who, uint256 amount, address receiver) internal {
        vm.startPrank(who);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, receiver);
        vm.stopPrank();
    }

    function _deposit(address who, uint256 amount) internal {
        _deposit(who, amount, who);
    }

    function _unauthorized(address who, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", who, role)
        );
    }
}
