// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AetUSDSilo
 * @notice Cooldown queue and reward streaming for sAetUSD.
 * @dev Holds AetUSD transferred from the sAetUSD vault during withdrawals.
 */
contract AetUSDSilo is Ownable {
    IERC20 public immutable aetUSD;
    address public vault; // sAetUSD address
    uint256 public cooldownPeriod; // e.g. 14 days

    struct Request {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => Request) public requests;

    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event CooldownUpdated(uint256 oldPeriod, uint256 newPeriod);
    event Enqueued(address indexed user, uint256 amount, uint256 unlockTime);
    event Claimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);

    constructor(address _aetUSD, address owner_, uint256 _cooldown) Ownable(owner_) {
        require(_aetUSD != address(0), "Silo: aetUSD zero");
        aetUSD = IERC20(_aetUSD);
        cooldownPeriod = _cooldown;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Silo: not vault");
        _;
    }

    function setVault(address _vault) external onlyOwner {
        emit VaultUpdated(vault, _vault);
        vault = _vault;
    }

    function setCooldownPeriod(uint256 _cooldown) external onlyOwner {
        emit CooldownUpdated(cooldownPeriod, _cooldown);
        cooldownPeriod = _cooldown;
    }

    /**
     * @notice Called by sAetUSD after transferring AetUSD here.
     * @dev Records a withdrawal request with cooldown.
     */
    function enqueueFromVault(address user, uint256 amount) external onlyVault {
        require(user != address(0), "Silo: user zero");
        require(amount > 0, "Silo: amount=0");

        Request storage r = requests[user];
        r.amount += amount;
        r.unlockTime = block.timestamp + cooldownPeriod;

        emit Enqueued(user, amount, r.unlockTime);
    }

    /**
     * @notice Claim AetUSD after cooldown ends.
     */
    function claim() external {
        Request memory r = requests[msg.sender];
        require(r.amount > 0, "Silo: nothing to claim");
        require(block.timestamp >= r.unlockTime, "Silo: cooling down");

        delete requests[msg.sender];
        require(aetUSD.transfer(msg.sender, r.amount), "Silo: transfer failed");
        emit Claimed(msg.sender, r.amount);
    }

    /**
     * @notice Distribute rewards to the vault (increases sAetUSD totalAssets).
     * @dev Fund this contract with AetUSD first, then call to stream out.
     */
    function distributeRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Silo: amount=0");
        require(vault != address(0), "Silo: vault not set");
        require(aetUSD.transfer(vault, amount), "Silo: transfer failed");
        emit RewardsDistributed(amount);
    }
}
