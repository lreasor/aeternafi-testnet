// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ConcreteOFT} from "./utils/ConcreteOFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract sAetUSD is ConcreteOFT, ERC4626, ReentrancyGuard {
    // During base constructor execution, this is false by default.

    address public silo;
    event SiloUpdated(address indexed oldSilo, address indexed newSilo);

    constructor(
        IERC20 _aetUSD,
        address lzEndpoint,
        address owner_
    )
        ERC4626(_aetUSD)
        ConcreteOFT("Staked AetUSD", "sAetUSD", 18, lzEndpoint, owner_)
    {}

    function decimals() public view override(ERC20, ERC4626) returns (uint8) {
    return ERC4626.decimals();
    }

    function setSilo(address _silo) external onlyOwner {
        emit SiloUpdated(silo, _silo);
        silo = _silo;
    }

    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 shares)
    {
        require(assets > 0, "sAetUSD: assets=0");
        shares = previewDeposit(assets);
        require(IERC20(asset()).transferFrom(msg.sender, address(this), assets));
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // Slither false positive: transferFrom must precede mint for correct share accounting
    // Reentrancy is blocked by nonReentrant
    function mint(uint256 shares, address receiver)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, "sAetUSD: shares=0");
        assets = previewMint(shares);
        require(IERC20(asset()).transferFrom(msg.sender, address(this), assets));
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 shares)
    {
        require(assets > 0, "sAetUSD: assets=0");
        shares = previewWithdraw(assets);

        if (owner_ != msg.sender) {
            uint256 allowed = allowance(owner_, msg.sender);
            require(allowed >= shares, "sAetUSD: allowance");
            _approve(owner_, msg.sender, allowed - shares);
        }

        _burn(owner_, shares);

        if (silo == address(0)) {
            require(IERC20(asset()).transfer(receiver, assets));
        } else {
            require(IERC20(asset()).transfer(silo, assets));
            IAetUSDSilo(silo).enqueueFromVault(receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, "sAetUSD: shares=0");

        if (owner_ != msg.sender) {
            uint256 allowed = allowance(owner_, msg.sender);
            require(allowed >= shares, "sAetUSD: allowance");
            _approve(owner_, msg.sender, allowed - shares);
        }

        assets = previewRedeem(shares);
        _burn(owner_, shares);

        if (silo == address(0)) {
            require(IERC20(asset()).transfer(receiver, assets));
        } else {
            require(IERC20(asset()).transfer(silo, assets));
            IAetUSDSilo(silo).enqueueFromVault(receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }
}

interface IAetUSDSilo {
    function enqueueFromVault(address user, uint256 assets) external;
}
