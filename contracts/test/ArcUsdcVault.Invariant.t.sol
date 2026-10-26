// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

contract ArcUsdcVaultHandler is Test {
    ArcUsdcVault public vault;
    MockERC20 public usdc;
    address public admin;
    address public pauser;
    address public capMgr;

    address[] public actors;
    uint256 public ghostMinted;
    uint256 public ghostBurned;
    bool public capEverLowered;

    constructor(ArcUsdcVault _vault, MockERC20 _usdc, address _admin, address _pauser, address _capMgr) {
        vault = _vault;
        usdc = _usdc;
        admin = _admin;
        pauser = _pauser;
        capMgr = _capMgr;
        for (uint256 i; i < 4; ++i) {
            address a = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(a);
            usdc.mint(a, 1e15);
        }
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function sumTrackedBalances() external view returns (uint256 s) {
        for (uint256 i; i < actors.length; ++i) {
            s += vault.balanceOf(actors[i]);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function deposit(uint256 payerSeed, uint256 receiverSeed, uint256 amount) external {
        address payer = _actor(payerSeed);
        address receiver = _actor(receiverSeed);
        amount = bound(amount, 1, 1e12);
        uint256 max = vault.maxDeposit();
        if (max == 0) return;
        amount = amount > max ? max : amount;
        vm.startPrank(payer);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, receiver);
        vm.stopPrank();
        ghostMinted += amount;
    }

    function withdraw(uint256 holderSeed, uint256 receiverSeed, uint256 amount) external {
        address holder = _actor(holderSeed);
        uint256 bal = vault.balanceOf(holder);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(holder);
        vault.withdraw(amount, _actor(receiverSeed));
        ghostBurned += amount;
    }

    function transferShares(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        uint256 bal = vault.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(from);
        vault.transfer(_actor(toSeed), amount);
    }

    function donate(uint256 actorSeed, uint256 amount) external {
        amount = bound(amount, 0, 1e10);
        vm.prank(_actor(actorSeed));
        usdc.transfer(address(vault), amount);
    }

    function rescueSurplus(uint256 amount) external {
        uint256 s = vault.surplus();
        if (s == 0) return;
        amount = bound(amount, 1, s);
        vm.prank(admin);
        vault.rescueToken(IERC20(address(usdc)), admin, amount);
    }

    function setCap(uint256 newCap) external {
        newCap = bound(newCap, 0, 1e13);
        if (newCap < vault.totalSupply()) capEverLowered = true;
        vm.prank(capMgr);
        vault.setDepositCap(newCap);
    }

    function togglePause(bool p) external {
        if (p == vault.paused()) return;
        vm.prank(pauser);
        if (p) vault.pause();
        else vault.unpause();
    }
}

contract ArcUsdcVaultInvariantTest is ArcUsdcVaultTestBase {
    ArcUsdcVaultHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new ArcUsdcVaultHandler(vault, usdc, admin, pauser, capMgr);
        targetContract(address(handler));
    }

    /// Backing: the vault always holds at least as much USDC as outstanding shares.
    function invariant_UsdcBalanceCoversSupply() public view {
        assertGe(usdc.balanceOf(address(vault)), vault.totalSupply());
    }

    /// Supply equals the sum of all holder balances (all holders are tracked actors).
    function invariant_SupplyEqualsSumOfBalances() public view {
        assertEq(vault.totalSupply(), handler.sumTrackedBalances());
    }

    /// Supply equals minted minus burned (shares only created by deposit / destroyed by withdraw).
    function invariant_SupplyEqualsMintedMinusBurned() public view {
        assertEq(vault.totalSupply(), handler.ghostMinted() - handler.ghostBurned());
    }

    /// Supply never exceeds the cap unless the cap was lowered below supply at some point.
    function invariant_SupplyWithinCapUnlessLowered() public view {
        if (!handler.capEverLowered()) {
            assertLe(vault.totalSupply(), vault.depositCap());
        }
    }

    /// Surplus is exactly balance minus supply and never reverts.
    function invariant_SurplusConsistent() public view {
        assertEq(vault.surplus(), usdc.balanceOf(address(vault)) - vault.totalSupply());
    }
}
