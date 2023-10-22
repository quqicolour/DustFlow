//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;
pragma abicoder v2;
import "./TimeMarket.sol";
import "../interfaces/ITimeFactory.sol";
contract TimeFactory is ITimeFactory{
    uint256 private id;
    address private owner;
    constructor(){
        owner=msg.sender;
    }

    mapping(uint256=>timeContract)private contractMes;

    modifier onlyOwner{
        require(msg.sender==owner,"Not owner");
        _;
    }

    //转移所有者
    function transferOwner(address newOwner)external onlyOwner{
        owner=newOwner;
    }

    //创建新的空投市场
    function createMarket(address airdropToken)external onlyOwner returns(address hat){
        hat=address(
            new TimeMarket{salt: keccak256(abi.encodePacked(id,airdropToken))}(airdropToken)
        );
        //记录所有已创建的合约
        contractMes[id]=timeContract({
            contractId:id,
            contractAddress:hat
        });
        id++;

    }

    //预测未来的奖励池

    //得到最新的id
    function getLastId()external view returns(uint256){
        return id;
    }

    //根据id得到已经创建的合约信息
    function getContractMes(uint256 _id)external view returns(timeContract memory){
        return contractMes[_id];
    }
}