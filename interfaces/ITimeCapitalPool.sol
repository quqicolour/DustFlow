//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface ITimeCapitalPool{

    struct withdrawMes{
        uint32 tradeId;
        uint256 amount;
        address userAddress;
        address tokenAddress;
    }

   //授权市场销毁a token,取回资产
    function approveMarket(address aToken,uint256 approveAmount)external;
    
}