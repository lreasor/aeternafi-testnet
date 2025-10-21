// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EndpointMock {
    uint32 public eid;

    constructor(uint32 _eid) {
        eid = _eid;
    }

    function getEid() external view returns (uint32) {
        return eid;
    }

    function setDelegate(address) external {}
}
