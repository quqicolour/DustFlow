//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;
pragma abicoder v2;
import "./TimeMarket.sol";
contract TimeFactory{
    uint256 private id;
    // address private owner;
    // constructor(){
    //     owner=msg.sender;
    // }

    mapping(uint256=>address)private idToContract;

    // modifier onlyOwner{
    //     require(msg.sender==owner,"Not owner");
    //     _;
    // }

    //转移所有者
    // function transferOwner(address newOwner)external onlyOwner{
    //     owner=newOwner;
    // }

    //创建新的空投市场
    function createMarket(address airdropToken)external returns(address hat){
        hat=address(
            new TimeMarket{salt: keccak256(abi.encodePacked(id,airdropToken))}(airdropToken)
        );
        //记录所有已创建的合约
        idToContract[id]=hat;
        id++;

    }

    //得到最新的id
    function getLastId()external view returns(uint256){
        return id;
    }

    //根据id得到已经创建的合约地址
    function getContractMes(uint256 _id)external view returns(address){
        return idToContract[_id];
    }
}