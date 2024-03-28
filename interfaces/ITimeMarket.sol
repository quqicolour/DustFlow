//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

import "../libraries/TimeLibrary.sol";

interface ITimeMarket{
    
    event RefundEvent(uint32 tradeId,uint256 amount,address receiver);

    function getTradeMes(uint32 _id)external view returns(TimeLibrary.tradeMes memory);

    function getUserDeposite(uint32 _id,address userAddress)external view returns(TimeLibrary.userDeposite memory);
    
}