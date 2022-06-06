//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeed {
    AggregatorV3Interface internal btcPriceFeed;
    AggregatorV3Interface internal daiPriceFeed;
    AggregatorV3Interface internal ethPriceFeed;
    

  

    constructor() {
        btcPriceFeed = AggregatorV3Interface(0x007A22900a3B98143368Bd5906f8E17e9867581b);
        daiPriceFeed = AggregatorV3Interface(0x0FCAa9c899EC5A91eBc3D5Dd869De833b06fB046);
        ethPriceFeed = AggregatorV3Interface(0x0715A7794a1dc8e42615F059dD6e406A6594651A);
         
    }

 

     function getLatestBtcPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int btcPrice,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = btcPriceFeed.latestRoundData();
        return btcPrice ;
    }

   


    function getLatestDaiPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int daiPrice,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = daiPriceFeed.latestRoundData();
        return daiPrice ;
    }



    function getLatestEthPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int ethPrice,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = ethPriceFeed.latestRoundData();
        return ethPrice ;
    }



    
}