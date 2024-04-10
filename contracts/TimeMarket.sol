//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;
import "../libraries/SafeERC20.sol";
import "../libraries/TimeLibrary.sol";
import "../interfaces/ITimeMarket.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/ITimeMarketFactory.sol";
import "../interfaces/ITimeCapitalPool.sol";
import "../interfaces/ITimeGovern.sol";

//aave v3
import "../interfaces/AaveV3/IPool.sol";

//计算个人获得的利息=个人质押数量/总质押数量*利息总数量+个人质押数量

contract TimeMarket is ITimeMarket{
    using SafeERC20 for IERC20;
    uint32 private id;  //交易订单次数
    uint256 private thisMarketId;

    bool private initState;

    address private timeCapitalPool;
    address private timeGovern;

    // address private AUSDT=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;   //aave usdt=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
    // address private AEthUsdt=0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6;

    //AAVE V3 (sepolia)
    IPool private AaveV3Pool=IPool(0xcC6114B983E4Ed2737E9BD3961c9924e6216c704);

    constructor(uint256 _thisMarketId){
        thisMarketId=_thisMarketId;
    }

    //记录对应下的交易信息
    mapping(uint32=>TimeLibrary.tradeMes)private _tradeMes;
    //记录用户的流动性数量
    mapping(address=>mapping(uint64=>uint)) private userLiquidity;

    //aaveV3=IPool(0xcC6114B983E4Ed2737E9BD3961c9924e6216c704)
    function initialize(address _timeCapitalPool,address _timeGovern,address _pool)external{
        require(initState==false,"Already init");
        timeCapitalPool=_timeCapitalPool;
        timeGovern=_timeGovern;
        AaveV3Pool=IPool(_pool);
        initState=true;
    }

    //挂单(买卖)
    function putTrade(address _tokenAddress,uint64 _amount,uint128 _price,uint256 doState)external{
        require(judgeInputStableToken(_tokenAddress)==1,"Non allowed token");
        //小数点后标志位
        uint8 decimals=IERC20Metadata(_tokenAddress).decimals();
        uint256 total = _price*_amount;  
        require(total>=10*(10**decimals),"less");

        TimeLibrary.tradeState newTradeState;
        if(doState==0){
            newTradeState=TimeLibrary.tradeState.buying;
        }else if(doState==1){
            newTradeState=TimeLibrary.tradeState.selling;
        }else{
            revert("Invalid order");
        }

        //清算时间24h前不能挂单
        // require(block.timestamp<=getClearTime()-1 days,"Not time");
        
        //将代币转入该合约
        IERC20(_tokenAddress).safeTransferFrom(msg.sender,address(this),total);
        //授权给AAVE V3的pool
        IERC20(_tokenAddress).approve(address(AaveV3Pool),total);
        //供应到AAVE V3
        AaveV3Pool.supply(
            _tokenAddress,       //供应的token地址
            total,               //供应数量
            timeCapitalPool,       //接收a token地址
            0                    //当前referralCode=0
        );

        uint256 thisNftId=mintNft(msg.sender,id,total,doState,_tokenAddress);

        _tradeMes[id] = TimeLibrary.tradeMes({
            tradeId:id,
            time:uint32(block.timestamp),
            amount:_amount,
            price:_price,
            usedToken:_tokenAddress,
            buyerNftId:doState==0?thisNftId:0,
            sellerNftId:doState==1?thisNftId:0,
            injectNftId:0,
            _tradeState:newTradeState
        });
        id++;
        
    }

    //匹配订单
    function matchTrade(uint32 _id) external{
        uint256 state;
        if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying){
            state=0;
        }else if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling){
            state=1;
        }else{
            revert("Invalid order");
        }

        //清算时间24h前不能买入或卖出
        // require(block.timestamp<=getClearTime()-1 days,"Not time");
        TimeLibrary.tradeMes memory maxTradeMes=_tradeMes[_id];
        address _tokenAddress=maxTradeMes.usedToken;
        uint256 total=maxTradeMes.price*maxTradeMes.amount;
        //质押违约金
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            total
        );

        //授权给AAVE V3的pool
        IERC20(_tokenAddress).approve(address(AaveV3Pool),total);
        //供应到AAVE V3
        AaveV3Pool.supply(
            _tokenAddress,       //供应的token地址
            total,               //供应数量
            timeCapitalPool,       //接收a token地址
            0                    //当前referralCode=0
        );

        uint256 thisNftId=mintNft(msg.sender,_id,total,state,_tokenAddress);
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.found;
        if(state==0){
            _tradeMes[_id].sellerNftId=thisNftId;
        }else if(state==1){
            _tradeMes[_id].buyerNftId=thisNftId;
        }else{
            revert("Invalid order");
        }
    }

    //取消订单
    function cancelOrder(uint32 _id,address aToken)external{
        uint256 _nftId;
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying){
            _nftId==_tradeMes[_id].buyerNftId;
        }else if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling){
            _nftId==_tradeMes[_id].sellerNftId;
        }else{
            revert("Invalid order");
        }
        require(getNftOwner(_nftId)==msg.sender,"Non owner");
        // require(block.timestamp<=getClearTime()-1 days,"Time closed");
        //该NFT质押的数量
        uint256 amount=IERC721(timeCapitalPool).getNftTradeIdMes(_nftId).value;
        require(amount>0,"Not deposite");
        address usedToken=_tradeMes[_id].usedToken;
        //从timeCapitalPool取回a token
        ITimeCapitalPool(timeCapitalPool).approveMarket(aToken,amount);
        IERC20(aToken).safeTransferFrom(timeCapitalPool,address(this),amount);
        //授权给AaveV3Pool
        IERC20(aToken).approve(address(AaveV3Pool),amount);
        //从aave v3提取供应的代币数量
        AaveV3Pool.withdraw(
            usedToken,
            amount,
            msg.sender
        );
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.inexistence;
        //删除该nft质押token信息
        require(ITimeCapitalPool(timeCapitalPool).burnNft(_nftId),"Burn fail");
    }

    //交易未达成,退款
    function refund(uint32 _id,address aToken)external{
        uint256 _nftId;
        require(judgeInputAToken(aToken)==1,"Non allowed token");
        // require(block.timestamp>getClearTime(),"Time has not arrived");
        if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.buying){
            _nftId==_tradeMes[_id].buyerNftId;
        }else if(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.selling){
            _nftId==_tradeMes[_id].sellerNftId;
        }else{
            revert("Invalid order");
        }
        require(getNftOwner(_nftId)==msg.sender,"Non owner");
        //该NFT质押的数量
        uint256 amount=IERC721(timeCapitalPool).getNftTradeIdMes(_nftId).value;
        address _usedToken=_tradeMes[_id].usedToken;
        //从timeCapitalPool取回a token
        ITimeCapitalPool(timeCapitalPool).approveMarket(aToken,amount);
        IERC20(aToken).safeTransferFrom(timeCapitalPool,address(this),amount);

        //授权给AaveV3Pool
        IERC20(aToken).approve(address(AaveV3Pool),amount);
        uint256 beforeAmount=IERC20(_usedToken).balanceOf(msg.sender);
        //从aave v3提取供应的代币数量
        AaveV3Pool.withdraw(
            _usedToken,
            amount,
            msg.sender
        );
        uint256 afterAmount=IERC20(_usedToken).balanceOf(msg.sender);
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.inexistence;
        emit RefundEvent(_id,afterAmount-beforeAmount,msg.sender);
        require(ITimeCapitalPool(timeCapitalPool).burnNft(_nftId),"Burn fail");
    }

    //交易达成,支付期权token
    function deposite(uint32 _id)external{
        require(_tradeMes[_id]._tradeState==TimeLibrary.tradeState.found,"Not found");
        uint256 buyerNftId=_tradeMes[_id].buyerNftId;
        uint256 sellerNftId=_tradeMes[_id].sellerNftId;
        address buyer=getNftOwner(buyerNftId);
        require(getNftOwner(sellerNftId)==msg.sender,"Non seller");
        uint256 amount=_tradeMes[_id].amount;
        address targetToken=getTargetToken();
        uint8 decimals=IERC20Metadata(targetToken).decimals();
        uint256 targetTokenAmount=amount*(10**decimals);
        IERC20(targetToken).safeTransferFrom(msg.sender,address(this),targetTokenAmount);
        uint256 nftId=mintNft(buyer,_id,targetTokenAmount,2,targetToken);
        _tradeMes[_id]._tradeState=TimeLibrary.tradeState.done;
        _tradeMes[_id].injectNftId=nftId;
    }

    //铸造nft
    function mintNft(address receiver,uint32 tradeId,uint256 value,uint256 state,address token)private returns(uint256){
        uint256 thisNftId=ITimeCapitalPool(timeCapitalPool).marketMint(receiver,thisMarketId,tradeId,value,state,token);
        return thisNftId;
    }

    //判断传入token是否允许
    function judgeInputStableToken(address inputToken)private view returns(uint256 state){
        address[] memory allowedTokens=ITimeGovern(timeGovern).getAllowedStableToken();
        state=TimeLibrary.judgeInputToken(inputToken,allowedTokens);
    }

    //判断传入的a token是否允许
    function judgeInputAToken(address inputAToken)private view returns(uint256 state){
        address[] memory allowedATokens=ITimeGovern(timeGovern).getAllowedATokens();
        state=TimeLibrary.judgeInputToken(inputAToken,allowedATokens);
    }

    //得到nft所有者
    function getNftOwner(uint256 _nftId)private view returns(address){
        return ITimeCapitalPool(timeCapitalPool).ownerOf(_nftId);
    }

    //返回当前清算时间
    function getClearTime()private view returns(uint256){
       return ITimeGovern(timeGovern).getClearingTime(thisMarketId);
    }

    //返回当前目标token
    function getTargetToken()private view returns(address){
        return ITimeGovern(timeGovern).getTargetToken(thisMarketId);
    }

    //根据交易id得到_tradeMes
    function getTradeMes(uint32 _id)external view returns(TimeLibrary.tradeMes memory){
        return _tradeMes[_id];
    }

    //最新的订单id
    function getLastId()external view returns(uint256){
        return id;
    }

}