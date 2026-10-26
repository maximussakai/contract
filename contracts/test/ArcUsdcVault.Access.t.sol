// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {ArcUsdcVault} from "../ArcUsdcVault.sol";
import {ArcUsdcVaultTestBase} from "./ArcUsdcVault.Base.t.sol";

contract ArcUsdcVaultAccessTest is ArcUsdcVaultTestBase {
    bytes32 internal PAUSER;
    bytes32 internal CAPM;
    bytes32 internal ADMIN_ROLE = 0x00;

    function setUp() public override {
        super.setUp();
        PAUSER = vault.PAUSER_ROLE();
        CAPM = vault.CAP_MANAGER_ROLE();
    }

    // ------------------------------------------------------------ constructor

    function test_Constructor_SetsStateAndRoles() public view {
        assertEq(address(vault.USDC()), address(usdc));
        assertEq(vault.depositCap(), CAP);
        assertEq(vault.name(), "Arc USDC Vault Share");
        assertEq(vault.symbol(), "vUSDC");
        assertEq(vault.defaultAdmin(), admin);
        assertEq(vault.defaultAdminDelay(), ADMIN_DELAY);
        assertTrue(vault.hasRole(ADMIN_ROLE, admin));
        assertTrue(vault.hasRole(PAUSER, pauser));
        assertTrue(vault.hasRole(CAPM, capMgr));
        assertFalse(vault.hasRole(PAUSER, admin));
        assertFalse(vault.hasRole(CAPM, admin));
        assertFalse(vault.paused());
        assertEq(vault.totalSupply(), 0);
    }

    function test_Constructor_EmitsInitialCap() public {
        address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vm.expectEmit(false, false, false, true, predicted);
        emit ArcUsdcVault.DepositCapUpdated(0, 123e6);
        new ArcUsdcVault(IERC20(address(usdc)), admin, ADMIN_DELAY, pauser, capMgr, 123e6);
    }

    function test_Constructor_ZeroCapAllowed() public {
        ArcUsdcVault v = new ArcUsdcVault(IERC20(address(usdc)), admin, ADMIN_DELAY, pauser, capMgr, 0);
        assertEq(v.depositCap(), 0);
        assertEq(v.maxDeposit(), 0);
    }

    function test_Constructor_RevertsOnZeroUsdc() public {
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        new ArcUsdcVault(IERC20(address(0)), admin, ADMIN_DELAY, pauser, capMgr, CAP);
    }

    function test_Constructor_RevertsOnZeroPauser() public {
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        new ArcUsdcVault(IERC20(address(usdc)), admin, ADMIN_DELAY, address(0), capMgr, CAP);
    }

    function test_Constructor_RevertsOnZeroCapManager() public {
        vm.expectRevert(ArcUsdcVault.ZeroAddress.selector);
        new ArcUsdcVault(IERC20(address(usdc)), admin, ADMIN_DELAY, pauser, address(0), CAP);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, address(0))
        );
        new ArcUsdcVault(IERC20(address(usdc)), address(0), ADMIN_DELAY, pauser, capMgr, CAP);
    }

    // ------------------------------------------------------ role authorization

    function test_Pause_OnlyPauser() public {
        address[4] memory bad = [admin, capMgr, attacker, alice];
        for (uint256 i; i < bad.length; ++i) {
            _unauthorized(bad[i], PAUSER);
            vm.prank(bad[i]);
            vault.pause();
        }
        assertFalse(vault.paused());
        vm.prank(pauser);
        vault.pause();
        assertTrue(vault.paused());
    }

    function test_Unpause_OnlyPauser() public {
        vm.prank(pauser);
        vault.pause();
        address[4] memory bad = [admin, capMgr, attacker, alice];
        for (uint256 i; i < bad.length; ++i) {
            _unauthorized(bad[i], PAUSER);
            vm.prank(bad[i]);
            vault.unpause();
        }
        assertTrue(vault.paused());
        vm.prank(pauser);
        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_SetDepositCap_OnlyCapManager() public {
        address[4] memory bad = [admin, pauser, attacker, alice];
        for (uint256 i; i < bad.length; ++i) {
            _unauthorized(bad[i], CAPM);
            vm.prank(bad[i]);
            vault.setDepositCap(1);
        }
        assertEq(vault.depositCap(), CAP);
        vm.prank(capMgr);
        vault.setDepositCap(1);
        assertEq(vault.depositCap(), 1);
    }

    function test_RescueToken_OnlyAdmin() public {
        MockERC20Like(address(usdc)).mint(address(vault), 10e6);
        address[4] memory bad = [pauser, capMgr, attacker, alice];
        for (uint256 i; i < bad.length; ++i) {
            _unauthorized(bad[i], ADMIN_ROLE);
            vm.prank(bad[i]);
            vault.rescueToken(IERC20(address(usdc)), bad[i], 1);
        }
        vm.prank(admin);
        vault.rescueToken(IERC20(address(usdc)), admin, 1);
        assertEq(usdc.balanceOf(admin), 1);
    }

    function test_Admin_CanGrantAndRevokeOperationalRoles() public {
        address newPauser = makeAddr("newPauser");
        vm.prank(admin);
        vault.grantRole(PAUSER, newPauser);
        vm.prank(newPauser);
        vault.pause();
        assertTrue(vault.paused());

        vm.prank(admin);
        vault.revokeRole(PAUSER, newPauser);
        _unauthorized(newPauser, PAUSER);
        vm.prank(newPauser);
        vault.unpause();
    }

    function test_NonAdmin_CannotGrantRoles() public {
        bytes32 role = PAUSER;
        _unauthorized(attacker, ADMIN_ROLE);
        vm.prank(attacker);
        vault.grantRole(role, attacker);
        _unauthorized(pauser, ADMIN_ROLE);
        vm.prank(pauser);
        vault.grantRole(CAPM, pauser);
    }

    function test_DefaultAdminRole_CannotBeGrantedDirectly() public {
        vm.prank(admin);
        vm.expectRevert(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector);
        vault.grantRole(ADMIN_ROLE, attacker);
    }

    // ------------------------------------------- delayed two-step admin transfer

    function test_AdminTransfer_HappyPathAfterDelay() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        vault.beginDefaultAdminTransfer(newAdmin);
        (address pending, uint48 schedule) = vault.pendingDefaultAdmin();
        assertEq(pending, newAdmin);
        assertEq(schedule, uint48(block.timestamp) + ADMIN_DELAY);

        vm.warp(uint256(schedule) + 1);
        vm.prank(newAdmin);
        vault.acceptDefaultAdminTransfer();

        assertEq(vault.defaultAdmin(), newAdmin);
        assertTrue(vault.hasRole(ADMIN_ROLE, newAdmin));
        assertFalse(vault.hasRole(ADMIN_ROLE, admin));

        // old admin has lost privileged power, new admin has it
        _unauthorized(admin, ADMIN_ROLE);
        vm.prank(admin);
        vault.rescueToken(IERC20(address(usdc)), admin, 1);
        MockERC20Like(address(usdc)).mint(address(vault), 1);
        vm.prank(newAdmin);
        vault.rescueToken(IERC20(address(usdc)), newAdmin, 1);
    }

    function test_AdminTransfer_AcceptBeforeDelayReverts() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        vault.beginDefaultAdminTransfer(newAdmin);
        (, uint48 schedule) = vault.pendingDefaultAdmin();
        vm.warp(schedule - 1);
        vm.prank(newAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule)
        );
        vault.acceptDefaultAdminTransfer();
        assertEq(vault.defaultAdmin(), admin);
    }

    function test_AdminTransfer_OnlyPendingAdminCanAccept() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        vault.beginDefaultAdminTransfer(newAdmin);
        skip(ADMIN_DELAY + 1);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, attacker)
        );
        vault.acceptDefaultAdminTransfer();
    }

    function test_AdminTransfer_OnlyAdminCanBegin() public {
        _unauthorized(attacker, ADMIN_ROLE);
        vm.prank(attacker);
        vault.beginDefaultAdminTransfer(attacker);
        _unauthorized(pauser, ADMIN_ROLE);
        vm.prank(pauser);
        vault.beginDefaultAdminTransfer(pauser);
    }

    function test_AdminTransfer_CancelPreventsAccept() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        vault.beginDefaultAdminTransfer(newAdmin);
        vm.prank(admin);
        vault.cancelDefaultAdminTransfer();
        skip(ADMIN_DELAY + 1);
        vm.prank(newAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, newAdmin)
        );
        vault.acceptDefaultAdminTransfer();
        assertEq(vault.defaultAdmin(), admin);
    }

    function test_AdminTransfer_AdminCannotRenounceDirectlyWithoutDelay() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, uint48(0))
        );
        vault.renounceRole(ADMIN_ROLE, admin);
        assertEq(vault.defaultAdmin(), admin);
    }
}

interface MockERC20Like {
    function mint(address to, uint256 amount) external;
}
