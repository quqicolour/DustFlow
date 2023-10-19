// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TESTTimeToken is ERC20 {
    constructor()
        ERC20("TEST TimeToken", "TTT")
    {
        mint(msg.sender,10000000000000000 ether);
    }

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
}