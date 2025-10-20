// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AetUSD} from "./AetUSD.sol";

/**
 * @title AetUSDMintr
 * @notice Controller that mints/burns AetUSD. Set this contract as minter in AetUSD.
 * @dev Collateral logic is protocol-specific; add it behind onlyOwner/role gates.
 */
contract AetUSDMintr is Ownable {
    AetUSD public immutable aetUSD;

    event Minted(address indexed to, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    constructor(address _aetUSD, address owner_) Ownable(owner_) {
        require(_aetUSD != address(0), "Mintr: aetUSD zero");
        aetUSD = AetUSD(_aetUSD);
    }

    /**
     * @notice Mint AetUSD to an address (stub: add collateral checks/quotas).
     */
    function mintTo(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Mintr: to zero");
        require(amount > 0, "Mintr: amount=0");
        aetUSD.mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burn the caller's AetUSD (stub: release collateral to user).
     */
    function redeem(uint256 amount) external {
        require(amount > 0, "Mintr: amount=0");
        aetUSD.burn(msg.sender, amount);
        emit Redeemed(msg.sender, amount);
        // TODO: transfer collateral out to msg.sender after validation
    }
}
