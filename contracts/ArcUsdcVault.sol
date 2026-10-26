// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Arc USDC Vault
/// @notice Immutable, fee-free vault issuing one six-decimal share per USDC unit.
/// @dev Assumes the underlying is trusted, six-decimal, non-rebasing USDC.
/// Pausing affects deposits only, not withdrawals or share transfers.
contract ArcUsdcVault is ERC20, AccessControlDefaultAdminRules, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CAP_MANAGER_ROLE = keccak256("CAP_MANAGER_ROLE");

    IERC20 public immutable USDC;
    uint256 public depositCap;

    error ZeroAddress();
    error ZeroAmount();
    error DepositCapExceeded(uint256 amount, uint256 available);
    error UnexpectedBalanceDelta(uint256 balanceBefore, uint256 balanceAfter, uint256 expectedIncrease);
    error InsufficientSurplus(uint256 amount, uint256 available);

    event Deposit(address indexed caller, address indexed receiver, uint256 amount);
    event Withdraw(address indexed caller, address indexed receiver, uint256 amount);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event TokenRescued(IERC20 indexed token, address indexed to, uint256 amount);

    /// @dev A zero cap is allowed. A zero admin is rejected by the inherited
    /// AccessControlDefaultAdminRules constructor with its custom error.
    constructor(
        IERC20 usdc,
        address admin,
        uint48 adminDelay,
        address pauser,
        address capManager,
        uint256 initialCap
    ) ERC20("Arc USDC Vault Share", "vUSDC") AccessControlDefaultAdminRules(adminDelay, admin) {
        if (address(usdc) == address(0) || pauser == address(0) || capManager == address(0)) {
            revert ZeroAddress();
        }

        USDC = usdc;
        depositCap = initialCap;
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(CAP_MANAGER_ROLE, capManager);
        emit DepositCapUpdated(0, initialCap);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Pull amount USDC from the caller and issue amount shares to receiver.
    /// @dev Effects precede the transfer; a failed transfer or balance-delta check
    /// reverts the entire transaction, including the mint.
    function deposit(uint256 amount, address receiver) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        uint256 available = maxDeposit();
        if (amount > available) revert DepositCapExceeded(amount, available);

        address caller = _msgSender();
        uint256 balanceBefore = USDC.balanceOf(address(this));
        _mint(receiver, amount);
        USDC.safeTransferFrom(caller, address(this), amount);
        uint256 balanceAfter = USDC.balanceOf(address(this));
        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != amount) {
            revert UnexpectedBalanceDelta(balanceBefore, balanceAfter, amount);
        }

        emit Deposit(caller, receiver, amount);
    }

    /// @notice Burn the caller's shares and send an equal amount of USDC to receiver.
    /// @dev Intentionally available while paused. A failed payout rolls back the burn.
    function withdraw(uint256 amount, address receiver) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        address caller = _msgSender();
        _burn(caller, amount);
        USDC.safeTransfer(receiver, amount);
        emit Withdraw(caller, receiver, amount);
    }

    /// @notice Set the cap, including to zero or below outstanding supply.
    /// @dev Lowering the cap does not affect existing holders' withdrawal rights.
    function setDepositCap(uint256 newCap) external onlyRole(CAP_MANAGER_ROLE) {
        uint256 oldCap = depositCap;
        depositCap = newCap;
        emit DepositCapUpdated(oldCap, newCap);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Recover accidental tokens, never USDC backing outstanding shares.
    function rescueToken(IERC20 token, address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (address(token) == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (address(token) == address(USDC)) {
            uint256 available = surplus();
            if (amount > available) revert InsufficientSurplus(amount, available);
        }

        token.safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    /// @notice Remaining deposit capacity, or zero when paused or at/above the cap.
    function maxDeposit() public view returns (uint256) {
        if (paused()) return 0;
        uint256 supply = totalSupply();
        uint256 cap = depositCap;
        return supply >= cap ? 0 : cap - supply;
    }

    /// @notice USDC held in excess of the backing for outstanding shares.
    /// @dev Checked subtraction reverts if the trusted underlying becomes insolvent.
    function surplus() public view returns (uint256) {
        return USDC.balanceOf(address(this)) - totalSupply();
    }
}
