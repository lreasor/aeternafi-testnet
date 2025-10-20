// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {sAetUSD} from "../src/sAetUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployScript is Script {
    function run() external {
        address aetUSD = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81; // WETH on Sepolia
        address lzEndpoint = 0xef7586B823d6224Ee5B11C1103305BcED432Dae4; // Mock End Point - LayerZero
        address owner = msg.sender;

        vm.startBroadcast();
        sAetUSD vault = new sAetUSD(IERC20(aetUSD), lzEndpoint, owner);
        vm.stopBroadcast();
    }
}
