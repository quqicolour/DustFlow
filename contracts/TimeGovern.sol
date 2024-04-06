//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../libraries/TimeLibrary.sol";
import "../interfaces/IERC20Metadata.sol";
import "./Ownable.sol";

contract TimeGovern is Ownable{

    address private timeMarketFactory;

    address private feeAddress;

    address[] private allowedAToken;
    address[] private allowedStableToken;

    mapping(uint256=>TimeLibrary.clearingMes)private _clearingMes;

    //usdc:0x52D800ca262522580CeBAD275395ca6e7598C014
    //usdt:0x1fdE0eCc619726f4cD597887C9F3b4c8740e19e2
    //ausdc:0x4086fabeE92a080002eeBA1220B9025a27a40A49
    //ausdt:0x5F3a71D07E95C1E54B9Cc055D418a219586A3473
    function setAllowToken(address[] calldata _allowedAToken,address[] calldata _allowedStableToken)external onlyOwner{
        allowedAToken=_allowedAToken;
        allowedStableToken=_allowedStableToken;
    }

    function setMarketMes(uint256 _marketId,address _targetToken,uint256 _clearingTime,bool ifSet)external onlyOwner{
        uint256 time=ifSet?_clearingTime+block.timestamp:block.timestamp+180 days;
        address token=ifSet?_targetToken:address(0);
        _clearingMes[_marketId]._marketId=_marketId;
        _clearingMes[_marketId]._clearingTime=time;
        _clearingMes[_marketId]._tokenAddress=token;
    }

    function getAllowedATokens()external view returns(address[] memory){
        require(allowedAToken.length!=0,"Zero");
        return allowedAToken;
    }

    function getAllowedStableToken()external view returns(address[] memory){
        require(allowedStableToken.length!=0,"Zero");
        return allowedStableToken;
    }

    //得到market targetToken
    function getTargetToken(uint256 _marketId)external view returns(address){
        address targetToken=_clearingMes[_marketId]._tokenAddress;
        require(targetToken!=address(0),"Zero address");
        return targetToken;
    }

    function getClearingTime(uint256 _marketId)external view returns(uint256){
        uint256 clearingTime=_clearingMes[_marketId]._clearingTime;
        return clearingTime;
    }
    
}