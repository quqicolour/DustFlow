//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0;

interface ITimeManager{
    //得到费用地址
    function getFeeAddress()external view returns(address);
    
    //得到合约所有者
    function getOwner()external view returns(address);
}