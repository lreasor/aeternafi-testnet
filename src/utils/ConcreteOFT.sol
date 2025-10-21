// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OFTCore} from "@layerzero/lz-evm-sdk-v2/contracts/oft/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ConcreteOFT is ERC20, OFTCore {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_, // <— explicitly pass decimals
        address lzEndpoint,
        address owner_
    )
        ERC20(name_, symbol_)
        OFTCore(decimals_, lzEndpoint, owner_)
        Ownable(owner_) // <— add this back
    {}

    function token() public view returns (address) {
        return address(this);
    }

    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }
}
