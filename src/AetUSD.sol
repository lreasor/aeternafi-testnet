// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ConcreteOFT} from "./utils/ConcreteOFT.sol";

/**
 * @title AetUSD
 * @notice Omnichain fungible token (OFT) representing AetUSD.
 *         Includes a designated minter role for controlled mint/burn.
 */
contract AetUSD is ConcreteOFT {
    address public minter;

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    /**
     * @param name_      ERC20 name
     * @param symbol_    ERC20 symbol
     * @param lzEndpoint LayerZero endpoint for this chain
     * @param owner_     Address that will be set as Ownable owner
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address lzEndpoint,
        address owner_
    )
        ConcreteOFT(name_, symbol_, 18, lzEndpoint, owner_) // ✅ forward all args to OFT (and Ownable)
    {}

    modifier onlyMinter() {
        require(msg.sender == minter, "AetUSD: not minter");
        _;
    }

    /// @notice Set the minter address (only callable by owner).
    function setMinter(address _minter) external onlyOwner {
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    /// @notice Mint new tokens to `to`. Only callable by minter.
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /// @notice Burn tokens from `from`. Only callable by minter.
    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
