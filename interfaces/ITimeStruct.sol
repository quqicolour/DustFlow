//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0;

interface ITimeStruct{
    struct tradeMes{
        uint8 tradeState; 
        uint64 tradeId;
        uint56 buyTime;
        uint128 buyTotalAmount; //预期空投代币数量
        uint128 buyPrice;       //buyPrice/1000=当前价格
        uint128 buyerATokenAmount;   //购买者铸造的aave token数量
        uint128 solderATokenAmount;   //出售者铸造的aave token数量
        address tokenAddress;
        address buyerAddress;
        address solderAddress;
    }
}