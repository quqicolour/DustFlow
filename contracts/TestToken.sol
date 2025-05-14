// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory thisName, string memory thisSymbol)
        ERC20(thisName, thisSymbol)
    {
        _mint(msg.sender, 1000000000000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
