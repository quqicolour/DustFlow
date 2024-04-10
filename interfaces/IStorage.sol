//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface IStorage{

    function storageImage(uint256 marketId,uint256 tardeId,uint256 nftId,uint256 value,uint256 state,address token)external;

    function getTokenUri(address marketAddress,uint256 _nftId)external view returns(string memory);
}