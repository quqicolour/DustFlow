//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface ITimeCapitalPoolFactory{

    function createCapitalPool(address _marketAddress,uint256 _marketId)external returns(address hat);

    function getCapitalPool(uint256 _marketId)external view returns(address);
 
    function getIfCreateCapitalPool(uint256 _marketId)external view returns(bool);
    
}