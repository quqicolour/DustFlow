//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;
import "./TimeMarket.sol";
import "../interfaces/ITimeManager.sol";
contract TimeMarketFactory{
    uint256 private marketId;
    address private timeManager; //管理合约地址

    mapping(uint256=>address)private idToMarket;

    //创建新的空投市场
    function createMarket()external returns(address hat){
        hat=address(
            new TimeMarket{salt: keccak256(abi.encodePacked(
                marketId,
                block.timestamp
            ))}(marketId)
        );
        //记录所有已创建的合约
        idToMarket[marketId]=hat;
        marketId++;
    }

    //得到最新的市场id
    function getLastMarketId()external view returns(uint256){
        return marketId;
    }

    //根据市场id得到已经创建的合约信息
    function getMarket(uint256 _marketId)external view returns(address){
        return idToMarket[_marketId];
    }

}