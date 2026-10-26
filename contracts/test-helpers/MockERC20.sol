// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Configurable 6-decimal mock: optional transfer fee, global revert switch,
/// blocklist, and a "return false" switch for transfers.
contract MockERC20 is ERC20 {
    uint8 private immutable _dec;

    uint256 public feeBps; // fee (burned) on every transfer, taken from the recipient's amount
    bool public revertTransfers;
    bool public returnFalse;
    mapping(address => bool) public blocked;

    error Blocked(address account);
    error TransfersDisabled();

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _dec = d;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFeeBps(uint256 v) external {
        feeBps = v;
    }

    function setRevertTransfers(bool v) external {
        revertTransfers = v;
    }

    function setReturnFalse(bool v) external {
        returnFalse = v;
    }

    function setBlocked(address a, bool v) external {
        blocked[a] = v;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (returnFalse) return false;
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (returnFalse) return false;
        return super.transferFrom(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            if (revertTransfers) revert TransfersDisabled();
            if (blocked[from]) revert Blocked(from);
            if (blocked[to]) revert Blocked(to);
            if (feeBps != 0) {
                uint256 fee = (value * feeBps) / 10_000;
                if (fee != 0) {
                    super._update(from, address(0), fee);
                    value -= fee;
                }
            }
        }
        super._update(from, to, value);
    }
}
