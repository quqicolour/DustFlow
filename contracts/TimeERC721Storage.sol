//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../interfaces/ITimeCapitalPoolFactory.sol";
import "../interfaces/ITimeCapitalPool.sol";
import "../interfaces/IERC721Metadata.sol";
import "../libraries/Strings.sol";
import "../libraries/Base64.sol";
import "./Ownable.sol";
contract TimeERC721Storage is Ownable{

    address private timeCapitalPoolFactory;
    function initialize(address _timeCapitalPoolFactory)external onlyOwner{
        timeCapitalPoolFactory=_timeCapitalPoolFactory;
    }

    mapping(address=>mapping(uint256=>string))private timeERC721TokenUri;

    event storageNft(address marketAddress,uint256 tradeId,uint256 nftId,uint256 value,address usedToken,string nftType);

    // 将NFT图像以svg的形式存储在链上
    string svgPart1 = '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" fill="none"><path fill="url(#B)" d="M0 0h270v270H0z"/><defs><filter id="A" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="360" width="360">\n'
    '<feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs>\n'
    '<defs><linearGradient id="B" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#cb5eee"/><stop offset="1" stop-color="#0cd7e4" stop-opacity=".99"/>\n'
    '</linearGradient></defs><text x="32.5" y="231" font-size="27" fill="#fff" filter="url(#A)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
    string svgPart2= '</text></svg>';

    function storageImage(uint256 marketId,uint256 tardeId,uint256 nftId,uint256 value,uint256 state,address token)external{
        require(msg.sender==ITimeCapitalPoolFactory(timeCapitalPoolFactory).getCapitalPool(marketId),"Non market");
        string memory symbol=IERC721Metadata(msg.sender).symbol();
        string memory nftType;
        if(state==0){
            nftType="buyer";
        }else if(state==1){
            nftType="seller";
        }else if(state==2){
            nftType="inject";
        }else{
            revert();
        }
        string memory finalSvg=string(abi.encodePacked(svgPart1, nftType, svgPart2));
        string memory json = Base64.encode(
        abi.encodePacked(
          '{"name": "',
          symbol,
          '", "description": "Welcome to the magical world of timeflow", "image": "data:image/svg+xml;base64,',
          Base64.encode(bytes(finalSvg)),'","marketId":"',Strings.toString(marketId),'","tardeId":"',Strings.toString(tardeId),'","nftId":"',Strings.toString(nftId),
          '","value":"',Strings.toString(value),'","nftType":"',nftType,'","token":"',Strings.toHexString(token),
          '"}'
        )
      );
      string memory finalTokenUri = string(abi.encodePacked("data:application/json;base64,", json));
      timeERC721TokenUri[msg.sender][nftId]=finalTokenUri;
      emit storageNft(msg.sender,tardeId,nftId,value,token,nftType);
    }

    //得到uri
    function getTokenUri(address marketAddress,uint256 _nftId)external view returns(string memory){
        return timeERC721TokenUri[marketAddress][_nftId];
    }

}