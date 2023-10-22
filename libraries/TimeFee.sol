//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;

library TimeFee{
    /*
        *  100 ether<=amount<1000 ether, 1%
        *  1000 ether<=amount<10000 ether,0.8%
        *  amount>10000 ether,0.5%
        * other error
    */
    function fee(uint8 _decimals,uint256 stableAmount)internal pure returns(uint256 stableFee){
        uint256 digit=10**_decimals;
        if(stableAmount>=100*digit && stableAmount<1000*digit){
            return stableAmount/100;
        }else if(stableAmount>=1000*digit && stableAmount<10000*digit){
            return stableAmount/125;
        }else if(stableAmount>=10000*digit){
            return stableAmount/200;
        }else{
            return 0;
        }
    }
}