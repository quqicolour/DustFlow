require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
// require("@nomiclabs/hardhat-etherscan");


task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  networks: {
    PolygonMumbai: {
      url: process.env.POLYGON_MUMBAI,
      accounts: [process.env.PRIVATE_KEY]
    },
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200
      }
    }
  },
  etherscan: {
    apiKey: process.env.POLYGON_MUMBAI_API_KEY
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 4000
  }
};
