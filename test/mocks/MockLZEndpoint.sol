// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockLZEndpoint {
    address public delegate;

    function setDelegate(address _delegate) external {
        delegate = _delegate;
    }
}
