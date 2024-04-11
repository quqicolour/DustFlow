//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../interfaces/ITimeCapitalPoolFactory.sol";
import "../interfaces/ITimeCapitalPool.sol";
import "../interfaces/IERC721Metadata.sol";
import "../libraries/Strings.sol";
import "../libraries/Base64.sol";
import "./Ownable.sol";

contract TimeERC721Storage is Ownable {
    address public timeCapitalPoolFactory;

    function initialize(address _timeCapitalPoolFactory) external onlyOwner {
        timeCapitalPoolFactory = _timeCapitalPoolFactory;
    }

    mapping(address => mapping(uint256 => string)) private timeERC721TokenUri;

    event storageNft(
        address indexed marketAddress,
        uint256 tradeId,
        uint256 nftId,
        uint256 value,
        address usedToken,
        string nftType
    );

    // 将NFT图像以svg的形式存储在链上
    string svgPart1 =
        '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" fill="none"><path fill="url(#B)" d="M0 0h270v270H0z"/>\n'
        '<defs><filter id="A" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270">\n'
        '<feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs>';
    string bgColor1 =
        '<defs><linearGradient id="B" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#fbc2eb"/>\n'
        '<stop offset="1" stop-color="#a6c1ee" stop-opacity=".99"/></linearGradient></defs>';
    string bgColor2 =
        '<defs><linearGradient id="B" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#e0c3fc"/>\n'
        '<stop offset="1" stop-color="#8ec5fc" stop-opacity=".99"/></linearGradient></defs>';
    string bgColor3 =
        '<defs><linearGradient id="B" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#a8edea"/>\n'
        '<stop offset="1" stop-color="#fed6e3" stop-opacity=".99"/></linearGradient></defs>';
    string svgPart2 =
        '<text x="32.5" y="50" font-size="27" fill="#fff" filter="url(#A)" font-weight="bold">tradeId:';
    string svgPart3 =
        '<text x="32.5" y="100" font-size="27" fill="#fff" filter="url(#A)" font-weight="bold">value:';
    string svgPart4 =
        '<text x="32.5" y="150" font-size="27" fill="#fff" filter="url(#A)" font-weight="bold">nftType:';
    string svgPart5 = "</text></svg>";
    string svgText = "</text>";

    function storageImage(
        uint256 marketId,
        uint256 tardeId,
        uint256 nftId,
        uint256 value,
        uint256 state,
        address token
    ) external {
        require(
            msg.sender ==
                ITimeCapitalPoolFactory(timeCapitalPoolFactory).getCapitalPool(
                    marketId
                ),
            "Non market"
        );
        string memory symbol = IERC721Metadata(msg.sender).symbol();
        string memory thisTradeId=Strings.toString(tardeId);
        string memory nftType;
        string memory bgColor;
        if (state == 0) {
            nftType = "buyer";
            bgColor = bgColor1;
        } else if (state == 1) {
            nftType = "seller";
            bgColor = bgColor2;
        } else if (state == 2) {
            nftType = "inject";
            bgColor = bgColor3;
        } else {
            revert();
        }
        string memory finalSvg = string(
            abi.encodePacked(
                svgPart1,
                bgColor,
                svgPart2,
                thisTradeId,
                svgText,
                svgPart3,
                Strings.toString(value),
                svgText,
                svgPart4,
                nftType,
                svgPart5
            )
        );
        string memory json = Base64.encode(
            abi.encodePacked(
                '{"name": "',
                symbol,
                '", "description": "Welcome to the magical world of timeflow", "image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(finalSvg)),
                '","marketId":"',
                Strings.toString(marketId),
                '","tardeId":"',
                thisTradeId,
                '","nftId":"',
                Strings.toString(nftId),
                '","value":"',
                Strings.toString(value),
                '","nftType":"',
                nftType,
                '","token":"',
                Strings.toHexString(token),
                '"}'
            )
        );
        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        timeERC721TokenUri[msg.sender][nftId] = finalTokenUri;
        emit storageNft(msg.sender, tardeId, nftId, value, token, nftType);
    }

    //得到uri
    function getTokenUri(address capitalPoolAddress, uint256 _nftId)
        external
        view
        returns (string memory)
    {
        return timeERC721TokenUri[capitalPoolAddress][_nftId];
    }
}
