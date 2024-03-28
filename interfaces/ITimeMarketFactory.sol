//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface ITimeMarketFactory{
    //得到最新的id
    function getLastId()external view returns(uint256);

    //根据id得到已经创建的合约信息
    function getMarket(uint256 _id)external view returns(address);
    
    //费用地址
    function thisFeeAddress()external view returns(address);

    //所有者
    function thisOwner()external view returns(address);
}