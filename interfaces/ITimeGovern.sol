//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;

interface ITimeGovern{

    function getTargetToken(uint256 _marketId)external view returns(address);

    function getClearingTime(uint256 _marketId)external view returns(uint256);

    function getAllowedATokens()external view returns(address[] memory);

    function getAllowedStableToken()external view returns(address[] memory);
}