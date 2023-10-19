//SPDX-License-Identifier:MIT
pragma solidity >=0.8.9;

library TimeFee{
    /*
        *  100 ether<=amount<1000 ether, 1%
        *  1000 ether<=amount<10000 ether,0.5%
        *  amount>10000 ether,0.25%
        * other error
    */
    function fee(uint256 stableAmount)internal pure returns(uint256 stableFee){
        if(stableAmount>=100 ether && stableAmount<1000 ether){
            return stableAmount/100;
        }else if(stableAmount>=1000 ether && stableAmount<10000 ether){
            return stableAmount/200;
        }else if(stableAmount>=10000 ether){
            return stableAmount/400;
        }else{
            return 0;
        }
    }
}