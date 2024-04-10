//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "./TimeCapitalPool.sol";
contract TimeCapitalPoolFactory{

    mapping(uint256=>address)private idToCapitalPool;

    mapping(uint256=>bool)private ifCreateCapitalPool;

    //创建新的空投市场
    function createCapitalPool(address _marketAddress,uint256 _marketId)external returns(address hat){
        require(ifCreateCapitalPool[_marketId]==false);
        hat=address(
            new TimeCapitalPool{salt: keccak256(abi.encodePacked(
                _marketId,
                _marketAddress
            ))}(_marketId)
        );
        //记录所有已创建的合约
        idToCapitalPool[_marketId]=hat;
        ifCreateCapitalPool[_marketId]=true;
    }

    //得到capital pool
    function getCapitalPool(uint256 _marketId)external view returns(address){
        return idToCapitalPool[_marketId];
    }

    //得到id是否创建了capital Pool
    function getIfCreateCapitalPool(uint256 _marketId)external view returns(bool){
        return ifCreateCapitalPool[_marketId];
    }


}