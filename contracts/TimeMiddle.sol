//SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;
import "@openzeppelin/contracts/access/Ownable.sol";
contract TimeMiddle is Ownable{
    uint256 private number; //周期
    address private futureToken; //预期token
    address[] private supervisorGroup;

    mapping(uint256=>mapping(address=>uint256)) private clearTime;  //清算时间
    mapping(uint256=>uint256) private disputeIfPass; //根据争议id得到争议票数
    mapping(address=>mapping(uint256=>bool)) private ifVoteDispute;  //某个争议内容是否投票
    mapping(address=>bool)private ifHadSet; //该合约地址是否已经设置
    mapping(address=>uint256)private contractToClearId;  //根据合约地址得到对应清算周期id
    //争议
    struct dispute{
        uint128 disputeId; //争议id
        uint128 disputeTime;  //争议创建时间
        string disputeName; //争议名字
        string disputeThing;  //争议内容
    }
    dispute[] private _dispute;

    //部署者设置清算时间、预期空投代币地址
    function setCleanTime(uint256 _clearTime, address airdropContract, address _futureToken)external onlyOwner{
        require(ifHadSet[airdropContract]==false,"Had set");
        clearTime[number][airdropContract]=block.timestamp+_clearTime;
        contractToClearId[airdropContract]=number;
        futureToken=_futureToken;
        ifHadSet[airdropContract]=true;
        number++;
    }

    //添加审查者
    function addSuperVisor(address newSupervisor)external onlyOwner{
        require(checkIfSupervisor(newSupervisor)!=true);  //是否已经是审查者
        supervisorGroup.push(newSupervisor);
    }

    //移除审查者
    function removeSuperVisor(address newSupervisor)external onlyOwner{
        require(checkIfSupervisor(newSupervisor));  //是否已经是审查者
        for(uint16 a;a<supervisorGroup.length;a++){
            if(newSupervisor==supervisorGroup[a]){
                delete supervisorGroup[a];
            }
        }
    }

    //争议者创建争议内容
    function createDispute(address _airdropContract,string calldata _disputeName,string calldata _disputeThing,uint128 _disputeId)external{
        require(block.timestamp < clearTime[number-1][_airdropContract],"Not create");  //争议内容需要在某个事务前结束前10分钟以上创建
        _dispute.push(dispute(_disputeId,uint128(block.timestamp),_disputeName,_disputeThing));
    }

    //审查争议内容
    function checkDispute(uint128 _disputeId)external{
        require(ifVoteDispute[msg.sender][_disputeId] == false,"Already vote"); //是否对某个事务已经投了票
        require(checkIfSupervisor(msg.sender),"Not supervisor");  //是否审查者
        require(ifPass(_disputeId)==false,"Pass");  //审查票数>=审查团一半+1即通过
        disputeIfPass[_disputeId]++;
        ifVoteDispute[msg.sender][_disputeId]=true;
    }

    //某个事务是否通过审查(pass代表提议者争议内容审查通过)
    function ifPass(uint256 _disputeId)public view returns(bool){
        if(disputeIfPass[_disputeId]>=(supervisorGroup.length/2+1)){
            return true;
        }else{
            return false;
        }
    }

    //得到预期token地址
    function getFutureTokenAddress()external view returns(address){
        return futureToken;
    }

    //检查是否是审查者
    function checkIfSupervisor(address userAddress)public view returns(bool userState){
        for(uint16 i;i<supervisorGroup.length;i++){
            if(userAddress==supervisorGroup[i]){
                return true;
            }
        }
    }

    //返回当前清算时间
    function getClearTime(uint256 _number,address _airdropContract)external view returns(uint256){
        require(_number<number,"Number error");  //是否在清算周期
        return clearTime[_number][_airdropContract];
    }

    //得到清算id
    function getClearId(address _airdropContract)external view returns(uint256){
        return contractToClearId[_airdropContract];
    }

    //返回当前最新的周期Number
    function getLastNumber()external view returns(uint256){
        return number;
    }

    //得到所有审查者
    function getAllSupervisor()external view returns(address[] memory){
        return supervisorGroup;
    }


}