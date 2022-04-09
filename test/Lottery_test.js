const { expect, assert, use } = require("chai");
const { network, ethers, web3 } = require("hardhat");
const { Contract, BigNumber, providers } = require("ethers");
const { Web3Provider } = require("@ethersproject/providers");
const { constants, time } = require('@openzeppelin/test-helpers');
const { printGas, toDays } = require("./utils");
const { latest } = require("@openzeppelin/test-helpers/src/time");
const { utils } = require("web3");

describe("Lottery", function () {

  // CONTRACT //
    let Lottery;
    let lottery;
  // TOKENS ACCEPTED //
    const dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  // LOTTERIES //
    const price = 10;
    const _numberOfLotteries = 2;
  // SIGNERS //    
    let owner;   
    
// BEFORE EACH TEST //
  
beforeEach(async function () {
    // THE CONTRACT IS INITIALIZED //    
    Lottery = await ethers.getContractFactory("Lottery");
    // THE INTERFACES ARE INITIALIZED //
    DAI = await ethers.getContractAt("IERC20Upgradeable", dai);
    USDC = await ethers.getContractAt("IERC20Upgradeable", usdc);
    USDT = await ethers.getContractAt("IERC20Upgradeable", usdt); 
    // THE ACCOUNTS AND SIGNERS ARE INITIALIZED // 
    [owner] = await ethers.getSigners();  
  });
// START OF THE TESTS //
it("Should deploy the lottery contract, first version, upgradeable", async function (){
  lottery = await upgrades.deployProxy(Lottery);
  await lottery.deployed(); 
  const lotteryAddress = lottery.address;     
});  
it("Should set the fee", async function (){
  const _fee = BigNumber.from(5);
  await lottery.setFee(_fee);
});
it("Should set the ticket price to 10 DAI", async function (){
  await lottery.setTicketPrice(price);
});
it("Should get the actual ticket price", async function (){
  const expectedPrice = await lottery.getTicketPrice();
  console.log("Ticket Price", expectedPrice);
});
it("Should fail to buy a ticket if there is no lotteries actives when paying with DAI",
async function (){
    await expect(lottery.buyTicketWithDai(10, dai)).
      to.be.revertedWith("There are no lotteries active right now");
});
it("Should fail to buy a ticket if there is no lotteries actives when paying with tokens", 
async function (){
    await expect(lottery.buyTicketWithTokens(10, usdt)).
      to.be.revertedWith("There are no lotteries active right now");
});
it("Should start the lotteries", async function (){
  await lottery.startLottery(_numberOfLotteries);
});
it("Should fail to buy a ticket if the token is incorrect when calling buying with DAI",
    async function (){
      await expect(lottery.buyTicketWithDai(price, usdt)).
        to.be.revertedWith("We only accept DAI within this function.");
});
it("Should fail to buy a ticket if the token is incorrect when calling buying with tokens",
    async function (){
      await expect(lottery.buyTicketWithTokens(price, dai)).
        to.be.revertedWith("We only accept USDT or USDC tokens within this function.");
});
it("Should fail to buy a ticket if the payment is less than needed when paying with DAI", 
    async function (){
      await expect(lottery.buyTicketWithDai(0, dai)).
        to.be.revertedWith("You have to buy at least one ticket.");
});
it("Should fail to buy a ticket if the payment is less than needed when paying with tokens", 
    async function (){
      await expect(lottery.buyTicketWithTokens(0, usdc)).
        to.be.revertedWith("You have to buy at least one ticket.");
});
it("Should buy tickets to the actual lottery with DAI", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x1e3D6eAb4BCF24bcD04721caA11C478a2e59852D"],
    });
  const daiBuyer = await ethers.getSigner("0x1e3D6eAb4BCF24bcD04721caA11C478a2e59852D")
  daiBuyer.sendTransaction();  

  await DAI.connect(daiBuyer).approve(lottery.address, 500);
  await expect(lottery.connect(daiBuyer).buyTicketWithDai(50, dai)).to.emit
    (lottery,"newPlayer").withArgs(daiBuyer.address, 50, 5, 1, true); 


  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0x1e3D6eAb4BCF24bcD04721caA11C478a2e59852D"],
  });
});
it("Should buy tickets to the actual lottery with other token", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0xCFFAd3200574698b78f32232aa9D63eABD290703"],
    });
  const usdcBuyer = await ethers.getSigner("0xCFFAd3200574698b78f32232aa9D63eABD290703")
  usdcBuyer.sendTransaction();  

  await USDC.connect(usdcBuyer).approve(lottery.address, 500);
  await expect(lottery.connect(usdcBuyer).buyTicketWithTokens(50, usdc)).to.emit
    (lottery,"newPlayer").withArgs(usdcBuyer.address, 50, 5, 1, true);
   
  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0xCFFAd3200574698b78f32232aa9D63eABD290703"],
  });
});
it("Should retire from the lottery", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x1B7BAa734C00298b9429b518D621753Bb0f6efF2"],
    });
  const retire = await ethers.getSigner("0x1B7BAa734C00298b9429b518D621753Bb0f6efF2")
  retire.sendTransaction();  

  await DAI.connect(retire).approve(lottery.address, 500);
  await lottery.connect(retire).buyTicketWithDai(50, dai);
  await lottery.connect(retire).retirement();


  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0x1B7BAa734C00298b9429b518D621753Bb0f6efF2"],
  });
});
it("Should fail to invest in Compound out of the time", async function (){   
  await expect(lottery.potInvestment(1)).to.be.revertedWith("You can not invest yet.");
});
it("Should fail to retire from Compound out of the time", async function (){   
  await expect(lottery.retireInvestment(1)).to.be.revertedWith("You can not retire the money yet.");
});
it("Should invest in Compound", async function (){   
  await time.increase(time.duration.days(2));
  await lottery.potInvestment(1);
});
it("Should buy tickets to the next lottery with DAI", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4"],
    });
  const daiSecondBuyer = await ethers.getSigner("0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4")
  daiSecondBuyer.sendTransaction();  

  await DAI.connect(daiSecondBuyer).approve(lottery.address, 500);
  await expect(lottery.connect(daiSecondBuyer).buyTicketWithDai(50, dai)).to.emit
    (lottery,"newPlayer").withArgs(daiSecondBuyer.address, 50, 5, 2, true); 

  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4"],
  });
});
it("Should buy tickets to the next lottery with other tokens", async function (){
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0xe31A9498a22493Ab922bc0EB240313A46525Ee0A"],
    });
  const usdcSecondBuyer = await ethers.getSigner("0xe31A9498a22493Ab922bc0EB240313A46525Ee0A")
  usdcSecondBuyer.sendTransaction();  

  await USDC.connect(usdcSecondBuyer).approve(lottery.address, 500);
  await expect(lottery.connect(usdcSecondBuyer).buyTicketWithTokens(50, usdc)).to.emit
    (lottery,"newPlayer").withArgs(usdcSecondBuyer.address, 50, 5, 2, true);
   
  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0xe31A9498a22493Ab922bc0EB240313A46525Ee0A"],
  }); 

});
it("Should retrieve the investment from Compound", async function (){ 
  await time.increase(time.duration.days(5));
  await lottery.retireInvestment(1);
});
it("Should fail to get a random number if the contract does not have Link", async function (){
  await expect(lottery.pickWinner()).to.be.revertedWith("Not enough LINK to pay fee");
});
it("Should ask for the random number and pay", async function (){   
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x500A746c9a44f68Fe6AA86a92e7B3AF4F322Ae66"],
    });
  const link = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  LINK = await ethers.getContractAt("IERC20Upgradeable", link);
  const linker = await ethers.getSigner("0x500A746c9a44f68Fe6AA86a92e7B3AF4F322Ae66")
  linker.sendTransaction();  

  await LINK.connect(linker).approve(lottery.address, 500);
  await LINK.connect(linker).transferFrom(linker.address, lottery.address, 500);
  
  const random = await lottery.pickWinner();
  console.log("VRF response", random);
   
  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: ["0x500A746c9a44f68Fe6AA86a92e7B3AF4F322Ae66"],
  });  

});
})
